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
//  AppDelegate.m
//  EASy68K for macOS — application delegate + programmatic main menu.
//
#import "AppDelegate.h"
#import "SimRemoteServer.h"
#import "SimController.h"
#import "AboutWindowController.h"
#import "SettingsWindowController.h"
#import "SimMemoryWindowController.h"
#import "SimLogController.h"
#import "EASyBINController.h"
#import "SimSoundEngine.h"
#import "E68Theme.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    [self buildMainMenu];

    // Localhost control API. Port is configurable because the user may run
    // several such servers at once:
    //   --control-port N   command-line argument
    //   EASY68K_CONTROL_PORT=N   environment variable
    //   --no-control       disable entirely
    NSProcessInfo *pi = NSProcessInfo.processInfo;
    uint16_t port = 8068;
    NSString *env = pi.environment[@"EASY68K_CONTROL_PORT"];
    if (env.length) port = (uint16_t)env.intValue;
    NSUInteger idx = [pi.arguments indexOfObject:@"--control-port"];
    if (idx != NSNotFound && idx + 1 < pi.arguments.count)
        port = (uint16_t)[pi.arguments[idx + 1] intValue];
    if (![pi.arguments containsObject:@"--no-control"] && port != 0)
        [[SimRemoteServer sharedServer] startOnPort:port];

    // create the audio engine on the main thread at launch (CoreAudio HAL setup
    // wants the main run loop; lazy creation on the sim thread can stall it)
    (void)[SimSoundEngine shared];

    // restore the remembered MIDI input (audio device/channels self-restore)
    [SettingsWindowController restoreSavedDevices];

    [NSApp activateIgnoringOtherApps:YES];
}

- (void)showAbout:(id)sender { [AboutWindowController showAbout]; }
- (void)showSettings:(id)sender { [SettingsWindowController showSettings]; }
- (void)showFontPanel:(id)sender {
    NSFontManager *fm = [NSFontManager sharedFontManager];
    [fm setSelectedFont:[E68Theme shared].monoFont isMultiple:NO];
    [fm orderFrontFontPanel:sender];
}
- (void)changeFont:(id)sender {           // NSFontManager sends this up the chain
    NSFont *f = [sender convertFont:[E68Theme shared].monoFont];
    [E68Theme shared].fontName = f.fontName;
    [E68Theme shared].fontSize = f.pointSize;   // posts the theme-changed notification
}
- (void)increaseFontSize:(id)sender { [[E68Theme shared] increaseFontSize]; }
- (void)decreaseFontSize:(id)sender { [[E68Theme shared] decreaseFontSize]; }
- (void)resetFontSize:(id)sender    { [[E68Theme shared] resetFontSize]; }
- (void)showStackWindow:(id)sender  { [[SimController sharedController] showStackWindow:sender]; }
- (void)showBreakpointsWindow:(id)sender { [[SimController sharedController] showBreakpointsWindow:sender]; }
- (void)showHardwareWindow:(id)sender { [[SimController sharedController] showHardwareWindow:sender]; }
- (void)newMemoryWindow:(id)sender { [SimMemoryWindowController openNewMemoryWindow]; }
- (void)showLogWindow:(id)sender    { [[SimLogController shared] showLog]; }
- (void)showEASyBIN:(id)sender      { [[EASyBINController shared] showBIN]; }

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender { return NO; }

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }

#pragma mark - Menu

static NSMenuItem *Item(NSString *title, SEL action, NSString *key) {
    NSMenuItem *it = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    return it;
}

