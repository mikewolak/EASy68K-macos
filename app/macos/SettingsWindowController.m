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
//  SettingsWindowController.m
//
#import "SettingsWindowController.h"
#import "E68Theme.h"
#import "E68BrushedView.h"

@implementation SettingsWindowController {
    NSSlider    *_fontSlider;
    NSTextField *_fontValue;
    NSTextField *_preview;
}

+ (void)showSettings {
    static SettingsWindowController *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SettingsWindowController alloc] initWithWindow:nil]; });
    [shared buildIfNeeded];
    [shared.window center];
    [shared showWindow:nil];
    [shared.window makeKeyAndOrderFront:nil];
    [shared syncFromTheme];
}

- (void)buildIfNeeded {
    if (self.window) return;

    NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 460, 280)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
        backing:NSBackingStoreBuffered defer:NO];
    w.title = @"Settings";
    w.releasedWhenClosed = NO;
    self.window = w;
    [E68BrushedView installInWindow:w];
    NSView *root = w.contentView;

    NSTextField *title = [NSTextField labelWithString:@"Settings"];
    title.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:title];

    NSBox *sep = [[NSBox alloc] initWithFrame:NSZeroRect];
    sep.boxType = NSBoxSeparator;
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:sep];

    NSTextField *fontLbl = [NSTextField labelWithString:@"Font size"];
    fontLbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    fontLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:fontLbl];

    _fontSlider = [NSSlider sliderWithValue:[E68Theme shared].fontSize minValue:8 maxValue:28
                                     target:self action:@selector(fontSliderChanged:)];
    _fontSlider.numberOfTickMarks = 21;
    _fontSlider.allowsTickMarkValuesOnly = YES;
    _fontSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:_fontSlider];

    _fontValue = [NSTextField labelWithString:@"12 pt"];
    _fontValue.alignment = NSTextAlignmentRight;
    _fontValue.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
    _fontValue.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:_fontValue];

    NSButton *reset = [NSButton buttonWithTitle:@"Reset" target:self action:@selector(resetFont:)];
    reset.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:reset];

    _preview = [NSTextField labelWithString:@"00001000  4EB9 0000 1234   JSR  start   * preview"];
    _preview.font = [E68Theme shared].monoFont;
    _preview.textColor = NSColor.secondaryLabelColor;
    _preview.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:_preview];

    NSTextField *hint = [NSTextField labelWithString:@"Tip: ⌘+ / ⌘− to resize, ⌘0 to reset."];
    hint.font = [NSFont systemFontOfSize:11];
    hint.textColor = NSColor.tertiaryLabelColor;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:hint];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:root.topAnchor constant:18],
        [title.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],

        [sep.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [sep.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
        [sep.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],

        [fontLbl.topAnchor constraintEqualToAnchor:sep.bottomAnchor constant:20],
        [fontLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],

        [_fontSlider.centerYAnchor constraintEqualToAnchor:fontLbl.centerYAnchor],
        [_fontSlider.leadingAnchor constraintEqualToAnchor:fontLbl.trailingAnchor constant:16],
        [_fontSlider.widthAnchor constraintEqualToConstant:220],

        [_fontValue.centerYAnchor constraintEqualToAnchor:fontLbl.centerYAnchor],
        [_fontValue.leadingAnchor constraintEqualToAnchor:_fontSlider.trailingAnchor constant:12],
        [_fontValue.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],

        [reset.topAnchor constraintEqualToAnchor:fontLbl.bottomAnchor constant:14],
        [reset.leadingAnchor constraintEqualToAnchor:_fontSlider.leadingAnchor],

        [_preview.topAnchor constraintEqualToAnchor:reset.bottomAnchor constant:24],
        [_preview.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],

        [hint.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-16],
        [hint.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncFromTheme)
                                                 name:E68ThemeChangedNotification object:nil];
}

- (void)syncFromTheme {
    CGFloat s = [E68Theme shared].fontSize;
    _fontSlider.doubleValue = s;
    _fontValue.stringValue = [NSString stringWithFormat:@"%d pt", (int)s];
    _preview.font = [E68Theme shared].monoFont;
}

- (void)fontSliderChanged:(NSSlider *)sender {
    [E68Theme shared].fontSize = sender.doubleValue;   // posts the notification
}
- (void)resetFont:(id)sender { [[E68Theme shared] resetFontSize]; }

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

@end
