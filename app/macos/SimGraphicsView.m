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
//  SimGraphicsView.m
//  EASy68K — simulator I/O drawing surface (CoreGraphics backbuffer).
//
#import "SimGraphicsView.h"
#import <CoreText/CoreText.h>
#import <CoreVideo/CoreVideo.h>

#define MIN_W 640
#define MIN_H 480

@implementation SimGraphicsView {
    CGContextRef _ctx;          // backbuffer (top-left origin, y down)
    int _w, _h;
    NSLock *_lock;

    // pen / colour state
    CGColorRef _lineColor, _fillColor;
    uint32_t _lineBGR, _fillBGR;
    CGFloat _penWidth;
    int _penMode;
    CGFloat _penX, _penY;

    // text console state
    CGFloat _charW, _charH;     // monospaced cell metrics
    int _textCol, _textRow;     // cursor (cells)
    uint32_t _fontBGR;
    CGFloat _fontSize;
    CTFontRef _font;

    // keyboard
    uint8_t _keyDown[256];
    int _lastKeyUp, _lastKeyDown;

    // double buffering + 60 FPS vsync-locked presentation
    CVDisplayLinkRef _displayLink;
    CGImageRef _frontImage;     // the last completed (presented) frame
    BOOL _doubleBuffer;         // task 92 mode 17 on / 16 off
    BOOL _backDirty;            // back buffer changed since last present
    uint64_t _presentSerial;    // bumped on each flip
    uint64_t _shownSerial;      // last serial pushed to the view
    NSCondition *_vsyncCond;    // signalled by the display link each refresh
    uint64_t _vsyncCount;       // bumped on every vsyncTick (frame-lock handshake)
    int _ticksPerFrame;         // vsyncs per presented frame (caps to ~60 FPS)
}

static CVReturn simDisplayLinkCB(CVDisplayLinkRef dl, const CVTimeStamp *now,
                                 const CVTimeStamp *out, CVOptionFlags flags,
                                 CVOptionFlags *flagsOut, void *ctx) {
    (void)dl;(void)now;(void)out;(void)flags;(void)flagsOut;
    [(__bridge SimGraphicsView *)ctx vsyncTick];
    return kCVReturnSuccess;
}

static CGColorRef bgrColor(uint32_t c) {
    CGFloat r = (c & 0xFF)/255.0, g = ((c>>8)&0xFF)/255.0, b = ((c>>16)&0xFF)/255.0;
    return CGColorCreateGenericRGB(r, g, b, 1.0);
}

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _lock = [NSLock new];
        _w = MIN_W; _h = MIN_H;
        _lineBGR = 0xFFFFFF; _fillBGR = 0x000000; _fontBGR = 0xFFFFFF;
        _penWidth = 1; _penMode = 13; _fontSize = 16;
        _doubleBuffer = NO;
        _vsyncCond = [NSCondition new];
        [self rebuildContext];

        // vsync-locked 60 FPS presentation: the sim thread draws into the back
        // buffer and flips (FormPaint) to a stable front frame; the display
        // link pushes only complete frames to the screen at the refresh rate.
        if (CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink) == kCVReturnSuccess) {
            CVDisplayLinkSetOutputCallback(_displayLink, simDisplayLinkCB, (__bridge void *)self);
            CVDisplayLinkStart(_displayLink);
        }
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_displayLink) { CVDisplayLinkStop(_displayLink); CVDisplayLinkRelease(_displayLink); }
    if (_frontImage) CGImageRelease(_frontImage);
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

// Fill the enclosing clip view so the canvas spans the whole window (and the
// whole screen in full-screen); drawRect then aspect-scales the bitmap into it.
- (void)viewDidMoveToSuperview {
    [super viewDidMoveToSuperview];
    NSView *clip = self.superview;
    if (clip) {
        clip.postsFrameChangedNotifications = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fitToClip)
                                                     name:NSViewFrameDidChangeNotification object:clip];
        [self fitToClip];
    }
}
- (void)fitToClip {
    NSView *clip = self.superview;
    if (clip && !NSEqualSizes(self.frame.size, clip.bounds.size)) {
        [self setFrame:clip.bounds];
        self.needsDisplay = YES;
    }
}

