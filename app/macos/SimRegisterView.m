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
//  SimRegisterView.m
//
#import "SimRegisterView.h"
#import "SimCore.h"

extern unsigned long long cycles;   // executed-cycle counter (globals.c)

// register ids used as NSTextField tags
enum { REG_D0 = 0, REG_A0 = 8, REG_US = 16, REG_PC = 17, REG_SR = 18 };

@implementation SimRegisterView {
    NSTextField *_field[19];     // D0-7, A0-7, US, PC, SR
    NSTextField *_flags;
    NSTextField *_cycles;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) [self build];
    return self;
}

// Flipped so that, as the scroll view's document view, the panel pins to the
// TOP-left of the clip area (a non-flipped doc view sinks to the bottom, which
// dropped the register grid into the vertical middle of the window).
- (BOOL)isFlipped { return YES; }

- (NSTextField *)makeField:(int)tag {
    NSTextField *f = [[NSTextField alloc] initWithFrame:NSZeroRect];
    f.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    f.alignment = NSTextAlignmentLeft;
    f.tag = tag; f.target = self; f.action = @selector(fieldEdited:);
    f.translatesAutoresizingMaskIntoConstraints = NO;
    [f.widthAnchor constraintEqualToConstant:(tag == REG_SR ? 52 : 84)].active = YES;
    return f;
}
- (NSTextField *)label:(NSString *)s {
    NSTextField *l = [NSTextField labelWithString:s];
    l.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightSemibold];
    l.textColor = [NSColor colorWithCalibratedRed:0.16 green:0.52 blue:1.0 alpha:1];
    return l;
}

- (void)build {
    NSGridView *g = [[NSGridView alloc] initWithFrame:NSZeroRect];
    g.translatesAutoresizingMaskIntoConstraints = NO;
    g.rowSpacing = 3; g.columnSpacing = 6;
    g.xPlacement = NSGridCellPlacementLeading;

    // D0..D7 (left columns) paired with A0..A7 (right columns)
    for (int i = 0; i < 8; i++) {
        _field[REG_D0 + i] = [self makeField:REG_D0 + i];
        _field[REG_A0 + i] = [self makeField:REG_A0 + i];
        [g addRowWithViews:@[ [self label:[NSString stringWithFormat:@"D%d", i]], _field[REG_D0 + i],
                              [self label:[NSString stringWithFormat:@"A%d", i]], _field[REG_A0 + i] ]];
    }
    // US (alternate stack pointer = A[8]) and PC
    _field[REG_US] = [self makeField:REG_US];
    _field[REG_PC] = [self makeField:REG_PC];
    [g addRowWithViews:@[ [self label:@"US"], _field[REG_US], [self label:@"PC"], _field[REG_PC] ]];
    // SR + flag breakdown
    _field[REG_SR] = [self makeField:REG_SR];
    _flags = [NSTextField labelWithString:@""];
    _flags.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    _flags.textColor = NSColor.secondaryLabelColor;
    NSGridRow *srRow = [g addRowWithViews:@[ [self label:@"SR"], _field[REG_SR], _flags ]];
    if (srRow.numberOfCells >= 4) [srRow mergeCellsInRange:NSMakeRange(2, 2)];

    // Cycles + Clear
    _cycles = [NSTextField labelWithString:@"0"];
    _cycles.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
    NSButton *clear = [NSButton buttonWithTitle:@"Clear" target:self action:@selector(clearCycles:)];
    clear.controlSize = NSControlSizeSmall; clear.font = [NSFont systemFontOfSize:11];
    (void)[g addRowWithViews:@[ [self label:@"Cyc"], _cycles, clear ]];

    [self addSubview:g];
    [NSLayoutConstraint activateConstraints:@[
        [g.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
        [g.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
        [g.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-8],
    ]];
    [self refresh];
}

#pragma mark edit -> CPU

- (void)fieldEdited:(NSTextField *)f {
    NSString *s = [f.stringValue stringByReplacingOccurrencesOfString:@"$" withString:@""];
    uint32_t v = (uint32_t)strtoul(s.UTF8String, NULL, 16);
    int t = (int)f.tag;
    if (t >= REG_D0 && t < REG_D0 + 8)      D[t - REG_D0] = (int32_t)v;
    else if (t >= REG_A0 && t < REG_A0 + 8) A[t - REG_A0] = (int32_t)v;
    else if (t == REG_US)                   A[8] = (int32_t)v;
    else if (t == REG_PC)                   PC = (int32_t)v;
    else if (t == REG_SR)                   SR = (short)(v & 0xFFFF);
    [self refresh];
    if (self.onEdit) self.onEdit();
}

- (void)clearCycles:(id)s { cycles = 0; [self refresh]; }

#pragma mark CPU -> fields

static NSString *flagStr(short sr) {
    int t = (sr >> 15) & 1, su = (sr >> 13) & 1, i = (sr >> 8) & 7;
    int x = (sr >> 4) & 1, n = (sr >> 3) & 1, z = (sr >> 2) & 1, v = (sr >> 1) & 1, c = sr & 1;
    return [NSString stringWithFormat:@"T=%d S=%d INT=%d  X=%d N=%d Z=%d V=%d C=%d", t, su, i, x, n, z, v, c];
}

- (void)setField:(int)tag value:(uint32_t)v width:(int)w {
    NSString *s = [NSString stringWithFormat:@"%0*X", w, v];
    // don't stomp the field the user is editing
    if (self.window.firstResponder == _field[tag].currentEditor) return;
    _field[tag].stringValue = s;
}

- (void)refresh {
    for (int i = 0; i < 8; i++) {
        [self setField:REG_D0 + i value:(uint32_t)D[i] width:8];
        [self setField:REG_A0 + i value:(uint32_t)A[i] width:8];
    }
    [self setField:REG_US value:(uint32_t)A[8] width:8];
    [self setField:REG_PC value:(uint32_t)PC width:8];
    [self setField:REG_SR value:(uint16_t)SR width:4];
    _flags.stringValue = flagStr(SR);
    _cycles.stringValue = [NSString stringWithFormat:@"%llu", (unsigned long long)cycles];
}

@end
