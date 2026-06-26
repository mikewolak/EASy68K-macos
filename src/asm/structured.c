/***********************************************************************

 		STRUCASM.C
  This file contains the routines to assemble structured code.

   Author: Charles Kelly,
           Monroe County Community College
           http://www.monroeccc.edu/ckelly

   C99 port: the original used Borland AnsiString and STL stack<>/vector<>
   containers. Those are replaced here with plain C string buffers and small
   fixed-capacity stacks. The generated assembly text is byte-for-byte
   identical to the original.

 ************************************************************************/

#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include "asm.h"

extern char line[256];		// Source line
extern bool listFlag;
extern bool pass2;		// Flag set during second pass
extern int loc;		// The assembler's location counter
extern unsigned int stcLabelI;  // structured if label number
extern unsigned int stcLabelW;  // structured while label number
extern unsigned int stcLabelR;  // structured repeat label number
extern unsigned int stcLabelF;  // structured for label number
extern unsigned int stcLabelD;  // structured dbloop label number
extern int errorCount, warningCount;
extern bool SEXflag;            // true expands structured listing
extern int lineNum;
extern FILE *listFile;		// Listing file
extern bool skipList;           // true to skip listing line in ASSEMBLE.CPP
extern int  macroNestLevel;     // used by macro processing
extern char lineIdent[];        // "s" used to identify structure in listing

// prototypes
static const char *getBcc(const char *cc, int mode, int orFlag);
static void outCmpBcc(char *token[], char *last, const char *label, int *error);
void assembleStc(char* line);

static const unsigned int stcMask  = 0xF0000000;
static const unsigned int stcMaskI = 0x00000000;
static const unsigned int stcMaskW = 0x10000000;
static const unsigned int stcMaskF = 0x20000000;
static const unsigned int stcMaskR = 0x30000000;
static const unsigned int stcMaskD = 0x40000000;

// constants for use with BccCodes[] below to select proper column.
#define RN_EA_OR 2
#define EA_IM_OR 2
#define IF_CC    1            // IF <cc>
#define RN_EA    1
#define EA_IM    1
#define EA_RN    3
#define IM_EA    3
#define EA_RN_OR 4
#define IM_EA_OR 4

#define BCC_COUNT 16
#define LAST_TOKEN 11      // highest token possible of structure

// This table contains the branch condition codes to use for the different
// conditional expressions.
static const char* BccCodes[BCC_COUNT][5] = {
//  <cc>     <-- original CC used in structured code
//            Rn<cc>ea   Rn<cc>ea OR   ea<cc>Rn    ea<cc>Rn OR  <-- if used like this
//           CMP ea,Rn    CMP ea,Rn   CMP ea,Rn    CMP ea,Rn    <-- use this CMP operation
//            ea<cc>#n   ea<cc>#n OR   #n<cc>ea    #n<cc>ea OR  <-- if used like this
//           CMP #n,ea    CMP #n,ea   CMP #n,ea    CMP #n,ea    <-- use this CMP operation
  {"<GT>",      "BLE",      "BGT",      "BGE",      "BLT"},    //<-- with condition below
  {"<GE>",      "BLT",      "BGE",      "BGT",      "BLE"},
  {"<LT>",      "BGE",      "BLT",      "BLE",      "BGT"},
  {"<LE>",      "BGT",      "BLE",      "BLT",      "BGE"},
  {"<EQ>",      "BNE",      "BEQ",      "BNE",      "BEQ"},
  {"<NE>",      "BEQ",      "BNE",      "BEQ",      "BNE"},
  {"<HI>",      "BLS",      "BHI",      "BHS",      "BLO"},
  {"<HS>",      "BLO",      "BHS",      "BHI",      "BLS"},
  {"<CC>",      "BLO",      "BCC",      "BHI",      "BLS"},
  {"<LO>",      "BHS",      "BLO",      "BLS",      "BHI"},
  {"<CS>",      "BHS",      "BCS",      "BLS",      "BHI"},
  {"<LS>",      "BHI",      "BLS",      "BLO",      "BHS"},
  {"<MI>",      "BPL",      "BMI",      "BPL",      "BMI"},
  {"<PL>",      "BMI",      "BPL",      "BMI",      "BPL"},
  {"<VC>",      "BVS",      "BVC",      "BVS",      "BVC"},
  {"<VS>",      "BVC",      "BVS",      "BVC",      "BVS"}
};

/* ------------------------------------------------------------------ *
 *  Structured-assembly stacks (replacing the original C++ STL stacks).
 *
 *    stcStack : nested structure label numbers (unsigned int)
 *    dbStack  : DBLOOP register-number characters (char)
 *    forStack : FOR-loop assembly lines emitted at ENDF (strings)
 *
 *  Capacity covers any realistic nesting depth; pushes beyond capacity
 *  are ignored (the original vector grew without bound).
 * ------------------------------------------------------------------ */
