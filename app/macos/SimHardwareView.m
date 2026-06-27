/*
 * EASy68K for macOS
 *
 * Copyright (c) 2026 mikewolak@gmail.com  —  Epromfoundry, Inc.
 * All rights reserved.
 *
 * ****  NOT FOR COMMERCIAL USE  ****
 * This software is licensed for PERSONAL and EDUCATIONAL use ONLY.
 * Any commercial use, sale, or distribution for profit is STRICTLY
 * PROHIBITED without the prior written permission of Epromfoundry, Inc.
 */

//
//  SimHardwareView.m
//
#import "SimHardwareView.h"
#import "SimCore.h"

#define ADDRMASK 0x00FFFFFF

#pragma mark - one 7-segment digit

@interface SevenSegView : NSView
@property (nonatomic) uint8_t value;   // bit0=a … bit6=g, bit7=dp
@end

@implementation SevenSegView
- (BOOL)isFlipped { return YES; }
- (void)setValue:(uint8_t)v { _value = v; self.needsDisplay = YES; }
- (void)drawRect:(NSRect)r {
    CGFloat W = NSWidth(self.bounds), H = NSHeight(self.bounds);
    CGFloat t = MIN(W, H) * 0.16;                 // segment thickness
    NSColor *on = NSColor.systemRedColor;
    NSColor *off = [NSColor colorWithCalibratedRed:0.25 green:0.0 blue:0.05 alpha:1.0];
    // segment rects (a b c d e f g) in a top-left coordinate system
    NSRect seg[7] = {
        NSMakeRect(t, 0, W-2*t, t),               // a  top
        NSMakeRect(W-t, t, t, H/2-t),             // b  top-right
        NSMakeRect(W-t, H/2, t, H/2-t),           // c  bottom-right
        NSMakeRect(t, H-t, W-2*t, t),             // d  bottom
        NSMakeRect(0, H/2, t, H/2-t),             // e  bottom-left
        NSMakeRect(0, t, t, H/2-t),               // f  top-left
        NSMakeRect(t, H/2-t/2, W-2*t, t),         // g  middle
    };
    for (int i = 0; i < 7; i++) {
        [((_value >> i) & 1) ? on : off setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(seg[i],0.5,0.5) xRadius:1 yRadius:1] fill];
    }
    // decimal point (bit7)
    [((_value >> 7) & 1) ? on : off setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(W-t, H-t, t, t)] fill];
}
@end

#pragma mark - Hardware window

@implementation SimHardwareView {
    SevenSegView *_seg[8];
    NSView       *_led[8];
    NSButton     *_switch[8];
    NSTextField  *_seg7Field, *_ledField, *_switchField, *_pbField;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _seg7Addr = 0x00FF8000; _ledAddr = 0x00FF8010;
        _switchAddr = 0x00FF8020; _pbAddr = 0x00FF8030;
        [self buildControls];
        [self refresh];
    }
    return self;
}
- (BOOL)isFlipped { return YES; }

- (NSTextField *)addrFieldDefault:(uint32_t)v {
    NSTextField *tf = [[NSTextField alloc] init];
    tf.stringValue = [NSString stringWithFormat:@"%08X", v];
    tf.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    tf.target = self; tf.action = @selector(addrChanged:);
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    [tf.widthAnchor constraintEqualToConstant:90].active = YES;
    return tf;
}

