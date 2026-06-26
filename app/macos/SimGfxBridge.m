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
//  SimGfxBridge.m
//  EASy68K — routes the C gfx_* calls to the active SimGraphicsView.
//
#import "SimGfxBridge.h"
#import "SimGraphicsView.h"

static SimGraphicsView *gView;   // the simulator's I/O surface

void gfx_setActiveView(void *view) { gView = (__bridge SimGraphicsView *)view; }

#define V if (!gView) return; SimGraphicsView *v = gView

void gfx_setLineColor(uint32_t bgr){ V; [v setLineColor:bgr]; }
void gfx_setFillColor(uint32_t bgr){ V; [v setFillColor:bgr]; }
void gfx_setPenWidth(int w){ V; [v setPenWidth:w]; }
void gfx_setPenMode(int m){ V; [v setDrawingMode:m]; }

void gfx_drawPixel(int x,int y){ V; [v drawPixelX:x y:y]; }
uint32_t gfx_getPixel(int x,int y){ if(!gView) return 0; return [gView getPixelX:x y:y]; }
void gfx_line(int x1,int y1,int x2,int y2){ V; [v lineX1:x1 y1:y1 x2:x2 y2:y2]; }
void gfx_lineTo(int x,int y){ V; [v lineToX:x y:y]; }
void gfx_moveTo(int x,int y){ V; [v moveToX:x y:y]; }
void gfx_getXY(int *x,int *y){ if(!gView){ if(x)*x=0; if(y)*y=0; return;} [gView penX:x y:y]; }
void gfx_rect(int x1,int y1,int x2,int y2,int f){ V; [v rectangleX1:x1 y1:y1 x2:x2 y2:y2 filled:(f!=0)]; }
void gfx_ellipse(int x1,int y1,int x2,int y2,int f){ V; [v ellipseX1:x1 y1:y1 x2:x2 y2:y2 filled:(f!=0)]; }
void gfx_floodFill(int x,int y){ V; [v floodFillX:x y:y]; }
void gfx_drawText(const char *s,int x,int y){ V; [v drawText:[NSString stringWithUTF8String:s?:""] x:x y:y]; }

void gfx_setWindowSize(int w,int h){ V; [v setCanvasWidth:w height:h]; }
void gfx_getWindowSize(int *w,int *h){ if(!gView){ if(w)*w=0; if(h)*h=0; return;} if(w)*w=[gView canvasWidth]; if(h)*h=[gView canvasHeight]; }
void gfx_clear(void){ V; [v clearScreen]; }
void gfx_present(void){ V; [v flip]; }

void gfx_textOut(const char *s,int nl){ V; [v textOut:[NSString stringWithUTF8String:s?:""] newline:(nl!=0)]; }
void gfx_charOut(char c){ V; [v charOut:(unichar)(unsigned char)c]; }
void gfx_gotorc(int row,int col){ V; [v gotoRow:row col:col]; }
void gfx_getrc(int *row,int *col){ if(!gView){ if(row)*row=0; if(col)*col=0; return;} [gView getCursorRow:row col:col]; }
void gfx_setFont(uint32_t bgr,int size){ V; [v setFontColor:bgr size:size]; }
uint32_t gfx_getKeyState(uint32_t codes){ if(!gView) return 0; return [gView keyStateForCodes:codes]; }
