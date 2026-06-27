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
//  SimSerialBridge.m
//
#import "SimSerialBridge.h"
#import "SimSerialEngine.h"

int  ser_open(int cid, const char *portName) { return [[SimSerialEngine shared] openComm:cid path:portName]; }
int  ser_setparams(int cid, int settings)    { return [[SimSerialEngine shared] setParams:cid settings:settings]; }
int  ser_read(int cid, char *buf, unsigned char *n)       { return [[SimSerialEngine shared] readComm:cid buf:buf count:n]; }
int  ser_send(int cid, const char *buf, unsigned char *n) { return [[SimSerialEngine shared] sendComm:cid buf:buf count:n]; }
void ser_close(int cid) { [[SimSerialEngine shared] closeComm:cid]; }
