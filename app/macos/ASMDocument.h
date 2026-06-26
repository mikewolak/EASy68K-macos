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
//  ASMDocument.h
//  EASy68K — document model for a .X68 68000 assembly source file.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASMDocument : NSDocument
@property (nonatomic, copy) NSString *text;        // source content

// ---- Remote control (HTTP control server; main thread) ----
- (NSString *)remoteSourceText;
- (void)remoteSetSourceText:(NSString *)text;
- (NSDictionary *)remoteAssemble;          // {diagnostics:[{line,message}], count}
- (void)remoteRunInSimulator;
@end

NS_ASSUME_NONNULL_END
