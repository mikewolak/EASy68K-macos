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
//  SimMemoryWindowController.m
//
#import "SimMemoryWindowController.h"
#import "SimCore.h"
#import "E68BrushedView.h"

#define ADDR_MASK (SIM_MEMSIZE - 1)

// Every open memory window, so Live windows can be refreshed after each step.
static NSHashTable<SimMemoryWindowController *> *gWindows;

@interface SimMemoryHexView : NSView          // draws the hex/ASCII dump
@property (nonatomic) uint32_t base;          // first address shown
@property (nonatomic) int rows;               // rows currently visible
@property (nonatomic) uint32_t selFrom, selTo;// highlighted range (From..To)
@end

@interface SimMemoryHeaderView : NSView @end  // column header, aligned to the dump

@implementation SimMemoryWindowController {
    SimMemoryHexView *_hex;
    NSTextField      *_addr, *_from, *_to, *_bytes;
    NSStepper        *_rowStep, *_pageStep;
    NSButton         *_live;
    NSTimer          *_liveTimer;
    uint32_t          _base;
}

- (void)dealloc { [_liveTimer invalidate]; }

+ (void)initialize { if (!gWindows) gWindows = [NSHashTable weakObjectsHashTable]; }

+ (instancetype)openNewMemoryWindow {
    SimMemoryWindowController *c = [[SimMemoryWindowController alloc] initWithWindow:nil];
    [c build];
    [gWindows addObject:c];
    // cascade so multiple windows don't stack exactly
    static int n = 0;
    NSPoint o = [c.window cascadeTopLeftFromPoint:NSMakePoint(60 + n*24, 0)]; n = (n+1) % 8;
    [c.window setFrameTopLeftPoint:NSMakePoint(o.x, NSScreen.mainScreen.frame.size.height - 80 - n*24)];
    [c.window center];
    [c showWindow:nil];
    [c.window makeKeyAndOrderFront:nil];
    [c refresh];
    return c;
}

+ (void)refreshLiveWindows {
    for (SimMemoryWindowController *c in gWindows.allObjects)
        if (c->_live.state == NSControlStateValueOn) [c refresh];
}

// Live mode drives its own timer: refreshState/cbUpdate only fires on step/stop,
// so a continuous Run would otherwise leave a "Live" window frozen. The timer
// reads memory directly at ~15 Hz while the box is checked and the window shows.
- (void)liveToggled:(NSButton *)b {
    [self refresh];
    if (_live.state == NSControlStateValueOn && !_liveTimer) {
        __weak SimMemoryWindowController *weak = self;
        _liveTimer = [NSTimer timerWithTimeInterval:1.0/15.0 repeats:YES block:^(NSTimer *t) {
            SimMemoryWindowController *s = weak;
            if (!s) { [t invalidate]; return; }
            if (s->_live.state == NSControlStateValueOn && s.window.isVisible) [s refresh];
        }];
        [[NSRunLoop currentRunLoop] addTimer:_liveTimer forMode:NSRunLoopCommonModes];
    } else if (_live.state != NSControlStateValueOn && _liveTimer) {
        [_liveTimer invalidate]; _liveTimer = nil;
    }
}

