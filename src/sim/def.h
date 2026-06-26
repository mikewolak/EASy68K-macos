//---------------------------------------------------------------------------
//   Author: Charles Kelly
//           www.easy68k.com
//---------------------------------------------------------------------------
#ifndef defH
#define defH

#include <stdio.h>
#include "../common/port68k.h"

/***************************** 68000 SIMULATOR ****************************
File Name: DEF.H
This file contains definitions used in the simulator source files.
***************************************************************************/
#define uint unsigned int
#define ushort unsigned short
#define uchar unsigned char
typedef unsigned char byte;     // VCL 'byte' type used by the hardware sim
//typedef unsigned int uint;
//typedef unsigned short ushort;
//typedef unsigned char uchar;

// version info
static const char TITLE[] = "EASy68K Simulator v5.16.1"; // ***** change both *****
enum { VERSION = 0x00051001 };    // ***** change both *****

// memory map types (bit flags which may be combined with OR logic)
typedef enum maptype {Invalid=0x01, Protected=0x02, Read=0x04, Rom=0x10} maptype;

// status register bitmasks

enum { bit_1 = 0x0001 };
enum { bit_2 = 0x0002 };
enum { bit_3 = 0x0004 };
enum { bit_4 = 0x0008 };
enum { bit_5 = 0x0010 };
enum { bit_6 = 0x0020 };
enum { bit_7 = 0x0040 };
enum { bit_8 = 0x0080 };
enum { bit_9 = 0x0100 };
enum { bit_10 = 0x0200 };
enum { bit_11 = 0x0400 };
enum { bit_12 = 0x0800 };


enum { cbit = 0x0001 };
enum { vbit = 0x0002 };
enum { zbit = 0x0004 };
enum { nbit = 0x0008 };
enum { xbit = 0x0010 };
enum { intmsk = 0x0700 };       // three bits
enum { sbit = 0x2000 };
enum { tbit = 0x8000 };


// misc
enum { MEMSIZE = 0x01000000 };   // 16 Meg address space
enum { ADDRMASK = 0x00ffffff };

enum { BYTE_MASK = 0xff };         // byte mask
enum { WORD_MASK = 0xffff };       // word mask
#define LONG_MASK (0xffffffff)   // int32_t mask


enum { D_REGS = 8 };            // number of D registers
enum { A_REGS = 9 };            // number of A registers


// Possible addressing modes permitted by an instruction
// Each bit represents a different addressing mode.
// For example CONTROL_ADDR = 0x07e4 which means the following addressing
// modes are permitted.
// Imm d[PC,Xi] d[PC] Abs.L Abs.W d[An,Xi] d[An] -[An] [An]+ [An] An Dn
//  0      1      1     1     1      1       1     0     0     1   0  0
enum { DATA_ADDR = 0x0ffd };
enum { MEMORY_ADDR = 0x0ffc };
enum { CONTROL_ADDR = 0x07e4 };
enum { ALTERABLE_ADDR = 0x01ff };
enum { ALL_ADDR = 0x0fff };
enum { DATA_ALT_ADDR = (DATA_ADDR & ALTERABLE_ADDR) };
enum { MEM_ALT_ADDR = (MEMORY_ADDR & ALTERABLE_ADDR) };
enum { CONT_ALT_ADDR = (CONTROL_ADDR & ALTERABLE_ADDR) };


/* these are the instruction return codes */

enum { SUCCESS = 0x0000 };
enum { BAD_INST = 0x0001 };
enum { NO_PRIVILEGE = 0x0002 };
enum { CHK_EXCEPTION = 0x0003 };
//const int ILLEGAL_TRAP		= 0x0004;
enum { STOP_TRAP = 0x0005 };
enum { TRAPV_TRAP = 0x0006 };
enum { TRAP_TRAP = 0x0007 };
enum { DIV_BY_ZERO = 0x0008 };
enum { USER_BREAK = 0x0009 };
enum { BUS_ERROR = 0x000A };
enum { ADDR_ERROR = 0x000B };
enum { LINE_1010 = 0x000C };
enum { LINE_1111 = 0x000D };
enum { TRACE_EXCEPTION = 0x000E };
enum { ROM_MAP = 0x000F };
enum { FAILURE = 0x1111 };	// general failure


// these are the cases for condition code setting

enum { N_A = 0 };
enum { GEN = 1 };
enum { ZER = 2 };
enum { UND = 3 };
enum { CASE_1 = 4 };
enum { CASE_2 = 5 };
enum { CASE_3 = 6 };
enum { CASE_4 = 7 };
enum { CASE_5 = 8 };
enum { CASE_6 = 9 };
enum { CASE_7 = 10 };
enum { CASE_8 = 11 };
enum { CASE_9 = 12 };


// these are used in run.c

enum { MODE_MASK = 0x0038 };
enum { REG_MASK = 0x0007 };
enum { FIRST_FOUR = 0xf000 };

enum { READ = 0xffff };
enum { WRITE = 0x0000 };


// conditions for BCC, DBCC, and SCC

