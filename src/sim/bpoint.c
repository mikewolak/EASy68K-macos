/***************************** 68000 SIMULATOR ****************************

File Name: bpoint.c
Debugger Component

C99 port of BPoint.cpp. Stores and tests a single user breakpoint.

***************************************************************************/

#include "extern.h"
#include "bpoint.h"

void BPoint_init(BPoint *bp)              { bp->isEnab = false; }

int  BPoint_getId(BPoint *bp)             { return bp->id; }
void BPoint_setId(BPoint *bp, int id)     { bp->id = id; }
int  BPoint_getType(BPoint *bp)           { return bp->type; }
void BPoint_setType(BPoint *bp, int t)    { bp->type = t; }
int32_t BPoint_getTypeId(BPoint *bp)         { return bp->typeId; }
void BPoint_setTypeId(BPoint *bp, int32_t t) { bp->typeId = t; }
int  BPoint_getOperator(BPoint *bp)       { return bp->op; }
void BPoint_setOperator(BPoint *bp, int o){ bp->op = o; }
int32_t BPoint_getValue(BPoint *bp)          { return bp->value; }
void BPoint_setValue(BPoint *bp, int32_t v)  { bp->value = v; }
int  BPoint_getReadWrite(BPoint *bp)      { return bp->readWrite; }
void BPoint_setReadWrite(BPoint *bp, int rw) { bp->readWrite = rw; }
int32_t BPoint_getSize(BPoint *bp)           { return bp->size; }
void BPoint_setSize(BPoint *bp, int32_t s)   { bp->size = s; }
bool BPoint_isEnabled(BPoint *bp)         { return bp->isEnab; }
void BPoint_setEnabled(BPoint *bp, bool e){ bp->isEnab = e; }

// Calculates whether or not the breakpoint condition has been met.
bool BPoint_isBreak(BPoint *bp) {
        if(!bp->isEnab) return false;    // Is breakpoint valid to check?

        // Give the benefit of the doubt, but change final condition
        // to false if any of the break conditions fail
        bool finalCondition = true;

        int32_t * curEA = NULL;

        if(bp->type == PC_REG_TYPE && bp->typeId != PC_TYPE_ID) {
                // Get the effective address for one of the registers.
                if(bp->typeId >= D0_TYPE_ID && bp->typeId <= D7_TYPE_ID)
                        curEA = &D[bp->typeId];
                else
                        curEA = &A[bp->typeId - A0_TYPE_ID];
        }
        else if(bp->type == ADDR_TYPE) {
                // Get the effective address for a memory location.
                curEA = (int32_t *)&memory[bp->typeId];

                // Is the readWrite condition met?
                bool write = false;
                bool read = false;

                // At the end of this section of code, either read or write will be
                // true, or neither will be true (not both true).
                if(bpRead && curEA == readEA)
                        read = true;
                else if(bpWrite && curEA == writeEA)
                        write = true;

                switch(bp->readWrite) {
                case RW_TYPE:   finalCondition = read || write;
                                break;
                case READ_TYPE: finalCondition = read;
                                break;
                case WRITE_TYPE:finalCondition = write;
                                break;
                case NA_TYPE:   // We don't care if currently reading or writing
                                finalCondition = true;
                                break;
                default:        // Invalid readWrite type specified.  No break.
                                finalCondition = false;
                                break;
                }
        }

        // Don't bother to continue testing condition if already failed.
        if(!finalCondition) return false;

        // Is the value in the correct range?
        int32_t valueFound;
        int32_t curSize = LONG_MASK;
        if(bp->size == BYTE_SIZE)
                curSize = BYTE_MASK;
        else if(bp->size == WORD_SIZE)
                curSize = WORD_MASK;
        else if(bp->size == LONG_SIZE)
                curSize = LONG_MASK;

        // Compute the value for the PC
        if(bp->type == PC_REG_TYPE && bp->typeId == PC_TYPE_ID) {
                valueFound = PC & curSize;
        }
        // Compute the value for effective addresses (registers or memory)
        else {
                value_of(curEA, &valueFound, curSize);
        }

        // The finalCondition is now determined by whether the value is
        // relationally equivalent to the valueFound.
        switch(bp->op) {
                case EQUAL_OP:          finalCondition = (valueFound == bp->value);
                                        break;
                case NOT_EQUAL_OP:      finalCondition = (valueFound != bp->value);
                                        break;
                case GT_OP:             finalCondition = (valueFound > bp->value);
                                        break;
                case GT_EQUAL_OP:       finalCondition = (valueFound >= bp->value);
                                        break;
                case LT_OP:             finalCondition = (valueFound < bp->value);
                                        break;
                case LT_EQUAL_OP:       finalCondition = (valueFound <= bp->value);
                                        break;
                case NA_OP:             // Value does not matter.
                                        finalCondition = true;
                                        break;
                default:                // Invalid op type specified.  No break.
                                        finalCondition = false;
                                        break;
        }

        return finalCondition;
}
