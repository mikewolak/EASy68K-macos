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
//  SimBridge.c
//  EASy68K — Cocoa host for the simulator core. Defines the simIO device and
//  the sim* host functions (replacing simhost_cli.c) and routes them to the
//  callbacks registered by the Objective-C SimController.
//
//  Compiled as plain C99 (no Cocoa headers) so the sim core's def.h enums
//  don't collide with system headers such as <mach/.../vm_param.h>.
//
#include <stdio.h>
#include <string.h>
#include "simhost.h"
#include "SimBridge.h"
#include "SimGfxBridge.h"     // routes graphics/text to the SimGraphicsView
#include "SimLogBridge.h"     // pretty-prints .L68 source lines into the log
#include "SimHwBridge.h"      // memory-mapped LEDs/7-seg/switches Hardware window
#include "SimSoundBridge.h"   // low-latency ring-buffer audio for TRAP sound tasks
#include "net.h"              // BSD-socket networking for TRAP net tasks (100-107)
#include "SimSerialBridge.h"  // termios serial for TRAP comm tasks (40-43)
#include "SimIntController.h" // MIDI/serial I/O interrupt control (TRAP task 121)

// Device I/O interrupt control (TRAP task 121): map func/source/level to the
// interrupt controller. func 0=disable 1=enable; source 0-3; level 1-7.
void simIOIntControl(int func, int source, int level) { simIntConfig(source, func, level); }

extern int PC;               // current program counter (globals.c, int32_t)

static SimBridgeCallbacks gCB;

void SimBridge_install(SimBridgeCallbacks cb) {
    gCB = cb;
}

/* ------------------------------------------------------------------ *
 *  simIO device — text console routed to the Cocoa I/O view; graphics,
 *  sound, comm and networking are no-ops (a later phase can add them).
 * ------------------------------------------------------------------ */
// Text goes through the controller (it captures for the remote /console API
// AND forwards to the graphics canvas for display).
static void io_textOut(const char *s)   { if (gCB.textOut) gCB.textOut(gCB.ctx, s, 0); }
static void io_textOutCR(const char *s) { if (gCB.textOut) gCB.textOut(gCB.ctx, s, 1); }
static void io_charOut(char ch)         { if (gCB.charOut) gCB.charOut(gCB.ctx, ch); }
static void io_charIn(char *ch)         { if (gCB.charIn) gCB.charIn(gCB.ctx, ch); else if (ch) *ch = 0; }

static void io_textIn(char *buf, int32_t *len, int32_t *num) {
    int n = 0;
    if (gCB.readLine) gCB.readLine(gCB.ctx, buf, 256, &n);
    else if (buf) buf[0] = '\0';
    if (len) *len = n;
    if (num) { long v = 0; sscanf(buf, "%ld", &v); *num = (int32_t)v; }
}

