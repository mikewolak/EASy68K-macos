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
#import "SimBreakpointsView.h"
#import "SimHardwareView.h"
#import "SimHwBridge.h"
#import "E68BrushedView.h"
#import "SimSoundBridge.h"
#import "SimIntController.h"
#import "SimLogController.h"
#import "SimLogBridge.h"
#import "E68Theme.h"
#import "SimGfxBridge.h"
#import <stdlib.h>
#import <string.h>

// Toolbar item ids.
static NSToolbarItemIdentifier const kOpen      = @"sim.open";
static NSToolbarItemIdentifier const kRun       = @"sim.run";
static NSToolbarItemIdentifier const kRunCursor = @"sim.runcursor";
static NSToolbarItemIdentifier const kAutoTrace = @"sim.autotrace";
static NSToolbarItemIdentifier const kStep      = @"sim.step";
static NSToolbarItemIdentifier const kTrace     = @"sim.trace";
static NSToolbarItemIdentifier const kPause     = @"sim.pause";
static NSToolbarItemIdentifier const kReset     = @"sim.reset";
static NSToolbarItemIdentifier const kReload    = @"sim.reload";
static NSToolbarItemIdentifier const kStack     = @"sim.stack";
static NSToolbarItemIdentifier const kLog       = @"sim.log";

@interface SimController () <NSToolbarDelegate, NSTextFieldDelegate, SimListingDelegate, SimBreakpointsDelegate>
@property (nonatomic, strong) NSTextView *registersView;
@property (nonatomic, strong) SimListingView *listingView;   // .L68 source pane
@property (nonatomic, strong) SimGraphicsView *gfxView;
@property (nonatomic, strong) NSWindow *ioWindow;            // separate I/O window
@property (nonatomic, strong) NSWindow *stackWindow;        // 68000 Stack window
@property (nonatomic, strong) SimStackView *stackView;
@property (nonatomic, strong) NSWindow *bpWindow;          // Break Points window
@property (nonatomic, strong) SimBreakpointsView *bpView;
@property (nonatomic, strong) NSWindow *hwWindow;         // Hardware window
@property (nonatomic, strong) SimHardwareView *hwView;
@property (nonatomic, strong) NSTimer *autoTraceTimer;     // AutoTrace animation
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
    NSRect frame = NSMakeRect(0, 0, 1240, 760);
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
    simlog_set_listing((__bridge void *)self.listingView);   // pretty-print log

    // Bottom: memory hex dump
    NSScrollView *memScroll = [[NSScrollView alloc] initWithFrame:content.bounds];
    self.memoryView = MonoTextView(memScroll, NO);
    [vsplit addSubview:memScroll];

    // The separate I/O window (graphics canvas + console input).
    [self buildIOWindow];
    [self buildStackWindow];
    [self buildBreakpointsWindow];
    [self buildHardwareWindow];

    // registers pane wide enough for the SR flags line ("T=0 S=1 ... C=0"),
    // the rest to the listing/memory so the 16-byte memory dump isn't clipped.
    dispatch_async(dispatch_get_main_queue(), ^{
        [hsplit setPosition:340 ofDividerAtIndex:0];
        [vsplit setPosition:NSHeight(vsplit.bounds) * 0.66 ofDividerAtIndex:0];
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
    [w center];                 // open centered on screen, not bottom-left
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
    [E68BrushedView installInWindow:w];
    self.stackView = [[SimStackView alloc] initWithFrame:((NSView *)w.contentView).bounds];
    self.stackView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [w.contentView addSubview:self.stackView];
    self.stackWindow = w;
}

- (void)showStackWindow:(id)sender {
    [self.stackWindow makeKeyAndOrderFront:nil];
    [self.stackView refresh];
}

// The Break Points window (manages the core's simple PC breakpoints).
- (void)buildBreakpointsWindow {
    NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 340)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                   NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    w.title = @"Break Points";
    w.releasedWhenClosed = NO;
    [E68BrushedView installInWindow:w];
    self.bpView = [[SimBreakpointsView alloc] initWithFrame:((NSView *)w.contentView).bounds];
    self.bpView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.bpView.bpDelegate = (id)self;
    [w.contentView addSubview:self.bpView];
    self.bpWindow = w;
}

