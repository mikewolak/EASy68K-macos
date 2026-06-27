/*
 * EASy68K for macOS
 *
 * Copyright (c) 2026 mikewolak@gmail.com  —  Epromfoundry, Inc.
 * All rights reserved.
 *
 * ****  NOT FOR COMMERCIAL USE  ****
 * This software is licensed for PERSONAL and EDUCATIONAL use ONLY.
 */

//
//  EASyBINController.m
//
#import "EASyBINController.h"
#import "E68BrushedView.h"
#import "E68Theme.h"
#include "easybin.h"

// ───────────────────────────── editable hex view ───────────────────────────
@protocol EBHexDelegate <NSObject>
- (void)hexCursorMovedTo:(uint32_t)addr;
@end

@interface EBHexView : NSView
@property (nonatomic) uint32_t base;       // first address shown (row 0)
@property (nonatomic) int rows;            // visible rows
@property (nonatomic) uint32_t cursor;     // selected byte address
@property (nonatomic, weak) id<EBHexDelegate> delegate;
@end

@implementation EBHexView {
    BOOL _highNibble;                      // next typed hex digit = high nibble
}
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame:f])) _highNibble = YES; return self; }

- (NSFont *)hexFont { return [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]; }

- (void)drawRect:(NSRect)dirty {
    [NSColor.textBackgroundColor setFill];
    NSRectFill(self.bounds);
    unsigned char *mem = eb_memory();
    NSFont *font = [self hexFont];
    NSDictionary *addrAttr = @{ NSFontAttributeName: font,
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.16 green:0.52 blue:1.0 alpha:1] };
    NSDictionary *hexAttr = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: NSColor.textColor };
    NSDictionary *curAttr = @{ NSFontAttributeName: font,
        NSForegroundColorAttributeName: NSColor.textColor,
        NSBackgroundColorAttributeName: [NSColor colorWithCalibratedRed:1 green:0.93 blue:0.5 alpha:1] };

    CGFloat y = 2, rowH = 15;
    for (int r = 0; r < self.rows; r++) {
        uint32_t a = (self.base + (uint32_t)r * 16) & (EB_MEMSIZE - 1);
        NSMutableAttributedString *line = [NSMutableAttributedString new];
        [line appendAttributedString:[[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"%06X  ", a] attributes:addrAttr]];
        for (int c = 0; c < 16; c++) {
            uint32_t aa = (a + c) & (EB_MEMSIZE - 1);
            BOOL cur = (aa == self.cursor);
            [line appendAttributedString:[[NSAttributedString alloc]
                initWithString:[NSString stringWithFormat:@"%02X ", mem[aa]]
                attributes:(cur ? curAttr : hexAttr)]];
        }
        [line appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:hexAttr]];
        for (int c = 0; c < 16; c++) {
            unsigned char ch = mem[(a + c) & (EB_MEMSIZE - 1)];
            NSString *cs = [NSString stringWithFormat:@"%c", (ch >= ' ' && ch < 127) ? ch : '.'];
            BOOL cur = ((a + c) == self.cursor);
            [line appendAttributedString:[[NSAttributedString alloc] initWithString:cs
                attributes:(cur ? curAttr : hexAttr)]];
        }
        [line drawAtPoint:NSMakePoint(4, y)];
        y += rowH;
    }
}

- (void)mouseDown:(NSEvent *)e {
    [self.window makeFirstResponder:self];
    NSPoint p = [self convertPoint:e.locationInWindow fromView:nil];
    int row = (int)((p.y - 2) / 15);
    // hex columns start at x≈4 + 8 chars (addr+2 spaces); each byte cell ~3 chars
    CGFloat charW = [@"0" sizeWithAttributes:@{NSFontAttributeName:[self hexFont]}].width;
    int col = (int)((p.x - 4 - 8 * charW) / (3 * charW));
    if (row >= 0 && col >= 0 && col < 16) {
        self.cursor = (self.base + (uint32_t)row * 16 + (uint32_t)col) & (EB_MEMSIZE - 1);
        _highNibble = YES;
        [self setNeedsDisplay:YES];
        if (self.delegate) [self.delegate hexCursorMovedTo:self.cursor];
    }
}

