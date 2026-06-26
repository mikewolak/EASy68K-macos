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
//  E68Theme.h
//  EASy68K — app-wide appearance settings (font size, colours), persisted in
//  NSUserDefaults and broadcast via E68ThemeChangedNotification so every view
//  restyles live. Modeled on ~/agentorange's AOTheme.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const E68ThemeChangedNotification;

@interface E68Theme : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) CGFloat fontSize;      // 8…28, persisted

- (void)increaseFontSize;
- (void)decreaseFontSize;
- (void)resetFontSize;

- (NSFont *)monoFont;        // the listing / registers / memory font
- (NSFont *)monoSmallFont;

@end

NS_ASSUME_NONNULL_END