#define STC_STACK_MAX 1024
#define STC_LINE_MAX  128

static unsigned int stcStackData[STC_STACK_MAX];
static int          stcStackCount = 0;
static char         dbStackData[STC_STACK_MAX];
static int          dbStackCount = 0;
static char         forStackData[STC_STACK_MAX][STC_LINE_MAX];
static int          forStackCount = 0;

static void stcPush(unsigned int v) { if (stcStackCount < STC_STACK_MAX) stcStackData[stcStackCount++] = v; }
static unsigned int stcTop(void)    { return (stcStackCount > 0) ? stcStackData[stcStackCount-1] : 0; }
static void stcPop(void)            { if (stcStackCount > 0) stcStackCount--; }

static void dbPush(char c)          { if (dbStackCount < STC_STACK_MAX) dbStackData[dbStackCount++] = c; }
static char dbTop(void)             { return (dbStackCount > 0) ? dbStackData[dbStackCount-1] : '0'; }
static void dbPop(void)             { if (dbStackCount > 0) dbStackCount--; }

static void forPush(const char *s)  { if (forStackCount < STC_STACK_MAX) { strncpy(forStackData[forStackCount], s, STC_LINE_MAX-1); forStackData[forStackCount][STC_LINE_MAX-1] = '\0'; forStackCount++; } }
static const char *forTop(void)     { return (forStackCount > 0) ? forStackData[forStackCount-1] : ""; }
static void forPop(void)            { if (forStackCount > 0) forStackCount--; }

// Reset all structured-assembly stacks (called between assemblies).
void stcStackClear(void) { stcStackCount = 0; }
void dbStackClear(void)  { dbStackCount = 0; }
void forStackClear(void) { forStackCount = 0; }

//-------------------------------------------------------
// returns a branch instruction
// orFlag is 1 on ea <cc> ea OR, 0 otherwise
static const char *getBcc(const char *cc, int mode, int orFlag) {
  for (int i=0; i<BCC_COUNT; i++) {
    if (strcasecmp(cc, BccCodes[i][0]) == 0)
      return BccCodes[i][mode + orFlag];
  }
  return "B??";
}