- (void)moveCursorBy:(int)delta {
    self.cursor = (uint32_t)((self.cursor + delta) & (EB_MEMSIZE - 1));
    _highNibble = YES;
    if (self.delegate) [self.delegate hexCursorMovedTo:self.cursor];
    [self setNeedsDisplay:YES];
}

- (void)keyDown:(NSEvent *)e {
    NSString *s = e.charactersIgnoringModifiers;
    if (s.length == 0) return;
    unichar ch = [s characterAtIndex:0];
    switch (ch) {
        case NSLeftArrowFunctionKey:  [self moveCursorBy:-1];  return;
        case NSRightArrowFunctionKey: [self moveCursorBy:+1];  return;
        case NSUpArrowFunctionKey:    [self moveCursorBy:-16]; return;
        case NSDownArrowFunctionKey:  [self moveCursorBy:+16]; return;
    }
    int nib = -1;
    if (ch >= '0' && ch <= '9') nib = ch - '0';
    else if (ch >= 'a' && ch <= 'f') nib = ch - 'a' + 10;
    else if (ch >= 'A' && ch <= 'F') nib = ch - 'A' + 10;
    if (nib < 0) return;
    unsigned char *mem = eb_memory();
    uint32_t addr = self.cursor;
    unsigned char v = mem[addr];
    if (_highNibble) {                       // first digit → high nibble, stay
        mem[addr] = (unsigned char)((nib << 4) | (v & 0x0F));
        _highNibble = NO;
        [self setNeedsDisplay:YES];
    } else {                                 // second digit → low nibble, advance
        mem[addr] = (unsigned char)((v & 0xF0) | nib);
        _highNibble = YES;
        [self moveCursorBy:+1];              // also marks high nibble + redraws
    }
}
@end

// ───────────────────────────── the window ──────────────────────────────────
@interface EASyBINController () <EBHexDelegate>
@end

@implementation EASyBINController {
    EBHexView   *_hex;
    NSScrollView *_hexScroll;
    NSStepper   *_rowStep, *_pageStep;
    NSTextField *_view, *_first, *_len, *_from, *_to, *_start;
    NSMatrix    *_split;
    NSTextField *_info;
    uint32_t     _base;
}

+ (instancetype)shared {
    static EASyBINController *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[EASyBINController alloc] initWithWindow:nil]; });
    return s;
}

- (void)showBIN { [self buildIfNeeded]; [self.window center]; [self showWindow:nil];
                  [self.window makeKeyAndOrderFront:nil]; [self refresh]; }

- (NSTextField *)field:(NSString *)val width:(CGFloat)w in:(NSView *)v {
    NSTextField *f = [[NSTextField alloc] initWithFrame:NSZeroRect];
    f.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    f.stringValue = val; f.alignment = NSTextAlignmentLeft;
    f.translatesAutoresizingMaskIntoConstraints = NO;
    [f.widthAnchor constraintEqualToConstant:w].active = YES;
    [v addSubview:f];
    return f;
}
- (NSTextField *)lab:(NSString *)s in:(NSView *)v {
    NSTextField *l = [NSTextField labelWithString:s];
    l.font = [NSFont systemFontOfSize:11];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:l];
    return l;
}
- (NSButton *)btn:(NSString *)t sel:(SEL)a in:(NSView *)v {
    NSButton *b = [NSButton buttonWithTitle:t target:self action:a];
    b.bezelStyle = NSBezelStyleRounded; b.font = [NSFont systemFontOfSize:12];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:b];
    return b;
}