enum { COND_T = 0x00 };
enum { COND_F = 0x01 };
enum { COND_HI = 0x02 };
enum { COND_LS = 0x03 };
enum { COND_CC = 0x04 };
enum { COND_CS = 0x05 };
enum { COND_NE = 0x06 };
enum { COND_EQ = 0x07 };
enum { COND_VC = 0x08 };
enum { COND_VS = 0x09 };
enum { COND_PL = 0x0a };
enum { COND_MI = 0x0b };
enum { COND_GE = 0x0c };
enum { COND_LT = 0x0d };
enum { COND_GT = 0x0e };
enum { COND_LE = 0x0f };


// file handling error codes
enum { F_SUCCESS = 0 };
enum { F_EOF = 1 };
enum { F_ERROR = 2 };
enum { F_READONLY = 3 };

enum { MAXFILES = 8 };         // maximun files that may be open at one time

typedef struct FileStruct {
  FILE *fp;                     // file pointer
  char name[256];               // file name
} FileStruct;

// simulator log types
enum { DISABLED = 0 };
enum { INSTRUCTION = 1 };
enum { REGISTERS = 2 };
enum { INST_REG_MEM = 3 };
enum { TEXTONLY = 1 };
// LogfileDialog returns
//const int CANCEL =  mrCancel;           // must be non-zero for modal form returns
//const int APPEND = mrAll;
//const int REPLACE = mrOk;

//////////////////////////////////
// DEBUG / Breakpoint definitions
//////////////////////////////////

enum { MAX_BPOINTS = 100 };
enum { MAX_BP_EXPR = 50 };
enum { MAX_LB_NODES = 10 };

// Define logical operator types
enum { AND_OP = 0 };
enum { OR_OP = 1 };

enum { LPAREN = MAX_BPOINTS + OR_OP + 1 };
enum { RPAREN = LPAREN + 1 };

// BPoint IDs are shared between PC/Reg and ADDR breakpoints.
// This constant is used to jump to the ADDR range.
// (It's ok to have unused breakPoints array elements .. see extern.h)
enum { ADDR_ID_OFFSET = 50 };

enum { MAX_REG_ROWS = 50 };
enum { MAX_ADDR_ROWS = 50 };
enum { MAX_EXPR_ROWS = 50 };

// Stored in fields of BPoint objects
enum { PC_REG_TYPE = 0 };
enum { ADDR_TYPE = 1 };

enum { D0_TYPE_ID = 0 };
enum { D1_TYPE_ID = 1 };
enum { D2_TYPE_ID = 2 };
enum { D3_TYPE_ID = 3 };
enum { D4_TYPE_ID = 4 };
enum { D5_TYPE_ID = 5 };
enum { D6_TYPE_ID = 6 };
enum { D7_TYPE_ID = 7 };
enum { A0_TYPE_ID = 8 };
enum { A1_TYPE_ID = 9 };
enum { A2_TYPE_ID = 10 };
enum { A3_TYPE_ID = 11 };
enum { A4_TYPE_ID = 12 };
enum { A5_TYPE_ID = 13 };
enum { A6_TYPE_ID = 14 };
enum { A7_TYPE_ID = 15 };
enum { PC_TYPE_ID = 16 };
enum { DEFAULT_TYPE_ID = PC_TYPE_ID };

enum { EQUAL_OP = 0 };         // ==
enum { NOT_EQUAL_OP = 1 };     // !=
enum { GT_OP = 2 };            // >
enum { GT_EQUAL_OP = 3 };      // >=
enum { LT_OP = 4 };            // <
enum { LT_EQUAL_OP = 5 };      // <=
enum { NA_OP = 6 };            // NA
enum { DEFAULT_OP = EQUAL_OP };

enum { BYTE_SIZE = 0 };
enum { WORD_SIZE = 1 };
enum { LONG_SIZE = 2 };
enum { DEFAULT_SIZE = LONG_SIZE };

enum { RW_TYPE = 0 };
enum { READ_TYPE = 1 };
enum { WRITE_TYPE = 2 };
enum { NA_TYPE = 3 };
enum { DEFAULT_TYPE = RW_TYPE };

enum { EXPR_ON = 0 };
enum { EXPR_OFF = 1 };

enum { SREC_MAX = 515 };       // maximum buffer size for S-Record

enum { MAX_COMM = 16 };        // maximum number of comm ports supported
enum { MAX_SERIAL_IN = 256 };  // maximum size of serial input buffer

//Default window locations and sizes.
enum { FORM1_TOP = 100 };          // Form1 Top
enum { FORM1_LEFT = 100 };         // Form1 Left
enum { SIMIO_FORM_TOP = 300 };     // SimIO Form Top
enum { SIMIO_FORM_LEFT = 200 };    // SimIO Form Left
enum { MEMORY_FORM_TOP = 80 };     // Memory Form Top
enum { MEMORY_FORM_LEFT = 280 };   // Memory Form Left
enum { STACK_FORM_TOP = 200 };     // Stack Form Top
enum { STACK_FORM_LEFT = 40 };     // Stack Form Left
enum { STACK_FORM_HEIGHT = 538 };  // Stack Form Height
enum { HARDWARE_FORM_TOP = 100 };  // Hardware Form Top
enum { HARDWARE_FORM_LEFT = 240 }; // Hardware Form Left

#endif
