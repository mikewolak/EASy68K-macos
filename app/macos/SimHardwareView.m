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
#import "E68BrushedView.h"

#define ADDRMASK 0x00FFFFFF

// Panels (from the .dfm, in 422x495 form coordinates, y-down)
static const CGRect kPanel2 = {{8, 8},  {329, 69}};   // 7-seg, black
static const CGRect kPanel1 = {{8, 84}, {329, 33}};   // LEDs, gray

// Momentary push button: fires onDown when pressed, onUp when released, and
// shows its alternate (pressed) image while held. The original pb0-7 are
// active-low — pressed clears the bit, released sets it.
@interface E68PushButton : NSButton
@property (nonatomic, copy) void (^onDown)(void);
@property (nonatomic, copy) void (^onUp)(void);
@end
@implementation E68PushButton
- (void)mouseDown:(NSEvent *)e {
    if (self.onDown) self.onDown();
    [super mouseDown:e];        // tracks the press until the mouse is released
    if (self.onUp) self.onUp();
}
@end

@implementation SimHardwareView {
    NSButton    *_switch[8];
    E68PushButton *_pb[8];          // eight momentary push buttons (Buttons Address)
    NSTextField *_seg7Field, *_ledField, *_switchField, *_pbField;
    uint8_t      _segVal[8];
    uint8_t      _ledVal;
    CGFloat      _ledGlow[8];       // afterglow 0..1 per LED for a smooth trail
    // memory map editor
    NSButton    *_mapChk[4];
    NSTextField *_mapStart[4], *_mapEnd[4];
    // auto interrupt
    NSPopUpButton *_autoIRQ;
    NSTextField   *_autoInterval;
    NSButton      *_autoBtn;
    NSButton      *_autoChk[7];     // per-IRQ "Automatic" enables
    NSTimer       *_autoTimer;
    NSTimer       *_refreshTimer;   // live-refresh while the window is visible
}

// Live-update the 7-seg / LEDs ~20x/sec while the window is on screen, so a
// running program driving the hardware addresses is reflected immediately.
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (self.window && !_refreshTimer) {
        __weak SimHardwareView *weak = self;
        _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *t) {
            if (weak.window.isVisible) [weak refresh];
        }];
    }
}
- (void)dealloc { [_refreshTimer invalidate]; [_autoTimer invalidate]; }

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

    // eight momentary PUSH BUTTONS (the Buttons Address row, pb7..pb0). The .dfm
    // puts them at y=192, 33x33, aligned under the switches; active-low.
    NSImage *pbUp = [self image:@"pushbutton_up"], *pbDn = [self image:@"pushbutton_down"];
    if (memory) memory[_pbAddr & ADDRMASK] = 0xFF;   // all released
    for (int b = 7; b >= 0; b--) {
        CGFloat x = 14 + 40 * (7 - b);
        E68PushButton *pb = [[E68PushButton alloc] initWithFrame:NSMakeRect(x, 185, 33, 33)];
        pb.buttonType = NSButtonTypeMomentaryChange;
        pb.bordered = NO; pb.imagePosition = NSImageOnly;
        pb.imageScaling = NSImageScaleProportionallyUpOrDown;
        pb.image = pbUp; pb.alternateImage = pbDn ?: pbUp;
        pb.toolTip = [NSString stringWithFormat:@"Push button %d (bit %d) — hold to press (active-low)", b, b];
        int bit = b;
        __weak SimHardwareView *weak = self;
        pb.onDown = ^{ if (memory) memory[weak.pbAddr & ADDRMASK] &= ~(1 << bit); [weak refresh]; };
        pb.onUp   = ^{ if (memory) memory[weak.pbAddr & ADDRMASK] |=  (1 << bit); [weak refresh]; };
        _pb[b] = pb;
        [self addSubview:pb];
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

// clMaroon (#800000) and clGray (#808080) — the original hardware panel colors.
+ (NSColor *)maroon { return [NSColor colorWithCalibratedRed:0.50 green:0.0 blue:0.0 alpha:1.0]; }
+ (NSColor *)panelGray { return [NSColor colorWithCalibratedWhite:0.50 alpha:1.0]; }

- (NSBox *)groupBox:(NSString *)title frame:(NSRect)f fill:(NSColor *)fill {
    NSBox *b = [[NSBox alloc] initWithFrame:f];
    b.boxType = NSBoxCustom;
    b.fillColor = fill;
    b.borderColor = [NSColor colorWithCalibratedWhite:0 alpha:0.5];
    b.borderWidth = 1; b.cornerRadius = 6;
    NSFont *tf = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    // white box title on the coloured fills (matches Font.Color = clWhite)
    NSCell *tc = b.titleCell;
    tc.attributedStringValue = [[NSAttributedString alloc] initWithString:title
        attributes:@{ NSForegroundColorAttributeName: NSColor.whiteColor, NSFontAttributeName: tf }];
    [self addSubview:b];
    return b;
}
// A push button that reads clearly on the maroon panels: dark-red bezel, white
// title (the default light bezel + black text washes out on the red fill).
- (NSButton *)maroonButton:(NSString *)title frame:(NSRect)f action:(SEL)a {
    NSButton *b = [NSButton buttonWithTitle:title target:self action:a];
    b.frame = f;
    b.bezelStyle = NSBezelStyleRounded;     // vertically centres its title
    b.bezelColor = [NSColor colorWithCalibratedRed:0.34 green:0.02 blue:0.02 alpha:1.0];
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.alignment = NSTextAlignmentCenter;
    b.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: NSColor.whiteColor,
        NSParagraphStyleAttributeName: ps,
        NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightMedium] }];
    return b;
}

