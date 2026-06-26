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
//  SimController.m
//  EASy68K — native 68000 simulator window.
//
#import "SimController.h"
#import "SimCore.h"
#import "SimBridge.h"
#import "SimGraphicsView.h"
#import "SimListingView.h"
#import "SimStackView.h"
#import "E68Theme.h"
#import "SimGfxBridge.h"
#import <stdlib.h>
#import <string.h>

// Toolbar item ids.
static NSToolbarItemIdentifier const kRun   = @"sim.run";
static NSToolbarItemIdentifier const kStep  = @"sim.step";
static NSToolbarItemIdentifier const kStop  = @"sim.stop";
static NSToolbarItemIdentifier const kReset = @"sim.reset";

@interface SimController () <NSToolbarDelegate, NSTextFieldDelegate>
@property (nonatomic, strong) NSTextView *registersView;
@property (nonatomic, strong) SimListingView *listingView;   // .L68 source pane
@property (nonatomic, strong) SimGraphicsView *gfxView;
@property (nonatomic, strong) NSWindow *ioWindow;            // separate I/O window
@property (nonatomic, strong) NSWindow *stackWindow;        // 68000 Stack window
@property (nonatomic, strong) SimStackView *stackView;
@property (nonatomic, strong) NSTextView *memoryView;
@property (nonatomic, strong) NSTextField *inputField;
@property (nonatomic, strong) NSTextField *statusField;
@property (nonatomic, strong) dispatch_queue_t simQueue;
@property (nonatomic, strong) dispatch_semaphore_t inputSem;
@property (nonatomic, copy)   NSString *pendingInput;
@property (nonatomic) BOOL programLoaded;
@property (nonatomic) BOOL running;
@property (nonatomic) uint32_t memBase;
@property (nonatomic, copy) NSString *programName;
@property (nonatomic, copy) NSString *srecPath;
@property (nonatomic, strong) NSMutableString *consoleText;   // capture for /console
- (void)appendConsole:(NSString *)s newline:(BOOL)nl;
- (int)readLineInto:(char *)buf size:(int)size outLen:(int *)outLen;
- (void)refreshState;
- (void)refreshRegisters;
- (void)refreshMemory;
- (BOOL)loadProgram:(NSString *)srecPath title:(NSString *)title;
@end

// ---- C trampolines: forward host callbacks to the controller ----
static void cbTextOut(void *ctx, const char *s, int nl) {
    SimController *c = (__bridge SimController *)ctx;
    [c appendConsole:[NSString stringWithUTF8String:s ?: ""] newline:(nl != 0)];
}
static void cbCharOut(void *ctx, char ch) {
    SimController *c = (__bridge SimController *)ctx;
    char str[2] = { ch, 0 };
    [c appendConsole:[NSString stringWithUTF8String:str] newline:NO];
}
static int cbReadLine(void *ctx, char *buf, int size, int *outLen) {
    SimController *c = (__bridge SimController *)ctx;
    return [c readLineInto:buf size:size outLen:outLen];
}
static void cbCharIn(void *ctx, char *ch) {
    SimController *c = (__bridge SimController *)ctx;
    char tmp[256]; int n = 0;
    [c readLineInto:tmp size:sizeof(tmp) outLen:&n];
    if (ch) *ch = n > 0 ? tmp[0] : 0;
}
static void cbClear(void *ctx) {
    SimController *c = (__bridge SimController *)ctx;
    [c.consoleText setString:@""];
    gfx_clear();
}
static void cbMessage(void *ctx, const char *s) {
    SimController *c = (__bridge SimController *)ctx;
    [c appendConsole:[NSString stringWithFormat:@"%@\n", [NSString stringWithUTF8String:s ?: ""]] newline:NO];
}
static void cbUpdate(void *ctx) {
    SimController *c = (__bridge SimController *)ctx;
    dispatch_async(dispatch_get_main_queue(), ^{ [c refreshState]; });
}
static void cbMemChanged(void *ctx, int addr) { (void)ctx; (void)addr; }

@implementation SimController

