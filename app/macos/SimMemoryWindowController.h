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
//  SimMemoryWindowController.h
//  EASy68K — standalone "68000 Memory" window (a 1:1 port of Memory1.dfm): a
//  hex/ASCII dump with an Address jump field, Row/Page up-down spinners, a
//  From/To/Bytes range with Copy/Fill/Save, mouse-wheel scrolling and a Live
//  checkbox that follows execution. Several may be open at once.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimMemoryWindowController : NSWindowController
+ (instancetype)openNewMemoryWindow;   // create + show another memory window
+ (void)refreshLiveWindows;            // redraw any window with Live checked
@end

NS_ASSUME_NONNULL_END
