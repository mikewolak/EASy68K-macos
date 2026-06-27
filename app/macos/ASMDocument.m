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
//  ASMDocument.m
//  EASy68K — .X68 document + editor window.
//
#import "ASMDocument.h"
#import "SyntaxHighlighter.h"
#import "LineNumberRuler.h"
#import "ASMAssembler.h"
#import "SimController.h"

#pragma mark - Editor window controller

@interface EditorWindowController : NSWindowController <NSTextViewDelegate, NSToolbarDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSTextView *editor;
@property (nonatomic, strong) NSTableView *results;
@property (nonatomic, strong) SyntaxHighlighter *highlighter;
@property (nonatomic, strong) NSArray<ASMDiagnostic *> *diagnostics;
@property (nonatomic, strong) NSTextField *statusField;
@property (nonatomic, strong) NSTextField *resultsPlaceholder;
@end

// Toolbar item identifiers.
static NSToolbarItemIdentifier const kOpenItem     = @"open";
static NSToolbarItemIdentifier const kSaveItem     = @"save";
static NSToolbarItemIdentifier const kAssembleItem = @"assemble";
static NSToolbarItemIdentifier const kRunItem      = @"run";

@implementation EditorWindowController

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 880, 680);
    NSWindow *win = [[NSWindow alloc] initWithContentRect:frame
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                   NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    win.titleVisibility = NSWindowTitleVisible;
    win.minSize = NSMakeSize(560, 380);
    [win center];

    if ((self = [super initWithWindow:win])) {
        [self buildToolbar];
        [self buildUI];
    }
    return self;
}

#pragma mark Toolbar (native icon+label items — the macOS look)

- (void)buildToolbar {
    NSToolbar *tb = [[NSToolbar alloc] initWithIdentifier:@"EASy68KEditorToolbar"];
    tb.delegate = self;
    tb.allowsUserCustomization = NO;
    tb.displayMode = NSToolbarDisplayModeIconAndLabel;
    if (@available(macOS 11.0, *)) self.window.toolbarStyle = NSWindowToolbarStyleUnified;
    self.window.toolbar = tb;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)tb {
    return @[kOpenItem, kSaveItem, NSToolbarFlexibleSpaceItemIdentifier, kAssembleItem, kRunItem];
}
- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)tb {
    return [self toolbarDefaultItemIdentifiers:tb];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)tb itemForItemIdentifier:(NSToolbarItemIdentifier)ident
 willBeInsertedIntoToolbar:(BOOL)flag {
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:ident];
    item.bordered = YES;
    NSString *sym; NSString *label; SEL action; id target = self;
    if ([ident isEqual:kOpenItem])          { sym=@"folder";                 label=@"Open";     action=@selector(openDocument:);  target=nil; }
    else if ([ident isEqual:kSaveItem])     { sym=@"square.and.arrow.down";  label=@"Save";     action=@selector(saveDocument:);  target=nil; }
    else if ([ident isEqual:kAssembleItem]) { sym=@"hammer.fill";            label=@"Assemble"; action=@selector(assemble:); }
    else if ([ident isEqual:kRunItem])      { sym=@"play.fill";              label=@"Run";      action=@selector(runProgram:); }
    else return nil;
    item.label = label;
    item.paletteLabel = label;
    item.image = [NSImage imageWithSystemSymbolName:sym accessibilityDescription:label];
    item.target = target;
    item.action = action;
    if ([ident isEqual:kRunItem]) item.toolTip = @"Assemble and run in the simulator";
    return item;
}