- (void)buildIfNeeded {
    if (self.window) return;
    NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,760,560)
        styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    w.title = @"EASyBIN — Binary / S-Record Utility";
    w.releasedWhenClosed = NO;
    self.window = w;
    [E68BrushedView installInWindow:w];
    NSView *root = w.contentView;

    // ── toolbar row of file buttons ──
    NSButton *openS = [self btn:@"Open S-Record…" sel:@selector(openSrec:) in:root];
    NSButton *openB = [self btn:@"Open Binary…"   sel:@selector(openBin:)  in:root];
    NSButton *saveB = [self btn:@"Save Binary…"   sel:@selector(saveBin:)  in:root];
    NSButton *saveS = [self btn:@"Save S-Record…" sel:@selector(saveSrec:) in:root];
    NSButton *clr   = [self btn:@"Clear"          sel:@selector(clearMem:) in:root];

    // ── info line (loaded range / S0) ──
    _info = [self lab:@"No file loaded." in:root];
    _info.textColor = NSColor.secondaryLabelColor;

    // ── binary range + split ──
    NSTextField *binLbl = [self lab:@"Binary:  First $" in:root];
    binLbl.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    _first = [self field:@"001000" width:80 in:root];
    NSTextField *lenLbl = [self lab:@"Length $" in:root];
    _len = [self field:@"000100" width:80 in:root];
    NSTextField *splitLbl = [self lab:@"Split:" in:root];
    _split = [[NSMatrix alloc] initWithFrame:NSZeroRect mode:NSRadioModeMatrix
        cellClass:[NSButtonCell class] numberOfRows:1 numberOfColumns:3];
    _split.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray *names = @[@"None", @"÷2 (even/odd)", @"÷4"];
    for (int i = 0; i < 3; i++) {
        NSButtonCell *c = _split.cells[i];
        c.title = names[i]; c.buttonType = NSButtonTypeRadio; c.font = [NSFont systemFontOfSize:11];
    }
    [_split selectCellAtRow:0 column:0]; [_split sizeToCells];
    [root addSubview:_split];

    // ── S-record range ──
    NSTextField *srLbl = [self lab:@"S-Record:  From $" in:root];
    srLbl.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    _from = [self field:@"001000" width:80 in:root];
    NSTextField *toLbl = [self lab:@"To $" in:root];
    _to = [self field:@"0010FF" width:80 in:root];
    NSTextField *stLbl = [self lab:@"Start $" in:root];
    _start = [self field:@"001000" width:80 in:root];

    // ── hex view + scroll + steppers + goto ──
    NSTextField *gotoLbl = [self lab:@"Goto $" in:root];
    _view = [self field:@"000000" width:80 in:root];
    _view.target = self; _view.action = @selector(gotoAddr:);
    _rowStep = [[NSStepper alloc] initWithFrame:NSZeroRect];
    _rowStep.valueWraps = NO; _rowStep.minValue = -100000; _rowStep.maxValue = 100000; _rowStep.intValue = 0;
    _rowStep.target = self; _rowStep.action = @selector(rowSpin:);
    _rowStep.translatesAutoresizingMaskIntoConstraints = NO; [root addSubview:_rowStep];
    NSTextField *rowLbl = [self lab:@"Row" in:root];
    _pageStep = [[NSStepper alloc] initWithFrame:NSZeroRect];
    _pageStep.valueWraps = NO; _pageStep.minValue = -100000; _pageStep.maxValue = 100000; _pageStep.intValue = 0;
    _pageStep.target = self; _pageStep.action = @selector(pageSpin:);
    _pageStep.translatesAutoresizingMaskIntoConstraints = NO; [root addSubview:_pageStep];
    NSTextField *pageLbl = [self lab:@"Page" in:root];

    _hexScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _hexScroll.hasVerticalScroller = NO; _hexScroll.borderType = NSBezelBorder;
    _hexScroll.drawsBackground = YES; _hexScroll.backgroundColor = NSColor.textBackgroundColor;
    _hexScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _hex = [[EBHexView alloc] initWithFrame:NSMakeRect(0,0,560,1600)];
    _hex.rows = 100; _hex.delegate = self;
    _hexScroll.documentView = _hex;
    [root addSubview:_hexScroll];

    // ── layout ──
    [NSLayoutConstraint activateConstraints:@[
        [openS.topAnchor constraintEqualToAnchor:root.topAnchor constant:14],
        [openS.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:14],
        [openB.centerYAnchor constraintEqualToAnchor:openS.centerYAnchor],
        [openB.leadingAnchor constraintEqualToAnchor:openS.trailingAnchor constant:8],
        [saveB.centerYAnchor constraintEqualToAnchor:openS.centerYAnchor],
        [saveB.leadingAnchor constraintEqualToAnchor:openB.trailingAnchor constant:8],
        [saveS.centerYAnchor constraintEqualToAnchor:openS.centerYAnchor],
        [saveS.leadingAnchor constraintEqualToAnchor:saveB.trailingAnchor constant:8],
        [clr.centerYAnchor constraintEqualToAnchor:openS.centerYAnchor],
        [clr.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-14],

        [_info.topAnchor constraintEqualToAnchor:openS.bottomAnchor constant:10],
        [_info.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:14],
        [_info.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-14],

        [binLbl.topAnchor constraintEqualToAnchor:_info.bottomAnchor constant:12],
        [binLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:14],
        [_first.centerYAnchor constraintEqualToAnchor:binLbl.centerYAnchor],
        [_first.leadingAnchor constraintEqualToAnchor:binLbl.trailingAnchor constant:2],
        [lenLbl.centerYAnchor constraintEqualToAnchor:binLbl.centerYAnchor],
        [lenLbl.leadingAnchor constraintEqualToAnchor:_first.trailingAnchor constant:10],
        [_len.centerYAnchor constraintEqualToAnchor:binLbl.centerYAnchor],
        [_len.leadingAnchor constraintEqualToAnchor:lenLbl.trailingAnchor constant:2],
        [splitLbl.centerYAnchor constraintEqualToAnchor:binLbl.centerYAnchor],
        [splitLbl.leadingAnchor constraintEqualToAnchor:_len.trailingAnchor constant:14],
        [_split.centerYAnchor constraintEqualToAnchor:binLbl.centerYAnchor],
        [_split.leadingAnchor constraintEqualToAnchor:splitLbl.trailingAnchor constant:6],

        [srLbl.topAnchor constraintEqualToAnchor:binLbl.bottomAnchor constant:10],
        [srLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:14],
        [_from.centerYAnchor constraintEqualToAnchor:srLbl.centerYAnchor],
        [_from.leadingAnchor constraintEqualToAnchor:srLbl.trailingAnchor constant:2],
        [toLbl.centerYAnchor constraintEqualToAnchor:srLbl.centerYAnchor],
        [toLbl.leadingAnchor constraintEqualToAnchor:_from.trailingAnchor constant:10],
        [_to.centerYAnchor constraintEqualToAnchor:srLbl.centerYAnchor],
        [_to.leadingAnchor constraintEqualToAnchor:toLbl.trailingAnchor constant:2],
        [stLbl.centerYAnchor constraintEqualToAnchor:srLbl.centerYAnchor],
        [stLbl.leadingAnchor constraintEqualToAnchor:_to.trailingAnchor constant:10],
        [_start.centerYAnchor constraintEqualToAnchor:srLbl.centerYAnchor],
        [_start.leadingAnchor constraintEqualToAnchor:stLbl.trailingAnchor constant:2],

        [gotoLbl.topAnchor constraintEqualToAnchor:srLbl.bottomAnchor constant:12],
        [gotoLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:14],
        [_view.centerYAnchor constraintEqualToAnchor:gotoLbl.centerYAnchor],
        [_view.leadingAnchor constraintEqualToAnchor:gotoLbl.trailingAnchor constant:2],
        [rowLbl.centerYAnchor constraintEqualToAnchor:gotoLbl.centerYAnchor],
        [rowLbl.leadingAnchor constraintEqualToAnchor:_view.trailingAnchor constant:16],
        [_rowStep.centerYAnchor constraintEqualToAnchor:gotoLbl.centerYAnchor],
        [_rowStep.leadingAnchor constraintEqualToAnchor:rowLbl.trailingAnchor constant:4],
        [pageLbl.centerYAnchor constraintEqualToAnchor:gotoLbl.centerYAnchor],
        [pageLbl.leadingAnchor constraintEqualToAnchor:_rowStep.trailingAnchor constant:14],
        [_pageStep.centerYAnchor constraintEqualToAnchor:gotoLbl.centerYAnchor],
        [_pageStep.leadingAnchor constraintEqualToAnchor:pageLbl.trailingAnchor constant:4],

        [_hexScroll.topAnchor constraintEqualToAnchor:gotoLbl.bottomAnchor constant:10],
        [_hexScroll.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:14],
        [_hexScroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-14],
        [_hexScroll.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-14],
    ]];
}

