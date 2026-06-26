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
//  SimGraphicsView.h
//  EASy68K — the simulator I/O surface: a real drawing canvas that renders
//  both the TRAP #15 graphics primitives and text output, 1:1 with the
//  original EASy68K simIO window (640x480 default, 0x00BBGGRR colours,
//  double-buffered).
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimGraphicsView : NSView

// ---- window ----
- (void)setCanvasWidth:(int)w height:(int)h;   // task 33 setWindowSize
- (int)canvasWidth;
- (int)canvasHeight;
- (void)clearScreen;                            // task 11 / clear

// ---- pen / colours (0x00BBGGRR) ----
- (void)setLineColor:(uint32_t)bgr;             // task 80
- (void)setFillColor:(uint32_t)bgr;             // task 81
- (void)setPenWidth:(int)w;                     // task 93
- (void)setDrawingMode:(int)mode;               // task 92
- (void)flip;                                   // task 94 / FormPaint — present frame

// ---- primitives ----
- (void)drawPixelX:(int)x y:(int)y;             // task 82
- (uint32_t)getPixelX:(int)x y:(int)y;          // task 83
- (void)lineX1:(int)x1 y1:(int)y1 x2:(int)x2 y2:(int)y2;  // task 84
- (void)lineToX:(int)x y:(int)y;                // task 85
- (void)moveToX:(int)x y:(int)y;                // task 86
- (void)penX:(int *)x y:(int *)y;               // task 96 getXY
- (void)rectangleX1:(int)x1 y1:(int)y1 x2:(int)x2 y2:(int)y2 filled:(BOOL)filled; // 87/90
- (void)ellipseX1:(int)x1 y1:(int)y1 x2:(int)x2 y2:(int)y2 filled:(BOOL)filled;   // 88/91
- (void)floodFillX:(int)x y:(int)y;             // task 89
- (void)drawText:(NSString *)s x:(int)x y:(int)y;  // task 95

// ---- text console (TRAP print/cursor) ----
- (void)textOut:(NSString *)s newline:(BOOL)nl;
- (void)charOut:(unichar)ch;
- (void)gotoRow:(int)row col:(int)col;
- (void)getCursorRow:(int *)row col:(int *)col;
- (void)setFontColor:(uint32_t)bgr size:(int)size;

// ---- key state captured from the view (for getKeyState) ----
- (uint32_t)keyStateForCodes:(uint32_t)codes;
- (void)lastKeyUp:(int *)up down:(int *)down;

@end

NS_ASSUME_NONNULL_END
