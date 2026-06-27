/*
 * EASy68K for macOS
 *
 * Copyright (c) 2026 mikewolak@gmail.com  —  Epromfoundry, Inc.
 * All rights reserved.
 *
 * ****  NOT FOR COMMERCIAL USE  ****
 * This software is licensed for PERSONAL and EDUCATIONAL use ONLY.
 */

//
//  EASyBINController.h
//  EASyBIN — binary / S-record file creation & editing utility (port of
//  EASyBIN v2.5.0). Standalone brushed-metal window.
//
#import <Cocoa/Cocoa.h>

@interface EASyBINController : NSWindowController
+ (instancetype)shared;
- (void)showBIN;
@end