+ (instancetype)sharedController {
    static SimController *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SimController alloc] init]; });
    return shared;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 960, 640);
    NSWindow *win = [[NSWindow alloc] initWithContentRect:frame
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                   NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    win.title = @"Simulator";
    win.minSize = NSMakeSize(720, 420);
    [win center];
    if ((self = [super initWithWindow:win])) {
        _simQueue = dispatch_queue_create("com.easy68k.sim", DISPATCH_QUEUE_SERIAL);
        _inputSem = dispatch_semaphore_create(0);
        _memBase = 0x1000;
        [self buildToolbar];
        [self buildUI];
        [self installHost];
    }
    return self;
}

- (void)installHost {
    SimBridgeCallbacks cb = {0};
    cb.ctx = (__bridge void *)self;
    cb.textOut = cbTextOut;
    cb.charOut = cbCharOut;
    cb.readLine = cbReadLine;
    cb.charIn = cbCharIn;
    cb.clearConsole = cbClear;
    cb.message = cbMessage;
    cb.updateDisplay = cbUpdate;
    cb.memoryChanged = cbMemChanged;
    SimBridge_install(cb);
}

#pragma mark UI

static NSTextView *MonoTextView(NSScrollView *scroll, BOOL editable) {
    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,400,400)];
    tv.minSize = NSMakeSize(0,0);
    tv.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    tv.verticallyResizable = YES; tv.horizontallyResizable = YES;
    tv.autoresizingMask = NSViewNotSizable;
    tv.textContainer.containerSize = NSMakeSize(FLT_MAX, FLT_MAX);
    tv.textContainer.widthTracksTextView = NO;
    tv.editable = editable; tv.richText = NO;
    tv.drawsBackground = YES;
    tv.backgroundColor = NSColor.textBackgroundColor;
    tv.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    tv.textContainerInset = NSMakeSize(6, 6);
    scroll.documentView = tv;
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = YES;
    scroll.borderType = NSNoBorder;
    return tv;
}

- (void)buildUI {
    NSView *content = self.window.contentView;

    // Horizontal split: [registers] | [console + memory]
    NSSplitView *hsplit = [[NSSplitView alloc] initWithFrame:content.bounds];
    hsplit.vertical = YES; hsplit.dividerStyle = NSSplitViewDividerStyleThin;
    hsplit.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:hsplit];
    [NSLayoutConstraint activateConstraints:@[
        [hsplit.topAnchor constraintEqualToAnchor:content.topAnchor],
        [hsplit.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [hsplit.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [hsplit.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24],
    ]];

    // Left: registers
    NSScrollView *regScroll = [[NSScrollView alloc] initWithFrame:content.bounds];
    self.registersView = MonoTextView(regScroll, NO);
    [hsplit addSubview:regScroll];

    // Right: vertical split [console] / [memory]
    NSSplitView *vsplit = [[NSSplitView alloc] initWithFrame:content.bounds];
    vsplit.vertical = NO; vsplit.dividerStyle = NSSplitViewDividerStyleThin;
    [hsplit addSubview:vsplit];

    // Center: the .L68 source-level listing (the main debugging view, with
    // PC-line highlight + breakpoint gutter) — same role as the original
    // Sim68K ListBox1. The I/O graphics live in their own window.
    self.listingView = [[SimListingView alloc] initWithFrame:content.bounds];
    self.listingView.listingDelegate = (id)self;
    [vsplit addSubview:self.listingView];

    // Bottom: memory hex dump
    NSScrollView *memScroll = [[NSScrollView alloc] initWithFrame:content.bounds];
    self.memoryView = MonoTextView(memScroll, NO);
    [vsplit addSubview:memScroll];

    // The separate I/O window (graphics canvas + console input).
    [self buildIOWindow];
    [self buildStackWindow];

    dispatch_async(dispatch_get_main_queue(), ^{
        [hsplit setPosition:250 ofDividerAtIndex:0];
        [vsplit setPosition:NSHeight(vsplit.bounds) * 0.62 ofDividerAtIndex:0];
    });

    // Status bar
    NSTextField *status = [NSTextField labelWithString:@"No program loaded"];
    status.font = [NSFont systemFontOfSize:11];
    status.textColor = NSColor.secondaryLabelColor;
    status.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:status];
    [NSLayoutConstraint activateConstraints:@[
        [status.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:10],
        [status.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-5],
    ]];
    self.statusField = status;

    // restyle the mono panes live when the font-size setting changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged)
                                                 name:E68ThemeChangedNotification object:nil];
    [self themeChanged];
}