#pragma mark actions

- (uint32_t)hexVal:(NSTextField *)f {
    return (uint32_t)strtoul([f.stringValue stringByReplacingOccurrencesOfString:@"$" withString:@""].UTF8String, NULL, 16);
}
- (int)splitValue { NSInteger c = [_split selectedColumn]; return c == 1 ? 2 : (c == 2 ? 4 : 0); }

- (void)openSrec:(id)s {
    NSOpenPanel *p = [NSOpenPanel openPanel];
    p.allowedFileTypes = @[@"S68",@"s68",@"sr",@"srec",@"hex",@"txt"];
    if ([p runModal] != NSModalResponseOK) return;
    char err[256] = {0}, s0[256] = {0};
    uint32_t lo = 0, hi = 0, start = 0;
    if (eb_load_srec(p.URL.fileSystemRepresentation, &lo, &hi, &start, s0, sizeof s0, err, sizeof err) != 0) {
        [self alert:@"S-Record load failed" info:@(err)]; return;
    }
    _first.stringValue = [NSString stringWithFormat:@"%06X", lo];
    _from.stringValue  = [NSString stringWithFormat:@"%06X", lo];
    _to.stringValue    = [NSString stringWithFormat:@"%06X", hi];
    _start.stringValue = [NSString stringWithFormat:@"%06X", start];
    _len.stringValue   = [NSString stringWithFormat:@"%06X", hi - lo + 1];
    _info.stringValue  = [NSString stringWithFormat:@"Loaded S-Record:  $%06X..$%06X  (%u bytes)   %@",
                          lo, hi, hi - lo + 1, s0[0] ? @(s0) : @""];
    _base = lo & ~0xFu; _hex.cursor = lo; [self refresh]; [self scrollToBase];
}