- (void)buildControls {
    // ---- 7-segment row ----
    NSStackView *segRow = [NSStackView stackViewWithViews:@[]];
    segRow.spacing = 8;
    for (int i = 0; i < 8; i++) {
        _seg[i] = [[SevenSegView alloc] initWithFrame:NSMakeRect(0,0,34,54)];
        [_seg[i].widthAnchor constraintEqualToConstant:34].active = YES;
        [_seg[i].heightAnchor constraintEqualToConstant:54].active = YES;
        [segRow addView:_seg[i] inGravity:NSStackViewGravityLeading];
    }

    // ---- LED row ----
    NSStackView *ledRow = [NSStackView stackViewWithViews:@[]];
    ledRow.spacing = 14; ledRow.alignment = NSLayoutAttributeCenterY;
    for (int i = 7; i >= 0; i--) {     // LED7 … LED0 left→right (bit7 first)
        NSView *l = [[NSView alloc] initWithFrame:NSMakeRect(0,0,22,22)];
        l.wantsLayer = YES; l.layer.cornerRadius = 11;
        l.layer.borderWidth = 1; l.layer.borderColor = NSColor.tertiaryLabelColor.CGColor;
        [l.widthAnchor constraintEqualToConstant:22].active = YES;
        [l.heightAnchor constraintEqualToConstant:22].active = YES;
        _led[i] = l;
        [ledRow addView:l inGravity:NSStackViewGravityLeading];
    }

    // ---- switch row ----
    NSStackView *swRow = [NSStackView stackViewWithViews:@[]];
    swRow.spacing = 10;
    for (int i = 7; i >= 0; i--) {     // switch7 … switch0
        NSButton *b = [NSButton buttonWithTitle:[NSString stringWithFormat:@"%d", i]
                                         target:self action:@selector(switchToggled:)];
        b.buttonType = NSButtonTypePushOnPushOff;
        b.bezelStyle = NSBezelStyleSmallSquare;
        b.tag = i;
        [b.widthAnchor constraintEqualToConstant:30].active = YES;
        _switch[i] = b;
        [swRow addView:b inGravity:NSStackViewGravityLeading];
    }

    // ---- address fields ----
    _seg7Field   = [self addrFieldDefault:_seg7Addr];
    _ledField    = [self addrFieldDefault:_ledAddr];
    _switchField = [self addrFieldDefault:_switchAddr];
    _pbField     = [self addrFieldDefault:_pbAddr];

    NSGridView *grid = [NSGridView gridViewWithViews:@[
        @[[self label:@"7-Segment Displays"], segRow],
        @[[self label:@"Address"], _seg7Field],
        @[[self label:@"LEDs"], ledRow],
        @[[self label:@"Address"], _ledField],
        @[[self label:@"Switches"], swRow],
        @[[self label:@"Address"], _switchField],
        @[[self label:@"Push-Button Address"], _pbField],
    ]];
    grid.rowSpacing = 12; grid.columnSpacing = 16;
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    [grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;
    [self addSubview:grid];
    [NSLayoutConstraint activateConstraints:@[
        [grid.topAnchor constraintEqualToAnchor:self.topAnchor constant:18],
        [grid.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
    ]];
}

- (NSTextField *)label:(NSString *)s {
    NSTextField *l = [NSTextField labelWithString:s];
    l.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    return l;
}

#pragma mark address config

- (void)addrChanged:(NSTextField *)tf {
    unsigned v = 0; sscanf(tf.stringValue.UTF8String ?: "", "%x", &v);
    if (tf == _seg7Field)   _seg7Addr   = v & ADDRMASK;
    else if (tf == _ledField)    _ledAddr    = v & ADDRMASK;
    else if (tf == _switchField) _switchAddr = v & ADDRMASK;
    else if (tf == _pbField)     _pbAddr     = v & ADDRMASK;
    [self refresh];
}

#pragma mark switches (write memory the program reads)

- (void)switchToggled:(NSButton *)b {
    if (!memory) return;
    int bit = (int)b.tag;
    uint32_t a = _switchAddr & ADDRMASK;
    if (b.state == NSControlStateValueOn) memory[a] |= (1 << bit);
    else                                  memory[a] &= ~(1 << bit);
}

#pragma mark display refresh (program writes LEDs/segments)

- (void)memoryChangedAt:(int)loc {
    int a = loc & ADDRMASK;
    if ((a >= (int)_seg7Addr - 4 && a <= (int)_seg7Addr + 15) ||
        (a >= (int)_ledAddr  - 4 && a <= (int)_ledAddr))
        dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
}

- (void)refresh {
    if (!memory) return;
    for (int i = 0; i < 8; i++)
        _seg[i].value = (uint8_t)memory[(_seg7Addr + i * 2) & ADDRMASK];
    uint8_t leds = (uint8_t)memory[_ledAddr & ADDRMASK];
    for (int i = 0; i < 8; i++) {
        BOOL on = (leds >> i) & 1;
        _led[i].layer.backgroundColor = on
            ? [NSColor colorWithCalibratedRed:0.20 green:1.0 blue:0.30 alpha:1.0].CGColor
            : [NSColor colorWithCalibratedRed:0.05 green:0.18 blue:0.07 alpha:1.0].CGColor;
    }
}

@end
