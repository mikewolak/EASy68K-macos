/***************************** 68000 SIMULATOR ****************************

File Name: simhost.h

Host interface for the simulator core. In the original Borland build the
core called directly into two VCL form objects:

  - Form1  : the main simulator window (register / cycle display, the
             message log, auto-trace timer, menu state)
  - simIO  : the Input/Output window (text console, graphics, sound,
             serial comm, networking)

To keep the CPU core portable, those are replaced by:

  - a set of sim*() host functions for the Form1 operations
  - a SimIODevice struct of function pointers for the simIO device, so
    every existing `simIO->method(args)` call site compiles unchanged

A host (the CLI runner or the Cocoa app) installs implementations. The CLI
provides a text console on stdin/stdout and no-op stubs for the graphics,
sound, comm and network devices; the Cocoa app provides the full GUI.

***************************************************************************/
#ifndef SIMHOST_H
#define SIMHOST_H

#include <stdbool.h>
#include <stdint.h>
#include "def.h"     // ushort, uchar

/* ------------------------------------------------------------------ *
 *  simIO : the Input/Output device.
 *  Signatures mirror the original TsimIO methods (AnsiString -> char*,
 *  C++ references -> pointers, 68000 longs -> int32_t).
 * ------------------------------------------------------------------ */
typedef struct SimIODevice {
    /* ---- text console ---- */
    void (*textOut)(const char *str);            // display string, no CRLF
    void (*textOutCR)(const char *str);          // display string, with CRLF
    void (*textIn)(char *buf, int32_t *len, int32_t *num);
    void (*charIn)(char *ch);
    void (*charOut)(char ch);
    void (*clear)(void);
    void (*gotorc)(int x, int y);                // set cursor row/col
    void (*getrc)(short *d1);                    // get cursor row/col
    void (*getCharAt)(ushort r, ushort c, char *d1);
    void (*scrollRect)(ushort r, ushort c, ushort w, ushort h, ushort dir);
    void (*setFontProperties)(int color, int style);
    void (*getKeyState)(int32_t *d1);

    /* ---- window ---- */
    void (*setupWindow)(void);
    void (*setWindowSize)(unsigned short width, unsigned short height);
    void (*getWindowSize)(unsigned short *width, unsigned short *height);

    /* ---- graphics ---- */
    void (*drawPixel)(int x, int y);
    int  (*getPixel)(int x, int y);
    void (*line)(int x1, int y1, int x2, int y2);
    void (*lineTo)(int x, int y);
    void (*moveTo)(int x, int y);
    void (*getXY)(short *x, short *y);
    void (*setLineColor)(int c);
    void (*setFillColor)(int c);
    void (*rectangle)(int x1, int y1, int x2, int y2);
    void (*ellipse)(int x1, int y1, int x2, int y2);
    void (*floodFill)(int x1, int y1);
    void (*unfilledRectangle)(int x1, int y1, int x2, int y2);
    void (*unfilledEllipse)(int x1, int y1, int x2, int y2);
    void (*setDrawingMode)(int m);
    void (*setPenWidth)(int w);
    void (*drawText)(const char *str, int x, int y);
    void (*FormPaint)(void *sender);

    /* ---- sound ---- */
    void (*playSound)(char *fileName, short *result);
    void (*loadSound)(char *fileName, int waveIndex);
    void (*playSoundMem)(int waveIndex, short *result);
    void (*controlSound)(int control, int waveIndex, short *result);
    void (*playSoundDX)(char *fileName, short *result);
    void (*loadSoundDX)(char *fileName, int waveIndex, short *result);
    void (*playSoundMemDX)(int waveIndex, short *result);
    void (*controlSoundDX)(int control, int waveIndex, short *result);
    void (*ResetSounds)(void);

    /* ---- serial comm ---- */
    void (*initComm)(int cid, char *portName, short *result);
    void (*setCommParams)(int cid, int settings, short *result);
    void (*readComm)(int cid, uchar *n, char *str, short *result);
    void (*sendComm)(int cid, uchar *n, char *str, short *result);

    /* ---- networking ---- */
    void (*createNetClient)(int settings, char *server, int *result);
    void (*createNetServer)(int settings, int *result);
    void (*sendNet)(int settings, char *data, char *remoteIP, int *count, int *result);
    void (*receiveNet)(int settings, char *buffer, int *count, char *senderIP, int *result);
    void (*sendPortNet)(int32_t *D0, int32_t *D1, char *data, char *remoteIP);
    void (*receivePortNet)(int32_t *D0, int32_t *D1, char *buffer, char *senderIP);
    void (*closeNetConnection)(int closeIP, int *result);
    void (*getLocalIP)(char *localIP, int *result);

    /* ---- misc ---- */
    void (*displayFileDialog)(int32_t *mode, int A1, int A2, int A3, short *result);

    /* ---- data members ---- */
    bool  fullScreen;        // true when the I/O window is full screen
    void *BackBuffer;        // opaque drawing surface (GUI-owned)
    void *Font;              // opaque font handle (GUI-owned)
} SimIODevice;

extern SimIODevice *simIO;   // installed by the host before running

/* ------------------------------------------------------------------ *
 *  Form1 (main window) host operations.
 * ------------------------------------------------------------------ */

// Append a line to the message/output log.
void simMessage(const char *msg);

// Auto-trace timer control (the GUI's continuous-run timer).
void simSetAutoTrace(bool enabled);

// Bring the main window forward (no-op for the CLI).
void simSetFocus(void);

// Menu/toolbar state during run vs. stopped.
void simSetMenuTrace(void);
void simSetMenuActive(void);
void simSetMenuTask19(void);
void simRestoreMenuTask19(void);

// Write the current instruction to the execution log; returns false to halt.
bool simLineToLog(void);

// Refresh the register / cycle-count display from the current CPU state.
void simUpdateDisplay(void);

// Persist the "exceptions enabled" setting (TRAP task that toggles it).
void simSaveSettings(void);
void simSetExceptionsEnabled(bool enabled);

/* ------------------------------------------------------------------ *
 *  Hardware-simulation window (LED / 7-seg / switches / memory map).
 *  Non-essential for standard console programs; CLI versions are no-ops
 *  or return sensible defaults.
 * ------------------------------------------------------------------ */
void simHardwareEnable(void);
void simHardwareDisable(void);
void simHardwareAutoIRQoff(void);
void simHardwareShow(void);
void simHardwareUpdate(int loc);              // refresh on memory write at loc
void simHardwareSetAutoIRQ(uchar irqNum, int interval);
int  simHardwareSeg7Addr(void);               // memory-mapped device addresses
int  simHardwareLEDAddr(void);
int  simHardwareSwitchAddr(void);
int  simHardwarePbAddr(void);
// Apply a memory-map region parsed from an S0 record during program load.
// kind: 0=ROM 1=Read-only 2=Protected 3=Invalid; start/end are addresses.
void simHardwareSetMap(int kind, int start, int end);

/* ------------------------------------------------------------------ *
 *  Host installation. install_cli_host() wires up the stdin/stdout
 *  console used by the sim68k command-line tool.
 * ------------------------------------------------------------------ */
void install_cli_host(void);

#endif
