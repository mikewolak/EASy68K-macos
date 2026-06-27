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
//  SimHwBridge.m
//
#import "SimHwBridge.h"
#import "SimHardwareView.h"

static SimHardwareView *gHW;

void hw_set_view(void *v) { gHW = (__bridge SimHardwareView *)v; }
void hw_update(int loc)   { [gHW memoryChangedAt:loc]; }
int  hw_led_addr(void)    { return gHW ? (int)gHW.ledAddr   : -1; }
int  hw_seg7_addr(void)   { return gHW ? (int)gHW.seg7Addr  : -1; }
int  hw_switch_addr(void) { return gHW ? (int)gHW.switchAddr: -1; }
int  hw_pb_addr(void)     { return gHW ? (int)gHW.pbAddr    : -1; }
