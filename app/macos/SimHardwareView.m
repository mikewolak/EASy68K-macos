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
//  Pixel-exact reconstruction of Sim68K's hardwareu.dfm (422x495): a black
//  Panel2 holding eight 7-segment displays, a gray Panel1 holding eight red
//  LEDs, eight bitmap toggle switches (the original toggleswitch.bmp) and the
//  four memory-mapped address fields — rendered with Core Graphics gradients so
//  it reads richer than the Windows original.
//
#import "SimHardwareView.h"
#import "SimCore.h"

#define ADDRMASK 0x00FFFFFF

// Panels (from the .dfm, in 422x495 form coordinates, y-down)
static const CGRect kPanel2 = {{8, 8},  {329, 69}};   // 7-seg, black
static const CGRect kPanel1 = {{8, 84}, {329, 33}};   // LEDs, gray

@implementation SimHardwareView {
    NSButton    *_switch[8];
    NSTextField *_seg7Field, *_ledField, *_switchField, *_pbField;
    uint8_t      _segVal[8];
    uint8_t      _ledVal;
    // memory map editor
    NSButton    *_mapChk[4];
    NSTextField *_mapStart[4], *_mapEnd[4];
    // auto interrupt
    NSPopUpButton *_autoIRQ;
    NSTextField   *_autoInterval;
    NSButton      *_autoBtn;
    NSTimer       *_autoTimer;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:NSMakeRect(0,0,462,495)])) {
        _seg7Addr = 0x00FF8000; _ledAddr = 0x00FF8010;
        _switchAddr = 0x00FF8020; _pbAddr = 0x00FF8030;
        [self buildControls];
        [self refresh];
    }
    return self;
}
- (BOOL)isFlipped { return YES; }

#pragma mark layout

- (NSImage *)image:(NSString *)name {
    NSImage *im = [NSImage imageNamed:name];
    if (!im) {
        NSString *p = [[NSBundle mainBundle] pathForResource:name ofType:@"png"];
        if (p) im = [[NSImage alloc] initWithContentsOfFile:p];
    }
    return im;
}

- (NSTextField *)addrFieldAt:(CGFloat)x y:(CGFloat)y value:(uint32_t)v {
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, 70, 22)];
    tf.stringValue = [NSString stringWithFormat:@"%08X", v];
    tf.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    tf.alignment = NSTextAlignmentCenter;
    tf.target = self; tf.action = @selector(addrChanged:);
    [self addSubview:tf];
    return tf;
}

- (void)buildControls {
    NSImage *off = [self image:@"switch_off"], *on = [self image:@"switch_on"];
    // eight toggle switches — switch7 (bit7) leftmost … switch0 (bit0) rightmost.
    // NSButtonTypeToggle persistently shows the alternate (on) image while the
    // button's state is on, so the switch visibly stays flipped.
    for (int b = 7; b >= 0; b--) {
        CGFloat x = 16 + 40 * (7 - b);
        NSButton *sw = [[NSButton alloc] initWithFrame:NSMakeRect(x, 130, 29, 45)];
        sw.buttonType = NSButtonTypeToggle;
        sw.bordered = NO; sw.imagePosition = NSImageOnly; sw.imageScaling = NSImageScaleProportionallyUpOrDown;
        sw.image = off; sw.alternateImage = on ?: off;
        sw.tag = b; sw.target = self; sw.action = @selector(switchToggled:);
        sw.toolTip = [NSString stringWithFormat:@"Switch %d (bit %d) — click to toggle", b, b];
        _switch[b] = sw;
        [self addSubview:sw];
    }

    // "Address:" labels + the four memory-mapped address fields (x=362 region,
    // y from the .dfm: seg7=48, LED=96, switch=152, pb=200)
    CGFloat ys[4]   = {48, 96, 152, 200};
    NSString *caps[4] = {@"7-Seg", @"LEDs", @"Switch", @"Buttons"};
    uint32_t vals[4] = {_seg7Addr, _ledAddr, _switchAddr, _pbAddr};
    for (int i = 0; i < 4; i++) {
        // Caption above each field (the field IS the address). The window is
        // widened on the right so the full "<section> Address" caption fits.
        NSTextField *cap = [NSTextField labelWithString:[caps[i] stringByAppendingString:@" Address"]];
        cap.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
        cap.frame = NSMakeRect(348, ys[i] - 17, 110, 14);
        [self addSubview:cap];
        NSTextField *field = [self addrFieldAt:348 y:ys[i] value:vals[i]];
        if (i == 0) _seg7Field = field;
        else if (i == 1) _ledField = field;
        else if (i == 2) _switchField = field;
        else _pbField = field;
    }
    [self buildLowerSections];
}

