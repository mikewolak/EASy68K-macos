//
//  SimGfxBridge.h
//  EASy68K — plain-C entry points the simulator host (SimBridge.c) calls to
//  drive the active SimGraphicsView. Implemented in SimGfxBridge.m (ObjC).
//  Kept free of Cocoa AND of the sim core's def.h so both sides can include it.
//
#ifndef SIMGFXBRIDGE_H
#define SIMGFXBRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void     gfx_setActiveView(void *view);   // SimController registers the view

// colours / pen
void     gfx_setLineColor(uint32_t bgr);
void     gfx_setFillColor(uint32_t bgr);
void     gfx_setPenWidth(int w);
void     gfx_setPenMode(int mode);
// primitives
void     gfx_drawPixel(int x, int y);
uint32_t gfx_getPixel(int x, int y);
void     gfx_line(int x1, int y1, int x2, int y2);
void     gfx_lineTo(int x, int y);
void     gfx_moveTo(int x, int y);
void     gfx_getXY(int *x, int *y);
void     gfx_rect(int x1, int y1, int x2, int y2, int filled);
void     gfx_ellipse(int x1, int y1, int x2, int y2, int filled);
void     gfx_floodFill(int x, int y);
void     gfx_drawText(const char *s, int x, int y);
// window
void     gfx_setWindowSize(int w, int h);
void     gfx_getWindowSize(int *w, int *h);
void     gfx_clear(void);
void     gfx_present(void);                // task 94 / FormPaint — flip back->front
// text console
void     gfx_textOut(const char *s, int withNewline);
void     gfx_charOut(char c);
void     gfx_gotorc(int row, int col);
void     gfx_getrc(int *row, int *col);
void     gfx_setFont(uint32_t bgr, int size);
// keyboard
uint32_t gfx_getKeyState(uint32_t codes);

#ifdef __cplusplus
}
#endif

#endif
