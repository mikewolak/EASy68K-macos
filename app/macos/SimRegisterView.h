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
//  SimRegisterView.h
//  EASy68K — the simulator's register panel (1:1 with SIM68Ku.dfm's GroupBox1):
//  editable hex fields for D0-D7, A0-A7, US (alternate stack pointer), PC and
//  SR, the SR flag breakdown (T S INT XNZVC) and a cycle counter with a Clear
//  button. Editing a field writes straight back to the live CPU register.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimRegisterView : NSView
@property (nonatomic, copy, nullable) void (^onEdit)(void);  // called after a reg is changed
- (void)refresh;                                             // pull values from the CPU
@end

NS_ASSUME_NONNULL_END