- (NSBox *)groupBox:(NSString *)title frame:(NSRect)f {
    NSBox *b = [[NSBox alloc] initWithFrame:f];
    b.title = title; b.titleFont = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    [self addSubview:b];
    return b;
}
- (NSTextField *)smallLabel:(NSString *)s frame:(NSRect)f in:(NSView *)v {
    NSTextField *l = [NSTextField labelWithString:s];
    l.font = [NSFont systemFontOfSize:10]; l.frame = f; [v addSubview:l]; return l;
}
- (NSTextField *)hexField:(NSRect)f in:(NSView *)v {
    NSTextField *tf = [[NSTextField alloc] initWithFrame:f];
    tf.font = [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular];
    tf.stringValue = @"00000000"; tf.target = self; tf.action = @selector(mapChanged:);
    [v addSubview:tf]; return tf;
}

- (void)buildLowerSections {
    // ---- Interrupt group: seven IRQ push buttons (1..7) ----
    NSBox *irqBox = [self groupBox:@"Interrupt" frame:NSMakeRect(8, 232, 196, 92)];
    NSView *ic = irqBox.contentView;
    for (int n = 1; n <= 7; n++) {
        NSButton *pb = [NSButton buttonWithTitle:[NSString stringWithFormat:@"%d", n]
                                          target:self action:@selector(irqButton:)];
        pb.frame = NSMakeRect(6 + (n-1)*26, 20, 24, 38);
        pb.bezelStyle = NSBezelStyleSmallSquare; pb.tag = n;
        pb.toolTip = [NSString stringWithFormat:@"Trigger IRQ %d", n];
        [ic addSubview:pb];
    }

    // ---- Auto Interval group ----
    NSBox *autoBox = [self groupBox:@"Auto Interval" frame:NSMakeRect(212, 232, 132, 92)];
    NSView *ac = autoBox.contentView;
    [self smallLabel:@"IRQ" frame:NSMakeRect(8, 48, 26, 14) in:ac];
    _autoIRQ = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(36, 44, 52, 22)];
    [_autoIRQ addItemsWithTitles:@[@"1",@"2",@"3",@"4",@"5",@"6",@"7"]];
    [ac addSubview:_autoIRQ];
    _autoInterval = [[NSTextField alloc] initWithFrame:NSMakeRect(8, 16, 46, 20)];
    _autoInterval.stringValue = @"500";
    [ac addSubview:_autoInterval];
    [self smallLabel:@"mS" frame:NSMakeRect(56, 18, 20, 14) in:ac];
    _autoBtn = [NSButton buttonWithTitle:@"Start" target:self action:@selector(autoToggle:)];
    _autoBtn.frame = NSMakeRect(78, 14, 50, 24); _autoBtn.bezelStyle = NSBezelStyleRounded;
    [ac addSubview:_autoBtn];

    // ---- Reset group ----
    NSBox *resetBox = [self groupBox:@"Reset" frame:NSMakeRect(352, 232, 100, 92)];
    NSButton *rb = [NSButton buttonWithTitle:@"Reset IRQ" target:self action:@selector(resetIRQ:)];
    rb.frame = NSMakeRect(12, 24, 76, 32); rb.bezelStyle = NSBezelStyleRounded;
    [resetBox.contentView addSubview:rb];

    // ---- Memory Map group ----
    NSBox *mapBox = [self groupBox:@"Memory Map" frame:NSMakeRect(8, 332, 406, 150)];
    NSView *mc = mapBox.contentView;
    [self smallLabel:@"Start" frame:NSMakeRect(120, 104, 80, 14) in:mc];
    [self smallLabel:@"End"   frame:NSMakeRect(240, 104, 80, 14) in:mc];
    NSString *names[4] = {@"ROM", @"Read-only", @"Protected", @"Invalid"};
    for (int i = 0; i < 4; i++) {
        CGFloat y = 78 - i * 26;
        _mapChk[i] = [NSButton checkboxWithTitle:names[i] target:self action:@selector(mapChanged:)];
        _mapChk[i].frame = NSMakeRect(10, y, 100, 20); _mapChk[i].tag = i;
        [mc addSubview:_mapChk[i]];
        _mapStart[i] = [self hexField:NSMakeRect(120, y, 100, 20) in:mc];
        _mapEnd[i]   = [self hexField:NSMakeRect(240, y, 100, 20) in:mc];
    }
}

