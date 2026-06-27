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
//  SimLogController.m
//
#import "SimLogController.h"
#import "E68Theme.h"
#import "E68BrushedView.h"
#import <stdio.h>

// Execution-log globals in the sim core (globals.c). ElogFlag values:
// DISABLED=0, INSTRUCTION=1, REGISTERS=2, INST_REG_MEM=3.
extern char         ElogFlag;
extern FILE        *ElogFile;
extern bool         logging;
extern unsigned int logMemAddr, logMemBytes;

@implementation SimLogController {
    NSButton    *_radio1, *_radio2, *_radio3;
    NSTextField *_memAddr, *_memBytes;
    NSButton    *_startBtn, *_stopBtn;
    NSTextView  *_logView;
    NSString    *_logPath;
    NSTimer     *_tailTimer;
    BOOL         _logging;
}

+ (instancetype)shared {
    static SimLogController *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[SimLogController alloc] initWithWindow:nil]; });
    return s;
}

- (void)showLog { [self buildIfNeeded]; [self.window center]; [self showWindow:nil];
                  [self.window makeKeyAndOrderFront:nil]; }
- (BOOL)isLogging { return _logging; }

- (void)buildIfNeeded {
    if (self.window) return;
    NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,560,460)
        styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    w.title = @"Execution Log";
    w.releasedWhenClosed = NO;
    self.window = w;
    [E68BrushedView installInWindow:w];
    NSView *root = w.contentView;

    NSTextField *typeLbl = [NSTextField labelWithString:@"Execution Log Type"];
    typeLbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    _radio1 = [NSButton radioButtonWithTitle:@"Instructions" target:self action:@selector(typeChanged:)];
    _radio2 = [NSButton radioButtonWithTitle:@"Instructions + Registers" target:self action:@selector(typeChanged:)];
    _radio3 = [NSButton radioButtonWithTitle:@"Instructions + Registers + Memory" target:self action:@selector(typeChanged:)];
    _radio1.state = NSControlStateValueOn;

    NSTextField *addrLbl = [NSTextField labelWithString:@"Memory addr:"];
    _memAddr = [[NSTextField alloc] init]; _memAddr.placeholderString = @"00001000"; _memAddr.stringValue = @"00001000";
    NSTextField *byteLbl = [NSTextField labelWithString:@"bytes:"];
    _memBytes = [[NSTextField alloc] init]; _memBytes.placeholderString = @"16"; _memBytes.stringValue = @"16";
    _memAddr.enabled = NO; _memBytes.enabled = NO;

    _startBtn = [NSButton buttonWithTitle:@"Log Start" target:self action:@selector(startTapped:)];
    _startBtn.keyEquivalent = @"\r";
    _stopBtn  = [NSButton buttonWithTitle:@"Log Stop"  target:self action:@selector(stopTapped:)];
    _stopBtn.enabled = NO;

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:root.bounds];
    scroll.hasVerticalScroller = YES; scroll.borderType = NSBezelBorder;
    _logView = [[NSTextView alloc] initWithFrame:root.bounds];
    _logView.editable = NO; _logView.font = [E68Theme shared].monoSmallFont;
    _logView.textContainerInset = NSMakeSize(6,6);
    scroll.documentView = _logView;

    for (NSView *v in @[typeLbl,_radio1,_radio2,_radio3,addrLbl,_memAddr,byteLbl,_memBytes,_startBtn,_stopBtn,scroll])
        v.translatesAutoresizingMaskIntoConstraints = NO, [root addSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [typeLbl.topAnchor constraintEqualToAnchor:root.topAnchor constant:14],
        [typeLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:16],
        [_radio1.topAnchor constraintEqualToAnchor:typeLbl.bottomAnchor constant:8],
        [_radio1.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
        [_radio2.topAnchor constraintEqualToAnchor:_radio1.bottomAnchor constant:4],
        [_radio2.leadingAnchor constraintEqualToAnchor:_radio1.leadingAnchor],
        [_radio3.topAnchor constraintEqualToAnchor:_radio2.bottomAnchor constant:4],
        [_radio3.leadingAnchor constraintEqualToAnchor:_radio1.leadingAnchor],

        [addrLbl.topAnchor constraintEqualToAnchor:_radio3.bottomAnchor constant:10],
        [addrLbl.leadingAnchor constraintEqualToAnchor:_radio1.leadingAnchor],
        [_memAddr.centerYAnchor constraintEqualToAnchor:addrLbl.centerYAnchor],
        [_memAddr.leadingAnchor constraintEqualToAnchor:addrLbl.trailingAnchor constant:6],
        [_memAddr.widthAnchor constraintEqualToConstant:90],
        [byteLbl.centerYAnchor constraintEqualToAnchor:addrLbl.centerYAnchor],
        [byteLbl.leadingAnchor constraintEqualToAnchor:_memAddr.trailingAnchor constant:10],
        [_memBytes.centerYAnchor constraintEqualToAnchor:addrLbl.centerYAnchor],
        [_memBytes.leadingAnchor constraintEqualToAnchor:byteLbl.trailingAnchor constant:6],
        [_memBytes.widthAnchor constraintEqualToConstant:54],

        [_startBtn.centerYAnchor constraintEqualToAnchor:addrLbl.centerYAnchor],
        [_startBtn.trailingAnchor constraintEqualToAnchor:_stopBtn.leadingAnchor constant:-8],
        [_stopBtn.centerYAnchor constraintEqualToAnchor:addrLbl.centerYAnchor],
        [_stopBtn.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-16],

        [scroll.topAnchor constraintEqualToAnchor:addrLbl.bottomAnchor constant:12],
        [scroll.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:12],
        [scroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-12],
        [scroll.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-12],
    ]];
}

