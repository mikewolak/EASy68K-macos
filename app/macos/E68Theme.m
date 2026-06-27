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
//  E68Theme.m
//
#import "E68Theme.h"

NSString * const E68ThemeChangedNotification = @"E68ThemeChanged";

#define DEFAULT_FONT_SIZE 12.0

@implementation E68Theme {
    NSString *_fontName;
}

+ (instancetype)shared {
    static E68Theme *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [E68Theme new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        CGFloat saved = [[NSUserDefaults standardUserDefaults] floatForKey:@"FontSize"];
        _fontSize = (saved >= 8 && saved <= 28) ? saved : DEFAULT_FONT_SIZE;
    }
    return self;
}

- (void)setFontSize:(CGFloat)fontSize {
    _fontSize = MAX(8, MIN(fontSize, 28));
    [[NSUserDefaults standardUserDefaults] setFloat:_fontSize forKey:@"FontSize"];
    [[NSNotificationCenter defaultCenter] postNotificationName:E68ThemeChangedNotification object:self];
}

- (void)increaseFontSize { self.fontSize = _fontSize + 1; }
- (void)decreaseFontSize { self.fontSize = _fontSize - 1; }
- (void)resetFontSize    { self.fontSize = DEFAULT_FONT_SIZE; self.fontName = nil; }

- (NSString *)fontName {
    if (!_fontName) _fontName = [[NSUserDefaults standardUserDefaults] stringForKey:@"FontName"];
    return _fontName;
}
- (void)setFontName:(NSString *)fontName {
    _fontName = [fontName copy];
    [[NSUserDefaults standardUserDefaults] setObject:(fontName ?: @"") forKey:@"FontName"];
    [[NSNotificationCenter defaultCenter] postNotificationName:E68ThemeChangedNotification object:self];
}

- (NSFont *)monoFont {
    NSFont *f = self.fontName.length ? [NSFont fontWithName:self.fontName size:_fontSize] : nil;
    return f ?: [NSFont monospacedSystemFontOfSize:_fontSize weight:NSFontWeightRegular];
}
- (NSFont *)monoSmallFont {
    NSFont *f = self.fontName.length ? [NSFont fontWithName:self.fontName size:MAX(8,_fontSize-1)] : nil;
    return f ?: [NSFont monospacedSystemFontOfSize:MAX(8,_fontSize-1) weight:NSFontWeightRegular];
}

@end