#pragma mark interrupt + map actions

- (void)irqButton:(NSButton *)b {
    int n = (int)b.tag;
    if (n >= 1 && n <= 7) irq |= (0x01 << (n - 1));   // pend IRQ n (run.c services it)
}
- (void)resetIRQ:(id)sender { irq = 0; }

- (void)autoToggle:(NSButton *)b {
    if (_autoTimer) {
        [_autoTimer invalidate]; _autoTimer = nil; _autoBtn.title = @"Start";
    } else {
        double ms = MAX(10, _autoInterval.doubleValue);
        int n = (int)_autoIRQ.indexOfSelectedItem + 1;
        _autoBtn.title = @"Stop";
        _autoTimer = [NSTimer scheduledTimerWithTimeInterval:ms/1000.0 repeats:YES block:^(NSTimer *t) {
            irq |= (0x01 << (n - 1));
        }];
    }
}

- (void)mapChanged:(id)sender {
    int starts[4], ends[4]; bool en[4];
    for (int i = 0; i < 4; i++) {
        unsigned s = 0, e = 0;
        sscanf(_mapStart[i].stringValue.UTF8String ?: "0", "%x", &s);
        sscanf(_mapEnd[i].stringValue.UTF8String ?: "0", "%x", &e);
        starts[i] = (int)(s & ADDRMASK); ends[i] = (int)(e & ADDRMASK);
        en[i] = (_mapChk[i].state == NSControlStateValueOn);
    }
    ROMStart = starts[0]; ROMEnd = ends[0]; ROMMap = en[0];
    ReadStart = starts[1]; ReadEnd = ends[1]; ReadMap = en[1];
    ProtectedStart = starts[2]; ProtectedEnd = ends[2]; ProtectedMap = en[2];
    InvalidStart = starts[3]; InvalidEnd = ends[3]; InvalidMap = en[3];
}

#pragma mark drawing — panels, LEDs, 7-segment digits

- (void)drawRect:(NSRect)dirty {
    // Panel2 (7-seg, black with a soft inner glow)
    [self drawPanel:kPanel2 top:[NSColor colorWithWhite:0.10 alpha:1] bottom:NSColor.blackColor radius:6];
    // Panel1 (LEDs, brushed gray)
    [self drawPanel:kPanel1 top:[NSColor colorWithWhite:0.62 alpha:1] bottom:[NSColor colorWithWhite:0.46 alpha:1] radius:6];

    // 7-segment displays inside Panel2: display d (0=left) -> memory[seg7loc+2d]
    for (int d = 0; d < 8; d++) {
        CGFloat bx = kPanel2.origin.x + 12 + 40 * d;   // 'a' segment left
        CGFloat by = kPanel2.origin.y + 8;
        [self drawDigit:_segVal[d] baseX:bx baseY:by];
    }

    // LEDs inside Panel1: bit b (7=left … 0=right)
    for (int b = 7; b >= 0; b--) {
        CGFloat x = kPanel1.origin.x + 16 + 40 * (7 - b);
        CGFloat y = kPanel1.origin.y + 8;
        [self drawLED:((_ledVal >> b) & 1) inRect:NSMakeRect(x, y, 17, 17)];
    }
}

- (void)drawPanel:(CGRect)r top:(NSColor *)t bottom:(NSColor *)b radius:(CGFloat)rad {
    NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:rad yRadius:rad];
    NSGradient *g = [[NSGradient alloc] initWithStartingColor:t endingColor:b];
    [g drawInBezierPath:p angle:-90];
    [[NSColor colorWithWhite:0 alpha:0.5] setStroke]; p.lineWidth = 1; [p stroke];
}

