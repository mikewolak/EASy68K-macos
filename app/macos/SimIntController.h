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
//  SimIntController.h
//  EASy68K — device I/O interrupt controller. MIDI and serial RX/TX sources can
//  each raise a 68000 autovector IRQ. All four are DISABLED by default and are
//  enabled/disabled by the running 68K program via TRAP #15 task 121, so the
//  program owns its interrupt service routines. Raising an IRQ just sets the
//  shared `irq` register the CPU loop already polls.
//
#ifndef SIMINTCONTROLLER_H
#define SIMINTCONTROLLER_H

#ifdef __cplusplus
extern "C" {
#endif

enum {
    SIM_INT_MIDI_RX = 0,   // MIDI data received
    SIM_INT_MIDI_TX = 1,   // MIDI ready to transmit
    SIM_INT_SER_RX  = 2,   // serial data received
    SIM_INT_SER_TX  = 3    // serial ready to transmit
};

// Configure a source: enable!=0 turns it on at autovector IRQ `level` (1-7).
// Enabling a TX source raises it once immediately (the device is ready).
void simIntConfig(int source, int enable, int level);

// An engine calls this when the source's event occurs; it raises the IRQ only
// if that source is currently enabled.
void simIntNotify(int source);

int  simIntEnabled(int source);
int  simIntLevel(int source);

// Disable every source. Called when a program is loaded or the sim is reset, so
// device interrupts never leak between runs — a program that never enables them
// behaves exactly as it did before this feature existed.
void simIntReset(void);

// Optional hook fired whenever the enabled set changes (config or reset), so an
// engine can start/stop background polling and stay fully dormant when unused.
void simIntSetOnChange(void (*cb)(void));

#ifdef __cplusplus
}
#endif

#endif