- (void)rebuildContext {
    if (_ctx) { CGContextRelease(_ctx); _ctx = NULL; }
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    _ctx = CGBitmapContextCreate(NULL, _w, _h, 8, _w*4, cs,
                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    // top-left origin (y increases downward)
    CGContextTranslateCTM(_ctx, 0, _h);
    CGContextScaleCTM(_ctx, 1, -1);

    if (_lineColor) CGColorRelease(_lineColor);
    if (_fillColor) CGColorRelease(_fillColor);
    _lineColor = bgrColor(_lineBGR);
    _fillColor = bgrColor(_fillBGR);

    if (_font) CFRelease(_font);
    _font = CTFontCreateWithName(CFSTR("Menlo"), _fontSize, NULL);
    _charW = CTFontGetAdvancesForGlyphs(_font, kCTFontOrientationHorizontal, NULL, NULL, 0); // placeholder
    // measure a monospaced cell using 'M'
    [self measureCell];
    _textCol = 0; _textRow = 0;

    // clear to black
    CGContextSetFillColorWithColor(_ctx, _fillColor);
    CGContextFillRect(_ctx, CGRectMake(0,0,_w,_h));
}

- (void)measureCell {
    UniChar ch = 'M'; CGGlyph g; CGSize adv;
    CTFontGetGlyphsForCharacters(_font, &ch, &g, 1);
    CTFontGetAdvancesForGlyphs(_font, kCTFontOrientationHorizontal, &g, &adv, 1);
    _charW = adv.width > 0 ? adv.width : _fontSize*0.6;
    _charH = CTFontGetAscent(_font) + CTFontGetDescent(_font) + CTFontGetLeading(_font);
    if (_charH < 1) _charH = _fontSize*1.2;
}

#pragma mark Window

- (void)setCanvasWidth:(int)w height:(int)h {
    [_lock lock];
    _w = MAX(w, MIN_W); _h = MAX(h, MIN_H);
    [self rebuildContext];
    [_lock unlock];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self fitToClip];           // keep filling the window; drawRect aspect-scales
        self.needsDisplay = YES;
    });
}
- (int)canvasWidth  { return _w; }
- (int)canvasHeight { return _h; }

- (void)clearScreen {
    [_lock lock];
    CGContextSetFillColorWithColor(_ctx, _fillColor);
    CGContextFillRect(_ctx, CGRectMake(0,0,_w,_h));
    _textCol = 0; _textRow = 0;
    [_lock unlock];
    [self markDirty];
}

#pragma mark Pen / colours

- (void)setLineColor:(uint32_t)bgr { [_lock lock]; _lineBGR=bgr; if(_lineColor)CGColorRelease(_lineColor); _lineColor=bgrColor(bgr); [_lock unlock]; }
- (void)setFillColor:(uint32_t)bgr { [_lock lock]; _fillBGR=bgr; if(_fillColor)CGColorRelease(_fillColor); _fillColor=bgrColor(bgr); [_lock unlock]; }
- (void)setPenWidth:(int)w { [_lock lock]; _penWidth = MAX(1,w); [_lock unlock]; }
- (void)setDrawingMode:(int)mode {
    int m = mode & 0xFF;
    if (m == 16)      { _doubleBuffer = NO; [self flip]; }  // disable + flush
    else if (m == 17) { _doubleBuffer = YES; }              // enable double buffering
    else              { _penMode = m; }                     // pen blend mode
}

- (void)applyPenMode {
    // XOR-style modes -> difference blend; everything else normal copy.
    CGContextSetBlendMode(_ctx, (_penMode == 7 || _penMode == 6) ? kCGBlendModeDifference : kCGBlendModeNormal);
}

#pragma mark Primitives

- (void)drawPixelX:(int)x y:(int)y {
    [_lock lock]; [self applyPenMode];
    CGContextSetFillColorWithColor(_ctx, _lineColor);
    CGContextFillRect(_ctx, CGRectMake(x, y, 1, 1));
    [_lock unlock]; [self markDirty];
}

- (uint32_t)getPixelX:(int)x y:(int)y {
    [_lock lock];
    uint32_t result = 0;
    unsigned char *data = CGBitmapContextGetData(_ctx);
    if (data && x>=0 && y>=0 && x<_w && y<_h) {
        // The context's flip transform makes a draw at 68000 (x,y) land in
        // memory row y (row 0 = top scanline), so read row y directly.
        size_t bpr = CGBitmapContextGetBytesPerRow(_ctx);
        unsigned char *px = data + (size_t)y*bpr + (size_t)x*4;
        result = ((uint32_t)px[2]<<16) | ((uint32_t)px[1]<<8) | px[0]; // 0x00BBGGRR
    }
    [_lock unlock];
    return result;
}

