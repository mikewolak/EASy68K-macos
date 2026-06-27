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
//  E68BrushedView.h
//  EASy68K — reusable brushed-aluminum background (vertical sheen + fine
//  horizontal striations). Install it as the backmost layer of any window.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface E68BrushedView : NSView
+ (void)drawBrushedAluminumIn:(NSRect)r;       // shared drawing routine
+ (void)installInWindow:(NSWindow *)window;    // add as backmost, autoresizing
@end

NS_ASSUME_NONNULL_END
