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
//  SyntaxHighlighter.h
//  EASy68K — 68000 assembly syntax highlighting for an NSTextStorage.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// Applies 68000 assembly syntax colouring. Attach as the text view's
// NSTextStorage delegate; it re-highlights the edited paragraph(s) on change.
@interface SyntaxHighlighter : NSObject <NSTextStorageDelegate>

@property (nonatomic, strong) NSFont *font;

// Re-highlight an explicit range (used for the initial pass after loading).
- (void)highlightRange:(NSRange)range inStorage:(NSTextStorage *)storage;
- (void)highlightAll:(NSTextStorage *)storage;

@end

NS_ASSUME_NONNULL_END
