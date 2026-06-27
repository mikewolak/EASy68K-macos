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
//  SimMidiBridge.m
//  EASy68K — implements the C simMIDI() host function (TRAP task 120) by routing
//  to the Obj-C CoreMIDI engine.
//
#import "SimMidiEngine.h"

int simMIDI(int op, int arg, char *buf, int buflen) {
    SimMidiEngine *e = [SimMidiEngine shared];
    switch (op) {
        case 0: return [e initMIDI];                                        // -> #destinations
        case 1: return [e destinationName:arg into:buf max:buflen];
        case 2: return [e openDestination:arg];
        case 3: return [e send:(const unsigned char *)buf length:arg];
        case 4: return [e sourceCount];
        case 5: return [e sourceName:arg into:buf max:buflen];
        case 6: return [e openSource:arg];
        case 7: return [e receiveInto:(unsigned char *)buf max:(arg < buflen ? arg : buflen)];
        case 8: return [e devicesChanged];
        default: return 0;
    }
}
