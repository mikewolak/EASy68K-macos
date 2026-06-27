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
//  SimSerialEngine.h
//  EASy68K — serial comm for the TRAP #15 comm tasks (40-43) over real macOS
//  serial devices (termios on /dev/cu.*). Enumerates ports via IOKit and posts
//  E68SerialPortsChangedNotification on USB hot-plug (insert/remove), so the
//  Settings picker stays live. The selected port + line parameters persist in
//  NSUserDefaults and are honoured by the TRAP tasks.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const E68SerialPortsChangedNotification;

@interface SimSerialEngine : NSObject
+ (instancetype)shared;

// device enumeration (live; refreshed on hot-plug)
- (NSArray<NSDictionary<NSString *, id> *> *)availablePorts;   // {name, path}

// persisted Settings selection
@property (nonatomic, copy, nullable) NSString *selectedPortPath;
@property (nonatomic) int baudIndex;   // EASy68K baud index 0..14 (7 = 9600)

// TRAP comm tasks, cid 0..15. result: 0 ok, 1 bad cid, 2 I/O error, 3 not open.
- (int)openComm:(int)cid path:(const char *)portName;
- (int)setParams:(int)cid settings:(int)settings;
- (int)readComm:(int)cid buf:(char *)buf count:(unsigned char *)n;
- (int)sendComm:(int)cid buf:(const char *)buf count:(unsigned char *)n;
- (void)closeComm:(int)cid;
@end

NS_ASSUME_NONNULL_END