- (void)strokeLineFrom:(CGPoint)a to:(CGPoint)b {
    [self applyPenMode];
    CGContextSetStrokeColorWithColor(_ctx, _lineColor);
    CGContextSetLineWidth(_ctx, _penWidth);
    CGContextSetLineCap(_ctx, kCGLineCapRound);
    CGContextBeginPath(_ctx);
    CGContextMoveToPoint(_ctx, a.x+0.5, a.y+0.5);
    CGContextAddLineToPoint(_ctx, b.x+0.5, b.y+0.5);
    CGContextStrokePath(_ctx);
}

- (void)lineX1:(int)x1 y1:(int)y1 x2:(int)x2 y2:(int)y2 {
    [_lock lock];
    [self strokeLineFrom:CGPointMake(x1,y1) to:CGPointMake(x2,y2)];
    _penX = x2; _penY = y2;
    [_lock unlock]; [self markDirty];
}
- (void)lineToX:(int)x y:(int)y {
    [_lock lock];
    [self strokeLineFrom:CGPointMake(_penX,_penY) to:CGPointMake(x,y)];
    _penX = x; _penY = y;
    [_lock unlock]; [self markDirty];
}
- (void)moveToX:(int)x y:(int)y { [_lock lock]; _penX=x; _penY=y; [_lock unlock]; }
- (void)penX:(int *)x y:(int *)y { if(x)*x=(int)_penX; if(y)*y=(int)_penY; }

- (void)rectangleX1:(int)x1 y1:(int)y1 x2:(int)x2 y2:(int)y2 filled:(BOOL)filled {
    [_lock lock]; [self applyPenMode];
    CGRect r = CGRectMake(MIN(x1,x2), MIN(y1,y2), ABS(x2-x1), ABS(y2-y1));
    if (filled) {
        CGContextSetFillColorWithColor(_ctx, _fillColor);
        CGContextFillRect(_ctx, r);
    }
    CGContextSetStrokeColorWithColor(_ctx, _lineColor);
    CGContextSetLineWidth(_ctx, _penWidth);
    CGContextStrokeRect(_ctx, CGRectInset(r, 0.5, 0.5));
    [_lock unlock]; [self markDirty];
}

- (void)ellipseX1:(int)x1 y1:(int)y1 x2:(int)x2 y2:(int)y2 filled:(BOOL)filled {
    [_lock lock]; [self applyPenMode];
    CGRect r = CGRectMake(MIN(x1,x2), MIN(y1,y2), ABS(x2-x1), ABS(y2-y1));
    if (filled) {
        CGContextSetFillColorWithColor(_ctx, _fillColor);
        CGContextFillEllipseInRect(_ctx, r);
    }
    CGContextSetStrokeColorWithColor(_ctx, _lineColor);
    CGContextSetLineWidth(_ctx, _penWidth);
    CGContextStrokeEllipseInRect(_ctx, CGRectInset(r, 0.5, 0.5));
    [_lock unlock]; [self markDirty];
}

- (void)floodFillX:(int)x y:(int)y {
    // Scanline flood fill of the contiguous region matching the seed colour,
    // replaced with the current fill colour. Operates on the raw bitmap.
    [_lock lock];
    unsigned char *data = CGBitmapContextGetData(_ctx);
    size_t bpr = CGBitmapContextGetBytesPerRow(_ctx);
    if (data && x>=0 && y>=0 && x<_w && y<_h) {
        #define PX(xx,yy) (data + (size_t)(yy)*bpr + (size_t)(xx)*4)  // row 0 = top
        unsigned char *seed = PX(x,y);
        unsigned char sr=seed[0], sg=seed[1], sb=seed[2];
        unsigned char fr=_fillBGR&0xFF, fg=(_fillBGR>>8)&0xFF, fb=(_fillBGR>>16)&0xFF;
        if (!(sr==fr && sg==fg && sb==fb)) {
            int cap = _w*_h, top=0;
            int *stack = malloc(sizeof(int)*2*cap);
            stack[top++]=x; stack[top++]=y;
            while (top>0) {
                int cy=stack[--top], cx=stack[--top];
                if (cx<0||cy<0||cx>=_w||cy>=_h) continue;
                unsigned char *p=PX(cx,cy);
                if (!(p[0]==sr&&p[1]==sg&&p[2]==sb)) continue;
                p[0]=fr; p[1]=fg; p[2]=fb; p[3]=0xFF;
                if (top < 2*cap-8) {
                    stack[top++]=cx+1; stack[top++]=cy;
                    stack[top++]=cx-1; stack[top++]=cy;
                    stack[top++]=cx;   stack[top++]=cy+1;
                    stack[top++]=cx;   stack[top++]=cy-1;
                }
            }
            free(stack);
        }
        #undef PX
    }
    [_lock unlock]; [self markDirty];
}

