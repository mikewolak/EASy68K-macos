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
//  SimRemoteServer.h
//  EASy68K — small localhost HTTP control server so the whole app can be
//  driven remotely (open/edit/assemble/run/step + read registers, memory,
//  console). Intended for automation and testing.
//
#import <Foundation/Foundation.h>

@interface SimRemoteServer : NSObject
+ (instancetype)sharedServer;
- (void)startOnPort:(uint16_t)port;   // default 8068
@end