//-------------------------------------------------------
// output a CMP and Branch to perform the specified expression
// Pre: the code is in all caps
// token[0] is the first token in the structure following the keyword. Normally
// the size. (IF.B  token[0] would be .B). The size may be missing in which case
// token[0] would contain the first operand or <cc> in the structure.
//    token number
//     0     1     2     3     4     5     6     7     8     9
//    <cc>  THEN
//    <cc>   OR   .B   <cc>  THEN
//    D1   <cc>   D2    OR    .B    <cc>  THEN
//    .B   <cc>  THEN
//    .B   <cc>   OR   <cc>  THEN
//    .B   <cc>   OR    .B   <cc>  THEN
//    .B    D0   <cc>   D1   THEN
//    .B   <cc>   AND   .B    D0   <cc>   D1   THEN
//    .B    D0   <cc>   D1    AND   .B    D2   <cc>   D3   THEN
static void outCmpBcc( char *token[], char *last, const char *label, int *error) {

  char stcLine[STC_LINE_MAX];
  const char *stcCmp;
  char extent[8];
  int orFlag=0, n=0;

  {
    *error = OK;
    if (token[n][0] == '.') {
      if (token[n][1] == 'B')
        stcCmp = "\tCMP.B\t";
      else if (token[n][1] == 'W')
        stcCmp = "\tCMP.W\t";
      else if (token[n][1] == 'L')
        stcCmp = "\tCMP.L\t";
      else {
        *error = SYNTAX;
        return;
      }
      n++;                        // token[n] at 1
    } else
      stcCmp = "\tCMP.W\t";

    // determine size of extent if present
    if (last[0] == '.') {
      if (last[1] == 'S')
        strcpy(extent, ".S\t");
      else if (last[1] == 'L')
        strcpy(extent, ".L\t");
      else {
        *error = SYNTAX;
        return;
      }
    } else
      strcpy(extent, "\t");

    if ( !(strcmp(token[n+1], "OR")) || !(strcmp(token[n+3], "OR"))) {
      orFlag = 1;
      strcpy(extent, ".S\t");     // first branch with OR logic is always short
    }

    if (token[n][0] == '<') {     // IF <cc> THEN
      snprintf(stcLine, sizeof(stcLine), "\t%s%s%s\n", getBcc(token[n],IF_CC,orFlag), extent, label);
      assembleStc(stcLine);
    }else if (token[n][0] == '#') {                    // #nn <cc> ea
      snprintf(stcLine, sizeof(stcLine), "%s%s,%s\n", stcCmp, token[n], token[n+2]);
      assembleStc(stcLine);
      snprintf(stcLine, sizeof(stcLine), "\t%s%s%s\n", getBcc(token[n+1],IM_EA,orFlag), extent, label);
      assembleStc(stcLine);
    }else if (token[n+2][0] == '#') {                    // ea <cc> #nn
      snprintf(stcLine, sizeof(stcLine), "%s%s,%s\n", stcCmp, token[n+2], token[n]);
      assembleStc(stcLine);
      snprintf(stcLine, sizeof(stcLine), "\t%s%s%s\n", getBcc(token[n+1],EA_IM,orFlag), extent, label);
      assembleStc(stcLine);
    // Rn <cc> ea
    }else if ((token[n][0]=='A' || token[n][0]=='D') &&
               isRegNum(token[n][1])) {
      snprintf(stcLine, sizeof(stcLine), "%s%s,%s\n", stcCmp, token[n+2], token[n]);
      assembleStc(stcLine);
      snprintf(stcLine, sizeof(stcLine), "\t%s%s%s\n", getBcc(token[n+1],RN_EA,orFlag), extent, label);
      assembleStc(stcLine);
    // ea <cc> Rn
    }else if ((token[n+2][0]=='A' || token[n+2][0]=='D') &&
               isRegNum(token[n+2][1])) {
      snprintf(stcLine, sizeof(stcLine), "%s%s,%s\n", stcCmp, token[n], token[n+2]);
      assembleStc(stcLine);
      snprintf(stcLine, sizeof(stcLine), "\t%s%s%s\n", getBcc(token[n+1],EA_RN,orFlag), extent, label);
      assembleStc(stcLine);
    // (An)+ <cc> (An)+  also supports (SP)+ (MUST BE LAST IN IF-ELSE CHAIN)
    }else if ((token[n][0]=='(' && token[n][3]==')' && token[n][4]=='+')) {
      snprintf(stcLine, sizeof(stcLine), "%s%s,%s\n", stcCmp, token[n], token[n+2]);
      assembleStc(stcLine);
      snprintf(stcLine, sizeof(stcLine), "\t%s%s%s\n", getBcc(token[n+1],RN_EA,orFlag), extent, label);
      assembleStc(stcLine);
    }else{
      *error = SYNTAX;
    }
  }
}


