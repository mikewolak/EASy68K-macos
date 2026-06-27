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
//  SimSerialBridge.h
//  Plain-C entry points the core's TRAP #15 comm tasks (40-43) call to drive
//  the termios-based SimSerialEngine.
//
#ifndef SIMSERIALBRIDGE_H
#define SIMSERIALBRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

int  ser_open(int cid, const char *portName);
int  ser_setparams(int cid, int settings);
int  ser_read(int cid, char *buf, unsigned char *n);
int  ser_send(int cid, const char *buf, unsigned char *n);
void ser_close(int cid);

#ifdef __cplusplus
}
#endif

#endif