- (void)drawString:(NSString *)s atX:(CGFloat)x y:(CGFloat)y color:(CGColorRef)color {
    NSDictionary *attrs = @{ (id)kCTFontAttributeName: (__bridge id)_font,
                             (id)kCTForegroundColorAttributeName: (__bridge id)color };
    CFAttributedStringRef as = CFAttributedStringCreate(NULL, (__bridge CFStringRef)s,
                                  (__bridge CFDictionaryRef)attrs);
    CTLineRef line = CTLineCreateWithAttributedString(as);
    CGContextSaveGState(_ctx);
    CGContextSetTextMatrix(_ctx, CGAffineTransformMakeScale(1,-1)); // text upright in flipped ctx
    CGContextSetTextPosition(_ctx, x, y + CTFontGetAscent(_font));
    CTLineDraw(line, _ctx);
    CGContextRestoreGState(_ctx);
    CFRelease(line); CFRelease(as);
}

- (void)drawText:(NSString *)s x:(int)x y:(int)y {
    [_lock lock];
    [self drawString:s atX:x y:y color:_lineColor];
    [_lock unlock]; [self markDirty];
}

#pragma mark Text console

- (void)scrollIfNeeded {
    int rows = (int)(_h / _charH);
    if (_textRow >= rows) {
        // scroll up one line: row 0 is the top scanline, so shift rows
        // [dy,_h) up to [0,_h-dy) and clear the newly-exposed bottom rows.
        unsigned char *data = CGBitmapContextGetData(_ctx);
        size_t bpr = CGBitmapContextGetBytesPerRow(_ctx);
        int dy = (int)_charH;
        memmove(data, data + (size_t)dy*bpr, (size_t)(_h-dy)*bpr);
        unsigned char fr=_fillBGR&0xFF, fg=(_fillBGR>>8)&0xFF, fb=(_fillBGR>>16)&0xFF;
        for (int yy=_h-dy; yy<_h; yy++) {
            unsigned char *row = data + (size_t)yy*bpr;
            for (int xx=0; xx<_w; xx++){ row[xx*4]=fr; row[xx*4+1]=fg; row[xx*4+2]=fb; row[xx*4+3]=0xFF; }
        }
        _textRow--;
    }
}

- (void)putChar:(unichar)ch {
    if (ch == '\n' || ch == '\r') { _textCol = 0; if (ch=='\n'){ _textRow++; [self scrollIfNeeded]; } return; }
    if (ch == '\t') { _textCol = (_textCol/8 + 1)*8; return; }
    CGFloat x = _textCol * _charW, y = _textRow * _charH;
    CGColorRef col = bgrColor(_fontBGR);
    // erase cell then draw
    CGContextSetFillColorWithColor(_ctx, _fillColor);
    CGContextFillRect(_ctx, CGRectMake(x, y, _charW, _charH));
    [self drawString:[NSString stringWithCharacters:&ch length:1] atX:x y:y color:col];
    CGColorRelease(col);
    _textCol++;
    if (_textCol * _charW + _charW > _w) { _textCol = 0; _textRow++; [self scrollIfNeeded]; }
}