//--------------------------------------------------------
/*
  Structured statements
    items in brackets [] are optional.

    An expression consists of either one of the following:
      <cc>
      op1 <cc> op2

    IF expression THEN[.S|.L]
    IF[.B|.W|.L] expression THEN[.S|.L]
    IF[.B|.W|.L] expression OR[.B|.W|.L]  expression THEN[.S|.L]
    IF[.B|.W|.L] expression AND[.B|.W|.L] expression THEN[.S|.L]

    ELSE[.S|.L]

    ENDI

    WHILE expression DO[.S|.L]
    WHILE[.B|.W|.L] expression DO[.S|.L]
    WHILE[.B|.W|.L] expression OR[.B|.W|.L]  expression DO[.S|.L]
    WHILE[.B|.W|.L] expression AND[.B|.W|.L] expression DO[.S|.L]

    ENDW

    REPEAT

    UNTIL expression [DO[.S|.L]]
    UNTIL[.B|.W|.L] expression [DO[.S|.L]]
    UNTIL[.B|.W|.L] expression OR[.B|.W|.L]  expression [DO[.S|.L]]
    UNTIL[.B|.W|.L] expression AND[.B|.W|.L] expression [DO[.S|.L]]

    FOR[.B|.W|.L] op1 = op2 TO     op3        DO[.S|.L]
    FOR[.B|.W|.L] op1 = op2 TO     op3 BY op3 DO[.S|.L]
    FOR[.B|.W|.L] op1 = op2 DOWNTO op3        DO[.S|.L]
    FOR[.B|.W|.L] op1 = op2 DOWNTO op3 BY op3 DO[.S|.L]

    ENDF

    DBLOOP op1 = op2
    UNLESS
    UNLESS <F>
    UNLESS[.B|.W|.L] expression

    token number
     1     2     3     4     5     6     7     8     9    10    11    12
    IF   <cc>  THEN
    IF   <cc>   OR    .B   <cc>  THEN
    IF    .B   <cc>   THEN
    IF    .B   <cc>   OR   <cc>  THEN
    IF    .B   <cc>   OR    .B   <cc>  THEN
    IF    .B    D0    <cc>  D1   THEN
    IF    .B   <cc>   AND   .B    D0   <cc>   D1    THEN
    IF    D0   <cc>   D1    OR   <cc>  THEN
    IF    .B    D0    <cc>  D1    OR   <cc>  THEN
    IF    .B    D0    <cc>  D1    AND   .B    D2    <cc>  D3   THEN   .S
*/
int asmStructure(int size, char *label, char *arg, int *errorPtr)
{
  {

    char *token[256];             // pointers to tokens
    char tokens[512];             // place tokens here
    char capLine[256];
    char tokenEnd[10];            // last token of structure goes here
    char stcLabel[16], stcLabel2[16], stcLine[STC_LINE_MAX], sizeStr[8], extent[8];
    int error;
    int n = 2;                    // token index
    int i;

    if (*label)                           // if label
      define(label, loc, pass2, true, errorPtr); // define label

    strcap(capLine, line);                // capitalize line
    error = OK;
    if (pass2 && listFlag) {
      if (!(macroNestLevel > 0 && skipList == true)) // if not called from macro with listing off
      {
        listLoc();
        if (macroNestLevel > 0)             // if called from macro
          listLine(line, lineIdent);        // tag line as macro
        else
          listLine(line, "\0");
      }
    }

    tokenize(capLine, ". \t\n", token, tokens);  	// tokenize statement

    if (token[n][0] == '.')
      n = 3;

    // -------------------- IF --------------------
    // IF[.B|.W|.L] op1 <cc> op2 [OR/AND[.B|.W|.L]  op3 <cc> op4] THEN
    if (!(strcmpi(token[1], "IF"))) {             // IF ?
      snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelI);
      tokenEnd[0] = '\0';
      for (i=3; i<=LAST_TOKEN; i++) {
        if (!(strcmp(token[i], "THEN"))) {    // find THEN
          strncpy(tokenEnd, token[i+1],3);    // copy branch distance to tokenEnd
          break;
        }
      }
      if(i > LAST_TOKEN) {                 // if THEN not found
        error = THEN_EXPECTED;
        NEWERROR(*errorPtr, error);
      }
      //           .B/W/L       op1       <cc>       op2   THEN/OR/AND  THEN.?   label
      outCmpBcc(&token[2], tokenEnd, stcLabel, &error);
      NEWERROR(*errorPtr, error);
      if (!(strcmp(token[n+1], "OR"))) {    // IF <cc> OR
        strcpy(stcLabel2, stcLabel);
        stcLabelI++;
        snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelI);
        //           .B/W/L       op3      <cc>      op4       THEN      THEN.?    label
        outCmpBcc(&token[n+2], tokenEnd, stcLabel, &error);
        NEWERROR(*errorPtr, error);
        snprintf(stcLine, sizeof(stcLine), "%s\n", stcLabel2);
        assembleStc(stcLine);
      } else if (!(strcmp(token[n+3], "OR"))) { // IF ea <cc> ea OR
        strcpy(stcLabel2, stcLabel);
        stcLabelI++;
        snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelI);
        //           .B/W/L       op3      <cc>      op4       THEN      THEN.?    label
        outCmpBcc(&token[n+4], tokenEnd, stcLabel, &error);
        NEWERROR(*errorPtr, error);
        snprintf(stcLine, sizeof(stcLine), "%s\n", stcLabel2);
        assembleStc(stcLine);
      } else if (!(strcmp(token[n+1], "AND"))) { // IF <cc> AND
        //            .B/W/L       op3       <cc>      op4       THEN     THEN.?    label
        outCmpBcc(&token[n+2], tokenEnd, stcLabel, &error);
        NEWERROR(*errorPtr, error);
      } else if (!(strcmp(token[n+3], "AND"))) { // IF ea <cc> ea AND
        //            .B/W/L       op3       <cc>      op4       THEN     THEN.?    label
        outCmpBcc(&token[n+4], tokenEnd, stcLabel, &error);
        NEWERROR(*errorPtr, error);
      }

      stcPush(stcLabelI);
      stcLabelI++;                        // prepare label for next if
      skipList = true;                        // don't display this line in ASSEMBLE.CPP
    }

    // -------------------- ELSE --------------------
    if (!(strcmp(token[1], "ELSE"))) {
      unsigned int elseLbl = stcTop();
      stcPop();
      if ((elseLbl & stcMask) != stcMaskI)
        NEWERROR(*errorPtr, NO_IF);
      // determine size of extent
      if (token[2][0] == '.') {
        if (token[2][1] == 'S')
          strcpy(extent, ".S\t");
        else if (token[2][1] == 'L')
          strcpy(extent, ".L\t");
        else {
          NEWERROR(*errorPtr, SYNTAX);
        }
      } else {
        strcpy(extent, "\t");
      }

      snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelI);
      snprintf(stcLine, sizeof(stcLine), "\tBRA%s%s\n", extent, stcLabel);
      assembleStc(stcLine);
      stcPush(stcLabelI);
      stcLabelI++;
      snprintf(stcLine, sizeof(stcLine), "_%08X\n", elseLbl);
      assembleStc(stcLine);
      skipList = true;                        // don't display this line in ASSEMBLE.CPP
    }

    // -------------------- ENDI --------------------
    if (!(strcmp(token[1], "ENDI"))) {
      unsigned int endiLbl = stcTop();
      stcPop();
      if ((endiLbl & stcMask) != stcMaskI)        // if label is not from an IF
        NEWERROR(*errorPtr, NO_IF);
      snprintf(stcLine, sizeof(stcLine), "_%08X\n", endiLbl);
      assembleStc(stcLine);
      skipList = true;                        // don't display this line in ASSEMBLE.CPP
    }

    // -------------------- WHILE --------------------
    // WHILE[.B|.W|.L] op1 <cc> op2 [OR/AND[.B|.W|.L]  op3 <cc> op4] DO
    // WHILE <T> D0 create infinite loop
    if (!(strcmp(token[1], "WHILE"))) {          // WHILE
      snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelW);
      snprintf(stcLine, sizeof(stcLine), "%s\n", stcLabel);
      assembleStc(stcLine);
      stcPush(stcLabelW);
      stcLabelW++;

      snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelW);
      tokenEnd[0] = '\0';
      for (i=3; i<=LAST_TOKEN; i++) {
        if (!(strcmp(token[i], "DO"))) {     // if DO
          strncpy(tokenEnd, token[i+1], 3);  // copy branch distance to tokenEnd
          break;
        }
      }
      if(i > LAST_TOKEN)                  // if DO not found
        NEWERROR(*errorPtr, DO_EXPECTED);
      if ((strcmp(token[n], "<T>"))) {       // if not infinite loop <T>
        //            .B/W/L      op1       <cc>       op2   DO/OR/AND    DO.?     label
        outCmpBcc(&token[2], tokenEnd, stcLabel, &error);
        NEWERROR(*errorPtr, error);
        if (!(strcmp(token[n+1], "OR"))) { // WHILE <cc> OR
          strcpy(stcLabel2, stcLabel);
          stcLabelW++;
          snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelW);
          //           .B/W/L        op3      <cc>      op4       DO       DO.?      label
          outCmpBcc(&token[n+2], tokenEnd, stcLabel, &error);
          NEWERROR(*errorPtr, error);
          snprintf(stcLine, sizeof(stcLine), "%s\n", stcLabel2);
          assembleStc(stcLine);
        } else if (!(strcmp(token[n+3], "OR"))) { // WHILE ea <cc> ea OR
          strcpy(stcLabel2, stcLabel);
          stcLabelW++;
          snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelW);
          //           .B/W/L        op3      <cc>      op4       DO       DO.?      label
          outCmpBcc(&token[n+4], tokenEnd, stcLabel, &error);
          NEWERROR(*errorPtr, error);
          snprintf(stcLine, sizeof(stcLine), "%s\n", stcLabel2);
          assembleStc(stcLine);
        } else if (!(strcmp(token[n+1], "AND"))) { // WHILE <cc> AND
          //           .B/W/L       op3       <cc>      op4       DO       DO.?      label
          outCmpBcc(&token[n+2], tokenEnd, stcLabel, &error);
          NEWERROR(*errorPtr, error);
        } else if (!(strcmp(token[n+3], "AND"))) { // WHILE ea <cc> ea AND
          //           .B/W/L       op3       <cc>      op4       DO       DO.?      label
          outCmpBcc(&token[n+4], tokenEnd, stcLabel, &error);
          NEWERROR(*errorPtr, error);
        }
      }

      stcPush(stcLabelW);
      stcLabelW++;
      skipList = true;                        // don't display this line in ASSEMBLE.CPP
    }

    // -------------------- ENDW --------------------
    if (!(strcmp(token[1], "ENDW"))) {
      unsigned int endwLbl = stcTop();
      stcPop();
      if ((endwLbl & stcMask) != stcMaskW)        // if label is not from a WHILE
        NEWERROR(*errorPtr, NO_WHILE);
      unsigned int whileLbl = stcTop();
      stcPop();
      snprintf(stcLine, sizeof(stcLine), "\tBRA\t_%08X\n", whileLbl);
      assembleStc(stcLine);
      snprintf(stcLine, sizeof(stcLine), "_%08X\n", endwLbl);
      assembleStc(stcLine);
      skipList = true;                        // don't display this line in ASSEMBLE.CPP
    }

    // -------------------- REPEAT --------------------
    if (!(strcmp(token[1], "REPEAT"))) {
      snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelR);
      snprintf(stcLine, sizeof(stcLine), "%s\n", stcLabel);
      assembleStc(stcLine);
      stcPush(stcLabelR);
      stcLabelR++;
      skipList = true;                        // don't display this line in ASSEMBLE.CPP
    }

    // -------------------- UNTIL --------------------
    // UNTIL[.B|.W|.L] op1 <cc> op2 [OR/AND[.B|.W|.L]  op3 <cc> op4] DO
    if (!(strcmp(token[1], "UNTIL"))) {          // UNTIL
      unsigned int untilLbl = stcTop();
      stcPop();
      if ((untilLbl & stcMask) != stcMaskR)       // if label is not from a REPEAT
        NEWERROR(*errorPtr, NO_REPEAT);
      snprintf(stcLabel2, sizeof(stcLabel2), "_%08X", untilLbl);
      snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelR);

      tokenEnd[0] = '\0';
      for (i=3; i<=LAST_TOKEN; i++) {
        if (!(strcmp(token[i], "DO"))) {     // if DO
          strncpy(tokenEnd, token[i+1], 3);         // copy branch distance to tokenEnd
          break;
        }
      }
      if(i > LAST_TOKEN)                   // if DO not found
        NEWERROR(*errorPtr, DO_EXPECTED);
      if (!(strcmp(token[n+1], "OR"))) {      // UNTIL <cc> OR
        //           .B/W/L       op1       <cc>       op2   DO/OR/AND    DO.?     label
        outCmpBcc(&token[2], tokenEnd, stcLabel, &error);
        NEWERROR(*errorPtr, error);
        //           .B/W/L       op3      <cc>      op4       DO         DO.?     label
        outCmpBcc(&token[n+2], tokenEnd, stcLabel2, &error);
        snprintf(stcLine, sizeof(stcLine), "%s\n", stcLabel);    // output label for first OR branch
        assembleStc(stcLine);
        stcLabelR++;
        NEWERROR(*errorPtr, error);

      } else if (!(strcmp(token[n+3], "OR"))) {      // UNTIL ea <cc> ea OR
        //           .B/W/L       op1       <cc>       op2   DO/OR/AND    DO.?     label
        outCmpBcc(&token[2], tokenEnd, stcLabel, &error);
        NEWERROR(*errorPtr, error);
        //           .B/W/L       op3      <cc>      op4       DO         DO.?     label
        outCmpBcc(&token[n+4], tokenEnd, stcLabel2, &error);
        snprintf(stcLine, sizeof(stcLine), "%s\n", stcLabel);    // output label for first OR branch
        assembleStc(stcLine);
        stcLabelR++;
        NEWERROR(*errorPtr, error);

      } else {
        //           .B/W/L       op1       <cc>       op2   DO/OR/AND    DO.?     label
        outCmpBcc(&token[2], tokenEnd, stcLabel2, &error);
        NEWERROR(*errorPtr, error);
        if (!(strcmp(token[n+1], "AND"))) {   // UNTIL <cc> AND
          //           .B/W/L       op3      <cc>      op4       DO         DO.?     label
          outCmpBcc(&token[n+2], tokenEnd, stcLabel2, &error);
          NEWERROR(*errorPtr, error);
        } else if (!(strcmp(token[n+3], "AND"))) {    // UNTIL ea <cc> ea AND
          //           .B/W/L       op3      <cc>      op4       DO         DO.?     label
          outCmpBcc(&token[n+4], tokenEnd, stcLabel2, &error);
          NEWERROR(*errorPtr, error);
        }
      }

      skipList = true;                        // don't display this line in ASSEMBLE.CPP
    }

    // -------------------- FOR --------------------
    // FOR[.<size>] op1 = op2 TO op3 [BY op4] DO
    if (!(strcmp(token[1], "FOR"))) {

      // determine size of extent if present
      tokenEnd[0] = '\0';
      for (i=3; i<=LAST_TOKEN; i++) {
        if (!(strcmp(token[i], "DO"))) {   // find DO
          strncpy(tokenEnd, token[i+1],3); // copy branch distance to tokenEnd
          break;
        }
      }
      if(i > LAST_TOKEN)                   // if DO not found
        NEWERROR(*errorPtr, DO_EXPECTED);
      if (tokenEnd[0] == '.') {
        if (tokenEnd[1] == 'S')
          strcpy(extent, ".S\t");
        else if (tokenEnd[1] == 'L')
          strcpy(extent, ".L\t");
        else {
          NEWERROR(*errorPtr, SYNTAX);
        }
      } else {
        strcpy(extent, "\t");
      }

      // determine size of CMP
      if (token[2][0] == '.') {
        if (token[2][1] == 'B')
          strcpy(sizeStr, ".B\t");
        else if (token[2][1] == 'W')
          strcpy(sizeStr, ".W\t");
        else if (token[2][1] == 'L')
          strcpy(sizeStr, ".L\t");
        else {
          NEWERROR(*errorPtr, SYNTAX);
        }
      } else
        strcpy(sizeStr, ".W\t");

      snprintf(stcLine, sizeof(stcLine), "\tMOVE%s%s,%s\n", sizeStr, token[n+2], token[n]);
      if ((strcmp(token[n+2],token[n])))  // if op1 != op2 (FOR D1 = D1 TO ... skips move)
        assembleStc(stcLine);             // MOVE op2,op1

      snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelF);
      stcLabelF++;
      snprintf(stcLabel2, sizeof(stcLabel2), "_%08X", stcLabelF);
      snprintf(stcLine, sizeof(stcLine), "\tBRA%s%s\n", extent, stcLabel2);
      assembleStc(stcLine);               //   BRA _20000001
      stcPush(stcLabelF);                 // push _20000001

      snprintf(stcLine, sizeof(stcLine), "%s\n", stcLabel);
      assembleStc(stcLine);               // _20000000

      if (!(strcmp(token[n+3], "DOWNTO")))
        snprintf(stcLine, sizeof(stcLine), "\tBGE%s%s\n", extent, stcLabel);
      else
        snprintf(stcLine, sizeof(stcLine), "\tBLE%s%s\n", extent, stcLabel);
      forPush(stcLine);                   // push Bcc _20000000

      snprintf(stcLine, sizeof(stcLine), "\tCMP%s%s,%s\n", sizeStr, token[n+4], token[n]);
      forPush(stcLine);                   // push CMP instruction

      if (!(strcmp(token[n+5], "BY")))
        if (!(strcmp(token[n+3], "DOWNTO")))
          snprintf(stcLine, sizeof(stcLine), "\tSUB%s%s,%s\n", sizeStr, token[n+6], token[n]);
        else
          snprintf(stcLine, sizeof(stcLine), "\tADD%s%s,%s\n", sizeStr, token[n+6], token[n]);
      else
        if (!(strcmp(token[n+3], "DOWNTO")))
          snprintf(stcLine, sizeof(stcLine), "\tSUB%s#1,%s\n", sizeStr, token[n]);
        else
          snprintf(stcLine, sizeof(stcLine), "\tADD%s#1,%s\n", sizeStr, token[n]);
      forPush(stcLine);                   // push SUB/ADD instruction

      stcLabelF++;                        // ready for next For instruction
      skipList = true;                    // don't display this line in ASSEMBLE.CPP
    }

    // -------------------- ENDF --------------------
    if (!(strcmp(token[1], "ENDF"))) {
      unsigned int endfLbl = stcTop();
      stcPop();
      if ((endfLbl & stcMask) != stcMaskF)  // if label is not from a FOR
        NEWERROR(*errorPtr, NO_FOR);
      else {
        strcpy(stcLine, forTop());
        assembleStc(stcLine);               //   ADD|SUB op4,op1  or  ADD|SUB #1,op1
        forPop();

        snprintf(stcLine, sizeof(stcLine), "_%08X\n", endfLbl);
        assembleStc(stcLine);               // _20000001

        strcpy(stcLine, forTop());
        assembleStc(stcLine);               //   CMP op3,op1
        forPop();

        strcpy(stcLine, forTop());
        assembleStc(stcLine);               //   BLT .2  or  BGT .2
        forPop();
      }
      skipList = true;                        // don't display this line in ASSEMBLE.CPP
    }

    // -------------------- DBLOOP --------------------
    // DBLOOP op1 = op2
    if (!(strcmp(token[1], "DBLOOP"))) {
      if (token[2][0] != 'D')
        NEWERROR(*errorPtr, SYNTAX);      // syntax must be DBLOOP Dn =
      if (token[2][1] < '0' || token[2][1] > '9' || token[3][0] != '=')
        NEWERROR(*errorPtr, SYNTAX);      // syntax must be DBLOOP Dn =
      dbPush(token[2][1]);                // push Dn number
      snprintf(stcLine, sizeof(stcLine), "\tMOVE\t%s,%s\n", token[4], token[2]);
      if ((strcmp(token[2],token[4])))    // if op1 != op2 (DBLOOP D0 = D0 ... skips move)
        assembleStc(stcLine);             //   MOVE op2,op1
      snprintf(stcLabel, sizeof(stcLabel), "_%08X", stcLabelD);
      snprintf(stcLine, sizeof(stcLine), "%s\n", stcLabel);
      assembleStc(stcLine);
      stcPush(stcLabelD);
      stcLabelD++;
      skipList = true;                        // don't display this line in ASSEMBLE.CPP
    }

    // -------------------- UNLESS --------------------
    // UNLESS[.B|.W|.L] op1 <cc> op2]
    if (!(strcmp(token[1], "UNLESS"))) {     // UNLESS
      unsigned int unlessLbl = stcTop();
      stcPop();
      if ((unlessLbl & stcMask) != stcMaskD)       // if label is not from a DBLOOP
        NEWERROR(*errorPtr, NO_DBLOOP);
      snprintf(stcLabel, sizeof(stcLabel), "\tD%c,_%08X", dbTop(), unlessLbl);
      dbPop();

      // UNLESS <F> and UNLESS use DBRA
      if ( !(strcmp(token[n], "<F>")) || token[2][0] == '\0') {
        snprintf(stcLine, sizeof(stcLine), "\tDBRA%s\n", stcLabel);
        assembleStc(stcLine);
      } else {
        // determine size of CMP
        if (token[2][0] == '.') {
          if (token[2][1] == 'B')
            strcpy(sizeStr, ".B\t");
          else if (token[2][1] == 'W')
            strcpy(sizeStr, ".W\t");
          else if (token[2][1] == 'L')
            strcpy(sizeStr, ".L\t");
          else
            NEWERROR(*errorPtr, SYNTAX);
        } else
          strcpy(sizeStr, ".W\t");

        if (token[n][0] == '<') {                      // UNLESS <cc>
          snprintf(stcLine, sizeof(stcLine), "\tD%s%s\n", getBcc(token[n],IF_CC,0), stcLabel);
          assembleStc(stcLine);
        }else if (token[n][0] == '#') {                // UNLESS #nn <cc> ea
          snprintf(stcLine, sizeof(stcLine), "\tCMP%s%s,%s\n", sizeStr, token[n], token[n+2]);
          assembleStc(stcLine);
          snprintf(stcLine, sizeof(stcLine), "\tD%s%s\n", getBcc(token[n+1],IM_EA,0), stcLabel);
          assembleStc(stcLine);
        }else if (token[n+2][0] == '#') {                // UNLESS ea <cc> #nn
          snprintf(stcLine, sizeof(stcLine), "\tCMP%s%s,%s\n", sizeStr, token[n+2], token[n]);
          assembleStc(stcLine);
          snprintf(stcLine, sizeof(stcLine), "\tD%s%s\n", getBcc(token[n+1],EA_IM,0), stcLabel);
          assembleStc(stcLine);
        // UNLESS Rn <cc> ea
        }else if ((token[n][0]=='A' || token[n][0]=='D') && isRegNum(token[n][1])) {
          snprintf(stcLine, sizeof(stcLine), "\tCMP%s%s,%s\n", sizeStr, token[n+2], token[n]);
          assembleStc(stcLine);
          snprintf(stcLine, sizeof(stcLine), "\tD%s%s\n", getBcc(token[n+1],RN_EA,0), stcLabel);
          assembleStc(stcLine);
        // UNLESS ea <cc> Rn
        }else if ((token[n+2][0]=='A' || token[n+2][0]=='D') && isRegNum(token[n+2][1])) {
          snprintf(stcLine, sizeof(stcLine), "\tCMP%s%s,%s\n", sizeStr, token[n], token[n+2]);
          assembleStc(stcLine);
          snprintf(stcLine, sizeof(stcLine), "\tD%s%s\n", getBcc(token[n+1],EA_RN,0), stcLabel);
          assembleStc(stcLine);
        }else{
          NEWERROR(*errorPtr, SYNTAX);
        }
      }
      skipList = true;                        // don't display this line in ASSEMBLE.CPP
    }
  }
  return NORMAL;
}

void assembleStc(char* line)
{
  int error = OK;
  int i=0;
  while(lineIdent[i] && i<MACRO_NEST_LIMIT)
    i++;
  lineIdent[i]='s';     // line identifier for listing
  lineIdent[i+1]='\0';
  if (!SEXflag)
    skipList = true;
  else
    if (!(macroNestLevel > 0 && skipList == true)) // if not called from macro with listing off
      skipList = false;
  assemble(line, &error);
  lineIdent[i]='\0';
}
