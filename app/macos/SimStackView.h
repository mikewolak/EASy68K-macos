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
//  SimStackView.h
//  EASy68K — the 68000 Stack window. Shows memory around a stack pointer
//  (4 bytes/row, ADDR: BB BB BB BB), centered on the selected A-register, with
//  the current A-reg byte and the system-stack (A7) byte highlighted — 1:1 with
//  the original Sim68K StackFrm.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimStackView : NSView
- (void)refresh;                 // re-read A[]/memory and redraw
@end

NS_ASSUME_NONNULL_END