- (void)themeChanged {
    NSFont *f = [E68Theme shared].monoFont;
    self.registersView.font = f;
    self.memoryView.font = f;
    if (self.programLoaded) { [self refreshRegisters]; [self refreshMemory]; }
}

// The simulator I/O window (separate from the main listing window, matching the
// original Sim68K's separate simIO form): the graphics/text canvas plus the
// console input field.
- (void)buildIOWindow {
    NSRect frame = NSMakeRect(0, 0, 660, 540);
    NSWindow *w = [[NSWindow alloc] initWithContentRect:frame
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                   NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    w.title = @"Output";
    w.releasedWhenClosed = NO;
    NSView *box = w.contentView;

    NSScrollView *gfxScroll = [[NSScrollView alloc] initWithFrame:box.bounds];
    gfxScroll.hasVerticalScroller = YES; gfxScroll.hasHorizontalScroller = YES;
    gfxScroll.borderType = NSNoBorder;
    gfxScroll.backgroundColor = NSColor.blackColor;
    gfxScroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.gfxView = [[SimGraphicsView alloc] initWithFrame:NSMakeRect(0,0,640,480)];
    gfxScroll.documentView = self.gfxView;
    [box addSubview:gfxScroll];

    NSTextField *input = [[NSTextField alloc] init];
    input.placeholderString = @"input…";
    input.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    input.translatesAutoresizingMaskIntoConstraints = NO;
    input.target = self; input.action = @selector(inputEntered:);
    input.delegate = self;
    input.enabled = NO;
    self.inputField = input;
    [box addSubview:input];
    [NSLayoutConstraint activateConstraints:@[
        [gfxScroll.topAnchor constraintEqualToAnchor:box.topAnchor],
        [gfxScroll.leadingAnchor constraintEqualToAnchor:box.leadingAnchor],
        [gfxScroll.trailingAnchor constraintEqualToAnchor:box.trailingAnchor],
        [gfxScroll.bottomAnchor constraintEqualToAnchor:input.topAnchor constant:-4],
        [input.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:6],
        [input.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-6],
        [input.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-6],
    ]];
    self.ioWindow = w;
    gfx_setActiveView((__bridge void *)self.gfxView);
}

// The 68000 Stack window (separate, matching the original Sim68K StackFrm).
- (void)buildStackWindow {
    NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 320, 460)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                   NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    w.title = @"68000 Stack";
    w.releasedWhenClosed = NO;
    self.stackView = [[SimStackView alloc] initWithFrame:((NSView *)w.contentView).bounds];
    self.stackView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [w.contentView addSubview:self.stackView];
    self.stackWindow = w;
}

- (void)showStackWindow:(id)sender {
    [self.stackWindow makeKeyAndOrderFront:nil];
    [self.stackView refresh];
}

// Breakpoint toggled from the listing gutter. The listing view holds the
// breakpoint set; run: snapshots it. (A dedicated Breakpoints window will hook
// here too.)
- (void)listingToggledBreakpointAtAddress:(uint32_t)addr enabled:(BOOL)enabled {
    (void)addr; (void)enabled;
}

#pragma mark Toolbar