- (void)buildUI {
    NSView *content = self.window.contentView;

    // Vertical split: editor (top) / results (bottom).
    NSSplitView *split = [[NSSplitView alloc] initWithFrame:content.bounds];
    split.dividerStyle = NSSplitViewDividerStyleThin;
    split.vertical = NO;
    split.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:split];
    [NSLayoutConstraint activateConstraints:@[
        [split.topAnchor constraintEqualToAnchor:content.topAnchor],
        [split.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [split.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [split.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-22],
    ]];

    // --- Editor ---
    NSScrollView *editScroll = [[NSScrollView alloc] initWithFrame:content.bounds];
    editScroll.hasVerticalScroller = YES;
    editScroll.hasHorizontalScroller = YES;
    editScroll.borderType = NSNoBorder;

    // Canonical NON-WRAPPING NSTextView-in-NSScrollView setup (Apple's "Text
    // System User Interface Layer" recipe). A FLT_MAX container width with
    // widthTracksTextView = NO means glyphs always lay out at full size, so
    // the view frame's initial width never collapses the text.
    NSTextView *tv = [[NSTextView alloc] initWithFrame:content.bounds];
    tv.minSize = NSMakeSize(0, 0);
    tv.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    tv.verticallyResizable = YES;
    tv.horizontallyResizable = YES;
    tv.autoresizingMask = NSViewNotSizable;
    tv.textContainer.containerSize = NSMakeSize(FLT_MAX, FLT_MAX);
    tv.textContainer.widthTracksTextView = NO;
    tv.richText = YES;          // honour syntax-colour attributes
    tv.usesFontPanel = NO;
    tv.usesRuler = NO;
    tv.automaticQuoteSubstitutionEnabled = NO;
    tv.automaticDashSubstitutionEnabled = NO;
    tv.automaticSpellingCorrectionEnabled = NO;
    tv.allowsUndo = YES;
    tv.usesFindBar = YES;          // native Find/Replace bar (Cmd-F / Cmd-Option-F)
    tv.incrementalSearchingEnabled = YES;
    tv.drawsBackground = YES;
    tv.backgroundColor = NSColor.textBackgroundColor;
    tv.textColor = NSColor.textColor;
    tv.insertionPointColor = NSColor.textColor;
    tv.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    tv.textContainerInset = NSMakeSize(4, 6);
    tv.delegate = self;
    editScroll.documentView = tv;
    self.editor = tv;

    // Syntax highlighting.
    self.highlighter = [[SyntaxHighlighter alloc] init];
    tv.textStorage.delegate = self.highlighter;

    // Line-number gutter.
    editScroll.hasVerticalRuler = YES;
    editScroll.rulersVisible = YES;
    editScroll.verticalRulerView = [[LineNumberRuler alloc] initWithTextView:tv];

    [split addSubview:editScroll];

    // --- Results table ---
    NSScrollView *resScroll = [[NSScrollView alloc] init];
    resScroll.hasVerticalScroller = YES;
    resScroll.borderType = NSNoBorder;

    NSTableView *table = [[NSTableView alloc] init];
    table.headerView = nil;
    table.rowSizeStyle = NSTableViewRowSizeStyleSmall;
    // No zebra stripes: an empty diagnostics list painted alternating row
    // backgrounds for the whole pane height, which read as placeholder cards.
    // Plain background + a centred hint when there are no messages.
    table.usesAlternatingRowBackgroundColors = NO;
    table.gridStyleMask = NSTableViewGridNone;
    table.backgroundColor = NSColor.textBackgroundColor;
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"msg"];
    col.resizingMask = NSTableColumnAutoresizingMask;
    [table addTableColumn:col];
    table.dataSource = self;
    table.delegate = self;
    table.target = self;
    table.doubleAction = @selector(jumpToDiagnostic:);
    resScroll.documentView = table;
    self.results = table;

    // Centred hint shown while the diagnostics list is empty.
    NSTextField *ph = [NSTextField labelWithString:@"No messages — ⌘B to assemble"];
    ph.font = [NSFont systemFontOfSize:11];
    ph.textColor = NSColor.tertiaryLabelColor;
    ph.translatesAutoresizingMaskIntoConstraints = NO;
    [resScroll addSubview:ph];
    [NSLayoutConstraint activateConstraints:@[
        [ph.centerXAnchor constraintEqualToAnchor:resScroll.centerXAnchor],
        [ph.centerYAnchor constraintEqualToAnchor:resScroll.centerYAnchor],
    ]];
    self.resultsPlaceholder = ph;

    [split addSubview:resScroll];
    // Position the divider once the split view has its real size.
    dispatch_async(dispatch_get_main_queue(), ^{
        // Results pane opens compact (~4 lines); the user can drag it taller.
        [split setPosition:NSHeight(split.bounds) - 78 ofDividerAtIndex:0];
    });

    // --- Status bar ---
    NSTextField *status = [NSTextField labelWithString:@"Ready"];
    status.font = [NSFont systemFontOfSize:11];
    status.textColor = NSColor.secondaryLabelColor;
    status.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:status];
    [NSLayoutConstraint activateConstraints:@[
        [status.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:10],
        [status.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-4],
    ]];
    self.statusField = status;
}

