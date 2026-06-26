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

static SimBridgeCallbacks gCB;

void SimBridge_install(SimBridgeCallbacks cb) {
    gCB = cb;
}

/* ------------------------------------------------------------------ *
 *  simIO device — text console routed to the Cocoa I/O view; graphics,
 *  sound, comm and networking are no-ops (a later phase can add them).
 * ------------------------------------------------------------------ */
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
static void io_gotorc(int x, int y)     { (void)x; (void)y; }
static void io_getrc(short *d1)         { if (d1) *d1 = 0; }
static void io_getCharAt(ushort r, ushort c, char *d1){ (void)r;(void)c; if(d1)*d1=0; }
static void io_scrollRect(ushort r, ushort c, ushort w, ushort h, ushort d){(void)r;(void)c;(void)w;(void)h;(void)d;}
static void io_setFontProperties(int c, int s){(void)c;(void)s;}
static void io_getKeyState(int32_t *d1){ if(d1)*d1=0; }
static void io_setupWindow(void){}
static void io_setWindowSize(unsigned short w,unsigned short h){(void)w;(void)h;}
static void io_getWindowSize(unsigned short *w,unsigned short *h){ if(w)*w=0; if(h)*h=0; }
static void io_drawPixel(int x,int y){(void)x;(void)y;}
static int  io_getPixel(int x,int y){(void)x;(void)y;return 0;}
static void io_line(int a,int b,int c,int d){(void)a;(void)b;(void)c;(void)d;}
static void io_lineTo(int x,int y){(void)x;(void)y;}
static void io_moveTo(int x,int y){(void)x;(void)y;}
static void io_getXY(short*x,short*y){ if(x)*x=0; if(y)*y=0; }
static void io_setLineColor(int c){(void)c;}
static void io_setFillColor(int c){(void)c;}
static void io_rectangle(int a,int b,int c,int d){(void)a;(void)b;(void)c;(void)d;}
static void io_ellipse(int a,int b,int c,int d){(void)a;(void)b;(void)c;(void)d;}
static void io_floodFill(int x,int y){(void)x;(void)y;}
static void io_unfilledRectangle(int a,int b,int c,int d){(void)a;(void)b;(void)c;(void)d;}
static void io_unfilledEllipse(int a,int b,int c,int d){(void)a;(void)b;(void)c;(void)d;}
static void io_setDrawingMode(int m){(void)m;}
static void io_setPenWidth(int w){(void)w;}
static void io_drawText(const char*s,int x,int y){(void)s;(void)x;(void)y;}
static void io_FormPaint(void*s){(void)s;}
static void io_playSound(char*f,short*r){(void)f; if(r)*r=0;}
static void io_loadSound(char*f,int i){(void)f;(void)i;}
static void io_playSoundMem(int i,short*r){(void)i; if(r)*r=0;}
static void io_controlSound(int c,int i,short*r){(void)c;(void)i; if(r)*r=0;}
static void io_playSoundDX(char*f,short*r){(void)f; if(r)*r=0;}
static void io_loadSoundDX(char*f,int i,short*r){(void)f;(void)i; if(r)*r=0;}
static void io_playSoundMemDX(int i,short*r){(void)i; if(r)*r=0;}
static void io_controlSoundDX(int c,int i,short*r){(void)c;(void)i; if(r)*r=0;}
static void io_ResetSounds(void){}
static void io_initComm(int c,char*p,short*r){(void)c;(void)p; if(r)*r=0;}
static void io_setCommParams(int c,int s,short*r){(void)c;(void)s; if(r)*r=0;}
static void io_readComm(int c,uchar*n,char*s,short*r){(void)c;(void)n;(void)s; if(r)*r=0;}
static void io_sendComm(int c,uchar*n,char*s,short*r){(void)c;(void)n;(void)s; if(r)*r=0;}
static void io_createNetClient(int s,char*sv,int*r){(void)s;(void)sv; if(r)*r=0;}
static void io_createNetServer(int s,int*r){(void)s; if(r)*r=0;}
static void io_sendNet(int s,char*d,char*ip,int*c,int*r){(void)s;(void)d;(void)ip; if(c)*c=0; if(r)*r=0;}
static void io_receiveNet(int s,char*b,int*c,char*ip,int*r){(void)s;(void)b;(void)ip; if(c)*c=0; if(r)*r=0;}
static void io_sendPortNet(int32_t*d0,int32_t*d1,char*d,char*ip){(void)d0;(void)d1;(void)d;(void)ip;}
static void io_receivePortNet(int32_t*d0,int32_t*d1,char*b,char*ip){(void)d0;(void)d1;(void)b;(void)ip;}
static void io_closeNetConnection(int c,int*r){(void)c; if(r)*r=0;}
static void io_getLocalIP(char*ip,int*r){ if(ip) ip[0]='\0'; if(r)*r=0; }
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
bool simLineToLog(void)                 { return true; }
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
void simHardwareUpdate(int loc)         { (void)loc; }
void simHardwareSetAutoIRQ(uchar n,int iv){ (void)n; (void)iv; }
int  simHardwareSeg7Addr(void)          { return 0; }
int  simHardwareLEDAddr(void)           { return 0; }
int  simHardwareSwitchAddr(void)        { return 0; }
int  simHardwarePbAddr(void)            { return 0; }
void simHardwareSetMap(int k,int s,int e){ (void)k; (void)s; (void)e; }