- (char)selectedType {
    if (_radio3.state == NSControlStateValueOn) return 3;   // INST_REG_MEM
    if (_radio2.state == NSControlStateValueOn) return 2;   // REGISTERS
    return 1;                                               // INSTRUCTION
}
- (void)typeChanged:(id)sender {
    BOOL mem = (_radio3.state == NSControlStateValueOn);
    _memAddr.enabled = mem; _memBytes.enabled = mem;
}

- (void)startTapped:(id)sender { [self startLogging]; }
- (void)stopTapped:(id)sender  { [self stopLogging]; }

- (void)startLogging {
    [self buildIfNeeded];
    if (_logging) return;
    _logPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"easy68k-exec.log"];
    ElogFile = fopen(_logPath.fileSystemRepresentation, "w");
    if (!ElogFile) { _logView.string = @"Could not open log file."; return; }
    ElogFlag = [self selectedType];
    unsigned a = 0, b = 16;
    sscanf(_memAddr.stringValue.UTF8String ?: "0", "%x", &a);
    sscanf(_memBytes.stringValue.UTF8String ?: "16", "%u", &b);
    logMemAddr = a; logMemBytes = b ? b : 16;
    logging = true;
    _logging = YES;
    _startBtn.enabled = NO; _stopBtn.enabled = YES;
    _radio1.enabled = _radio2.enabled = _radio3.enabled = NO;
    _logView.string = @"";
    [self showLog];
    // live-tail the log file into the view
    _tailTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *t) {
        [self tail];
    }];
}

- (void)stopLogging {
    if (!_logging) return;
    logging = false;            // sim stops entering the log block first
    _logging = NO;
    // close after a beat so any in-flight fprintf on the sim thread completes
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (ElogFile) { fflush(ElogFile); fclose(ElogFile); ElogFile = NULL; }
        [self tail];
    });
    [_tailTimer invalidate]; _tailTimer = nil;
    _startBtn.enabled = YES; _stopBtn.enabled = NO;
    _radio1.enabled = _radio2.enabled = _radio3.enabled = YES;
}

- (void)tail {
    if (ElogFile) fflush(ElogFile);
    NSString *s = [NSString stringWithContentsOfFile:_logPath encoding:NSUTF8StringEncoding error:nil];
    if (!s) s = [NSString stringWithContentsOfFile:_logPath encoding:NSISOLatin1StringEncoding error:nil];
    if (s && ![s isEqualToString:_logView.string]) {
        _logView.string = s;
        [_logView scrollRangeToVisible:NSMakeRange(s.length, 0)];
    }
}

@end
