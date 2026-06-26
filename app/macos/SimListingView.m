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
//  SimListingView.m
//
#import "SimListingView.h"

#define GUTTER 18.0

// Visible to the gutter-click handler in SimListingTable below.
@interface SimListingView (GutterClick)
- (void)toggleBreakpointAtRow:(NSInteger)row;
@end

// Parse the 8-char hex address column (cols 1-8). Returns -1 if not all hex.
static long parseAddrCol(NSString *line) {
    if (line.length < 8) return -1;
    long v = 0;
    for (int i = 0; i < 8; i++) {
        unichar c = [line characterAtIndex:i];
        int d;
        if (c >= '0' && c <= '9') d = c - '0';
        else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
        else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
        else return -1;
        v = (v << 4) | d;
    }
    return v;
}

// A line is an executable instruction line when cols 1-8 are a hex address AND
// machine code is present at col 11 (a hex digit) — labels/equates/comments are
// not. Mirrors the original isInstruction().
static BOOL lineIsInstruction(NSString *line) {
    if (parseAddrCol(line) < 0) return NO;
    if (line.length < 11) return NO;
    unichar c = [line characterAtIndex:10];
    return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
}

#pragma mark - row view (draws the breakpoint dot + PC highlight)

@interface SimListingRowView : NSTableRowView
@property (nonatomic) BOOL hasBreakpoint;
@property (nonatomic) BOOL isCurrentPC;
@end

@implementation SimListingRowView
- (void)drawBackgroundInRect:(NSRect)dirtyRect {
    [super drawBackgroundInRect:dirtyRect];
    if (_isCurrentPC) {
        [[NSColor colorWithCalibratedRed:0.18 green:0.34 blue:0.62 alpha:0.55] setFill];
        NSRectFill(self.bounds);
    }
    if (_hasBreakpoint) {
        NSRect dot = NSMakeRect(4, NSMidY(self.bounds) - 4, 8, 8);
        [[NSColor systemRedColor] setFill];
        [[NSBezierPath bezierPathWithOvalInRect:dot] fill];
    }
}
- (void)drawSelectionInRect:(NSRect)dirtyRect { /* PC highlight stands in for selection */ }
@end

#pragma mark - table view (gutter click = toggle breakpoint)

@interface SimListingTable : NSTableView
@property (nonatomic, weak) SimListingView *owner;
@end

@implementation SimListingTable
- (void)mouseDown:(NSEvent *)event {
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    if (p.x < GUTTER) {
        NSInteger row = [self rowAtPoint:p];
        if (row >= 0) { [self.owner toggleBreakpointAtRow:row]; return; }
    }
    [super mouseDown:event];
}
@end

#pragma mark - listing view

@interface SimListingView () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation SimListingView {
    SimListingTable *_table;
    NSMutableArray<NSString *> *_lines;
    NSMutableArray<NSNumber *> *_addr;       // parsed address per line, or -1
    NSMutableIndexSet *_instrRows;           // rows that are instructions
    NSMutableSet<NSNumber *> *_breaks;       // breakpoint addresses
    NSInteger _pcRow;                        // currently highlighted row, or -1
    NSFont *_font;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _lines = [NSMutableArray array];
        _addr = [NSMutableArray array];
        _instrRows = [NSMutableIndexSet indexSet];
        _breaks = [NSMutableSet set];
        _pcRow = -1;
        _font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];

        NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:self.bounds];
        scroll.hasVerticalScroller = YES;
        scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        scroll.borderType = NSNoBorder;

        _table = [[SimListingTable alloc] initWithFrame:self.bounds];
        _table.owner = self;
        _table.dataSource = self;
        _table.delegate = self;
        _table.headerView = nil;
        _table.rowHeight = ceil(_font.ascender - _font.descender + _font.leading) + 2;
        _table.intercellSpacing = NSMakeSize(0, 0);
        _table.backgroundColor = NSColor.textBackgroundColor;
        _table.gridStyleMask = NSTableViewGridNone;
        _table.allowsEmptySelection = YES;

        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"line"];
        col.resizingMask = NSTableColumnAutoresizingMask;
        [_table addTableColumn:col];

        scroll.documentView = _table;
        [self addSubview:scroll];
    }
    return self;
}

#pragma mark loading

