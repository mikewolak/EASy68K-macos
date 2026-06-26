/***************************** 68000 SIMULATOR ****************************

File Name: globals.c

C99 port of var.h. Defines every global the simulator core declares in
extern.h. In the original Borland build these lived in var.h, included
once by the GUI main module (SIM68Ku.cpp); here they form a standalone
translation unit shared by the CLI and the Cocoa app.

The Borland-only members of var.h are intentionally not defined here:
  - AnsiString errstr/str         -> only used by the GUI-coupled files
  - stack<int> s_operator         -> breakpoint-builder GUI state
  - Win32 multi-monitor API ptrs  -> native full-screen lives in the GUI

***************************************************************************/

#include "extern.h"

// General
char    *memory = NULL;         // pointer for main 68000 memory

char buffer[256];               // used to form messages for display
char numBuf[20];                // "

// 68000 registers (these must remain grouped; put()/value_of() compare
// their addresses to decide register-vs-memory operations)
int32_t    D[D_REGS], OLD_D[D_REGS], A[A_REGS], OLD_A[A_REGS];
int32_t    PC, OLD_PC;
short   SR, OLD_SR;

int32_t    global_temp;            // to hold an immediate data operand
int32_t    *EA1, *EA2;
int32_t    EV1, EV2;
int32_t    source, dest, result;
int     inst;

uint64_t cycles;
int     trace, sstep, old_trace, old_sstep, exceptions;
bool    bitfield, simhalt_on;
bool    halt;                   // true, halts running program
bool    stopInstruction;        // true after running stop instruction

char    lbuf[SREC_MAX], *wordptr[20];   // command buffers
char    bpoints = 0;
int     brkpt[100], wcount;
int     stepToAddr;             // Step Over stopping address
int     runToAddr;              // runToCursor stopping address

int     errflg;

// port structure is :{control,trans data,status,recieve data}
unsigned int port1[4] = {0x00,0,0x82,0};        // simulated 6850 port
char    p1dif = 0;

bool    runMode;                // true when running 68000 program (not tracing)
bool    runModeSave;

bool    keyboardEcho;           // true, EASy68K input is echoed (default)
char    pendingKey;             // pending key for char input
bool    inputPrompt;            // true, display prompt during input (default)
bool    inputLFdisplay;         // true, display LF on CR during input (default)

char    inputBuf[256];          // simulator input buffer
int32_t    inputSize;              // number of characters input
bool    inputMode;              // true when getting keyboard input

FileStruct files[MAXFILES];     // array of file structures

// log output
char ElogFlag;                  // Execution log file setting
FILE *ElogFile;                 // Execution Log file
char OlogFlag;                  // Output log file setting
FILE *OlogFile;                 // Output Log file
bool logging;                   // true when logging
unsigned int logMemAddr;        // log memory address
unsigned int logMemBytes;       // log memory bytes

bool autoTraceInProgress;       // true when auto tracing

// Breakpoints / expression groups.
// PC/Reg break points are in elements 0-49.  Addr => 50-99.
BPoint breakPoints[MAX_BPOINTS];
BPointExpr bpExpressions[MAX_BP_EXPR];
int bpCountCond[MAX_BPOINTS];
int regCount = 0;
int addrCount = 0;
int exprCount = 0;

// Arrays used while building a break expression.
int infixExpr[MAX_LB_NODES];
int postfixExpr[MAX_LB_NODES];
int infixCount = 0;
int postfixCount;

// Used to track which GUI buttons are available while building an expression.
bool mruOperand = false;
bool mruOperator = false;
int parenCount = 0;

// Read/write flags so breakpoints can test read/write access.
bool bpRead;
bool bpWrite;
int32_t * readEA;
int32_t * writeEA;

// Interrupt and Reset Control
bool hardReset;
int irq;

// Memory map (set from S0 records / the hardware window; enforced by
// memoryMapCheck in utils.c). In the Windows build these lived in
// hardwareu.cpp; they are core simulator state here.
int ROMStart=0, ROMEnd=0, ReadStart=0, ReadEnd=0;
int ProtectedStart=0, ProtectedEnd=0, InvalidStart=0, InvalidEnd=0;
bool ROMMap=false, ReadMap=false, ProtectedMap=false, InvalidMap=false;

// Memory-mapped hardware device locations (0 = not mapped).
int seg7loc=0, LEDloc=0, switchLoc=0, pbLoc=0;

// Full-screen output target (0 = primary, 1+ = secondary monitors)
unsigned char FullScreenMonitor;
char FullScreenDeviceName[32];

// true if directSound may be used (native sound lives in the GUI)
bool dsoundExist;

// Mouse / keyboard state (fed by the GUI, read by the hardware-sim TRAPs)
int mouseX, mouseY;
bool mouseLeft, mouseRight, mouseMiddle, mouseDouble;
bool keyShift, keyAlt, keyCtrl;

int mouseXUp, mouseYUp;
bool mouseLeftUp, mouseRightUp, mouseMiddleUp, mouseDoubleUp;
bool keyShiftUp, keyAltUp, keyCtrlUp;

int mouseXDown, mouseYDown;
bool mouseLeftDown, mouseRightDown, mouseMiddleDown, mouseDoubleDown;
bool keyShiftDown, keyAltDown, keyCtrlDown;
byte mouseDownIRQ, mouseUpIRQ, mouseMoveIRQ;
byte keyDownIRQ, keyUpIRQ;