- (void)buildMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    // --- Application menu ---
    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] init];
    appItem.submenu = appMenu;
    NSMenuItem *about = Item(@"About EASy68K", @selector(showAbout:), @"");
    about.target = self;
    [appMenu addItem:about];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *settings = Item(@"Settings…", @selector(showSettings:), @",");
    settings.target = self;
    [appMenu addItem:settings];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItem:Item(@"Hide EASy68K", @selector(hide:), @"h")];
    NSMenuItem *hideOthers = Item(@"Hide Others", @selector(hideOtherApplications:), @"h");
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagOption | NSEventModifierFlagCommand;
    [appMenu addItem:hideOthers];
    [appMenu addItem:Item(@"Show All", @selector(unhideAllApplications:), @"")];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItem:Item(@"Quit EASy68K", @selector(terminate:), @"q")];

    // --- File menu ---
    NSMenuItem *fileItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:fileItem];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    fileItem.submenu = fileMenu;
    [fileMenu addItem:Item(@"New", @selector(newDocument:), @"n")];
    [fileMenu addItem:Item(@"Open…", @selector(openDocument:), @"o")];
    NSMenuItem *openData = Item(@"Open Data…", @selector(openData:), @"o");
    openData.keyEquivalentModifierMask = NSEventModifierFlagShift | NSEventModifierFlagCommand;
    [fileMenu addItem:openData];   // load a binary file into 68000 memory
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItem:Item(@"Close", @selector(performClose:), @"w")];
    [fileMenu addItem:Item(@"Save…", @selector(saveDocument:), @"s")];
    NSMenuItem *saveAs = Item(@"Save As…", @selector(saveDocumentAs:), @"s");
    saveAs.keyEquivalentModifierMask = NSEventModifierFlagShift | NSEventModifierFlagCommand;
    [fileMenu addItem:saveAs];
    [fileMenu addItem:Item(@"Revert to Saved", @selector(revertDocumentToSaved:), @"")];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *pageSetup = Item(@"Page Setup…", @selector(runPageLayout:), @"p");
    pageSetup.keyEquivalentModifierMask = NSEventModifierFlagShift | NSEventModifierFlagCommand;
    [fileMenu addItem:pageSetup];
    [fileMenu addItem:Item(@"Print…", @selector(printDocument:), @"p")];

    // --- Edit menu ---
    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:editItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    editItem.submenu = editMenu;
    [editMenu addItem:Item(@"Undo", @selector(undo:), @"z")];
    NSMenuItem *redo = Item(@"Redo", @selector(redo:), @"z");
    redo.keyEquivalentModifierMask = NSEventModifierFlagShift | NSEventModifierFlagCommand;
    [editMenu addItem:redo];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItem:Item(@"Cut", @selector(cut:), @"x")];
    [editMenu addItem:Item(@"Copy", @selector(copy:), @"c")];
    [editMenu addItem:Item(@"Paste", @selector(paste:), @"v")];
    [editMenu addItem:Item(@"Select All", @selector(selectAll:), @"a")];
    [editMenu addItem:[NSMenuItem separatorItem]];
    // Find submenu — native NSTextFinder actions (target = first responder)
    NSMenuItem *findItem = [[NSMenuItem alloc] init];
    findItem.title = @"Find";
    NSMenu *findMenu = [[NSMenu alloc] initWithTitle:@"Find"];
    findItem.submenu = findMenu;
    NSMenuItem *(^FindItem)(NSString *, NSInteger, NSString *, NSEventModifierFlags) =
        ^(NSString *t, NSInteger tag, NSString *key, NSEventModifierFlags mods) {
            NSMenuItem *m = [[NSMenuItem alloc] initWithTitle:t action:@selector(performTextFinderAction:) keyEquivalent:key];
            m.tag = tag; if (mods) m.keyEquivalentModifierMask = mods;
            [findMenu addItem:m]; return m;
        };
    FindItem(@"Find…", 1 /*ShowFindInterface*/, @"f", 0);
    FindItem(@"Find Next", 2 /*NextMatch*/, @"g", 0);
    FindItem(@"Find Previous", 3 /*PreviousMatch*/, @"g", NSEventModifierFlagShift|NSEventModifierFlagCommand);
    FindItem(@"Replace…", 12 /*ShowReplaceInterface*/, @"f", NSEventModifierFlagOption|NSEventModifierFlagCommand);
    FindItem(@"Use Selection for Find", 7 /*SetSearchString*/, @"e", 0);
    [editMenu addItem:findItem];

    // --- Build menu ---
    NSMenuItem *buildItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:buildItem];
    NSMenu *buildMenu = [[NSMenu alloc] initWithTitle:@"Build"];
    buildItem.submenu = buildMenu;
    [buildMenu addItem:Item(@"Assemble", @selector(assemble:), @"b")];
    [buildMenu addItem:Item(@"Assemble and Run", @selector(runProgram:), @"r")];

    // --- Run menu (simulator controls; dispatched to the key sim window via the
    //     responder chain, so they enable only when the Simulator is frontmost) ---
    NSMenuItem *runItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:runItem];
    NSMenu *runMenu = [[NSMenu alloc] initWithTitle:@"Run"];
    runItem.submenu = runMenu;
    NSMenuItem *(^FKey)(NSString *, SEL, unichar) = ^(NSString *t, SEL a, unichar fk) {
        NSMenuItem *m = [[NSMenuItem alloc] initWithTitle:t action:a
            keyEquivalent:(fk ? [NSString stringWithCharacters:&fk length:1] : @"")];
        if (fk) m.keyEquivalentModifierMask = NSEventModifierFlagFunction;
        [runMenu addItem:m]; return m;
    };
    FKey(@"Run",            @selector(run:),         NSF9FunctionKey);
    FKey(@"Step Over",      @selector(step:),        NSF8FunctionKey);
    FKey(@"Trace Into",     @selector(traceInto:),   NSF7FunctionKey);
    FKey(@"Run To Cursor",  @selector(runToCursor:), NSF5FunctionKey);
    FKey(@"Auto Trace",     @selector(autoTrace:),   0);
    FKey(@"Auto Trace Options…", @selector(autoTraceOptions:), 0);
    FKey(@"Pause",          @selector(pause:),       NSF6FunctionKey);
    [runMenu addItem:[NSMenuItem separatorItem]];
    FKey(@"Reset",          @selector(resetSim:),    0);
    FKey(@"Reload Program", @selector(reload:),      0);

    // --- Search menu (Find in memory + Goto PC, plus editor Find) ---
    NSMenuItem *searchItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:searchItem];
    NSMenu *searchMenu = [[NSMenu alloc] initWithTitle:@"Search"];
    searchItem.submenu = searchMenu;
    [searchMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Find in Memory…"
        action:@selector(findInMemory:) keyEquivalent:@""]];
    NSMenuItem *gotoPC = [[NSMenuItem alloc] initWithTitle:@"Goto PC"
        action:@selector(gotoPC:) keyEquivalent:@""];
    [searchMenu addItem:gotoPC];

    // --- View menu (font size) ---
    NSMenuItem *viewItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:viewItem];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    viewItem.submenu = viewMenu;
    NSMenuItem *bigger = Item(@"Increase Font Size", @selector(increaseFontSize:), @"+");
    bigger.target = self;
    [viewMenu addItem:bigger];
    // also accept ⌘= (so Shift isn't required for the + key)
    NSMenuItem *biggerEq = Item(@"Increase Font Size", @selector(increaseFontSize:), @"=");
    biggerEq.target = self; biggerEq.alternate = YES;
    biggerEq.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [viewMenu addItem:biggerEq];
    NSMenuItem *smaller = Item(@"Decrease Font Size", @selector(decreaseFontSize:), @"-");
    smaller.target = self;
    [viewMenu addItem:smaller];
    NSMenuItem *resetF = Item(@"Actual Size", @selector(resetFontSize:), @"0");
    resetF.target = self;
    [viewMenu addItem:resetF];
    [viewMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *fontItem = Item(@"Font…", @selector(showFontPanel:), @"t");
    fontItem.target = self;
    [viewMenu addItem:fontItem];   // pick the mono font family for source/regs/memory

    // --- Window menu ---
    NSMenuItem *windowItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:windowItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    windowItem.submenu = windowMenu;
    [windowMenu addItem:Item(@"Minimize", @selector(performMiniaturize:), @"m")];
    [windowMenu addItem:Item(@"Zoom", @selector(performZoom:), @"")];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *stackWin = Item(@"68000 Stack", @selector(showStackWindow:), @"");
    stackWin.target = self;
    [windowMenu addItem:stackWin];
    NSMenuItem *bpWin = Item(@"Break Points", @selector(showBreakpointsWindow:), @"");
    bpWin.target = self;
    [windowMenu addItem:bpWin];
    NSMenuItem *hwWin = Item(@"Hardware", @selector(showHardwareWindow:), @"");
    hwWin.target = self;
    [windowMenu addItem:hwWin];
    NSMenuItem *memWin = Item(@"New Memory Window", @selector(newMemoryWindow:), @"m");
    memWin.keyEquivalentModifierMask = NSEventModifierFlagShift | NSEventModifierFlagCommand;
    memWin.target = self;
    [windowMenu addItem:memWin];
    NSMenuItem *logWin = Item(@"Execution Log", @selector(showLogWindow:), @"");
    logWin.target = self;
    [windowMenu addItem:logWin];
    NSMenuItem *binWin = Item(@"EASyBIN — Binary Utility", @selector(showEASyBIN:), @"");
    binWin.target = self;
    [windowMenu addItem:binWin];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItem:Item(@"Bring All to Front", @selector(arrangeInFront:), @"")];
    NSApp.windowsMenu = windowMenu;

    NSApp.mainMenu = mainMenu;
}

@end
