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
//  SimLogController.h
//  EASy68K — the Execution Log window (Sim68K's Log Output / LogfileDialog):
//  pick a log type (Instructions / Registers / +Memory), Start/Stop logging,
//  and watch the execution log live.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimLogController : NSWindowController
+ (instancetype)shared;
- (void)showLog;
- (void)startLogging;     // toolbar "Log Start"
- (void)stopLogging;      // toolbar "Log Stop"
@property (nonatomic, readonly) BOOL isLogging;
@end

NS_ASSUME_NONNULL_END
