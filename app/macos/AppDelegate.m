//
//  AppDelegate.m
//  EASy68K for macOS — application delegate + programmatic main menu.
//
#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    [self buildMainMenu];
    [NSApp activateIgnoringOtherApps:YES];
}

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
    [appMenu addItem:Item(@"About EASy68K", @selector(orderFrontStandardAboutPanel:), @"")];
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
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItem:Item(@"Close", @selector(performClose:), @"w")];
    [fileMenu addItem:Item(@"Save…", @selector(saveDocument:), @"s")];
    NSMenuItem *saveAs = Item(@"Save As…", @selector(saveDocumentAs:), @"s");
    saveAs.keyEquivalentModifierMask = NSEventModifierFlagShift | NSEventModifierFlagCommand;
    [fileMenu addItem:saveAs];
    [fileMenu addItem:Item(@"Revert to Saved", @selector(revertDocumentToSaved:), @"")];

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

    // --- Build menu ---
    NSMenuItem *buildItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:buildItem];
    NSMenu *buildMenu = [[NSMenu alloc] initWithTitle:@"Build"];
    buildItem.submenu = buildMenu;
    [buildMenu addItem:Item(@"Assemble", @selector(assemble:), @"b")];
    [buildMenu addItem:Item(@"Assemble and Run", @selector(runProgram:), @"r")];

    // --- Window menu ---
    NSMenuItem *windowItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:windowItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    windowItem.submenu = windowMenu;
    [windowMenu addItem:Item(@"Minimize", @selector(performMiniaturize:), @"m")];
    [windowMenu addItem:Item(@"Zoom", @selector(performZoom:), @"")];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItem:Item(@"Bring All to Front", @selector(arrangeInFront:), @"")];
    NSApp.windowsMenu = windowMenu;

    NSApp.mainMenu = mainMenu;
}

@end