- (NSTextField *)smallLabel:(NSString *)s frame:(NSRect)f in:(NSView *)v {
    return [self smallLabel:s frame:f in:v white:NO];
}
- (NSTextField *)smallLabel:(NSString *)s frame:(NSRect)f in:(NSView *)v white:(BOOL)white {
    NSTextField *l = [NSTextField labelWithString:s];
    l.font = [NSFont systemFontOfSize:10]; l.frame = f;
    if (white) l.textColor = NSColor.whiteColor;
    [v addSubview:l]; return l;
}
- (NSTextField *)hexField:(NSRect)f in:(NSView *)v {
    NSTextField *tf = [[NSTextField alloc] initWithFrame:f];
    tf.font = [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular];
    tf.stringValue = @"00000000"; tf.target = self; tf.action = @selector(mapChanged:);
    [v addSubview:tf]; return tf;
}

- (void)buildLowerSections {
    NSColor *maroon = [SimHardwareView maroon];
    // ---- Interrupt group (MAROON): seven IRQ buttons + per-IRQ "Automatic" ----
    NSBox *irqBox = [self groupBox:@"Interrupt" frame:NSMakeRect(8, 232, 196, 92) fill:maroon];
    NSView *ic = irqBox.contentView;
    // buttons are labelled 7..1 left-to-right (matching the .dfm) and momentary.
    for (int col = 0; col < 7; col++) {
        int n = 7 - col;                      // leftmost = IRQ7
        CGFloat x = 4 + col * 26;
        NSTextField *l = [self smallLabel:[NSString stringWithFormat:@"%d", n]
                                    frame:NSMakeRect(x + 5, 2, 16, 12) in:ic white:YES];
        l.alignment = NSTextAlignmentCenter;
        NSButton *pb = [NSButton buttonWithTitle:@"" target:self action:@selector(irqButton:)];
        pb.frame = NSMakeRect(x, 16, 24, 24);
        pb.bezelStyle = NSBezelStyleSmallSquare; pb.tag = n;
        pb.toolTip = [NSString stringWithFormat:@"Trigger IRQ %d", n];
        [ic addSubview:pb];
        NSButton *chk = [NSButton checkboxWithTitle:@"" target:nil action:NULL];
        chk.frame = NSMakeRect(x + 4, 44, 18, 18); chk.tag = n;
        chk.toolTip = [NSString stringWithFormat:@"Automatic IRQ %d at the Auto Interval rate", n];
        [ic addSubview:chk];
        _autoChk[n-1] = chk;
    }
    [self smallLabel:@"Automatic" frame:NSMakeRect(6, 64, 120, 12) in:ic white:YES];

    // ---- Auto Interval group (MAROON) — wider so "Start" fits inside ----
    NSBox *autoBox = [self groupBox:@"Auto Interval" frame:NSMakeRect(208, 232, 156, 92) fill:maroon];
    NSView *ac = autoBox.contentView;
    _autoInterval = [[NSTextField alloc] initWithFrame:NSMakeRect(8, 46, 52, 22)];
    _autoInterval.stringValue = @"500"; _autoInterval.alignment = NSTextAlignmentRight;
    [ac addSubview:_autoInterval];
    [self smallLabel:@"mS" frame:NSMakeRect(64, 49, 24, 14) in:ac white:YES];
    [self smallLabel:@"IRQ" frame:NSMakeRect(8, 18, 26, 14) in:ac white:YES];
    _autoIRQ = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(34, 14, 50, 24)];
    [_autoIRQ addItemsWithTitles:@[@"1",@"2",@"3",@"4",@"5",@"6",@"7"]];
    // dark popup with white text so the value reads on the maroon panel
    _autoIRQ.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    for (NSMenuItem *it in _autoIRQ.itemArray)
        it.attributedTitle = [[NSAttributedString alloc] initWithString:it.title attributes:@{
            NSForegroundColorAttributeName: NSColor.whiteColor,
            NSFontAttributeName: [NSFont systemFontOfSize:12] }];
    [ac addSubview:_autoIRQ];
    _autoBtn = [self maroonButton:@"Start" frame:NSMakeRect(92, 14, 56, 24) action:@selector(autoToggle:)];
    [ac addSubview:_autoBtn];

    // ---- Reset group (MAROON) — button centred in the box's content area ----
    NSBox *resetBox = [self groupBox:@"Reset" frame:NSMakeRect(368, 232, 86, 92) fill:maroon];
    NSView *rc = resetBox.contentView;
    NSButton *rb = [self maroonButton:@"Reset IRQ" frame:NSZeroRect action:@selector(resetIRQ:)];
    rb.translatesAutoresizingMaskIntoConstraints = NO;
    [rc addSubview:rb];
    [NSLayoutConstraint activateConstraints:@[      // exact centre, layout-time-independent
        [rb.centerXAnchor constraintEqualToAnchor:rc.centerXAnchor],
        [rb.centerYAnchor constraintEqualToAnchor:rc.centerYAnchor],
        [rb.widthAnchor constraintEqualToConstant:74],
        [rb.heightAnchor constraintEqualToConstant:28],
    ]];

    // ---- Memory Map group (GRAY) ----
    NSBox *mapBox = [self groupBox:@"Memory Map" frame:NSMakeRect(8, 332, 406, 150) fill:[SimHardwareView panelGray]];
    NSView *mc = mapBox.contentView;
    [self smallLabel:@"Start" frame:NSMakeRect(120, 104, 80, 14) in:mc white:YES];
    [self smallLabel:@"End"   frame:NSMakeRect(240, 104, 80, 14) in:mc white:YES];
    NSString *names[4] = {@"ROM", @"Read-only", @"Protected", @"Invalid"};
    for (int i = 0; i < 4; i++) {
        CGFloat y = 78 - i * 26;
        _mapChk[i] = [NSButton checkboxWithTitle:names[i] target:self action:@selector(mapChanged:)];
        _mapChk[i].frame = NSMakeRect(10, y, 100, 20); _mapChk[i].tag = i;
        _mapChk[i].attributedTitle = [[NSAttributedString alloc] initWithString:names[i]
            attributes:@{ NSForegroundColorAttributeName: NSColor.whiteColor,
                          NSFontAttributeName: [NSFont systemFontOfSize:12] }];
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

- (void)setAutoBtnTitle:(NSString *)t {
    _autoBtn.attributedTitle = [[NSAttributedString alloc] initWithString:t attributes:@{
        NSForegroundColorAttributeName: NSColor.whiteColor,
        NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightMedium] }];
}
- (void)autoToggle:(NSButton *)b {
    if (_autoTimer) {
        [_autoTimer invalidate]; _autoTimer = nil; [self setAutoBtnTitle:@"Start"];
    } else {
        double ms = MAX(10, _autoInterval.doubleValue);
        int n = (int)_autoIRQ.indexOfSelectedItem + 1;
        [self setAutoBtnTitle:@"Stop"];
        __weak SimHardwareView *weak = self;
        _autoTimer = [NSTimer scheduledTimerWithTimeInterval:ms/1000.0 repeats:YES block:^(NSTimer *t) {
            irq |= (0x01 << (n - 1));                 // the Auto Interval IRQ
            SimHardwareView *s = weak; if (!s) return;
            for (int k = 0; k < 7; k++)               // + any IRQ marked Automatic
                if (s->_autoChk[k].state == NSControlStateValueOn) irq |= (0x01 << k);
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
    // brushed-aluminum backdrop for the whole panel
    [self drawBrushedAluminumIn:self.bounds];

    // Panel2 (7-seg, black with a soft inner glow)
    [self drawPanel:kPanel2 top:[NSColor colorWithWhite:0.10 alpha:1] bottom:NSColor.blackColor radius:6];
    // Panel1 (LEDs) — recessed dark metal so the LEDs pop on the aluminum
    [self drawPanel:kPanel1 top:[NSColor colorWithWhite:0.30 alpha:1] bottom:[NSColor colorWithWhite:0.18 alpha:1] radius:6];

    // 7-segment displays inside Panel2: display d (0=left) -> memory[seg7loc+2d]
    for (int d = 0; d < 8; d++) {
        CGFloat bx = kPanel2.origin.x + 12 + 40 * d;   // 'a' segment left
        CGFloat by = kPanel2.origin.y + 8;
        [self drawDigit:_segVal[d] baseX:bx baseY:by];
    }

    // LEDs inside Panel1: bit b (7=left … 0=right). _ledGlow is the (optionally
    // decaying) brightness so a sweep leaves a smooth trail.
    for (int b = 7; b >= 0; b--) {
        CGFloat x = kPanel1.origin.x + 16 + 40 * (7 - b);
        CGFloat y = kPanel1.origin.y + 8;
        [self drawLED:_ledGlow[b] inRect:NSMakeRect(x, y, 17, 17)];
    }
}

- (void)drawBrushedAluminumIn:(NSRect)r { [E68BrushedView drawBrushedAluminumIn:r]; }

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

// level 0..1 — full brightness at 1, fading to the dark "off" look at 0.
- (void)drawLED:(CGFloat)level inRect:(NSRect)r {
    if (level < 0) level = 0; if (level > 1) level = 1;
    NSColor *bright = [NSColor colorWithCalibratedRed:1.0 green:0.22 blue:0.18 alpha:1];
    NSColor *dark   = [NSColor colorWithCalibratedRed:0.45 green:0.04 blue:0.04 alpha:1];
    NSColor *offc   = [NSColor colorWithCalibratedRed:0.32 green:0.06 blue:0.06 alpha:1];
    NSBezierPath *body = [NSBezierPath bezierPathWithOvalInRect:r];
    if (level > 0.02) {
        NSColor *hi = [offc blendedColorWithFraction:level ofColor:bright];   // brightness lerp
        NSColor *lo = [offc blendedColorWithFraction:level ofColor:dark];
        NSShadow *s = [NSShadow new];
        s.shadowColor = [bright colorWithAlphaComponent:0.9 * level];
        s.shadowBlurRadius = 6 * level;
        [NSGraphicsContext saveGraphicsState]; [s set];
        NSGradient *g = [[NSGradient alloc] initWithColors:@[hi, lo]];
        [g drawInBezierPath:body relativeCenterPosition:NSMakePoint(-0.25, -0.3)];
        [NSGraphicsContext restoreGraphicsState];
        // specular highlight, brightest when fully lit
        NSRect hl = NSInsetRect(r, r.size.width*0.30, r.size.height*0.30);
        hl.origin.x -= r.size.width*0.10; hl.origin.y -= r.size.height*0.12;
        [[NSColor colorWithWhite:1 alpha:0.55 * level] setFill];
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

// Called from the SIM thread on every write to a hardware-mapped address. It
// MUST NOT dispatch to the main queue per write: a tight loop writing the 7-seg
// fires this millions of times/sec and would flood the main queue into a freeze.
// The ~20 Hz refresh timer (viewDidMoveToWindow) repaints from memory instead.
- (void)memoryChangedAt:(int)loc { (void)loc; }

- (void)refresh {
    if (memory) {
        for (int i = 0; i < 8; i++) _segVal[i] = (uint8_t)memory[(_seg7Addr + i * 2) & ADDRMASK];
        _ledVal = (uint8_t)memory[_ledAddr & ADDRMASK];
    }
    // LED afterglow (a macOS-only nicety, toggled in Settings; default on). When
    // off the LEDs are crisp on/off exactly like the original.
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    BOOL glow = [u objectForKey:@"HwLEDGlow"] ? [u boolForKey:@"HwLEDGlow"] : YES;
    for (int b = 0; b < 8; b++) {
        BOOL on = (_ledVal >> b) & 1;
        if (!glow)      _ledGlow[b] = on ? 1.0 : 0.0;
        else if (on)    _ledGlow[b] = 1.0;                          // snap on
        else { _ledGlow[b] *= 0.55; if (_ledGlow[b] < 0.01) _ledGlow[b] = 0; }  // fade out
    }
    self.needsDisplay = YES;
}

@end
