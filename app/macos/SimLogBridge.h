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
//  SimLogBridge.h
//  EASy68K — lets the C simulator core pretty-print the .L68 source line into
//  the execution log (the listing lives in Objective-C, the core does not).
//
#ifndef SIMLOGBRIDGE_H
#define SIMLOGBRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void simlog_set_listing(void *listingView);   // register the active SimListingView
// Write the source line for the instruction at `addr` to the execution log.
// Returns 1 if a line was written, 0 otherwise (caller logs a fallback).
int  simlog_emit_source(uint32_t addr);

#ifdef __cplusplus
}
#endif

#endif