// One 7-segment digit. value bits: a=01 b=02 c=04 d=08 e=10 f=20 g=40 dp=80.
- (void)drawDigit:(uint8_t)v baseX:(CGFloat)bx baseY:(CGFloat)by {
    NSColor *on  = [NSColor colorWithCalibratedRed:1.0 green:0.16 blue:0.13 alpha:1.0];
    NSColor *off = [NSColor colorWithCalibratedRed:0.22 green:0.02 blue:0.03 alpha:1.0];
    // segment rects relative to the 'a' top-left (bx,by)
    CGRect seg[7] = {
        CGRectMake(bx,    by,    20, 5),   // a
        CGRectMake(bx+20, by+4,  5, 20),   // b
        CGRectMake(bx+20, by+28, 5, 20),   // c
        CGRectMake(bx,    by+48, 20, 5),   // d
        CGRectMake(bx-4,  by+28, 5, 20),   // e
        CGRectMake(bx-4,  by+4,  5, 20),   // f
        CGRectMake(bx,    by+24, 20, 5),   // g
    };
    for (int i = 0; i < 7; i++) {
        BOOL lit = (v >> i) & 1;
        if (lit) {  // soft glow under lit segments
            NSShadow *s = [NSShadow new];
            s.shadowColor = [on colorWithAlphaComponent:0.9]; s.shadowBlurRadius = 4;
            [NSGraphicsContext saveGraphicsState]; [s set];
            [on setFill]; [[NSBezierPath bezierPathWithRoundedRect:seg[i] xRadius:1.5 yRadius:1.5] fill];
            [NSGraphicsContext restoreGraphicsState];
        } else {
            [off setFill]; [[NSBezierPath bezierPathWithRoundedRect:seg[i] xRadius:1.5 yRadius:1.5] fill];
        }
    }
    // decimal point
    CGRect dp = CGRectMake(bx+28, by+50, 4, 4);
    [((v >> 7) & 1) ? on : off setFill];
    [[NSBezierPath bezierPathWithOvalInRect:dp] fill];
}

- (void)drawLED:(BOOL)lit inRect:(NSRect)r {
    NSColor *bright = [NSColor colorWithCalibratedRed:1.0 green:0.22 blue:0.18 alpha:1];
    NSColor *dark   = [NSColor colorWithCalibratedRed:0.45 green:0.04 blue:0.04 alpha:1];
    NSColor *offc   = [NSColor colorWithCalibratedRed:0.32 green:0.06 blue:0.06 alpha:1];
    NSBezierPath *body = [NSBezierPath bezierPathWithOvalInRect:r];
    if (lit) {
        NSShadow *s = [NSShadow new];
        s.shadowColor = [bright colorWithAlphaComponent:0.9]; s.shadowBlurRadius = 6;
        [NSGraphicsContext saveGraphicsState]; [s set];
        NSGradient *g = [[NSGradient alloc] initWithColors:@[bright, dark]];
        [g drawInBezierPath:body relativeCenterPosition:NSMakePoint(-0.25, -0.3)];
        [NSGraphicsContext restoreGraphicsState];
        // specular highlight
        NSRect hl = NSInsetRect(r, r.size.width*0.30, r.size.height*0.30);
        hl.origin.x -= r.size.width*0.10; hl.origin.y -= r.size.height*0.12;
        [[NSColor colorWithWhite:1 alpha:0.55] setFill];
        [[NSBezierPath bezierPathWithOvalInRect:hl] fill];
    } else {
        [offc setFill]; [body fill];
    }
    [[NSColor colorWithCalibratedRed:0.40 green:0.0 blue:0.0 alpha:1] setStroke];
    body.lineWidth = 2; [body stroke];
}

#pragma mark interaction + state

- (void)addrChanged:(NSTextField *)tf {
    unsigned v = 0; sscanf(tf.stringValue.UTF8String ?: "", "%x", &v);
    if (tf == _seg7Field)        _seg7Addr   = v & ADDRMASK;
    else if (tf == _ledField)    _ledAddr    = v & ADDRMASK;
    else if (tf == _switchField) _switchAddr = v & ADDRMASK;
    else if (tf == _pbField)     _pbAddr     = v & ADDRMASK;
    [self refresh];
}

- (void)switchToggled:(NSButton *)b {
    if (!memory) return;
    int bit = (int)b.tag;
    uint32_t a = _switchAddr & ADDRMASK;
    if (b.state == NSControlStateValueOn) memory[a] |= (1 << bit);
    else                                  memory[a] &= ~(1 << bit);
}

- (void)memoryChangedAt:(int)loc {
    int a = loc & ADDRMASK;
    if ((a >= (int)_seg7Addr - 4 && a <= (int)_seg7Addr + 15) ||
        (a >= (int)_ledAddr  - 4 && a <= (int)_ledAddr))
        dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
}

- (void)refresh {
    if (memory) {
        for (int i = 0; i < 8; i++) _segVal[i] = (uint8_t)memory[(_seg7Addr + i * 2) & ADDRMASK];
        _ledVal = (uint8_t)memory[_ledAddr & ADDRMASK];
    }
    self.needsDisplay = YES;
}

@end
