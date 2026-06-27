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
//  SimMidiEngine.h
//  EASy68K — CoreMIDI engine for the new MIDI I/O TRAP (task 120). Enumerates
//  MIDI destinations/sources, sends + receives raw MIDI, and tracks hot-plug
//  device changes (the same CoreMIDI approach as KickDrumWorkshop). A genuine
//  "better than the original" extension — the Windows EASy68K has no MIDI.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimMidiEngine : NSObject
+ (instancetype)shared;

- (int)initMIDI;                                  // create client/ports -> #destinations
- (int)destinationCount;
- (int)sourceCount;
- (int)destinationName:(int)index into:(char *)buf max:(int)max;
- (int)sourceName:(int)index into:(char *)buf max:(int)max;
- (int)openDestination:(int)index;               // 1 ok
- (int)openSource:(int)index;                     // 1 ok
- (int)send:(const unsigned char *)bytes length:(int)len;
- (int)receiveInto:(unsigned char *)buf max:(int)max;   // bytes copied
- (int)devicesChanged;                            // 1 if hot-plug since last call
@end

NS_ASSUME_NONNULL_END