- (void)showLog:(id)sender { [[SimLogController shared] showLog]; }

// Maintain the core's brkpt[] array so runprog() stops there natively.
- (void)coreSetBreakpoint:(uint32_t)addr enabled:(BOOL)enabled {
    if (enabled) {
        for (int i = 0; i < bpoints; i++) if ((uint32_t)brkpt[i] == addr) return;
        if (bpoints < 100) brkpt[(int)bpoints++] = (int)addr;
    } else {
        for (int i = 0; i < bpoints; i++)
            if ((uint32_t)brkpt[i] == addr) {
                for (int j = i; j < bpoints - 1; j++) brkpt[j] = brkpt[j + 1];
                bpoints--;
                break;
            }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"E68BreakpointsChanged" object:nil];
}

// SimListingDelegate — gutter toggled (the listing already updated its dot).
- (void)listingToggledBreakpointAtAddress:(uint32_t)addr enabled:(BOOL)enabled {
    [self coreSetBreakpoint:addr enabled:enabled];
}

// SimBreakpointsDelegate — the Break Points window adds/removes; keep the
// listing gutter and the core's brkpt[] in sync.
- (void)addBreakpointAtAddress:(uint32_t)addr {
    [self.listingView setBreakpoint:addr enabled:YES];
    [self coreSetBreakpoint:addr enabled:YES];
}
- (void)removeBreakpointAtAddress:(uint32_t)addr {
    [self.listingView setBreakpoint:addr enabled:NO];
    [self coreSetBreakpoint:addr enabled:NO];
}
- (void)clearAllBreakpoints {
    for (NSNumber *a in [[self.listingView breakpointAddresses] copy])
        [self.listingView setBreakpoint:a.unsignedIntValue enabled:NO];
    bpoints = 0;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"E68BreakpointsChanged" object:nil];
}
- (NSString *)sourceLineForAddress:(uint32_t)addr {
    return [self.listingView instructionLineForAddress:addr];
}

- (void)showBreakpointsWindow:(id)sender {
    [self.bpWindow makeKeyAndOrderFront:nil];
    [self.bpView refresh];
}

// The Hardware window (memory-mapped LEDs / 7-seg / switches).
- (void)buildHardwareWindow {
    // Sim68K hardwareu.dfm layout (422 wide) + room for the right-hand address
    // captions = 462 x 495, fixed.
    NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 462, 495)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
        backing:NSBackingStoreBuffered defer:NO];
    w.title = @"EASy68K Hardware";
    w.releasedWhenClosed = NO;
    self.hwView = [[SimHardwareView alloc] initWithFrame:NSMakeRect(0,0,462,495)];
    [w.contentView addSubview:self.hwView];
    self.hwWindow = w;
    hw_set_view((__bridge void *)self.hwView);
}

- (void)showHardwareWindow:(id)sender {
    [self.hwWindow makeKeyAndOrderFront:nil];
    [self.hwView refresh];
}

#pragma mark Toolbar

