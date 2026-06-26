//
//  SimBridge.h
//  EASy68K — plain-C bridge between the simulator core's host interface and
//  the Cocoa simulator window. Deliberately free of the sim core's def.h so
//  it can be #imported by Objective-C without clashing with system headers.
//
#ifndef SIMBRIDGE_H
#define SIMBRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Callbacks the Cocoa controller registers. ctx is the controller (id),
// passed back to each C trampoline which forwards to Objective-C.
typedef struct {
    void *ctx;
    void (*textOut)(void *ctx, const char *s, int withNewline); // TRAP print
    void (*charOut)(void *ctx, char c);
    int  (*readLine)(void *ctx, char *buf, int size, int *outLen); // blocks; returns chars
    void (*charIn)(void *ctx, char *ch);                        // blocks; one char
    void (*clearConsole)(void *ctx);
    void (*message)(void *ctx, const char *s);                  // status/message log
    void (*updateDisplay)(void *ctx);                           // refresh registers
    void (*memoryChanged)(void *ctx, int addr);
} SimBridgeCallbacks;

// Install the Cocoa host (sets the global simIO device + sim* handlers and
// stores the callbacks). Call once before running the simulator.
void SimBridge_install(SimBridgeCallbacks cb);

#ifdef __cplusplus
}
#endif

#endif
