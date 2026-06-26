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
//  LineNumberRuler.m
//  EASy68K — line-number gutter.
//
#import "LineNumberRuler.h"

@implementation LineNumberRuler

- (instancetype)initWithTextView:(NSTextView *)textView {
    NSScrollView *scroll = textView.enclosingScrollView;
    if ((self = [super initWithScrollView:scroll orientation:NSVerticalRuler])) {
        self.clientView = textView;
        self.ruleThickness = 44;
        // Redraw the gutter as the text changes or scrolls.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(needsRedraw:)
            name:NSTextDidChangeNotification object:textView];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(needsRedraw:)
            name:NSViewBoundsDidChangeNotification object:scroll.contentView];
        scroll.contentView.postsBoundsChangedNotifications = YES;
    }
    return self;
}

- (void)needsRedraw:(NSNotification *)n { self.needsDisplay = YES; }

- (void)drawHashMarksAndLabelsInRect:(NSRect)rect {
    NSTextView *tv = (NSTextView *)self.clientView;
    NSLayoutManager *lm = tv.layoutManager;
    NSTextContainer *tc = tv.textContainer;
    NSString *text = tv.string;

    // Gutter background — fill ONLY this ruler's own bounds (its thickness),
    // never the caller-supplied rect, which can span the document width and
    // would paint over the editor text.
    NSRect b = self.bounds;
    [[NSColor controlBackgroundColor] set];
    NSRectFill(b);
    [[NSColor separatorColor] set];
    NSRectFill(NSMakeRect(b.size.width - 1, 0, 1, b.size.height));

    CGFloat yInset = tv.textContainerInset.height;
    CGFloat relYOffset = [self convertPoint:NSZeroPoint fromView:tv].y;

    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
    };

    NSRange visibleGlyphs = [lm glyphRangeForBoundingRect:tv.visibleRect inTextContainer:tc];
    NSUInteger index = visibleGlyphs.location;

    // Count the line number at the start of the visible range.
    NSUInteger lineNo = 1;
    NSUInteger charIndex = [lm characterIndexForGlyphAtIndex:index];
    for (NSUInteger i = 0; i < charIndex && i < text.length; i++)
        if ([text characterAtIndex:i] == '\n') lineNo++;

    while (index < NSMaxRange(visibleGlyphs)) {
        NSRange lineGlyphRange;
        NSRect lineRect = [lm lineFragmentRectForGlyphAtIndex:index effectiveRange:&lineGlyphRange];
        CGFloat y = NSMinY(lineRect) + relYOffset + yInset;

        NSString *label = [NSString stringWithFormat:@"%lu", (unsigned long)lineNo];
        NSSize sz = [label sizeWithAttributes:attrs];
        [label drawAtPoint:NSMakePoint(b.size.width - sz.width - 6, y) withAttributes:attrs];

        index = NSMaxRange(lineGlyphRange);
        lineNo++;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