#pragma mark Content sync

- (void)loadText:(NSString *)text {
    self.editor.string = text ?: @"";
    [self.highlighter highlightAll:self.editor.textStorage];
}

- (void)textDidChange:(NSNotification *)notification {
    ASMDocument *doc = (ASMDocument *)self.document;
    doc.text = self.editor.string;
    [doc updateChangeCount:NSChangeDone];
}

#pragma mark Assemble

- (void)assemble:(id)sender {
    ASMDocument *doc = (ASMDocument *)self.document;
    doc.text = self.editor.string;

    // Need a path to derive .S68/.L68. If unsaved, prompt to save first.
    if (!doc.fileURL) {
        self.statusField.stringValue = @"Save the file before assembling.";
        [doc saveDocumentWithDelegate:nil didSaveSelector:NULL contextInfo:NULL];
        if (!doc.fileURL) return;
    }
    // Save current edits so the assembled source matches the editor.
    [doc saveDocument:nil];

    ASMAssembler *asm68k = [[ASMAssembler alloc] init];
    ASMResult *r = [asm68k assembleSource:self.editor.string workPath:doc.fileURL.path];

    self.diagnostics = r.diagnostics;
    [self refreshResults];

    NSString *summary = [NSString stringWithFormat:@"%ld error%@, %ld warning%@%@",
        (long)r.errorCount, r.errorCount == 1 ? @"" : @"s",
        (long)r.warningCount, r.warningCount == 1 ? @"" : @"s",
        r.errorCount == 0 ? [NSString stringWithFormat:@"  →  %@", r.objectPath.lastPathComponent] : @""];
    self.statusField.stringValue = summary;
    self.statusField.textColor = r.errorCount ? NSColor.systemRedColor : NSColor.secondaryLabelColor;
}

- (void)runProgram:(id)sender {
    // Assemble first; only run a clean build.
    [self assemble:sender];
    for (ASMDiagnostic *d in self.diagnostics)
        if (![d.message hasPrefix:@"WARNING"]) {
            self.statusField.stringValue = @"Fix errors before running.";
            return;
        }
    ASMDocument *doc = (ASMDocument *)self.document;
    NSString *srec = [[doc.fileURL.path stringByDeletingPathExtension] stringByAppendingPathExtension:@"S68"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:srec]) {
        self.statusField.stringValue = @"No S-record to run.";
        return;
    }
    // Open the integrated native simulator window and load the program.
    [[SimController sharedController] loadAndShow:srec title:doc.fileURL.lastPathComponent];
    self.statusField.stringValue = @"Opened simulator.";
}

- (void)jumpToDiagnostic:(id)sender {
    NSInteger row = self.results.clickedRow;
    if (row < 0 || row >= (NSInteger)self.diagnostics.count) return;
    ASMDiagnostic *d = self.diagnostics[row];
    if (d.line <= 0) return;
    // Select the diagnostic's source line.
    NSString *s = self.editor.string;
    __block NSInteger ln = 1; __block NSRange target = NSMakeRange(NSNotFound, 0);
    [s enumerateSubstringsInRange:NSMakeRange(0, s.length)
        options:NSStringEnumerationByLines | NSStringEnumerationSubstringNotRequired
        usingBlock:^(NSString *sub, NSRange r, NSRange er, BOOL *stop) {
            if (ln == d.line) { target = r; *stop = YES; }
            ln++;
        }];
    if (target.location != NSNotFound) {
        [self.editor setSelectedRange:target];
        [self.editor scrollRangeToVisible:target];
        [self.window makeFirstResponder:self.editor];
    }
}