- (void)buildToolbar {
    NSToolbar *tb = [[NSToolbar alloc] initWithIdentifier:@"SimToolbar"];
    tb.delegate = self; tb.displayMode = NSToolbarDisplayModeIconAndLabel;
    if (@available(macOS 11.0, *)) self.window.toolbarStyle = NSWindowToolbarStyleUnified;
    self.window.toolbar = tb;
}
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)t {
    return @[kRun, kStep, kStop, NSToolbarFlexibleSpaceItemIdentifier, kReset];
}
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)t { return [self toolbarDefaultItemIdentifiers:t]; }
- (NSToolbarItem *)toolbar:(NSToolbar *)t itemForItemIdentifier:(NSToolbarItemIdentifier)i willBeInsertedIntoToolbar:(BOOL)f {
    NSToolbarItem *it = [[NSToolbarItem alloc] initWithItemIdentifier:i];
    it.bordered = YES; it.target = self;
    NSString *sym, *label; SEL a;
    if ([i isEqual:kRun])       { sym=@"play.fill"; label=@"Run";   a=@selector(run:); }
    else if ([i isEqual:kStep]) { sym=@"arrow.turn.down.right"; label=@"Step"; a=@selector(step:); }
    else if ([i isEqual:kStop]) { sym=@"stop.fill"; label=@"Stop";  a=@selector(stop:); }
    else if ([i isEqual:kReset]){ sym=@"arrow.counterclockwise"; label=@"Reset"; a=@selector(resetSim:); }
    else return nil;
    it.label = label; it.image = [NSImage imageWithSystemSymbolName:sym accessibilityDescription:label];
    it.action = a;
    return it;
}

#pragma mark Load / run

- (void)loadAndShow:(NSString *)srecPath title:(NSString *)title {
    [self loadProgram:srecPath title:title];
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
    [self.ioWindow orderFront:nil];   // surface the separate I/O window
    if (self.programLoaded)
        [self run:nil];        // "Assemble and Run" executes immediately
}

// Load (or reload) the program into a fresh machine state.
- (BOOL)loadProgram:(NSString *)srecPath title:(NSString *)title {
    self.srecPath = srecPath;
    self.programName = title;
    self.window.title = [NSString stringWithFormat:@"Simulator — %@", title];
    if (!memory) memory = (char *)calloc(SIM_MEMSIZE, 1);
    exceptions = 1; bitfield = true;
    initSim();
    memset(memory, 0, SIM_MEMSIZE);
    int rc = loadSrec((char *)srecPath.fileSystemRepresentation);
    OLD_PC = PC;        // prime the current-instruction tracker to the start
                        // address (the GUI's run handler does this; the first
                        // relative branch needs OLD_PC == its own address)
    // Load the .L68 listing for source-level debugging and apply its
    // *[sim68k] directives (breakpoints, bitfield, simhalt_off).
    [self.listingView loadListingForSRecord:srecPath];
    BOOL bf = NO, shoff = NO;
    [self.listingView scanDirectivesBitfield:&bf simhaltOff:&shoff];
    if (bf) bitfield = true;
    [self.consoleText setString:@""];
    [self.gfxView clearScreen];
    self.programLoaded = (rc == 0 /*SUCCESS*/);
    self.memBase = (uint32_t)PC & 0xFFFFF0;
    [self refreshState];
    self.statusField.stringValue = self.programLoaded
        ? [NSString stringWithFormat:@"Loaded %@ — PC=%08X (Step or Run)", title, (unsigned)PC]
        : @"Failed to load program";
    return self.programLoaded;
}