- (void)textOut:(NSString *)s newline:(BOOL)nl {
    [_lock lock];
    for (NSUInteger i=0;i<s.length;i++) [self putChar:[s characterAtIndex:i]];
    if (nl) [self putChar:'\n'];
    [_lock unlock]; [self markDirty];
}
- (void)charOut:(unichar)ch { [_lock lock]; [self putChar:ch]; [_lock unlock]; [self markDirty]; }
- (void)gotoRow:(int)row col:(int)col { [_lock lock]; _textRow=row; _textCol=col; [_lock unlock]; }
- (void)getCursorRow:(int *)row col:(int *)col { if(row)*row=_textRow; if(col)*col=_textCol; }
- (void)setFontColor:(uint32_t)bgr size:(int)size {
    [_lock lock];
    _fontBGR = bgr;
    if (size > 0) { _fontSize = size; if(_font)CFRelease(_font); _font=CTFontCreateWithName(CFSTR("Menlo"),_fontSize,NULL); [self measureCell]; }
    [_lock unlock];
}

#pragma mark Keyboard

// EASy68K's keyboard model (TRAP #15 task 19) indexes a keys[256] array by
// Windows Virtual-Key code -- that is the general contract every program uses,
// so we translate macOS key events to the corresponding Win32 VK code. Letters
// map to their uppercase ASCII (== VK_A..VK_Z), digits to ASCII, and the
// navigation/function/control keys to their VK_* values.
static int macCharToVK(unichar c) {
    if (c >= 'a' && c <= 'z') return c - ('a' - 'A');        // VK_A..VK_Z
    if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) return c;
    switch (c) {
        case ' ':                 return 0x20;  // VK_SPACE
        case '\r': case 0x03:     return 0x0D;  // VK_RETURN
        case '\t':                return 0x09;  // VK_TAB
        case 0x1B:                return 0x1B;  // VK_ESCAPE
        case 0x7F: case 0x08:     return 0x08;  // VK_BACK
        case NSLeftArrowFunctionKey:  return 0x25;  // VK_LEFT
        case NSUpArrowFunctionKey:    return 0x26;  // VK_UP
        case NSRightArrowFunctionKey: return 0x27;  // VK_RIGHT
        case NSDownArrowFunctionKey:  return 0x28;  // VK_DOWN
        case NSHomeFunctionKey:       return 0x24;  // VK_HOME
        case NSEndFunctionKey:        return 0x23;  // VK_END
        case NSPageUpFunctionKey:     return 0x21;  // VK_PRIOR
        case NSPageDownFunctionKey:   return 0x22;  // VK_NEXT
        case NSInsertFunctionKey:     return 0x2D;  // VK_INSERT
        case NSDeleteFunctionKey:     return 0x2E;  // VK_DELETE
    }
    if (c >= NSF1FunctionKey && c <= NSF1FunctionKey + 23)
        return 0x70 + (int)(c - NSF1FunctionKey);   // VK_F1..VK_F24
    if (c < 0x80) return (int)c;                     // punctuation fallback
    return 0;
}

- (void)keyDown:(NSEvent *)e {
    NSString *chars = e.charactersIgnoringModifiers;
    if (chars.length) {
        int vk = macCharToVK([chars characterAtIndex:0]);
        if (vk > 0 && vk < 256) { _keyDown[vk] = 1; _lastKeyDown = vk; }
    }
}
- (void)keyUp:(NSEvent *)e {
    NSString *chars = e.charactersIgnoringModifiers;
    if (chars.length) {
        int vk = macCharToVK([chars characterAtIndex:0]);
        if (vk > 0 && vk < 256) { _keyDown[vk] = 0; _lastKeyUp = vk; }
    }
}
// Modifier keys arrive via flagsChanged, not keyDown/keyUp.
- (void)flagsChanged:(NSEvent *)e {
    NSEventModifierFlags f = e.modifierFlags;
    _keyDown[0x10] = (f & NSEventModifierFlagShift)   ? 1 : 0;  // VK_SHIFT
    _keyDown[0x11] = (f & NSEventModifierFlagControl) ? 1 : 0;  // VK_CONTROL
    _keyDown[0x12] = (f & NSEventModifierFlagOption)  ? 1 : 0;  // VK_MENU (Alt)
}

- (uint32_t)keyStateForCodes:(uint32_t)codes {
    // Faithful to TRAP task 19: if codes==0, return (lastUp<<16)|lastDown;
    // otherwise each of the 4 code bytes -> 0xFF in its position if that key
    // is currently down.
    if (codes == 0)
        return (uint32_t)(((_lastKeyUp & 0xFF) << 16) | (_lastKeyDown & 0xFF));
    uint32_t out = 0;
    for (int i = 0; i < 4; i++) {
        uint8_t k = (codes >> (i*8)) & 0xFF;
        if (_keyDown[k]) out |= (0xFFu << (i*8));
    }
    return out;
}
- (void)lastKeyUp:(int *)up down:(int *)down { if(up)*up=_lastKeyUp; if(down)*down=_lastKeyDown; }

