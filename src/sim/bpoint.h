/***************************** 68000 SIMULATOR ****************************

File Name: bpoint.h
Debugger Component

C99 port of the original C++ BPoint class: a single user breakpoint
(PC/Reg or memory-address condition). The class members become a plain
struct; the methods become BPoint_* functions taking the struct pointer.

***************************************************************************/
#ifndef BPOINT_H
#define BPOINT_H

#include <stdbool.h>

#define BREAK_CONDITIONS 2

typedef struct BPoint {
    int  id;          // Uniquely identifies breakpoint within PC/Reg and Addr
                      // categories (0-49, 50-99); its place in breakpoints[]
    int  type;        // PC/Reg, Addr
    int32_t typeId;      // D0-7, A8-15, 16 => PC/Reg; address => Addr
    int  op;          // ==, !=, <, <=, >, >=
    int32_t value;       // value sought at the breakpoint
    int  readWrite;   // whether a read or write is needed to trigger
    int32_t size;        // size of the value to test
    bool isEnab;      // should the condition be tested?
} BPoint;

void BPoint_init(BPoint *bp);                 // constructor (isEnab = false)

int  BPoint_getId(BPoint *bp);
void BPoint_setId(BPoint *bp, int id);
int  BPoint_getType(BPoint *bp);
void BPoint_setType(BPoint *bp, int type);
int32_t BPoint_getTypeId(BPoint *bp);
void BPoint_setTypeId(BPoint *bp, int32_t typeId);
int  BPoint_getOperator(BPoint *bp);
void BPoint_setOperator(BPoint *bp, int op);
int32_t BPoint_getValue(BPoint *bp);
void BPoint_setValue(BPoint *bp, int32_t value);
int  BPoint_getReadWrite(BPoint *bp);
void BPoint_setReadWrite(BPoint *bp, int readWrite);
int32_t BPoint_getSize(BPoint *bp);
void BPoint_setSize(BPoint *bp, int32_t size);
bool BPoint_isEnabled(BPoint *bp);
void BPoint_setEnabled(BPoint *bp, bool isEnab);
bool BPoint_isBreak(BPoint *bp);

#endif