- (void)openBin:(id)s {
    NSOpenPanel *p = [NSOpenPanel openPanel];
    if ([p runModal] != NSModalResponseOK) return;
    char err[256] = {0};
    uint32_t first = [self hexVal:_first];
    int n = eb_load_binary(p.URL.fileSystemRepresentation, first, [self splitValue], err, sizeof err);
    if (n < 0) { [self alert:@"Binary load failed" info:@(err)]; return; }
    _info.stringValue = [NSString stringWithFormat:@"Loaded binary at $%06X  (%d bytes, split %d)",
                         first, n, [self splitValue]];
    _base = first & ~0xFu; _hex.cursor = first; [self refresh]; [self scrollToBase];
}

- (void)saveBin:(id)s {
    NSSavePanel *p = [NSSavePanel savePanel];
    p.nameFieldStringValue = @"output.bin";
    if ([p runModal] != NSModalResponseOK) return;
    char err[256] = {0};
    if (eb_save_binary(p.URL.fileSystemRepresentation, [self hexVal:_first], [self hexVal:_len],
                       [self splitValue], err, sizeof err) != 0) {
        [self alert:@"Save Binary failed" info:@(err)]; return;
    }
    int sp = [self splitValue];
    _info.stringValue = sp ? [NSString stringWithFormat:@"Saved binary (split ÷%d → _0.._%d files).", sp, sp-1]
                           : @"Saved raw binary.";
}

- (void)saveSrec:(id)s {
    NSSavePanel *p = [NSSavePanel savePanel];
    p.nameFieldStringValue = @"output.S68";
    if ([p runModal] != NSModalResponseOK) return;
    char err[256] = {0};
    if (eb_save_srecord(p.URL.fileSystemRepresentation, [self hexVal:_from], [self hexVal:_to],
                        [self hexVal:_start], err, sizeof err) != 0) {
        [self alert:@"Save S-Record failed" info:@(err)]; return;
    }
    _info.stringValue = @"Saved S-Record.";
}

- (void)clearMem:(id)s { eb_clear(); _info.stringValue = @"Memory cleared."; [self refresh]; }

- (void)gotoAddr:(id)s { _base = [self hexVal:_view] & ~0xFu; _hex.cursor = [self hexVal:_view]; [self refresh]; [self scrollToBase]; }
- (void)rowSpin:(NSStepper *)st {
    int d = (int)st.intValue; st.intValue = 0;
    _base = (uint32_t)((int64_t)_base + d * 16) & (EB_MEMSIZE - 1) & ~0xFu;
    [self refresh]; [self scrollToBase];
}
- (void)pageSpin:(NSStepper *)st {
    int d = (int)st.intValue; st.intValue = 0;
    _base = (uint32_t)((int64_t)_base + d * 256) & (EB_MEMSIZE - 1) & ~0xFu;
    [self refresh]; [self scrollToBase];
}

- (void)hexCursorMovedTo:(uint32_t)addr { _view.stringValue = [NSString stringWithFormat:@"%06X", addr]; }

- (void)scrollToBase {
    // place _base at the top of the clip view (document is flipped)
    int row = (int)(_base / 16);
    [_hex scrollPoint:NSMakePoint(0, row * 15)];
}