- (void)run:(id)sender {
    if (!self.programLoaded || self.running) return;
    self.running = YES;
    self.statusField.stringValue = @"Running…";
    // Surface the I/O window and give its canvas keyboard focus so TRAP #15
    // task 19 (getKeyState) sees live key presses while the program runs.
    [self.ioWindow makeKeyAndOrderFront:nil];
    [self.ioWindow makeFirstResponder:self.gfxView];
    // Snapshot the breakpoint addresses for a lock-free check in the run loop.
    NSArray<NSNumber *> *bpArr = [self.listingView breakpointAddresses];
    NSUInteger nbp = bpArr.count;
    uint32_t *bps = (uint32_t *)malloc(sizeof(uint32_t) * (nbp ? nbp : 1));
    for (NSUInteger i = 0; i < nbp; i++) bps[i] = bpArr[i].unsignedIntValue;
    trace = false; sstep = false; halt = false; stopInstruction = false; runMode = true;
    dispatch_async(self.simQueue, ^{
        while (runMode && !halt) {
            runprog();
            if (nbp) {
                uint32_t pc = (uint32_t)PC;
                for (NSUInteger i = 0; i < nbp; i++)
                    if (bps[i] == pc) { runMode = false; break; }
            }
        }
        free(bps);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.running = NO;
            [self refreshState];
            BOOL atBP = [self.listingView hasBreakpointAtAddress:(uint32_t)PC];
            self.statusField.stringValue = [NSString stringWithFormat:
                @"%@ — PC=%08X  cycles=%llu", atBP ? @"Breakpoint" : @"Halted",
                (unsigned)PC, (unsigned long long)cycles];
        });
    });
}

- (void)step:(id)sender {
    if (!self.programLoaded || self.running) return;
    trace = true; sstep = false; halt = false; runMode = true;
    dispatch_async(self.simQueue, ^{
        runprog();
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshState];
            self.statusField.stringValue = [NSString stringWithFormat:
                @"Stepped — PC=%08X  cycles=%llu", (unsigned)PC, (unsigned long long)cycles];
        });
    });
}

- (void)stop:(id)sender {
    runMode = false; halt = true;
    // Release a pending input wait so the sim thread can unwind.
    dispatch_semaphore_signal(self.inputSem);
}

- (void)resetSim:(id)sender {
    if (self.running) [self stop:sender];
    // Reload the program so the PC and memory are restored to the start.
    if (self.srecPath) [self loadProgram:self.srecPath title:self.programName];
    self.statusField.stringValue = @"Reset — ready to Step or Run";
}

#pragma mark Console + input

- (void)appendConsole:(NSString *)s newline:(BOOL)nl {
    if (!self.consoleText) self.consoleText = [NSMutableString string];
    [self.consoleText appendString:s];
    if (nl) [self.consoleText appendString:@"\n"];
    // Render onto the graphics canvas (the I/O surface).
    gfx_textOut(s.UTF8String ?: "", nl ? 1 : 0);
}

- (int)readLineInto:(char *)buf size:(int)size outLen:(int *)outLen {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.inputField.enabled = YES;
        [self.window makeFirstResponder:self.inputField];
        self.statusField.stringValue = @"Waiting for input…";
    });
    dispatch_semaphore_wait(self.inputSem, DISPATCH_TIME_FOREVER);
    NSString *line = self.pendingInput ?: @"";
    const char *utf = line.UTF8String ?: "";
    strncpy(buf, utf, size - 1);
    buf[size - 1] = '\0';
    int n = (int)strlen(buf);
    if (outLen) *outLen = n;
    self.pendingInput = nil;
    return n;
}

- (void)inputEntered:(id)sender {
    NSString *line = self.inputField.stringValue;
    self.pendingInput = line;
    [self appendConsole:line newline:YES];   // echo
    self.inputField.stringValue = @"";
    self.inputField.enabled = NO;
    if (self.running) self.statusField.stringValue = @"Running…";
    dispatch_semaphore_signal(self.inputSem);
}

#pragma mark Display

- (void)refreshState {
    [self refreshRegisters];
    [self refreshMemory];
    [self.listingView highlightPC:(uint32_t)PC halted:(halt || !self.running)];
    if (self.stackWindow.isVisible) [self.stackView refresh];
}

static NSString *Flags(short sr) {
    char b[18];
    const char *names = "TS  III   XNZVC";  // bit15..bit0 labels (approx positions)
    (void)names;
    // Build a readable SR breakdown.
    int t = (sr >> 15) & 1, s = (sr >> 13) & 1, i = (sr >> 8) & 7;
    int x = (sr >> 4) & 1, n = (sr >> 3) & 1, z = (sr >> 2) & 1, v = (sr >> 1) & 1, c = sr & 1;
    snprintf(b, sizeof(b), "%d%d%d%d%d", x, n, z, v, c);
    return [NSString stringWithFormat:@"T=%d S=%d I=%d  X=%d N=%d Z=%d V=%d C=%d", t, s, i, x, n, z, v, c];
}

