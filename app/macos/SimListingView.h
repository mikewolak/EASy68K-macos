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
//  SimListingView.h
//  EASy68K — the main simulator window's source-level listing pane. Loads the
//  assembler's .L68 listing, highlights the line whose address column matches
//  PC (source-level debugging, exactly as the original Sim68K ListBox1), and
//  shows a clickable breakpoint margin. No disassembler: the .L68 IS the view.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SimListingDelegate <NSObject>
- (void)listingToggledBreakpointAtAddress:(uint32_t)addr enabled:(BOOL)enabled;
@end

@interface SimListingView : NSView

@property (nonatomic, weak) id<SimListingDelegate> listingDelegate;

// Load the .L68 listing that matches the given .S68 path (same name, .L68 ext).
// Returns NO and shows the "source debugging unavailable" message if absent.
- (BOOL)loadListingForSRecord:(NSString *)srecPath;

// Parse + apply the *[sim68k]break / bitfield / simhalt_off directives.
// Returns the set of breakpoint addresses found, and the flags via out-params.
- (NSArray<NSNumber *> *)scanDirectivesBitfield:(BOOL *)bitfield simhaltOff:(BOOL *)simhaltOff;

// Address parsed from the first instruction line (the program's start PC), or
// 0 if none.
- (uint32_t)firstAddress;

// Highlight + scroll to the line whose address column == pc (no-op if none).
- (void)highlightPC:(uint32_t)pc halted:(BOOL)halted;

// Breakpoint margin state.
- (void)setBreakpoint:(uint32_t)addr enabled:(BOOL)enabled;
- (BOOL)hasBreakpointAtAddress:(uint32_t)addr;
- (NSArray<NSNumber *> *)breakpointAddresses;

// Address of the currently-selected line (for Run-To-Cursor), or 0.
- (uint32_t)selectedAddress;

@end

NS_ASSUME_NONNULL_END
