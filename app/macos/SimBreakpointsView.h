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
//  SimBreakpointsView.h
//  EASy68K — the Break Points window. Lists the simple PC breakpoints the core
//  checks (brkpt[]), keeps them in sync with the listing gutter, and lets you
//  add by address / remove / clear.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SimBreakpointsDelegate <NSObject>
- (NSString *)sourceLineForAddress:(uint32_t)addr;
- (void)addBreakpointAtAddress:(uint32_t)addr;
- (void)removeBreakpointAtAddress:(uint32_t)addr;
- (void)clearAllBreakpoints;
@end

@interface SimBreakpointsView : NSView
@property (nonatomic, weak) id<SimBreakpointsDelegate> bpDelegate;
- (void)refresh;
@end

NS_ASSUME_NONNULL_END
