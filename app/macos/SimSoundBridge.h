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
//  SimSoundBridge.h
//  EASy68K — plain-C entry points the core's TRAP #15 sound tasks call to drive
//  the low-latency ring-buffer SimSoundEngine.
//
#ifndef SIMSOUNDBRIDGE_H
#define SIMSOUNDBRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

void snd_set_base_dir(const char *dir);
int  snd_load(const char *name, int index);
int  snd_play_file(const char *name);
int  snd_play_index(int index);
void snd_control(int control, int index);
void snd_reset(void);

#ifdef __cplusplus
}
#endif

#endif
