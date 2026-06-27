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

// Remote control (driven by SimRemoteServer, no modal panels) — mirrors the
// other functions so EASyBIN can be scripted/tested headlessly.
- (NSDictionary *)remoteLoadSrec:(NSString *)path;
- (NSDictionary *)remoteLoadBinary:(NSString *)path addr:(uint32_t)addr split:(int)split;
- (NSDictionary *)remoteSaveBinary:(NSString *)path from:(uint32_t)from length:(uint32_t)length split:(int)split;
- (NSDictionary *)remoteSaveSrec:(NSString *)path from:(uint32_t)from to:(uint32_t)to start:(uint32_t)start;
- (NSString *)remoteMemoryAt:(uint32_t)addr length:(int)len;
@end
