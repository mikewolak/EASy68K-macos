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
//  SimIntController.c
//
#include "SimIntController.h"

extern int irq;          // the 68000 IRQ request register (globals.c); the CPU
                         // loop autovectors on bit (level-1) and clears it.

static int gEnabled[4];  // all zero => disabled by default
static int gLevel[4];

static void raiseIRQ(int source) {
    if (gEnabled[source] && gLevel[source] >= 1 && gLevel[source] <= 7)
        irq |= (1 << (gLevel[source] - 1));
}

void simIntConfig(int source, int enable, int level) {
    if (source < 0 || source > 3) return;
    gEnabled[source] = enable ? 1 : 0;
    if (level >= 1 && level <= 7) gLevel[source] = level;
    // a freshly-enabled transmitter is immediately "ready" -> first IRQ now
    if (gEnabled[source] && (source == SIM_INT_MIDI_TX || source == SIM_INT_SER_TX))
        raiseIRQ(source);
}

void simIntNotify(int source) {
    if (source < 0 || source > 3) return;
    raiseIRQ(source);
}

int simIntEnabled(int source) { return (source >= 0 && source < 4) ? gEnabled[source] : 0; }
int simIntLevel(int source)   { return (source >= 0 && source < 4) ? gLevel[source]   : 0; }
