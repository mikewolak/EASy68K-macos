# Gravity Wave 3D demo generator
# Copyright (c) 2026 mikewolak@gmail.com, Epromfoundry, Inc.
import math

# ---------------- tunables ----------------
GRID  = 45
A     = 0.60        # camera azimuth
E     = 0.95        # camera elevation (top-down enough to read the spiral)
SCALE = 3.6         # px per data unit
VZ    = 9.0         # base vertical amplitude
LIFT  = 14          # px the bodies hover above the sheet centre
MASSRAD = 9
NINS   = 300        # inspiral frames (paced by the 60 FPS vsync frame-lock)
NMERGE = 54         # merge / ringdown frames
NTOT   = NINS + NMERGE
A0, AEND = 40.0, 5.0   # orbital separation start/end (data units)
DPHI_CAP = 9           # max orbital advance per frame (256ths)
CHIRP_K  = 1.0         # orbital-rate scale (dphi at A0 ~ CHIRP_K)

cosA, sinA = math.cos(A), math.sin(A)
cosE, sinE = math.cos(E), math.sin(E)

def coord(i): return -45.0 + 90.0 * i / (GRID - 1)

# ---- surface node tables ----
dx=[]; dy=[]; phase=[]; ampf=[]
for i in range(GRID):
    x = coord(i)
    for j in range(GRID):
        y = coord(j)
        r = math.hypot(x, y); a = math.atan2(y, x)
        phase.append(round((2*a + 0.544331*r) * 256/(2*math.pi)) % 256)
        ampf.append(round(60.0*VZ*cosE/(20.0+r) * 256))      # Q8
        u = x*cosA - y*sinA; v = x*sinA + y*cosA
        dx.append(round(SCALE*u)); dy.append(round(SCALE*v*sinE))

# ---- inspiral / merge keyframe tables (length NTOT) ----
INR=[]; IND=[]; ING=[]; RINGR=[]
Kchirp = CHIRP_K * (A0**1.5)    # so dphi(A0) ~ CHIRP_K
for k in range(NTOT):
    if k < NINS:
        t = (NINS-1-k)/(NINS-1)         # 1 -> 0
        a = AEND + (A0-AEND)*math.sqrt(t)
        dphi = min(DPHI_CAP, Kchirp * a**-1.5)
        gain = 1.0 + 1.5*(1.0 - (a-AEND)/(A0-AEND))      # 1.0 -> 2.5
        INR.append(round(a)); IND.append(round(dphi*256))
        ING.append(round(gain*256)); RINGR.append(0)
    else:
        mf = k - NINS
        f = mf/(NMERGE-1)               # 0 -> 1
        INR.append(0)
        IND.append(round(DPHI_CAP*256)) # fast ringdown spin
        ING.append(round((2.5*(1.0-f) + 0.2)*256))       # decay
        RINGR.append(round(8 + f*230))  # expanding burst ring (px)

# ---- projection constants for the orbiting bodies (Q12) ----
PXC = round(SCALE*cosA*4096); PXS = round(SCALE*sinA*4096)
PYC = round(SCALE*sinA*sinE*4096); PYS = round(SCALE*cosA*sinE*4096)

# ---- Q14 sine ----
sv=[max(-32768,min(32767,round(16384*math.sin(2*math.pi*i/256)))) for i in range(256)]

def emit(name, arr, p=12):
    o=[name]
    for k in range(0,len(arr),p):
        o.append("        DC.W    "+",".join(str(v) for v in arr[k:k+p]))
    return "\n".join(o)

print(f"GRID={GRID} nodes={GRID*GRID} lines/frame={2*GRID*(GRID-1)} "
      f"samples/wave={ (2*math.pi/0.544331)*SCALE / (SCALE*90/(GRID-1)):.1f} "
      f"ampFmax={max(ampf)} dphi[0]={IND[0]/256:.2f} dphi[end]={IND[NINS-1]/256:.2f}")