- (void)build {
    if (self.window) return;
    NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 450)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                   NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    w.title = @"68000 Memory";
    w.releasedWhenClosed = NO;
    self.window = w;
    NSView *root = w.contentView;

    // ---- top bar: Address / From / To / Bytes + Copy / Fill / Save ----
    NSView *bar = [[NSView alloc] initWithFrame:NSZeroRect];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:bar];

    NSTextField *(^lbl)(NSString *) = ^(NSString *s){
        NSTextField *l = [NSTextField labelWithString:s];
        l.font = [NSFont systemFontOfSize:11]; l.translatesAutoresizingMaskIntoConstraints = NO;
        [bar addSubview:l]; return l;
    };
    NSTextField *(^hexField)(SEL) = ^(SEL a){
        NSTextField *f = [[NSTextField alloc] initWithFrame:NSZeroRect];
        f.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
        f.translatesAutoresizingMaskIntoConstraints = NO;
        f.target = self; f.action = a; f.placeholderString = @"$0";
        [bar addSubview:f]; return f;
    };
    NSTextField *aLbl = lbl(@"Address $"); _addr  = hexField(@selector(addrChanged:));
    NSTextField *fLbl = lbl(@"From $");    _from  = hexField(@selector(rangeChanged:));
    NSTextField *tLbl = lbl(@"To $");      _to    = hexField(@selector(rangeChanged:));
    NSTextField *bLbl = lbl(@"Bytes");     _bytes = hexField(@selector(rangeChanged:));

    NSButton *copy = [NSButton buttonWithTitle:@"Copy" target:self action:@selector(copyRange:)];
    NSButton *fill = [NSButton buttonWithTitle:@"Fill" target:self action:@selector(fillRange:)];
    NSButton *save = [NSButton buttonWithTitle:@"Save…" target:self action:@selector(saveRange:)];
    for (NSButton *b in @[copy, fill, save]) {
        b.bezelStyle = NSBezelStyleRounded; b.controlSize = NSControlSizeSmall;
        b.font = [NSFont systemFontOfSize:11]; b.translatesAutoresizingMaskIntoConstraints = NO;
        [bar addSubview:b];
    }

    // column header row, drawn with the SAME font/x-origin/spacing as the data
    // rows so the byte columns and the ASCII header line up exactly.
    SimMemoryHeaderView *hdr = [[SimMemoryHeaderView alloc] initWithFrame:NSZeroRect];
    hdr.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:hdr];

    // ---- the hex dump view ----
    _hex = [[SimMemoryHexView alloc] initWithFrame:NSZeroRect];
    _hex.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:_hex];

    // ---- right rail: Row / Page spinners + Live ----
    NSTextField *rowLbl = lbl(@"Row");  rowLbl.alignment = NSTextAlignmentCenter;
    NSTextField *pgLbl  = lbl(@"Page"); pgLbl.alignment  = NSTextAlignmentCenter;
    [rowLbl removeFromSuperview]; [pgLbl removeFromSuperview];
    rowLbl.translatesAutoresizingMaskIntoConstraints = NO; [root addSubview:rowLbl];
    pgLbl.translatesAutoresizingMaskIntoConstraints  = NO; [root addSubview:pgLbl];

    _rowStep = [[NSStepper alloc] initWithFrame:NSZeroRect];
    _rowStep.minValue = -1e9; _rowStep.maxValue = 1e9; _rowStep.valueWraps = NO;
    _rowStep.target = self; _rowStep.action = @selector(rowSpin:);
    _rowStep.translatesAutoresizingMaskIntoConstraints = NO; [root addSubview:_rowStep];

    _pageStep = [[NSStepper alloc] initWithFrame:NSZeroRect];
    _pageStep.minValue = -1e9; _pageStep.maxValue = 1e9; _pageStep.valueWraps = NO;
    _pageStep.target = self; _pageStep.action = @selector(pageSpin:);
    _pageStep.translatesAutoresizingMaskIntoConstraints = NO; [root addSubview:_pageStep];

    _live = [NSButton checkboxWithTitle:@"Live" target:self action:@selector(liveToggled:)];
    _live.font = [NSFont systemFontOfSize:11];
    _live.translatesAutoresizingMaskIntoConstraints = NO; [root addSubview:_live];

    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:root.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [bar.heightAnchor constraintEqualToConstant:30],

        [aLbl.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:8],
        [aLbl.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [_addr.leadingAnchor constraintEqualToAnchor:aLbl.trailingAnchor constant:2],
        [_addr.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [_addr.widthAnchor constraintEqualToConstant:64],
        [fLbl.leadingAnchor constraintEqualToAnchor:_addr.trailingAnchor constant:10],
        [fLbl.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [_from.leadingAnchor constraintEqualToAnchor:fLbl.trailingAnchor constant:2],
        [_from.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [_from.widthAnchor constraintEqualToConstant:64],
        [tLbl.leadingAnchor constraintEqualToAnchor:_from.trailingAnchor constant:8],
        [tLbl.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [_to.leadingAnchor constraintEqualToAnchor:tLbl.trailingAnchor constant:2],
        [_to.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [_to.widthAnchor constraintEqualToConstant:64],
        [bLbl.leadingAnchor constraintEqualToAnchor:_to.trailingAnchor constant:8],
        [bLbl.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [_bytes.leadingAnchor constraintEqualToAnchor:bLbl.trailingAnchor constant:2],
        [_bytes.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [_bytes.widthAnchor constraintEqualToConstant:54],
        [save.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-8],
        [save.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [fill.trailingAnchor constraintEqualToAnchor:save.leadingAnchor constant:-6],
        [fill.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [copy.trailingAnchor constraintEqualToAnchor:fill.leadingAnchor constant:-6],
        [copy.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],

        [hdr.topAnchor constraintEqualToAnchor:bar.bottomAnchor constant:4],
        [hdr.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:8],
        [hdr.trailingAnchor constraintEqualToAnchor:rowLbl.leadingAnchor constant:-6],
        [hdr.heightAnchor constraintEqualToConstant:16],

        [_hex.topAnchor constraintEqualToAnchor:hdr.bottomAnchor constant:2],
        [_hex.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:8],
        [_hex.trailingAnchor constraintEqualToAnchor:rowLbl.leadingAnchor constant:-6],
        [_hex.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-8],

        [rowLbl.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-6],
        [rowLbl.topAnchor constraintEqualToAnchor:_hex.topAnchor constant:4],
        [rowLbl.widthAnchor constraintEqualToConstant:34],
        [_rowStep.topAnchor constraintEqualToAnchor:rowLbl.bottomAnchor constant:2],
        [_rowStep.centerXAnchor constraintEqualToAnchor:rowLbl.centerXAnchor],
        [pgLbl.topAnchor constraintEqualToAnchor:_rowStep.bottomAnchor constant:14],
        [pgLbl.centerXAnchor constraintEqualToAnchor:rowLbl.centerXAnchor],
        [pgLbl.widthAnchor constraintEqualToConstant:34],
        [_pageStep.topAnchor constraintEqualToAnchor:pgLbl.bottomAnchor constant:2],
        [_pageStep.centerXAnchor constraintEqualToAnchor:rowLbl.centerXAnchor],
        [_live.topAnchor constraintEqualToAnchor:_pageStep.bottomAnchor constant:16],
        [_live.centerXAnchor constraintEqualToAnchor:rowLbl.centerXAnchor],
    ]];

    _base = 0;
    self.window.delegate = (id<NSWindowDelegate>)self;
}

#pragma mark refresh / navigation

- (int)visibleRows {
    CGFloat h = _hex.bounds.size.height;
    int r = (int)(h / 15.0);
    return r < 1 ? 1 : r;
}

- (void)refresh {
    _hex.base = _base;
    _hex.rows = [self visibleRows];
    _hex.selFrom = (uint32_t)([self parseHex:_from.stringValue] & ADDR_MASK);
    _hex.selTo   = (uint32_t)([self parseHex:_to.stringValue]   & ADDR_MASK);
    _hex.needsDisplay = YES;
    if (![_addr.stringValue length] || _addr.window.firstResponder != _addr)
        _addr.stringValue = [NSString stringWithFormat:@"%06X", _base];
}

- (long)parseHex:(NSString *)s {
    s = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    s = [s stringByReplacingOccurrencesOfString:@"$" withString:@""];
    if (!s.length) return 0;
    return (long)strtoul(s.UTF8String, NULL, 16);
}

- (void)setBase:(long)a { _base = (uint32_t)(((a) & ADDR_MASK) & ~0xF); [self refresh]; }

- (void)addrChanged:(id)s  { [self setBase:[self parseHex:_addr.stringValue]]; }
- (void)rowSpin:(NSStepper *)s {
    [self setBase:(long)_base + (s.integerValue > 0 ? 16 : -16) * (long)16 / 16];
    s.integerValue = 0;
}
- (void)pageSpin:(NSStepper *)s {
    [self setBase:(long)_base + (s.integerValue > 0 ? 1 : -1) * 16L * [self visibleRows]];
    s.integerValue = 0;
}
- (void)scrollWheel:(NSEvent *)e {
    [self setBase:(long)_base - (e.deltaY > 0 ? 16 : -16) * 3];
}

- (void)rangeChanged:(id)s {
    // keep Bytes = To - From + 1 in sync when From/To edited
    long f = [self parseHex:_from.stringValue], t = [self parseHex:_to.stringValue];
    if (s == _bytes) {
        long n = [self parseHex:_bytes.stringValue];
        t = f + (n > 0 ? n - 1 : 0);
        _to.stringValue = [NSString stringWithFormat:@"%06lX", t & ADDR_MASK];
    } else if (t >= f) {
        _bytes.stringValue = [NSString stringWithFormat:@"%ld", t - f + 1];
    }
    [self refresh];
}

#pragma mark Copy / Fill / Save over From..To

- (BOOL)rangeFrom:(uint32_t *)pf to:(uint32_t *)pt {
    uint32_t f = (uint32_t)([self parseHex:_from.stringValue] & ADDR_MASK);
    uint32_t t = (uint32_t)([self parseHex:_to.stringValue] & ADDR_MASK);
    if (_to.stringValue.length == 0) t = f;
    if (t < f) { uint32_t x = f; f = t; t = x; }
    *pf = f; *pt = t; return memory != NULL;
}

- (void)copyRange:(id)s {
    uint32_t f, t; if (![self rangeFrom:&f to:&t]) return;
    NSMutableString *m = [NSMutableString string];
    for (uint32_t a = f; a <= t; a++) {
        [m appendFormat:@"%02X ", (unsigned char)memory[a]];
        if (((a - f) & 0xF) == 0xF) [m appendString:@"\n"];
    }
    [NSPasteboard.generalPasteboard clearContents];
    [NSPasteboard.generalPasteboard setString:m forType:NSPasteboardTypeString];
}

- (void)fillRange:(id)s {
    uint32_t f, t; if (![self rangeFrom:&f to:&t]) return;
    NSAlert *al = [NSAlert new];
    al.messageText = [NSString stringWithFormat:@"Fill $%06X..$%06X with byte:", f, t];
    NSTextField *in = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,80,24)];
    in.stringValue = @"00"; al.accessoryView = in;
    [al addButtonWithTitle:@"Fill"]; [al addButtonWithTitle:@"Cancel"];
    if ([al runModal] != NSAlertFirstButtonReturn) return;
    unsigned char v = (unsigned char)strtoul(in.stringValue.UTF8String, NULL, 16);
    for (uint32_t a = f; a <= t; a++) memory[a] = (char)v;
    [SimMemoryWindowController refreshLiveWindows];
    [self refresh];
}

- (void)saveRange:(id)s {
    uint32_t f, t; if (![self rangeFrom:&f to:&t]) return;
    NSSavePanel *p = [NSSavePanel savePanel];
    p.nameFieldStringValue = [NSString stringWithFormat:@"mem_%06X_%06X.bin", f, t];
    if ([p runModal] != NSModalResponseOK) return;
    NSData *d = [NSData dataWithBytes:&memory[f] length:(NSUInteger)(t - f + 1)];
    [d writeToURL:p.URL atomically:YES];
}

@end

#pragma mark - hex dump view

@implementation SimMemoryHexView

- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirty {
    [NSColor.textBackgroundColor setFill];
    NSRectFill(self.bounds);
    if (!memory) return;

    NSFont *font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    NSDictionary *addrAttr = @{ NSFontAttributeName: font,
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.16 green:0.52 blue:1.0 alpha:1] };
    NSDictionary *hexAttr  = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: NSColor.textColor };
    NSDictionary *selAttr  = @{ NSFontAttributeName: font,
        NSForegroundColorAttributeName: NSColor.textColor,
        NSBackgroundColorAttributeName: [NSColor colorWithCalibratedRed:1 green:0.93 blue:0.5 alpha:1] };

    CGFloat y = 2, rowH = 15;
    for (int r = 0; r < _rows; r++) {
        uint32_t a = (_base + (uint32_t)r * 16) & ADDR_MASK;
        NSMutableAttributedString *line = [NSMutableAttributedString new];
        [line appendAttributedString:[[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"%06X  ", a] attributes:addrAttr]];
        for (int c = 0; c < 16; c++) {
            uint32_t aa = (a + c) & ADDR_MASK;
            BOOL sel = (_selTo >= _selFrom) && aa >= _selFrom && aa <= _selTo;
            [line appendAttributedString:[[NSAttributedString alloc]
                initWithString:[NSString stringWithFormat:@"%02X ", (unsigned char)memory[aa]]
                attributes:(sel ? selAttr : hexAttr)]];
        }
        [line appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:hexAttr]];
        for (int c = 0; c < 16; c++) {
            unsigned char ch = (unsigned char)memory[(a + c) & ADDR_MASK];
            NSString *cs = [NSString stringWithFormat:@"%c", (ch >= ' ' && ch < 127) ? ch : '.'];
            [line appendAttributedString:[[NSAttributedString alloc] initWithString:cs attributes:hexAttr]];
        }
        [line drawAtPoint:NSMakePoint(4, y)];
        y += rowH;
    }
}

@end

@implementation SimMemoryHeaderView

- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirty {
    [NSColor.textBackgroundColor setFill];
    NSRectFill(self.bounds);
    // Mirror a data row's layout EXACTLY: "%06X  " address (8 cols) + 16×"%02X "
    // + " " separator + 16 ASCII chars, same font + x-origin as SimMemoryHexView.
    NSFont *font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightSemibold];
    NSMutableString *s = [@"        " mutableCopy];        // 8 spaces under the address
    for (int c = 0; c < 16; c++) [s appendFormat:@"%02X ", c];
    [s appendString:@" 0123456789ABCDEF"];
    [[[NSAttributedString alloc] initWithString:s attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: NSColor.secondaryLabelColor }] drawAtPoint:NSMakePoint(4, 0)];
}

@end
