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
//  SimSoundBridge.m
//
#import "SimSoundBridge.h"
#import "SimSoundEngine.h"

static NSString *str(const char *s) { return s ? [NSString stringWithUTF8String:s] : @""; }

void snd_set_base_dir(const char *dir) { [SimSoundEngine shared].baseDirectory = str(dir); }
int  snd_load(const char *name, int index) { return [[SimSoundEngine shared] loadSound:str(name) index:index]; }
int  snd_play_file(const char *name)       { return [[SimSoundEngine shared] playFile:str(name)]; }
int  snd_play_index(int index)             { return [[SimSoundEngine shared] playIndex:index]; }
void snd_control(int control, int index)   { [[SimSoundEngine shared] control:control index:index]; }
void snd_reset(void)                       { [[SimSoundEngine shared] resetSounds]; }