- (void)buildToolbar {
    NSToolbar *tb = [[NSToolbar alloc] initWithIdentifier:@"SimToolbar"];
    tb.delegate = self; tb.displayMode = NSToolbarDisplayModeIconAndLabel;
    if (@available(macOS 11.0, *)) self.window.toolbarStyle = NSWindowToolbarStyleUnified;
    self.window.toolbar = tb;
}
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)t {
    return @[kOpen, NSToolbarSpaceItemIdentifier,
             kRun, kRunCursor, kAutoTrace, kStep, kTrace, kPause,
             NSToolbarFlexibleSpaceItemIdentifier,
             kStack, kLog, kReload, kReset];
}
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)t {
    return [[self toolbarDefaultItemIdentifiers:t] arrayByAddingObjectsFromArray:
            @[NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier]];
}
- (NSToolbarItem *)toolbar:(NSToolbar *)t itemForItemIdentifier:(NSToolbarItemIdentifier)i willBeInsertedIntoToolbar:(BOOL)f {
    NSToolbarItem *it = [[NSToolbarItem alloc] initWithItemIdentifier:i];
    it.bordered = YES; it.target = self;
    NSString *sym, *label; SEL a;
    if ([i isEqual:kOpen])           { sym=@"folder"; label=@"Open"; a=@selector(openProgram:); }
    else if ([i isEqual:kRun])       { sym=@"play.fill"; label=@"Run";   a=@selector(run:); }
    else if ([i isEqual:kRunCursor]) { sym=@"forward.end.fill"; label=@"To Cursor"; a=@selector(runToCursor:); }
    else if ([i isEqual:kAutoTrace]) { sym=@"goforward"; label=@"AutoTrace"; a=@selector(autoTrace:); }
    else if ([i isEqual:kStep])      { sym=@"arrow.right.to.line"; label=@"Step Over"; a=@selector(step:); }
    else if ([i isEqual:kTrace])     { sym=@"arrow.turn.down.right"; label=@"Trace"; a=@selector(traceInto:); }
    else if ([i isEqual:kPause])     { sym=@"pause.fill"; label=@"Pause";  a=@selector(pause:); }
    else if ([i isEqual:kStack])     { sym=@"square.stack.3d.up"; label=@"Stack"; a=@selector(showStackWindow:); }
    else if ([i isEqual:kLog])       { sym=@"doc.text"; label=@"Log"; a=@selector(showLog:); }
    else if ([i isEqual:kReload])    { sym=@"arrow.clockwise"; label=@"Reload"; a=@selector(reload:); }
    else if ([i isEqual:kReset])     { sym=@"arrow.counterclockwise"; label=@"Reset"; a=@selector(resetSim:); }
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
    // resolve relative WAV names (TRAP sound tasks) against the program's folder
    snd_set_base_dir([srecPath stringByDeletingLastPathComponent].fileSystemRepresentation);
    self.window.title = [NSString stringWithFormat:@"Simulator — %@", title];
    if (!memory) memory = (char *)calloc(SIM_MEMSIZE, 1);
    exceptions = 1; bitfield = true;
    initSim();
    simIntReset();      // device I/O interrupts always start disabled for a new
                        // program — they never leak in from a previous run
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
    // sync the core's simple-breakpoint array from the listing (gutter +
    // *[sim68k]break directives)
    bpoints = 0;
    for (NSNumber *a in [self.listingView breakpointAddresses])
        if (bpoints < 100) brkpt[(int)bpoints++] = (int)a.unsignedIntValue;
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

// Unified execution engine. runprog() stops itself when `trace` is set (or at
// stepToAddr for step-over), so Run / Run-To-Cursor / Step / Trace all share
// this one loop and differ only by the trace/sstep flags + the stop set.
//   tr=NO,ss=NO            -> Run (free running, stops on breakpoint/halt)
//   tr=YES,ss=NO           -> Trace (step into, one instruction)
//   tr=YES,ss=YES          -> Step (over: runs through BSR/JSR subroutines)
//   stopAt>=0              -> extra one-shot stop address (Run To Cursor)
- (void)startTrace:(BOOL)tr sstep:(BOOL)ss stopAt:(int64_t)stopAt verb:(NSString *)verb {
    if (!self.programLoaded || self.running) return;
    self.running = YES;
    if (!tr) {       // free run / run-to-cursor
        self.statusField.stringValue = @"Running…";
        [self.ioWindow makeKeyAndOrderFront:nil];
        [self.ioWindow makeFirstResponder:self.gfxView];
    }
    // The core checks brkpt[] (simple breakpoints), runToAddr (run-to-cursor)
    // and bpExpressions[] (advanced) itself in runprog(), forcing trace=true to
    // stop — so the run loop just spins until runMode clears.
    runToAddr = (stopAt >= 0) ? (int)stopAt : 0;
    trace = tr; sstep = ss; halt = false; stopInstruction = false;
    if (ss) stepToAddr = 0;
    runMode = true;
    dispatch_async(self.simQueue, ^{
        while (runMode && !halt) runprog();
        dispatch_async(dispatch_get_main_queue(), ^{
            self.running = NO;
            [self refreshState];
            BOOL atBP = [self.listingView hasBreakpointAtAddress:(uint32_t)PC];
            NSString *v = atBP ? @"Breakpoint" : (verb ?: @"Halted");
            self.statusField.stringValue = [NSString stringWithFormat:
                @"%@ — PC=%08X  cycles=%llu", v, (unsigned)PC, (unsigned long long)cycles];
        });
    });
}

- (void)run:(id)sender          { [self stopAutoTrace]; [self startTrace:NO  sstep:NO  stopAt:-1 verb:@"Halted"]; }
- (void)step:(id)sender         { [self stopAutoTrace]; [self startTrace:YES sstep:YES stopAt:-1 verb:@"Stepped"]; }  // Step Over
- (void)traceInto:(id)sender    { [self stopAutoTrace]; [self startTrace:YES sstep:NO  stopAt:-1 verb:@"Traced"]; }    // Trace Into
- (void)runToCursor:(id)sender {
    uint32_t target = [self.listingView selectedAddress];
    if (!target) { self.statusField.stringValue = @"Run To Cursor: select an instruction line first"; return; }
    [self stopAutoTrace];
    [self startTrace:NO sstep:NO stopAt:(int64_t)target verb:@"At cursor"];
}

// AutoTrace: animate single-stepping on a timer (the original's AutoTraceTimer).
- (void)autoTrace:(id)sender {
    if (self.autoTraceTimer) { [self stopAutoTrace]; return; }   // toggle
    self.autoTraceTimer = [NSTimer scheduledTimerWithTimeInterval:0.06 repeats:YES block:^(NSTimer *t) {
        if (self.running || !self.programLoaded || halt) return;
        [self startTrace:YES sstep:NO stopAt:-1 verb:@"AutoTrace"];
    }];
    self.statusField.stringValue = @"AutoTrace…";
}
- (void)stopAutoTrace {
    if (self.autoTraceTimer) { [self.autoTraceTimer invalidate]; self.autoTraceTimer = nil; }
}

- (void)pause:(id)sender { [self stop:sender]; }

- (void)stop:(id)sender {
    [self stopAutoTrace];
    runMode = false; halt = true;
    // Release a pending input wait so the sim thread can unwind.
    dispatch_semaphore_signal(self.inputSem);
}

// Open a .S68 program from disk into the simulator.
- (void)openProgram:(id)sender {
    NSOpenPanel *p = [NSOpenPanel openPanel];
    p.allowedFileTypes = @[@"S68", @"s68", @"h68", @"x68"];
    p.allowsMultipleSelection = NO;
    if ([p runModal] == NSModalResponseOK && p.URLs.firstObject) {
        NSURL *u = p.URLs.firstObject;
        [self stop:nil];
        [self loadProgram:u.path title:u.lastPathComponent];
        [self.ioWindow orderFront:nil];
    }
}

// Reload the current program from disk (the original's Reload).
- (void)reload:(id)sender {
    if (self.srecPath) { [self stop:nil]; [self loadProgram:self.srecPath title:self.programName]; }
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
        // The input field lives in the separate I/O window — surface it and make
        // it first responder THERE (not in the main listing window).
        [self.ioWindow makeKeyAndOrderFront:nil];
        self.inputField.enabled = YES;
        [self.ioWindow makeFirstResponder:self.inputField];
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
    // Return keyboard focus to the canvas so getKeyState (task 19) keeps working.
    [self.ioWindow makeFirstResponder:self.gfxView];
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