static void io_clear(void)              { if (gCB.clearConsole) gCB.clearConsole(gCB.ctx); }
static void io_gotorc(int x, int y)     { gfx_gotorc(y, x); }   // D1: col(high)/row(low)
static void io_getrc(short *d1)         { int row=0,col=0; gfx_getrc(&row,&col); if(d1)*d1=(short)((col<<8)|(row&0xFF)); }
static void io_getCharAt(ushort r, ushort c, char *d1){ (void)r;(void)c; if(d1)*d1=0; }
static void io_scrollRect(ushort r, ushort c, ushort w, ushort h, ushort d){(void)r;(void)c;(void)w;(void)h;(void)d;}
static void io_setFontProperties(int c, int s){ gfx_setFont((uint32_t)c, s & 0xFF ? (s>>16)&0xFF : 0); }
static void io_getKeyState(int32_t *d1){ if(d1) *d1 = (int32_t)gfx_getKeyState((uint32_t)*d1); }
static void io_setupWindow(void){ gfx_setWindowSize(0,0); }
static void io_setWindowSize(unsigned short w,unsigned short h){ gfx_setWindowSize(w,h); }
static void io_getWindowSize(unsigned short *w,unsigned short *h){ int ww=0,hh=0; gfx_getWindowSize(&ww,&hh); if(w)*w=(unsigned short)ww; if(h)*h=(unsigned short)hh; }
static void io_drawPixel(int x,int y){ gfx_drawPixel(x,y); }
static int  io_getPixel(int x,int y){ return (int)gfx_getPixel(x,y); }
static void io_line(int a,int b,int c,int d){ gfx_line(a,b,c,d); }
static void io_lineTo(int x,int y){ gfx_lineTo(x,y); }
static void io_moveTo(int x,int y){ gfx_moveTo(x,y); }
static void io_getXY(short*x,short*y){ int xx=0,yy=0; gfx_getXY(&xx,&yy); if(x)*x=(short)xx; if(y)*y=(short)yy; }
static void io_setLineColor(int c){ gfx_setLineColor((uint32_t)c); }
static void io_setFillColor(int c){ gfx_setFillColor((uint32_t)c); }
static void io_rectangle(int a,int b,int c,int d){ gfx_rect(a,b,c,d,1); }
static void io_ellipse(int a,int b,int c,int d){ gfx_ellipse(a,b,c,d,1); }
static void io_floodFill(int x,int y){ gfx_floodFill(x,y); }
static void io_unfilledRectangle(int a,int b,int c,int d){ gfx_rect(a,b,c,d,0); }
static void io_unfilledEllipse(int a,int b,int c,int d){ gfx_ellipse(a,b,c,d,0); }
static void io_setDrawingMode(int m){ gfx_setPenMode(m); }
static void io_setPenWidth(int w){ gfx_setPenWidth(w); }
static void io_drawText(const char*s,int x,int y){ gfx_drawText(s,x,y); }
static void io_FormPaint(void*s){(void)s; gfx_present();}  // task 94: flip back->front
static void io_playSound(char*f,short*r){ int ok=snd_play_file(f); if(r)*r=ok?0:1; }
static void io_loadSound(char*f,int i){ snd_load(f,i); }
static void io_playSoundMem(int i,short*r){ int ok=snd_play_index(i); if(r)*r=ok?0:1; }
static void io_controlSound(int c,int i,short*r){ snd_control(c,i); if(r)*r=0; }
static void io_playSoundDX(char*f,short*r){ int ok=snd_play_file(f); if(r)*r=ok?0:1; }
static void io_loadSoundDX(char*f,int i,short*r){ snd_load(f,i); if(r)*r=0; }
static void io_playSoundMemDX(int i,short*r){ int ok=snd_play_index(i); if(r)*r=ok?0:1; }
static void io_controlSoundDX(int c,int i,short*r){ snd_control(c,i); if(r)*r=0; }
static void io_ResetSounds(void){ snd_reset(); }
// Serial comm (TRAP #15 tasks 40-43) -> termios SimSerialEngine. The port and
// baud come from Settings (hot-plug aware) unless the program passes a /dev path.
static void io_initComm(int c,char*p,short*r){ int res=ser_open(c,p); if(r)*r=(short)res; }
static void io_setCommParams(int c,int s,short*r){ int res=ser_setparams(c,s); if(r)*r=(short)res; }
static void io_readComm(int c,uchar*n,char*s,short*r){ int res=ser_read(c,s,n); if(r)*r=(short)res; }
static void io_sendComm(int c,uchar*n,char*s,short*r){ int res=ser_send(c,s,n); if(r)*r=(short)res; }
// Networking (TRAP #15 tasks 100-107) -> BSD-socket net.c. The `settings`
// word packs the connection type (low byte) and port (high word); send/recv
// pack the byte count (low word).
static void io_createNetClient(int s,char*sv,int*r){
    int type=s&0xFF, port=(s>>16)&0xFFFF;
    if(r)*r=netCreateClient(sv,port,type);
}
static void io_createNetServer(int s,int*r){
    int type=s&0xFF, port=(s>>16)&0xFFFF;
    if(r)*r=netCreateServer(port,type);
}
static void io_sendNet(int s,char*d,char*ip,int*c,int*r){
    unsigned int size=(unsigned int)(s&0xFFFF);
    int res=netSendData(d,&size,ip);
    if(r)*r=res; if(c&&res==NET_OK)*c=(int)size;
}
static void io_receiveNet(int s,char*b,int*c,char*ip,int*r){
    unsigned int size=(unsigned int)(s&0xFFFF);
    int res=netReadData(b,&size,ip);
    if(r)*r=res; if(c&&res==NET_OK)*c=(int)size;
}
static void io_sendPortNet(int32_t*d0,int32_t*d1,char*d,char*ip){
    unsigned int size=(unsigned int)(*d1&0xFFFF);
    unsigned short port=(unsigned short)((*d1>>16)&0xFFFF);
    *d0=netSendDataPort(d,&size,ip,port);
    if(*d0==NET_OK)*d1=(int32_t)size;
}
static void io_receivePortNet(int32_t*d0,int32_t*d1,char*b,char*ip){
    unsigned int size=(unsigned int)(*d1&0xFFFF);
    unsigned short port=0;
    *d0=netReadDataPort(b,&size,ip,&port);
    if(*d0==NET_OK)*d1=((int32_t)port<<16)|((int32_t)size&0xFFFF);
}
static void io_closeNetConnection(int c,int*r){(void)c; if(r)*r=netCloseSockets();}
static void io_getLocalIP(char*ip,int*r){ int res=netLocalIP(ip); if(r)*r=res; }
static void io_displayFileDialog(int32_t*m,int a1,int a2,int a3,short*r){(void)m;(void)a1;(void)a2;(void)a3; if(r)*r=0;}