- (void)refresh { _hex.base = _base; [_hex setNeedsDisplay:YES]; }

- (void)alert:(NSString *)msg info:(NSString *)info {
    NSAlert *a = [NSAlert new]; a.messageText = msg; a.informativeText = info ?: @"";
    [a addButtonWithTitle:@"OK"]; [a runModal];
}

#pragma mark remote control (no modal panels)

// Push a value into a field if the window has been built (so an open window
// reflects remote-driven state); harmless if it hasn't.
- (void)setField:(NSTextField *)f hex:(uint32_t)v {
    if (f) f.stringValue = [NSString stringWithFormat:@"%06X", v];
}

- (NSDictionary *)remoteLoadSrec:(NSString *)path {
    [self buildIfNeeded];
    char err[256] = {0}, s0[256] = {0}; uint32_t lo = 0, hi = 0, st = 0;
    int r = eb_load_srec(path.fileSystemRepresentation, &lo, &hi, &st, s0, sizeof s0, err, sizeof err);
    if (r != 0) return @{ @"ok": @NO, @"error": @(err) };
    [self setField:_first hex:lo]; [self setField:_from hex:lo];
    [self setField:_to hex:hi]; [self setField:_start hex:st];
    [self setField:_len hex:hi - lo + 1];
    _info.stringValue = [NSString stringWithFormat:@"Loaded S-Record: $%06X..$%06X (%u bytes) %@",
                         lo, hi, hi - lo + 1, s0[0] ? @(s0) : @""];
    _base = lo & ~0xFu; _hex.cursor = lo; [self refresh]; [self scrollToBase];
    return @{ @"ok": @YES, @"low": @(lo), @"high": @(hi), @"start": @(st),
              @"length": @(hi - lo + 1), @"s0": @(s0) };
}

- (NSDictionary *)remoteLoadBinary:(NSString *)path addr:(uint32_t)addr split:(int)split {
    [self buildIfNeeded];
    char err[256] = {0};
    int n = eb_load_binary(path.fileSystemRepresentation, addr, split, err, sizeof err);
    if (n < 0) return @{ @"ok": @NO, @"error": @(err) };
    [self setField:_first hex:addr];
    _info.stringValue = [NSString stringWithFormat:@"Loaded binary at $%06X (%d bytes, split %d)", addr, n, split];
    _base = addr & ~0xFu; _hex.cursor = addr; [self refresh]; [self scrollToBase];
    return @{ @"ok": @YES, @"addr": @(addr), @"bytes": @(n), @"split": @(split) };
}

- (NSDictionary *)remoteSaveBinary:(NSString *)path from:(uint32_t)from length:(uint32_t)length split:(int)split {
    char err[256] = {0};
    int r = eb_save_binary(path.fileSystemRepresentation, from, length, split, err, sizeof err);
    return r == 0 ? @{ @"ok": @YES, @"from": @(from), @"length": @(length), @"split": @(split) }
                  : @{ @"ok": @NO, @"error": @(err) };
}

- (NSDictionary *)remoteSaveSrec:(NSString *)path from:(uint32_t)from to:(uint32_t)to start:(uint32_t)start {
    char err[256] = {0};
    int r = eb_save_srecord(path.fileSystemRepresentation, from, to, start, err, sizeof err);
    return r == 0 ? @{ @"ok": @YES, @"from": @(from), @"to": @(to), @"start": @(start) }
                  : @{ @"ok": @NO, @"error": @(err) };
}

- (NSString *)remoteMemoryAt:(uint32_t)addr length:(int)len {
    unsigned char *mem = eb_memory();
    NSMutableString *m = [NSMutableString string];
    uint32_t base = addr & 0xFFFFFFF0u;
    for (int row = 0; row * 16 < len; row++) {
        uint32_t a = base + (uint32_t)row * 16;
        if (a >= EB_MEMSIZE) break;
        [m appendFormat:@"%06X  ", a];
        for (int c = 0; c < 16; c++) [m appendFormat:@"%02X ", mem[a + c]];
        [m appendString:@" "];
        for (int c = 0; c < 16; c++) { unsigned char ch = mem[a + c]; [m appendFormat:@"%c", (ch >= ' ' && ch < 127) ? ch : '.']; }
        [m appendString:@"\n"];
    }
    return m;
}

@end