CODE = f'''*-----------------------------------------------------------
* Title      : Gravity Wave  -  binary inspiral (LIGO) demo
* Copyright  : (c) 2026 mikewolak@gmail.com, Epromfoundry, Inc.
* Written by : EASy68K for macOS  (mikewolak@gmail.com)
* Description: Two solid bodies spiral inward (a binary black-hole
*              inspiral) and their orbital motion radiates the
*              "gravity wave" - a rippling green wireframe sheet.
*
*   sheet:  z = 60 * cos( 2*atan2(y,x) - THETA + 0.544331*r ) / (20+r)
*           r = sqrt(x*x+y*y),  x,y in [-45,45]
*           (the surface from community.wolfram.com/groups/-/m/t/790989)
*
*   physics handled here:
*     - the two bodies orbit at radius R(t), 180 deg apart
*     - THETA = 2 * orbital phase   (the quadrupole / m=2 relation:
*       the GW phase is twice the orbital phase, so the two spiral
*       arms stay locked to the two bodies)
*     - chirp: R shrinks and the orbital rate climbs toward merger
*     - wave amplitude grows as the bodies inspiral
*     - merger: bodies coalesce, a bright ring-down burst expands, loop
*
* All trig / sqrt / atan2 / division and the camera projection are
* baked into DC.W tables at build time.  Per-frame the 68000 only
* shifts a phase, scales by a gain, and draws lines + two ellipses.
*-----------------------------------------------------------
        ORG     $1000

GRID    EQU     {GRID}
NODES   EQU     GRID*GRID
NINS    EQU     {NINS}
NTOT    EQU     {NTOT}
LIFT    EQU     {LIFT}
MASSRAD EQU     {MASSRAD}
GREEN   EQU     $0000FF00
WHITE   EQU     $00FFFFFF
GOLD    EQU     $0040C0FF

START
* ---- double buffering on ----
        moveq   #17,d1
        moveq   #92,d0
        trap    #15
* ---- canvas size + centre ----
        clr.l   d1
        moveq   #33,d0
        trap    #15
        move.w  d1,SCRH
        swap    d1
        move.w  d1,SCRW
        move.w  SCRW,d0
        lsr.w   #1,d0
        move.w  d0,CX
        move.w  SCRH,d0
        lsr.w   #1,d0
        move.w  d0,CY
* ---- bake centre into the node screen offsets (one time) ----
        lea     DXOFF,a0
        lea     DYOFF,a1
        move.w  CX,d2
        move.w  CY,d3
        move.w  #NODES,d6
CENTLP  add.w   d2,(a0)+
        add.w   d3,(a1)+
        subq.w  #1,d6
        bne     CENTLP

        clr.w   PHI
        clr.w   FRAMEIDX

*===========================================================
FRAME
* ---- per-frame keyframe state ----
        move.w  FRAMEIDX,d0
        add.w   d0,d0
        lea     INR,a0
        move.w  (a0,d0.w),RCUR
        lea     ING,a1
        move.w  (a1,d0.w),GAINCUR
* ANGcur = (PHI>>8) & 255 ;  THETA = (2*ANGcur)&255
        move.w  PHI,d0
        lsr.w   #8,d0
        and.w   #$FF,d0
        move.w  d0,ANGCUR
        add.w   d0,d0
        and.w   #$FF,d0
        move.w  d0,THETA

* ---- 1. surface height pass: PY = DYOFF - (z*gain) ----
        lea     PHASE,a0
        lea     AMPF,a1
        lea     DYOFF,a2
        lea     PY,a3
        lea     SINTAB,a5
        move.w  THETA,d7
        move.w  GAINCUR,d5
        move.w  #NODES,d6
NLOOP   move.w  (a0)+,d0
        sub.w   d7,d0
        add.w   #64,d0
        and.w   #$FF,d0
        add.w   d0,d0
        move.w  (a5,d0.w),d1        cosVal Q14
        move.w  (a1)+,d0            AMPF   Q8
        muls    d1,d0
        moveq   #22,d2
        asr.l   d2,d0               z = (AMPF*cos)>>22
        muls    d5,d0               z * gain(Q8)
        asr.l   #8,d0
        move.w  (a2)+,d1
        sub.w   d0,d1
        move.w  d1,(a3)+
        subq.w  #1,d6
        bne     NLOOP

* ---- 2. clear offscreen ----
        moveq   #0,d1
        moveq   #81,d0
        trap    #15
        moveq   #0,d1
        moveq   #80,d0
        trap    #15
        moveq   #0,d1
        moveq   #0,d2
        move.w  SCRW,d3
        move.w  SCRH,d4
        moveq   #87,d0
        trap    #15

* ---- 3. draw green wireframe mesh ----
        move.l  #GREEN,d1
        moveq   #80,d0
        trap    #15
        lea     DXOFF,a0
        lea     PY,a1
        clr.w   d7
MDI     clr.w   d6
MDJ     move.w  d7,d5
        mulu    #GRID,d5
        add.w   d6,d5
        add.w   d5,d5
        cmp.w   #GRID-1,d6
        bge     MSKH
        move.w  (a0,d5.w),d1
        move.w  (a1,d5.w),d2
        move.w  2(a0,d5.w),d3
        move.w  2(a1,d5.w),d4
        moveq   #84,d0
        trap    #15
MSKH    cmp.w   #GRID-1,d7
        bge     MSKV
        move.w  (a0,d5.w),d1
        move.w  (a1,d5.w),d2
        move.w  GRID*2(a0,d5.w),d3
        move.w  GRID*2(a1,d5.w),d4
        moveq   #84,d0
        trap    #15
MSKV    addq.w  #1,d6
        cmp.w   #GRID,d6
        blt     MDJ
        addq.w  #1,d7
        cmp.w   #GRID,d7
        blt     MDI

* ---- 4. the orbiting bodies (or the merger burst) ----
        move.w  FRAMEIDX,d0
        add.w   d0,d0
        lea     RINGR,a0
        move.w  (a0,d0.w),d0        ring radius (0 => still inspiralling)
        tst.w   d0
        bne     BURST

* two solid bodies, 180 deg apart, at radius RCUR
        move.l  #WHITE,d1
        moveq   #81,d0
        trap    #15
        move.l  #WHITE,d1
        moveq   #80,d0
        trap    #15
        move.w  #MASSRAD,MRAD
        move.w  RCUR,MR
        move.w  ANGCUR,MANG
        bsr     DRAWMASS
        move.l  #GOLD,d1
        moveq   #81,d0
        trap    #15
        move.l  #GOLD,d1
        moveq   #80,d0
        trap    #15
        move.w  ANGCUR,d0
        add.w   #128,d0
        and.w   #$FF,d0
        move.w  d0,MANG
        bsr     DRAWMASS
        bra     BODYDONE

BURST   move.w  d0,d5              ring radius -> d5
* coalesced core
        move.l  #WHITE,d1
        moveq   #81,d0
        trap    #15
        move.l  #WHITE,d1
        moveq   #80,d0
        trap    #15
        move.w  #MASSRAD+5,d0
        move.w  CX,d1
        sub.w   d0,d1
        move.w  CY,d2
        sub.w   #LIFT,d2
        sub.w   d0,d2
        move.w  CX,d3
        add.w   d0,d3
        move.w  CY,d4
        sub.w   #LIFT,d4
        add.w   d0,d4
        moveq   #88,d0
        trap    #15
* expanding ring-down burst
        move.l  #WHITE,d1
        moveq   #80,d0
        trap    #15
        move.w  d5,d0
        move.w  CX,d1
        sub.w   d0,d1
        move.w  CY,d2
        sub.w   #LIFT,d2
        sub.w   d0,d2
        move.w  CX,d3
        add.w   d0,d3
        move.w  CY,d4
        sub.w   #LIFT,d4
        add.w   d0,d4
        moveq   #91,d0
        trap    #15
BODYDONE

* ---- 5. caption ----
        move.l  #GREEN,d1
        moveq   #80,d0
        trap    #15
        lea     TITLE,a1
        moveq   #8,d1
        moveq   #8,d2
        moveq   #95,d0
        trap    #15

* ---- 6. present + advance the binary ----
        moveq   #94,d0             present + frame-lock to vsync (60 FPS)
        trap    #15
        move.w  FRAMEIDX,d0
        add.w   d0,d0
        lea     IND,a0
        move.w  (a0,d0.w),d1
        add.w   d1,PHI
        move.w  FRAMEIDX,d0
        addq.w  #1,d0
        cmp.w   #NTOT,d0
        blt     NORST
        moveq   #0,d0
NORST   move.w  d0,FRAMEIDX
        bra     FRAME

        STOP    #$2000

*-----------------------------------------------------------
* DRAWMASS - draw one filled body.  MANG=angle(0..255), MR=radius
*            (data units), MRAD=pixel radius.  Fill/pen preset.
*-----------------------------------------------------------
DRAWMASS
        movem.l d0-d4/a5,-(sp)
        lea     SINTAB,a5
        move.w  MANG,d3
        move.w  d3,d0
        add.w   #64,d0
        and.w   #$FF,d0
        add.w   d0,d0
        move.w  (a5,d0.w),d1        ca Q14
        move.w  d3,d0
        and.w   #$FF,d0
        add.w   d0,d0
        move.w  (a5,d0.w),d2        sa Q14
* cx = (R*ca)>>14
        move.w  MR,d0
        muls    d1,d0
        moveq   #14,d3
        asr.l   d3,d0
        move.w  d0,d4               cx -> d4
* cy = (R*sa)>>14
        move.w  MR,d0
        muls    d2,d0
        moveq   #14,d3
        asr.l   d3,d0
        move.w  d0,d2               cy -> d2
* sx = CX + (cx*PXC - cy*PXS)>>12
        move.w  d4,d0
        muls    PXC,d0
        move.w  d2,d1
        muls    PXS,d1
        sub.l   d1,d0
        moveq   #12,d3
        asr.l   d3,d0
        add.w   CX,d0
        move.w  d0,MSX
* sy = CY + (cx*PYC + cy*PYS)>>12 - LIFT
        move.w  d4,d0
        muls    PYC,d0
        move.w  d2,d1
        muls    PYS,d1
        add.l   d1,d0
        moveq   #12,d3
        asr.l   d3,d0
        add.w   CY,d0
        sub.w   #LIFT,d0
        move.w  d0,MSY
* filled ellipse box
        move.w  MRAD,d0
        move.w  MSX,d1
        sub.w   d0,d1
        move.w  MSY,d2
        sub.w   d0,d2
        move.w  MSX,d3
        add.w   d0,d3
        move.w  MSY,d4
        add.w   d0,d4
        moveq   #88,d0
        trap    #15
        movem.l (sp)+,d0-d4/a5
        rts

TITLE   DC.B    'EASy68K  -  68000 binary inspiral / gravity wave',0
        DS.W    0

* ---- projection constants for the bodies (Q12) ----
PXC     DC.W    {PXC}
PXS     DC.W    {PXS}
PYC     DC.W    {PYC}
PYS     DC.W    {PYS}

{emit("SINTAB", sv)}

{emit("DXOFF", dx)}

{emit("DYOFF", dy)}

{emit("PHASE", phase)}

{emit("AMPF", ampf)}

{emit("INR", INR)}

{emit("IND", IND)}

{emit("ING", ING)}

{emit("RINGR", RINGR)}

* ---- per-frame state ----
PY      DS.W    NODES
SCRW    DS.W    1
SCRH    DS.W    1
CX      DS.W    1
CY      DS.W    1
THETA   DS.W    1
PHI     DS.W    1
ANGCUR  DS.W    1
FRAMEIDX DS.W   1
RCUR    DS.W    1
GAINCUR DS.W    1
MANG    DS.W    1
MR      DS.W    1
MRAD    DS.W    1
MSX     DS.W    1
MSY     DS.W    1

        END     START
'''
open("/Users/MWOLAK/EASy68K-macos/demos/gravityWave/gravityWave.X68","w").write(CODE)
print("wrote .X68:", len(CODE.splitlines()), "lines")