static SimIODevice cocoa_io = {
    io_textOut, io_textOutCR, io_textIn, io_charIn, io_charOut, io_clear,
    io_gotorc, io_getrc, io_getCharAt, io_scrollRect, io_setFontProperties, io_getKeyState,
    io_setupWindow, io_setWindowSize, io_getWindowSize,
    io_drawPixel, io_getPixel, io_line, io_lineTo, io_moveTo, io_getXY,
    io_setLineColor, io_setFillColor, io_rectangle, io_ellipse, io_floodFill,
    io_unfilledRectangle, io_unfilledEllipse, io_setDrawingMode, io_setPenWidth,
    io_drawText, io_FormPaint,
    io_playSound, io_loadSound, io_playSoundMem, io_controlSound,
    io_playSoundDX, io_loadSoundDX, io_playSoundMemDX, io_controlSoundDX, io_ResetSounds,
    io_initComm, io_setCommParams, io_readComm, io_sendComm,
    io_createNetClient, io_createNetServer, io_sendNet, io_receiveNet,
    io_sendPortNet, io_receivePortNet, io_closeNetConnection, io_getLocalIP,
    io_displayFileDialog,
    0,      // fullScreen
    0,      // BackBuffer
    0,      // Font
};

SimIODevice *simIO = &cocoa_io;

/* ------------------------------------------------------------------ *
 *  Form1 (main window) host operations -> Cocoa controller.
 * ------------------------------------------------------------------ */
void simMessage(const char *msg)        { if (gCB.message) gCB.message(gCB.ctx, msg); }
void simUpdateDisplay(void)             { if (gCB.updateDisplay) gCB.updateDisplay(gCB.ctx); }
void simMemoryUpdate(int loc)           { if (gCB.memoryChanged) gCB.memoryChanged(gCB.ctx, loc); }
void simSetAutoTrace(bool e)            { (void)e; }
void simSetFocus(void)                  {}
void simSetMenuTrace(void)              {}
void simSetMenuActive(void)             {}
void simSetMenuTask19(void)             {}
void simRestoreMenuTask19(void)         {}
// Pretty-print the .L68 source line for the current instruction (at PC-2, the
// instruction address at the trace/log point) into the execution log, exactly
// like the Windows version. Returns true if a source line was written; false
// makes run.c fall back to "PC=.. Code=.. mnemonic".
bool simLineToLog(void)                 { return simlog_emit_source((uint32_t)(PC - 2)) ? true : false; }
void simSaveSettings(void)              {}
void simSetExceptionsEnabled(bool e)    { (void)e; }
void simProcessMessages(void)           {}
void simStopLog(void)                   {}
void simPrintChar(char ch)              { if (gCB.charOut) gCB.charOut(gCB.ctx, ch); }
void simPrintFormFeed(void)             { if (gCB.charOut) gCB.charOut(gCB.ctx, '\f'); }

void simHardwareEnable(void)            {}
void simHardwareDisable(void)           {}
void simHardwareAutoIRQoff(void)        {}
void simHardwareShow(void)              {}
void simHardwareUpdate(int loc)         { hw_update(loc); }
void simHardwareSetAutoIRQ(uchar n,int iv){ (void)n; (void)iv; }
int  simHardwareSeg7Addr(void)          { return hw_seg7_addr(); }
int  simHardwareLEDAddr(void)           { return hw_led_addr(); }
int  simHardwareSwitchAddr(void)        { return hw_switch_addr(); }
int  simHardwarePbAddr(void)            { return hw_pb_addr(); }
void simHardwareSetMap(int k,int s,int e){ (void)k; (void)s; (void)e; }
