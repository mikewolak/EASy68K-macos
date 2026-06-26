/***************************** 68000 SIMULATOR ****************************

File Name: simhost_cli.c

Command-line implementation of the simulator host interface (simhost.h).
Provides a text console on stdin/stdout for the TRAP #15 I/O tasks and
no-op stubs for the graphics, sound, serial and network devices (those
require the GUI). The Cocoa app supplies its own full implementation.

***************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "extern.h"
#include "simhost.h"

/* ------------------------------------------------------------------ *
 *  Text console
 * ------------------------------------------------------------------ */
static void cli_textOut(const char *str)   { fputs(str, stdout); fflush(stdout); }
static void cli_textOutCR(const char *str) { fputs(str, stdout); putchar('\n'); fflush(stdout); }
static void cli_charOut(char ch)           { putchar(ch); fflush(stdout); }

static void cli_charIn(char *ch)
{
    int c = getchar();
    *ch = (c == EOF) ? 0 : (char)c;
}

// Read a line; *len = character count; if num != NULL, parse a number into it.
static void cli_textIn(char *buf, int32_t *len, int32_t *num)
{
    if (fgets(buf, 256, stdin) == NULL) { buf[0] = '\0'; }
    size_t n = strlen(buf);
    if (n > 0 && buf[n-1] == '\n') { buf[--n] = '\0'; }
    if (len) *len = (int32_t)n;
    if (num) {
        long v = 0;
        sscanf(buf, "%ld", &v);
        *num = (int32_t)v;
    }
}

static void cli_clear(void)                          { /* no terminal clear by default */ }
static void cli_gotorc(int x, int y)                 { (void)x; (void)y; }
static void cli_getrc(short *d1)                     { if (d1) *d1 = 0; }
static void cli_getCharAt(ushort r, ushort c, char *d1) { (void)r; (void)c; if (d1) *d1 = 0; }
static void cli_scrollRect(ushort r, ushort c, ushort w, ushort h, ushort dir)
                                                     { (void)r;(void)c;(void)w;(void)h;(void)dir; }
static void cli_setFontProperties(int color, int style) { (void)color; (void)style; }
static void cli_getKeyState(int32_t *d1)             { if (d1) *d1 = 0; }

/* ------------------------------------------------------------------ *
 *  Window / graphics / sound / comm / network — stubs.
 *  (The CLI has no graphical I/O window; the Cocoa app implements these.)
 * ------------------------------------------------------------------ */
static void cli_setupWindow(void) {}
static void cli_setWindowSize(unsigned short w, unsigned short h) { (void)w; (void)h; }
static void cli_getWindowSize(unsigned short *w, unsigned short *h) { if (w) *w = 0; if (h) *h = 0; }

static void cli_drawPixel(int x, int y) { (void)x;(void)y; }
static int  cli_getPixel(int x, int y)  { (void)x;(void)y; return 0; }
static void cli_line(int a,int b,int c,int d){(void)a;(void)b;(void)c;(void)d;}
static void cli_lineTo(int x,int y){(void)x;(void)y;}
static void cli_moveTo(int x,int y){(void)x;(void)y;}
static void cli_getXY(short *x, short *y){ if(x)*x=0; if(y)*y=0; }
static void cli_setLineColor(int c){(void)c;}
static void cli_setFillColor(int c){(void)c;}
static void cli_rectangle(int a,int b,int c,int d){(void)a;(void)b;(void)c;(void)d;}
static void cli_ellipse(int a,int b,int c,int d){(void)a;(void)b;(void)c;(void)d;}
static void cli_floodFill(int x,int y){(void)x;(void)y;}
static void cli_unfilledRectangle(int a,int b,int c,int d){(void)a;(void)b;(void)c;(void)d;}
static void cli_unfilledEllipse(int a,int b,int c,int d){(void)a;(void)b;(void)c;(void)d;}
static void cli_setDrawingMode(int m){(void)m;}
static void cli_setPenWidth(int w){(void)w;}
static void cli_drawText(const char *s,int x,int y){(void)s;(void)x;(void)y;}
static void cli_FormPaint(void *sender){(void)sender;}

static void cli_playSound(char *f, short *r){(void)f; if(r)*r=0;}
static void cli_loadSound(char *f, int i){(void)f;(void)i;}
static void cli_playSoundMem(int i, short *r){(void)i; if(r)*r=0;}
static void cli_controlSound(int c,int i,short *r){(void)c;(void)i; if(r)*r=0;}
static void cli_playSoundDX(char *f, short *r){(void)f; if(r)*r=0;}
static void cli_loadSoundDX(char *f,int i,short *r){(void)f;(void)i; if(r)*r=0;}
static void cli_playSoundMemDX(int i,short *r){(void)i; if(r)*r=0;}
static void cli_controlSoundDX(int c,int i,short *r){(void)c;(void)i; if(r)*r=0;}
static void cli_ResetSounds(void){}

