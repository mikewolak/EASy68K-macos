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
//  SimCore.h
//  EASy68K — plain-C declarations of the simulator core state and entry
//  points the Cocoa controller drives. Kept free of the core's def.h so it
//  can be imported by Objective-C without system-header clashes.
//
#ifndef SIMCORE_H
#define SIMCORE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Address space size (def.h MEMSIZE = 0x01000000, 16 MB).
#define SIM_MEMSIZE 0x01000000

// Entry points (run.c / startsim.c / simops2.c).
extern void initSim(void);
extern int  loadSrec(char *name);
extern int  runprog(void);      // execute one instruction + housekeeping

// CPU + simulator state (globals.c).
extern char     *memory;
extern int32_t   D[8], A[9], PC, OLD_PC, stepToAddr;
extern short     SR;
extern uint64_t  cycles;
extern bool      halt, runMode, trace, sstep, stopInstruction;
extern int       exceptions;
extern bool      bitfield;

// Breakpoints — the core checks these itself in runprog() (sets trace=true to
// stop). brkpt[0..bpoints) are simple PC breakpoints; runToAddr is the
// run-to-cursor stop address (0 = none).
extern int       brkpt[100];
extern char      bpoints;
extern int       runToAddr;

// Hardware: pending interrupt bits, and the memory map (ROM/Read/Protected/
// Invalid regions checked by memoryMapCheck()).
extern int       irq;
extern int       ROMStart, ROMEnd, ReadStart, ReadEnd;
extern int       ProtectedStart, ProtectedEnd, InvalidStart, InvalidEnd;
extern bool      ROMMap, ReadMap, ProtectedMap, InvalidMap;

#ifdef __cplusplus
}
#endif

#endif