- (void)refreshRegisters {
    NSMutableString *m = [NSMutableString string];
    for (int r = 0; r < 8; r++)
        [m appendFormat:@"D%d  %08X    A%d  %08X\n", r, (unsigned)D[r], r, (unsigned)A[r]];
    [m appendFormat:@"\nUSP %08X    SSP %08X\n", (unsigned)A[7], (unsigned)A[8]];
    [m appendFormat:@"PC  %08X\n", (unsigned)PC];
    [m appendFormat:@"SR  %04X\n", (unsigned short)SR];
    [m appendFormat:@"    %@\n", Flags(SR)];
    [m appendFormat:@"\nCycles  %llu\n", (unsigned long long)cycles];
    self.registersView.string = m;
}

#pragma mark Remote control

- (void)remoteLoad:(NSString *)srecPath title:(NSString *)title {
    [self loadProgram:srecPath title:(title ?: srecPath.lastPathComponent)];
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
}
- (void)remoteRun   { [self run:nil]; }
- (void)remoteStep  { [self step:nil]; }   // async; poll /status for result
- (void)remoteStop  { [self stop:nil]; }
- (void)remoteReset { [self resetSim:nil]; }
- (void)remoteInput:(NSString *)text {
    self.inputField.stringValue = text ?: @"";
    [self inputEntered:nil];
}

- (NSDictionary *)remoteState {
    NSMutableArray *d = [NSMutableArray array], *a = [NSMutableArray array];
    for (int i = 0; i < 8; i++) [d addObject:@((uint32_t)D[i])];
    for (int i = 0; i < 9; i++) [a addObject:@((uint32_t)A[i])];
    return @{
        @"D": d, @"A": a,
        @"PC": @((uint32_t)PC),
        @"SR": @((uint16_t)SR),
        @"cycles": @((unsigned long long)cycles),
        @"halted": @(halt ? YES : NO),
        @"running": @(self.running),
        @"loaded": @(self.programLoaded),
        @"program": self.programName ?: @"",
        @"status": self.statusField.stringValue ?: @"",
    };
}

- (NSString *)remoteMemoryAt:(uint32_t)addr length:(int)len {
    if (!memory) return @"";
    NSMutableString *m = [NSMutableString string];
    uint32_t base = addr & 0xFFFFFFF0;
    for (int row = 0; row * 16 < len; row++) {
        uint32_t a = base + row * 16;
        if (a >= SIM_MEMSIZE) break;
        [m appendFormat:@"%06X  ", a];
        for (int c = 0; c < 16; c++) [m appendFormat:@"%02X ", (unsigned char)memory[a + c]];
        [m appendString:@" "];
        for (int c = 0; c < 16; c++) { unsigned char ch = memory[a + c]; [m appendFormat:@"%c", (ch >= ' ' && ch < 127) ? ch : '.']; }
        [m appendString:@"\n"];
    }
    return m;
}

- (NSString *)remoteConsole { return self.consoleText ?: @""; }

- (void)refreshMemory {
    if (!memory) return;
    NSMutableString *m = [NSMutableString string];
    uint32_t base = self.memBase & 0xFFFFF0;
    for (int row = 0; row < 24; row++) {
        uint32_t addr = base + row * 16;
        if (addr >= SIM_MEMSIZE) break;
        [m appendFormat:@"%06X  ", addr];
        for (int col = 0; col < 16; col++) {
            [m appendFormat:@"%02X", (unsigned char)memory[addr + col]];
            if (col % 2) [m appendString:@" "];
        }
        [m appendString:@" "];
        for (int col = 0; col < 16; col++) {
            unsigned char ch = (unsigned char)memory[addr + col];
            [m appendFormat:@"%c", (ch >= ' ' && ch < 127) ? ch : '.'];
        }
        [m appendString:@"\n"];
    }
    self.memoryView.string = m;
}

@end
