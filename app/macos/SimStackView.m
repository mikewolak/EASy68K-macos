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
//  SimStackView.m
//
#import "SimStackView.h"
#import "SimCore.h"
#import "E68Theme.h"

#define ADDRMASK 0x00FFFFFF

@implementation SimStackView {
    NSPopUpButton *_which;       // which A-register to centre on
    NSTextView    *_text;
    NSScrollView  *_scroll;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        NSTextField *lbl = [NSTextField labelWithString:@"View"];
        lbl.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:lbl];

        _which = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        [_which addItemsWithTitles:@[@"A7 — User SP", @"A8 — System SP",
                                     @"A0",@"A1",@"A2",@"A3",@"A4",@"A5",@"A6"]];
        _which.translatesAutoresizingMaskIntoConstraints = NO;
        _which.target = self; _which.action = @selector(refresh);
        [self addSubview:_which];

        _scroll = [[NSScrollView alloc] initWithFrame:self.bounds];
        _scroll.hasVerticalScroller = YES;
        _scroll.borderType = NSNoBorder;
        _scroll.translatesAutoresizingMaskIntoConstraints = NO;
        _text = [[NSTextView alloc] initWithFrame:self.bounds];
        _text.editable = NO; _text.richText = YES; _text.drawsBackground = YES;
        _text.backgroundColor = NSColor.textBackgroundColor;
        _text.textContainerInset = NSMakeSize(8, 6);
        _scroll.documentView = _text;
        [self addSubview:_scroll];

        [NSLayoutConstraint activateConstraints:@[
            [lbl.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
            [lbl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [_which.centerYAnchor constraintEqualToAnchor:lbl.centerYAnchor],
            [_which.leadingAnchor constraintEqualToAnchor:lbl.trailingAnchor constant:6],
            [_scroll.topAnchor constraintEqualToAnchor:_which.bottomAnchor constant:6],
            [_scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh)
                                                     name:E68ThemeChangedNotification object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

// Map popup selection -> A[] index. A7=7, A8=8, A0..A6 = 0..6.
- (int)selectedAregIndex {
    switch (_which.indexOfSelectedItem) {
        case 0: return 7;
        case 1: return 8;
        default: return (int)_which.indexOfSelectedItem - 2;  // A0..A6
    }
}

- (void)refresh {
    if (!memory) { _text.string = @""; return; }
    NSFont *font = [E68Theme shared].monoFont;
    int sel = [self selectedAregIndex];
    uint32_t aregAddr = (uint32_t)A[sel] & ADDRMASK;
    uint32_t a7Addr   = (uint32_t)A[7] & ADDRMASK;
    uint32_t center   = aregAddr & ~1u;             // force even

    // rows that fit; the selected pointer sits in the middle
    CGFloat lineH = [[NSLayoutManager new] defaultLineHeightForFont:font];
    int nRows = MAX(16, (int)(NSHeight(_scroll.contentView.bounds) / lineH));
    int midRow = nRows / 2;
    long dispAddr = ((long)center - (long)midRow * 4) & ADDRMASK;

    NSColor *aqua   = [NSColor colorWithCalibratedRed:0.62 green:0.86 blue:0.92 alpha:0.85];
    NSColor *yellow = [NSColor colorWithCalibratedRed:0.96 green:0.88 blue:0.45 alpha:0.85];

    NSMutableAttributedString *out = [[NSMutableAttributedString alloc] init];
    NSDictionary *base = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: NSColor.labelColor };
    NSDictionary *addrAttr = @{ NSFontAttributeName: font,
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.30 green:0.62 blue:0.86 alpha:1.0] };

    for (int r = 0; r < nRows; r++) {
        uint32_t rowAddr = (uint32_t)((dispAddr + (long)r * 4) & ADDRMASK);
        [out appendAttributedString:[[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"%08X: ", rowAddr] attributes:addrAttr]];
        for (int i = 0; i < 4; i++) {
            uint32_t a = (rowAddr + i) & ADDRMASK;
            unsigned char b = (unsigned char)memory[a];
            NSMutableDictionary *at = [base mutableCopy];
            if (a == aregAddr)      at[NSBackgroundColorAttributeName] = aqua;
            else if (a == a7Addr)   at[NSBackgroundColorAttributeName] = yellow;
            [out appendAttributedString:[[NSAttributedString alloc]
                initWithString:[NSString stringWithFormat:@"%02X", b] attributes:at]];
            [out appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:base]];
        }
        [out appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:base]];
    }
    [_text.textStorage setAttributedString:out];

    // centre the selected pointer's row in the viewport
    NSUInteger charsPerRow = 0;  // compute from the first row length
    NSString *s = _text.string;
    NSRange nl = [s rangeOfString:@"\n"];
    charsPerRow = (nl.location != NSNotFound) ? nl.location + 1 : 0;
    if (charsPerRow) {
        NSUInteger midChar = (NSUInteger)midRow * charsPerRow;
        [_text scrollRangeToVisible:NSMakeRange(MIN(midChar, s.length), 0)];
    }
}

@end