- (BOOL)loadListingForSRecord:(NSString *)srecPath {
    [_lines removeAllObjects]; [_addr removeAllObjects];
    [_instrRows removeAllIndexes]; _pcRow = -1;

    NSString *l68 = [[srecPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"L68"];
    NSString *content = [NSString stringWithContentsOfFile:l68 encoding:NSUTF8StringEncoding error:nil];
    if (!content)
        content = [NSString stringWithContentsOfFile:l68 encoding:NSISOLatin1StringEncoding error:nil];
    BOOL found = (content != nil);

    if (!found) {
        for (NSString *s in @[@"A matching .L68 file was not found. The .L68 file",
                              @"is used to provide source level debugging.", @"",
                              @"Use EASy68K to assemble the source file to create",
                              @"a properly formatted .L68 file and make sure the",
                              @".L68 and .S68 files are in the same directory.", @"",
                              @"You may run the program without an .L68 file but",
                              @"source level debugging will not be available."])
            [_lines addObject:s];
    } else {
        for (NSString *raw in [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r"]];
            [_lines addObject:line];
        }
    }
    for (NSUInteger i = 0; i < _lines.count; i++) {
        NSString *ln = _lines[i];
        [_addr addObject:@(parseAddrCol(ln))];
        if (lineIsInstruction(ln)) [_instrRows addIndex:i];
    }
    [_table reloadData];
    return found;
}

- (NSArray<NSNumber *> *)scanDirectivesBitfield:(BOOL *)bitfield simhaltOff:(BOOL *)simhaltOff {
    NSMutableArray<NSNumber *> *bps = [NSMutableArray array];
    if (bitfield) *bitfield = NO;
    if (simhaltOff) *simhaltOff = NO;
    for (NSUInteger i = 0; i < _lines.count; i++) {
        NSString *low = [_lines[i] lowercaseString];
        // directives live in the comment column (col 41+, 1-based -> index 40)
        if (low.length < 41) continue;
        NSString *tail = [low substringFromIndex:40];
        if ([tail hasPrefix:@"*[sim68k]break"] && i + 1 < _lines.count && i + 1 > 2) {
            if (lineIsInstruction(_lines[i+1])) {
                long a = parseAddrCol(_lines[i+1]);
                if (a >= 0) { [_breaks addObject:@((uint32_t)a)]; [bps addObject:@((uint32_t)a)]; }
            }
        }
        if ([tail hasPrefix:@"*[sim68k]bitfield"] && bitfield) *bitfield = YES;
        if ([tail hasPrefix:@"*[sim68k]simhalt_off"] && simhaltOff) *simhaltOff = YES;
    }
    [_table reloadData];
    return bps;
}

- (uint32_t)firstAddress {
    for (NSUInteger i = 0; i < _addr.count; i++)
        if ([_instrRows containsIndex:i]) return (uint32_t)_addr[i].longValue;
    return 0;
}

#pragma mark highlight + breakpoints

- (NSInteger)rowForAddress:(uint32_t)pc instructionOnly:(BOOL)instrOnly {
    for (NSUInteger i = 0; i < _addr.count; i++) {
        if (_addr[i].longValue == (long)pc && (!instrOnly || [_instrRows containsIndex:i]))
            return (NSInteger)i;
    }
    return -1;
}

- (void)highlightPC:(uint32_t)pc halted:(BOOL)halted {
    NSInteger row = [self rowForAddress:pc instructionOnly:!halted];
    if (row < 0 && halted) row = [self rowForAddress:pc instructionOnly:NO];
    NSInteger old = _pcRow;
    _pcRow = row;
    if (old >= 0 && old < (NSInteger)_lines.count) [self refreshRow:old];
    if (row >= 0) {
        [self refreshRow:row];
        [_table scrollRowToVisible:row];
    }
}

- (void)refreshRow:(NSInteger)row {
    SimListingRowView *rv = [_table rowViewAtRow:row makeIfNecessary:NO];
    if (rv) {
        rv.isCurrentPC = (row == _pcRow);
        rv.hasBreakpoint = [self rowHasBreakpoint:row];
        rv.needsDisplay = YES;
    }
}

- (BOOL)rowHasBreakpoint:(NSInteger)row {
    long a = _addr[row].longValue;
    return a >= 0 && [_breaks containsObject:@((uint32_t)a)];
}

- (void)toggleBreakpointAtRow:(NSInteger)row {
    if (![_instrRows containsIndex:row]) return;     // only on instruction lines
    long a = _addr[row].longValue;
    if (a < 0) return;
    BOOL en = ![_breaks containsObject:@((uint32_t)a)];
    [self setBreakpoint:(uint32_t)a enabled:en];
    if ([self.listingDelegate respondsToSelector:@selector(listingToggledBreakpointAtAddress:enabled:)])
        [self.listingDelegate listingToggledBreakpointAtAddress:(uint32_t)a enabled:en];
}

- (void)setBreakpoint:(uint32_t)addr enabled:(BOOL)enabled {
    if (enabled) [_breaks addObject:@(addr)]; else [_breaks removeObject:@(addr)];
    NSInteger row = [self rowForAddress:addr instructionOnly:YES];
    if (row >= 0) [self refreshRow:row];
}
- (BOOL)hasBreakpointAtAddress:(uint32_t)addr { return [_breaks containsObject:@(addr)]; }
- (NSArray<NSNumber *> *)breakpointAddresses { return _breaks.allObjects; }

- (uint32_t)selectedAddress {
    NSInteger row = _table.selectedRow;
    if (row >= 0 && row < (NSInteger)_addr.count && [_instrRows containsIndex:row])
        return (uint32_t)_addr[row].longValue;
    return 0;
}

#pragma mark table data source / delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return _lines.count; }

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    NSTextField *tf = [tableView makeViewWithIdentifier:@"cell" owner:self];
    if (!tf) {
        tf = [[NSTextField alloc] initWithFrame:NSZeroRect];
        tf.identifier = @"cell";
        tf.bordered = NO; tf.editable = NO; tf.selectable = NO;
        tf.drawsBackground = NO;
        tf.font = _font;
        tf.lineBreakMode = NSLineBreakByClipping;
    }
    tf.stringValue = _lines[row];
    tf.textColor = [_instrRows containsIndex:row] ? NSColor.labelColor : NSColor.secondaryLabelColor;
    return tf;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    SimListingRowView *rv = [[SimListingRowView alloc] initWithFrame:NSZeroRect];
    rv.isCurrentPC = (row == _pcRow);
    rv.hasBreakpoint = [self rowHasBreakpoint:row];
    return rv;
}

// indent the text past the gutter
- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    NSView *cell = [rowView viewAtColumn:0];
    if (cell) {
        cell.frame = NSMakeRect(GUTTER, 0, NSWidth(rowView.bounds) - GUTTER, NSHeight(rowView.bounds));
    }
}

@end
