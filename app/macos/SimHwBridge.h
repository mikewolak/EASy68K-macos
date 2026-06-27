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
//  SimHwBridge.h
//  EASy68K — routes the C core's simHardware* hooks to the Obj-C Hardware
//  window (memory-mapped LEDs / 7-segment displays / switches / push buttons).
//
#ifndef SIMHWBRIDGE_H
#define SIMHWBRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

void hw_set_view(void *hardwareView);   // register the active SimHardwareView
void hw_update(int loc);                // a write hit memory[loc] — refresh if mapped
int  hw_led_addr(void);
int  hw_seg7_addr(void);
int  hw_switch_addr(void);
int  hw_pb_addr(void);

#ifdef __cplusplus
}
#endif

#endif
