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
//  AboutWindowController.m
//  EASy68K — About panel.
//
#import "AboutWindowController.h"

@implementation AboutWindowController

+ (void)showAbout {
    static AboutWindowController *shared;
    if (!shared) shared = [[AboutWindowController alloc] init];
    [shared showWindow:nil];
    [shared.window center];
    [shared.window makeKeyAndOrderFront:nil];
}

- (instancetype)init {
    NSWindow *win = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 420, 420)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
        backing:NSBackingStoreBuffered defer:NO];
    win.title = @"About EASy68K";
    if ((self = [super initWithWindow:win])) {
        [self build];
    }
    return self;
}

- (void)build {
    NSView *c = self.window.contentView;

    // Wordmark logo from the bundle.
    NSImageView *logo = [[NSImageView alloc] init];
    logo.image = [NSImage imageNamed:@"logo"] ?:
        [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"logo" ofType:@"png"]];
    logo.imageScaling = NSImageScaleProportionallyUpOrDown;
    logo.translatesAutoresizingMaskIntoConstraints = NO;

    NSString *version = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"";
    NSTextField *title = [NSTextField labelWithString:@"EASy68K for macOS"];
    title.font = [NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
    title.alignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *ver = [NSTextField labelWithString:[NSString stringWithFormat:@"Version %@", version]];
    ver.font = [NSFont systemFontOfSize:12];
    ver.textColor = NSColor.secondaryLabelColor;
    ver.alignment = NSTextAlignmentCenter;
    ver.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *credits = [NSTextField wrappingLabelWithString:
        @"Editor/Assembler and Simulator for the Motorola 68000.\n\n"
         "Original EASy68K by Charles Kelly, Paul McKee, Tim Larson and "
         "Eric Nelson.\n\n"
         "macOS port by mikewolak@gmail.com — a native Cocoa/AppKit application "
         "with a C99 assembler + simulator core."];
    credits.font = [NSFont systemFontOfSize:11];
    credits.textColor = NSColor.secondaryLabelColor;
    credits.alignment = NSTextAlignmentCenter;
    credits.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *copyright = [NSTextField wrappingLabelWithString:
        @"Copyright © 2026 mikewolak@gmail.com — Epromfoundry, Inc.\n"
         "Not for commercial use."];
    copyright.font = [NSFont systemFontOfSize:10];
    copyright.textColor = NSColor.tertiaryLabelColor;
    copyright.alignment = NSTextAlignmentCenter;
    copyright.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSView *v in @[logo, title, ver, credits, copyright]) [c addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [logo.topAnchor constraintEqualToAnchor:c.topAnchor constant:28],
        [logo.centerXAnchor constraintEqualToAnchor:c.centerXAnchor],
        [logo.widthAnchor constraintEqualToConstant:240],
        [logo.heightAnchor constraintEqualToConstant:102],

        [title.topAnchor constraintEqualToAnchor:logo.bottomAnchor constant:18],
        [title.centerXAnchor constraintEqualToAnchor:c.centerXAnchor],

        [ver.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
        [ver.centerXAnchor constraintEqualToAnchor:c.centerXAnchor],

        [credits.topAnchor constraintEqualToAnchor:ver.bottomAnchor constant:18],
        [credits.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:28],
        [credits.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-28],

        [copyright.topAnchor constraintEqualToAnchor:credits.bottomAnchor constant:16],
        [copyright.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:28],
        [copyright.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-28],
    ]];
}

@end
