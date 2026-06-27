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
//  E68BrushedView.m
//
#import "E68BrushedView.h"

@implementation E68BrushedView

+ (void)drawBrushedAluminumIn:(NSRect)r {
    NSGradient *base = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedWhite:0.86 alpha:1], 0.0,
        [NSColor colorWithCalibratedWhite:0.78 alpha:1], 0.45,
        [NSColor colorWithCalibratedWhite:0.72 alpha:1], 0.55,
        [NSColor colorWithCalibratedWhite:0.82 alpha:1], 1.0, nil];
    [base drawInRect:r angle:-90];

    [NSGraphicsContext saveGraphicsState];
    NSRectClip(r);
    unsigned seed = 0x68000;
    for (CGFloat y = NSMinY(r); y < NSMaxY(r); y += 1.0) {
        seed = seed * 1103515245u + 12345u;
        CGFloat n = ((seed >> 16) & 0xFF) / 255.0;
        CGFloat a = 0.04 + n * 0.06;
        NSColor *c = (n < 0.5) ? [NSColor colorWithCalibratedWhite:1 alpha:a]
                               : [NSColor colorWithCalibratedWhite:0 alpha:a*0.7];
        [c setStroke];
        NSBezierPath *ln = [NSBezierPath bezierPath];
        ln.lineWidth = 1;
        [ln moveToPoint:NSMakePoint(NSMinX(r), y + 0.5)];
        [ln lineToPoint:NSMakePoint(NSMaxX(r), y + 0.5)];
        [ln stroke];
    }
    [NSGraphicsContext restoreGraphicsState];

    NSGradient *hl = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:1 alpha:0.30]
                                                   endingColor:[NSColor colorWithCalibratedWhite:1 alpha:0.0]];
    [hl drawInRect:NSMakeRect(NSMinX(r), NSMaxY(r)-40, NSWidth(r), 40) angle:-90];
}

- (void)drawRect:(NSRect)dirtyRect { [E68BrushedView drawBrushedAluminumIn:self.bounds]; }

+ (void)installInWindow:(NSWindow *)window {
    NSView *content = window.contentView;
    if (!content) return;
    E68BrushedView *bg = [[E68BrushedView alloc] initWithFrame:content.bounds];
    bg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [content addSubview:bg positioned:NSWindowBelow relativeTo:nil];
}

@end
