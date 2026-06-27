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
//  SimHardwareView.h
//  EASy68K — the Hardware window: memory-mapped 8 LEDs, eight 7-segment
//  displays, 8 toggle switches and push buttons, 1:1 with Sim68K's Hardware
//  form. The program drives the LEDs/segments by writing memory; the user
//  drives the switches/buttons which write memory the program reads.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimHardwareView : NSView
@property (nonatomic, readonly) uint32_t ledAddr;
@property (nonatomic, readonly) uint32_t seg7Addr;
@property (nonatomic, readonly) uint32_t switchAddr;
@property (nonatomic, readonly) uint32_t pbAddr;
- (void)memoryChangedAt:(int)loc;   // refresh if loc maps to LEDs/segments
- (void)refresh;
@end

NS_ASSUME_NONNULL_END