#pragma mark Display — double buffered, 60 FPS vsync locked

// Drawing primitives only mark the back buffer dirty; nothing reaches the
// screen until a flip (FormPaint, or the display link in immediate mode).
- (void)markDirty { _backDirty = YES; }

// Snapshot the back buffer into the stable front frame (the "flip").
- (void)snapshotLocked {
    if (_frontImage) CGImageRelease(_frontImage);
    _frontImage = CGBitmapContextCreateImage(_ctx);
    _presentSerial++;
    _backDirty = NO;
}

// TRAP #15 task 94 / FormPaint — present the completed frame.
// When double-buffered, this blocks the (background) sim thread until the
// display link presents the next refresh, frame-locking the program to the
// screen's refresh rate (swap-on-vsync semantics).  A short timeout keeps it
// from hanging if the link is stalled (window hidden, run stopped, etc.).
- (void)flip {
    [_lock lock]; [self snapshotLocked]; BOOL db = _doubleBuffer; [_lock unlock];
    if (db) {
        // Present at ~60 FPS: on a high-refresh panel (e.g. 120 Hz ProMotion)
        // wait two vsyncs per frame, on a 60 Hz panel wait one.
        if (_ticksPerFrame == 0) {
            double p = _displayLink ? CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink) : 0;
            double hz = (p > 0) ? 1.0/p : 60.0;
            _ticksPerFrame = (int)lround(hz/60.0);
            if (_ticksPerFrame < 1) _ticksPerFrame = 1;
        }
        [_vsyncCond lock];
        uint64_t target = _vsyncCount + _ticksPerFrame;
        while (_vsyncCount < target) {
            if (![_vsyncCond waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]])
                break;                                  // vsync timed out -> don't stall
        }
        [_vsyncCond unlock];
    }
}

// Called from the CVDisplayLink at the display refresh rate (~60 Hz).
- (void)vsyncTick {
    [_lock lock];
    // In immediate (non-double-buffered) mode, auto-flip dirty back buffer so
    // console text and direct drawing appear without an explicit FormPaint.
    if (!_doubleBuffer && _backDirty) [self snapshotLocked];
    BOOL haveNew = (_presentSerial != _shownSerial);
    _shownSerial = _presentSerial;
    [_lock unlock];
    // release any sim thread blocked in flip() — one tick = one frame
    [_vsyncCond lock]; _vsyncCount++; [_vsyncCond broadcast]; [_vsyncCond unlock];
    if (haveNew)
        dispatch_async(dispatch_get_main_queue(), ^{ self.needsDisplay = YES; });
}

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    NSRect b = self.bounds;
    [_lock lock];
    CGImageRef img = _frontImage ? CGImageRetain(_frontImage) : NULL;
    double cw = _w, ch = _h;
    [_lock unlock];

    // Black letterbox/pillarbox fill behind the (aspect-scaled) canvas.
    [[NSColor blackColor] setFill];
    NSRectFill(b);
    if (!img) return;

    CGContextRef c = NSGraphicsContext.currentContext.CGContext;
    // Scale the canvas to the largest size that fits the view while keeping its
    // exact aspect ratio, then centre it (so full-screen pillar/letter-boxes).
    double scale = MIN(b.size.width / cw, b.size.height / ch);
    if (scale <= 0) scale = 1;
    double dw = cw * scale, dh = ch * scale;
    double ox = (b.size.width  - dw) * 0.5;
    double oy = (b.size.height - dh) * 0.5;

    // The view is flipped (top-left origin) but the bitmap's row 0 is the top
    // scanline; flip the CTM within the destination rect so it blits upright.
    CGContextSaveGState(c);
    CGContextSetInterpolationQuality(c, kCGInterpolationNone);   // crisp pixels
    CGContextTranslateCTM(c, ox, oy + dh);
    CGContextScaleCTM(c, 1, -1);
    CGContextDrawImage(c, CGRectMake(0, 0, dw, dh), img);
    CGContextRestoreGState(c);
    CGImageRelease(img);
}

@end
