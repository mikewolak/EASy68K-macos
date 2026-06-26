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
//  SimBreakpointsView.m
//
#import "SimBreakpointsView.h"
#import "SimCore.h"
#import "E68Theme.h"

@interface SimBreakpointsView () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation SimBreakpointsView {
    NSTableView *_table;
    NSTextField *_addrField;
    NSMutableArray<NSNumber *> *_rows;   // breakpoint addresses (snapshot of brkpt[])
}

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _rows = [NSMutableArray array];

        NSTextField *hdr = [NSTextField labelWithString:@"PC Break Points"];
        hdr.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];

        NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:self.bounds];
        scroll.hasVerticalScroller = YES; scroll.borderType = NSBezelBorder;
        _table = [[NSTableView alloc] initWithFrame:self.bounds];
        _table.dataSource = self; _table.delegate = self;
        _table.rowHeight = 18; _table.usesAlternatingRowBackgroundColors = YES;
        NSTableColumn *cAddr = [[NSTableColumn alloc] initWithIdentifier:@"addr"];
        cAddr.title = @"Address"; cAddr.width = 90;
        NSTableColumn *cSrc = [[NSTableColumn alloc] initWithIdentifier:@"src"];
        cSrc.title = @"Source"; cSrc.width = 360;
        [_table addTableColumn:cAddr]; [_table addTableColumn:cSrc];
        scroll.documentView = _table;

        NSTextField *al = [NSTextField labelWithString:@"Address:"];
        _addrField = [[NSTextField alloc] init]; _addrField.placeholderString = @"00001000";
        NSButton *addB    = [NSButton buttonWithTitle:@"Add"       target:self action:@selector(addTapped:)];
        addB.keyEquivalent = @"\r";
        NSButton *removeB = [NSButton buttonWithTitle:@"Remove"    target:self action:@selector(removeTapped:)];
        NSButton *clearB  = [NSButton buttonWithTitle:@"Clear All" target:self action:@selector(clearTapped:)];

        for (NSView *v in @[hdr,scroll,al,_addrField,addB,removeB,clearB])
            v.translatesAutoresizingMaskIntoConstraints = NO, [self addSubview:v];

        [NSLayoutConstraint activateConstraints:@[
            [hdr.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
            [hdr.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [scroll.topAnchor constraintEqualToAnchor:hdr.bottomAnchor constant:6],
            [scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
            [scroll.bottomAnchor constraintEqualToAnchor:al.topAnchor constant:-10],
            [al.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [al.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-14],
            [_addrField.centerYAnchor constraintEqualToAnchor:al.centerYAnchor],
            [_addrField.leadingAnchor constraintEqualToAnchor:al.trailingAnchor constant:6],
            [_addrField.widthAnchor constraintEqualToConstant:90],
            [addB.centerYAnchor constraintEqualToAnchor:al.centerYAnchor],
            [addB.leadingAnchor constraintEqualToAnchor:_addrField.trailingAnchor constant:8],
            [removeB.centerYAnchor constraintEqualToAnchor:al.centerYAnchor],
            [removeB.leadingAnchor constraintEqualToAnchor:addB.trailingAnchor constant:6],
            [clearB.centerYAnchor constraintEqualToAnchor:al.centerYAnchor],
            [clearB.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        ]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh)
                                                     name:@"E68BreakpointsChanged" object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)refresh {
    [_rows removeAllObjects];
    for (int i = 0; i < bpoints; i++) [_rows addObject:@((uint32_t)brkpt[i])];
    [_rows sortUsingSelector:@selector(compare:)];
    [_table reloadData];
}

- (void)addTapped:(id)sender {
    unsigned a = 0;
    if (sscanf(_addrField.stringValue.UTF8String ?: "", "%x", &a) == 1) {
        [self.bpDelegate addBreakpointAtAddress:(uint32_t)a];
        _addrField.stringValue = @"";
        [self refresh];
    }
}
- (void)removeTapped:(id)sender {
    NSInteger row = _table.selectedRow;
    if (row >= 0 && row < (NSInteger)_rows.count) {
        [self.bpDelegate removeBreakpointAtAddress:_rows[row].unsignedIntValue];
        [self refresh];
    }
}
- (void)clearTapped:(id)sender { [self.bpDelegate clearAllBreakpoints]; [self refresh]; }

#pragma mark table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)t { return _rows.count; }
- (id)tableView:(NSTableView *)t objectValueForTableColumn:(NSTableColumn *)c row:(NSInteger)row {
    uint32_t a = _rows[row].unsignedIntValue;
    if ([c.identifier isEqual:@"addr"]) return [NSString stringWithFormat:@"%08X", a];
    return [self.bpDelegate sourceLineForAddress:a] ?: @"";
}
- (void)tableView:(NSTableView *)t willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)c row:(NSInteger)row {
    if ([cell isKindOfClass:NSCell.class]) [(NSCell *)cell setFont:[E68Theme shared].monoSmallFont];
}

@end
