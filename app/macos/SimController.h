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
//  SimController.h
//  EASy68K — native 68000 simulator window (registers, memory, I/O console).
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimController : NSWindowController

// Open (or reuse) the simulator window and load the given .S68 program.
+ (instancetype)sharedController;
- (void)loadAndShow:(NSString *)srecPath title:(NSString *)title;

// ---- Remote control (used by the HTTP control server; main-thread) ----
- (void)remoteLoad:(NSString *)srecPath title:(NSString *)title;  // load, don't run
- (void)remoteRun;
- (void)remoteStep;
- (void)remoteStop;
- (void)remoteReset;
- (void)remoteInput:(NSString *)text;
- (NSDictionary *)remoteState;                                     // regs + status
- (NSString *)remoteMemoryAt:(uint32_t)addr length:(int)len;       // hex dump
- (NSString *)remoteConsole;

@end

NS_ASSUME_NONNULL_END
