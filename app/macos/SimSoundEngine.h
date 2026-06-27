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
//  SimSoundEngine.h
//  EASy68K — polyphonic sound for the TRAP #15 sound tasks (70-77). A pro
//  CoreAudio engine (AVAudioEngine over the default output device, automatic
//  hot-plug/format handling, the same CoreAudio foundation as KickDrumWorkshop)
//  with a pool of voices so overlapping game effects mix. WAVs load into 256
//  indexed slots, converted to a canonical format once.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimSoundEngine : NSObject
+ (instancetype)shared;

// Directory that relative WAV names resolve against (the loaded .S68's folder).
@property (nonatomic, copy, nullable) NSString *baseDirectory;

- (int)loadSound:(NSString *)fileName index:(int)index;  // 1 ok, 0 fail
- (int)playFile:(NSString *)fileName;                    // load-if-needed + play once
- (int)playIndex:(int)index;                             // play slot once
- (void)control:(int)control index:(int)index;           // 0 stop, 1 play, 2 loop
- (void)resetSounds;                                      // stop everything

// ---- output device + L/R channel routing (persisted in NSUserDefaults) ----
- (NSArray<NSDictionary<NSString *, id> *> *)outputDevices;  // {name, uid, channels}
- (NSString *)currentDeviceUID;
- (void)selectDeviceUID:(NSString *)uid;
- (int)deviceChannelCount;       // output channels on the current device
- (int)leftChannel;              // 0-based device channel feeding L
- (int)rightChannel;             // 0-based device channel feeding R
- (void)setLeftChannel:(int)L right:(int)R;
@end

NS_ASSUME_NONNULL_END