static void cli_initComm(int c,char *p,short *r){(void)c;(void)p; if(r)*r=0;}
static void cli_setCommParams(int c,int s,short *r){(void)c;(void)s; if(r)*r=0;}
static void cli_readComm(int c,uchar *n,char *s,short *r){(void)c;(void)n;(void)s; if(r)*r=0;}
static void cli_sendComm(int c,uchar *n,char *s,short *r){(void)c;(void)n;(void)s; if(r)*r=0;}

static void cli_createNetClient(int s,char *srv,int *r){(void)s;(void)srv; if(r)*r=0;}
static void cli_createNetServer(int s,int *r){(void)s; if(r)*r=0;}
static void cli_sendNet(int s,char *d,char *ip,int *c,int *r){(void)s;(void)d;(void)ip; if(c)*c=0; if(r)*r=0;}
static void cli_receiveNet(int s,char *b,int *c,char *ip,int *r){(void)s;(void)b;(void)ip; if(c)*c=0; if(r)*r=0;}
static void cli_sendPortNet(int32_t *d0,int32_t *d1,char *d,char *ip){(void)d0;(void)d1;(void)d;(void)ip;}
static void cli_receivePortNet(int32_t *d0,int32_t *d1,char *b,char *ip){(void)d0;(void)d1;(void)b;(void)ip;}
static void cli_closeNetConnection(int c,int *r){(void)c; if(r)*r=0;}
static void cli_getLocalIP(char *ip,int *r){ if(ip) ip[0]='\0'; if(r)*r=0; }

static void cli_displayFileDialog(int32_t *m,int a1,int a2,int a3,short *r)
{ (void)m;(void)a1;(void)a2;(void)a3; if(r)*r=0; }

static SimIODevice cli_io = {
    cli_textOut, cli_textOutCR, cli_textIn, cli_charIn, cli_charOut, cli_clear,
    cli_gotorc, cli_getrc, cli_getCharAt, cli_scrollRect, cli_setFontProperties,
    cli_getKeyState,
    cli_setupWindow, cli_setWindowSize, cli_getWindowSize,
    cli_drawPixel, cli_getPixel, cli_line, cli_lineTo, cli_moveTo, cli_getXY,
    cli_setLineColor, cli_setFillColor, cli_rectangle, cli_ellipse, cli_floodFill,
    cli_unfilledRectangle, cli_unfilledEllipse, cli_setDrawingMode, cli_setPenWidth,
    cli_drawText, cli_FormPaint,
    cli_playSound, cli_loadSound, cli_playSoundMem, cli_controlSound,
    cli_playSoundDX, cli_loadSoundDX, cli_playSoundMemDX, cli_controlSoundDX,
    cli_ResetSounds,
    cli_initComm, cli_setCommParams, cli_readComm, cli_sendComm,
    cli_createNetClient, cli_createNetServer, cli_sendNet, cli_receiveNet,
    cli_sendPortNet, cli_receivePortNet, cli_closeNetConnection, cli_getLocalIP,
    cli_displayFileDialog,
    false,      // fullScreen
    NULL,       // BackBuffer
    NULL,       // Font
};

SimIODevice *simIO = &cli_io;

/* ------------------------------------------------------------------ *
 *  Form1 (main window) host operations — CLI versions.
 * ------------------------------------------------------------------ */
void simMessage(const char *msg)        { fprintf(stderr, "%s\n", msg); }
void simSetAutoTrace(bool enabled)      { (void)enabled; }
void simSetFocus(void)                  {}
void simSetMenuTrace(void)              {}
void simSetMenuActive(void)             {}
void simSetMenuTask19(void)             {}
void simRestoreMenuTask19(void)         {}
bool simLineToLog(void)                 { return true; }  // don't halt
void simUpdateDisplay(void)             {}
void simMemoryUpdate(int loc)           { (void)loc; }
void simSaveSettings(void)              {}
void simSetExceptionsEnabled(bool e)    { (void)e; }
void simProcessMessages(void)           {}
void simStopLog(void)                   {}
void simPrintChar(char ch)              { (void)ch; }   // no printer in CLI
void simPrintFormFeed(void)             {}

/* ------------------------------------------------------------------ *
 *  Hardware-simulation window — CLI stubs.
 * ------------------------------------------------------------------ */
void simHardwareEnable(void)                  {}
void simHardwareDisable(void)                 {}
void simHardwareAutoIRQoff(void)              {}
void simHardwareShow(void)                    {}
void simHardwareUpdate(int loc)               { (void)loc; }
void simHardwareSetAutoIRQ(uchar n, int iv)   { (void)n; (void)iv; }
int  simHardwareSeg7Addr(void)                { return 0; }
int  simHardwareLEDAddr(void)                 { return 0; }
int  simHardwareSwitchAddr(void)              { return 0; }
int  simHardwarePbAddr(void)                  { return 0; }
void simHardwareSetMap(int kind, int s, int e){ (void)kind; (void)s; (void)e; }

void install_cli_host(void)
{
    simIO = &cli_io;
}