#pragma mark Results table

// Reload the diagnostics list and show the centred hint only when it's empty.
- (void)refreshResults {
    [self.results reloadData];
    self.resultsPlaceholder.hidden = (self.diagnostics.count > 0);
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv { return self.diagnostics.count; }

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    NSTextField *cell = [tv makeViewWithIdentifier:@"cell" owner:self];
    if (!cell) {
        cell = [[NSTextField alloc] init];
        cell.identifier = @"cell";
        cell.bordered = NO; cell.editable = NO; cell.drawsBackground = NO;
        cell.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    }
    ASMDiagnostic *d = self.diagnostics[row];
    NSString *loc = d.line > 0 ? [NSString stringWithFormat:@"Line %ld: ", (long)d.line] : @"";
    cell.stringValue = [NSString stringWithFormat:@"%@%@", loc, d.message];
    cell.textColor = [d.message hasPrefix:@"WARNING"] ? NSColor.systemOrangeColor : NSColor.systemRedColor;
    return cell;
}

@end

#pragma mark - Document

@implementation ASMDocument

- (instancetype)init {
    if ((self = [super init])) { _text = @""; }
    return self;
}

+ (BOOL)autosavesInPlace { return NO; }

- (void)makeWindowControllers {
    EditorWindowController *wc = [[EditorWindowController alloc] init];
    [self addWindowController:wc];
    [wc loadText:self.text];
    self.windowControllers.firstObject.window.title =
        self.fileURL ? self.fileURL.lastPathComponent : @"Untitled.X68";
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    return [self.text dataUsingEncoding:NSUTF8StringEncoding];
}

// File > Print / Page Setup: print the source. NSDocument's printDocument: and
// runPageLayout: drive this; we hand back a print operation for the editor view
// laid out to the page width.
- (NSPrintOperation *)printOperationWithSettings:(NSDictionary<NSPrintInfoAttributeKey,id> *)settings
                                           error:(NSError **)error {
    EditorWindowController *wc = self.windowControllers.firstObject;
    NSPrintInfo *pi = [self.printInfo copy];
    [pi.dictionary addEntriesFromDictionary:settings];
    pi.horizontalPagination = NSPrintingPaginationModeFit;
    pi.verticallyCentered = NO;

    NSSize page = pi.paperSize;
    CGFloat w = page.width - pi.leftMargin - pi.rightMargin;
    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, w, 100)];
    tv.string = wc.editor.string ?: self.text ?: @"";
    tv.font = [NSFont userFixedPitchFontOfSize:10];
    tv.textContainer.containerSize = NSMakeSize(w, FLT_MAX);
    tv.textContainer.widthTracksTextView = YES;
    [tv sizeToFit];
    return [NSPrintOperation printOperationWithView:tv printInfo:pi];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    self.text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    EditorWindowController *wc = self.windowControllers.firstObject;
    if (wc) [wc loadText:self.text];
    return YES;
}

#pragma mark Remote control

- (NSString *)remoteSourceText {
    EditorWindowController *wc = self.windowControllers.firstObject;
    return wc ? wc.editor.string : self.text;
}

- (void)remoteSetSourceText:(NSString *)text {
    self.text = text ?: @"";
    EditorWindowController *wc = self.windowControllers.firstObject;
    if (wc) [wc loadText:self.text];
    [self updateChangeCount:NSChangeDone];
}

- (NSDictionary *)remoteAssemble {
    EditorWindowController *wc = self.windowControllers.firstObject;
    if (!wc) return @{ @"error": @"no editor window" };
    [wc assemble:nil];
    NSMutableArray *diags = [NSMutableArray array];
    for (ASMDiagnostic *d in wc.diagnostics)
        [diags addObject:@{ @"line": @(d.line), @"message": d.message ?: @"" }];
    return @{ @"diagnostics": diags, @"count": @(wc.diagnostics.count) };
}

- (void)remoteRunInSimulator {
    EditorWindowController *wc = self.windowControllers.firstObject;
    [wc runProgram:nil];
}

@end
