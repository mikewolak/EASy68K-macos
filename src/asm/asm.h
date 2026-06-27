/***********************************************************************
 *
 *		ASM.H
 *		Global Definitions for 68000 Assembler
 *
 *      Author: Paul McKee
 *		ECE492    North Carolina State University
 *
 *        Date:	12/13/86
 *
 *    Modified: Charles Kelly
 *              Monroe County Community College
 *              http://www.monroeccc.edu/ckelly
 *
 ************************************************************************/
#ifndef asmH
#define asmH


/* include system header files for prototype checking */
#include "../common/port68k.h"

/* fgets that also strips CR, so Windows (CRLF) source files tokenize correctly
 * on macOS/Unix (a stray \r would otherwise corrupt the last token on a line). */
char *fgetsNoCR(char *s, int n, FILE *f);

/* Directory of the main source file (with trailing separator), so INCLUDE
 * resolves relative to the source, not the current working directory. */
extern char sourceDir[256];

/* Define a couple of useful tests */

#define isTerm(c)   (c == ',' || c == '/' || c == '-' || isspace(c) || !c || c == '{')
#define isRegNum(c) ((c >= '0') && (c <= '7'))

static const char VERSION[] = "5.16.01";  // don't forget to change version.txt on easy68k.com
static const char TITLE[] = "EASy68K Editor/Assembler v5.16.01";

/* Status values */

/* These status values are 12 bits long with
   a severity code in the upper 4 bits */

enum { OK = 0x00 };

/* Severe errors */
enum { SEVERE = 0x400 };
enum { SYNTAX = 0x401 };
enum { INV_OPCODE = 0x402 };
enum { INV_ADDR_MODE = 0x403 };
enum { LABEL_REQUIRED = 0x404 };
enum { NO_ENDM = 0x405 };
enum { TOO_MANY_ARGS = 0x406 };
enum { INVALID_ARG = 0x407 };
enum { COMMA_EXPECTED = 0x408 };
enum { PHASE_ERROR = 0x409 };
enum { FILE_ERROR = 0x40A };
enum { MACRO_NEST = 0x40B };
enum { NO_IF = 0x40C };
enum { NO_WHILE = 0x40D };
enum { NO_REPEAT = 0x40E };
enum { NO_FOR = 0x40F };
enum { ENDI_EXPECTED = 0x410 };
enum { ENDW_EXPECTED = 0x411 };
enum { ENDF_EXPECTED = 0x412 };
enum { REPEAT_EXPECTED = 0x413 };
enum { LABEL_ERROR = 0x414 };
enum { NO_DBLOOP = 0x415 };
enum { DBLOOP_EXPECTED = 0x416 };
enum { BAD_BITFIELD = 0x417 };
enum { ILLEGAL_SYMBOL = 0x418 };

enum { EXCEPTION = 0x999 };


/* Errors */
enum { ERRORN = 0x300 };
enum { UNDEFINED = 0x301 };
enum { DIV_BY_ZERO = 0x302 };
enum { MULTIPLE_DEFS = 0x303 };
enum { REG_MULT_DEFS = 0x304 };
enum { REG_LIST_UNDEF = 0x305 };
enum { INV_FORWARD_REF = 0x306 };
enum { INV_LENGTH = 0x307 };

/* Minor errors */
enum { MINOR = 0x200 };
enum { INV_SIZE_CODE = 0x201 };
enum { INV_QUICK_CONST = 0x202 };
enum { INV_MOVE_QUICK_CONST = 0x203 };
enum { INV_VECTOR_NUM = 0x204 };
enum { INV_BRANCH_DISP = 0x205 };
enum { INV_DISP = 0x206 };
enum { INV_ABS_ADDRESS = 0x207 };
enum { INV_8_BIT_DATA = 0x208 };
enum { INV_16_BIT_DATA = 0x209 };
enum { NOT_REG_LIST = 0x20A };
enum { REG_LIST_SPEC = 0x20B };
enum { INV_SHIFT_COUNT = 0x20C };
enum { INV_OPERATOR = 0x20D };
enum { FAIL_ERROR = 0x20E };        // user defined

/* Warnings */
enum { WARNING = 0x100 };
enum { ASCII_TOO_BIG = 0x101 };
enum { NUMBER_TOO_BIG = 0x102 };
enum { INCOMPLETE = 0x103 };
enum { FORCING_SHORT = 0x104 };
enum { ODD_ADDRESS = 0x105 };
enum { END_MISSING = 0x106 };
enum { ADDRESS_MISSING = 0x107 };
enum { THEN_EXPECTED = 0x108 };
enum { DO_EXPECTED = 0x109 };
enum { FORWARD_REF = 0x10A };
enum { LABEL_TOO_LONG = 0x10B };


enum { SEVERITY = 0xF00 };

/* The NEWERROR macros updates the error variable var only if the
   new error code is more severe than all previous errors.  Throughout
   ASM this is the standard means of reporting errors. */

//#define NEWERROR(var, code)	if ((code & SEVERITY) > var) var = code
// ck: the previous line was causing errors when placed inside if-else
#define NEWERROR(var, code)      var = ((code & SEVERITY) > var) ? code : var


/* Symbol table definitions */

enum { SIGCHARS = 33 };        // significant characters in symbol
enum { MAX_ARGS = 36 };        // maximum number of macro arguments
enum { ARG_SIZE = 256 };       // maximum size of each argument

/* Structure for operand descriptors */
typedef struct opDescriptor
{
  int  mode;	// Mode number (see below)
  int  data;	// IMMEDIATE value, displacement, or absolute address
  int  field;   // for bitField instructions
  char reg;	// Principal register number (0-7)
  char index;	// Index register number (0-7 = D0-D7, 8-15 = A0-A7)
  char size;	// Size of index register (WORD or LONG, see below)
                // or forced size of IMMEDIATE instruction
                // BYTE_SIZE, WORD_SIZE, LONG_SIZE
                // Also used to prevent MOVEQ, ADDQ & SUBQ optimizations (see OPPARSE.CPP)
  bool backRef;	// True if data field is known on first pass
} opDescriptor;


/* Structure for a symbol table entry */
typedef struct symbolEntry {
	int value;			/* 32-bit value of the symbol */
	struct symbolEntry *next;	/* Pointer to next symbol in linked list */
	char flags;			/* Flags (see below) */
	char name[SIGCHARS+1];		/* Name */
	} symbolDef;

/* Flag values for the "flags" field of a symbol */
enum { BACKREF = 0x01 };	/* Set when the symbol is defined on the 2nd pass */
enum { REDEFINABLE = 0x02 };	/* Set for symbols defined by the SET directive */
enum { REG_LIST_SYM = 0x04 };	/* Set for symbols defined by the REG directive */
enum { MACRO_SYM = 0x08 };    // Set for macros
enum { DS_SYM = 0x10 };    // Set for labels defined with DS directive

/* Instruction table definitions */

/* Structure to describe one "flavor" of an instruction */

typedef struct {
	int source,		/* Bit masks for the legal source...	*/
	    dest;		/*  and destination addressing modes	*/
	char sizes;		/* Bit mask for the legal sizes */
	int (*exec)(int, int, opDescriptor *, opDescriptor *, int *);
                                /* Pointer to routine to build the instruction */
	short int bytemask,	/* Skeleton instruction masks for byte size...  */
		  wordmask,	/*  word size, ...			        */
		  longmask;	/*  and long sizes of the instruction	        */
	} flavor;


/* Structure for the instruction table */
typedef struct {
	char *mnemonic;		/* Mnemonic */
	flavor *flavorPtr;	/* Pointer to flavor list */
	char flavorCount;	/* Number of flavors in flavor list */
	bool parseFlag;		/* Should assemble() parse the operands? */
	int (*exec)(int, char *, char *, int *);
			/* Routine to be called if parseFlag is FALSE */
	} instruction;


/* Addressing mode codes/bitmasks */

enum { DnDirect = 0x00001 };
enum { AnDirect = 0x00002 };
enum { AnInd = 0x00004 };
enum { AnIndPost = 0x00008 };
enum { AnIndPre = 0x00010 };
enum { AnIndDisp = 0x00020 };
enum { AnIndIndex = 0x00040 };
enum { AbsShort = 0x00080 };
enum { AbsLong = 0x00100 };
enum { PCDisp = 0x00200 };
enum { PCIndex = 0x00400 };
enum { IMMEDIATE = 0x00800 };
enum { SRDirect = 0x01000 };
enum { CCRDirect = 0x02000 };
enum { USPDirect = 0x04000 };
enum { SFCDirect = 0x08000 };
enum { DFCDirect = 0x10000 };
enum { VBRDirect = 0x20000 };


/* Register and operation size codes/bitmasks */

//const int BYTE	((int) 1)
//const int WORD	((int) 2)
//const int LONG	((int) 4)
//const int SHORT	((int) 8)

enum { BYTE_SIZE = 1 };
enum { WORD_SIZE = 2 };
enum { LONG_SIZE = 4 };
enum { SHORT_SIZE = 8 };

// upper limit of 68000 memory
enum { MEM_SIZE = 0x00FFFFFF };

// function return codes
enum { NORMAL = 0 };
enum { MILD_ERROR = 1 };
enum { CRITICAL = 2 };

// tab types
typedef enum tabTypes{ Assembly, Fixed } tabTypes;

enum { TAB1 = 12 };          // tab positions for smart tabs (in characters)
enum { TAB2 = 20 };
enum { TAB3 = 44 };

enum { MACRO_NEST_LIMIT = 256 };  // nesting level limit

// syntax highlight
typedef struct
{
  TColor color;
  bool   bold;
  bool   italic;
  bool   underline;
} FontStyle;

static const TColor DEFAULT_CODE_COLOR = clBlack;
static const TColor DEFAULT_UNKNOWN_COLOR = clOlive;
static const TColor DEFAULT_DIRECTIVE_COLOR = clGreen;
static const TColor DEFAULT_COMMENT_COLOR = clBlue;
static const TColor DEFAULT_LABEL_COLOR = clPurple;
static const TColor DEFAULT_STRUCTURE_COLOR = clMaroon;
static const TColor DEFAULT_ERROR_COLOR = clRed;
static const TColor DEFAULT_TEXT_COLOR = clTeal;
static const TColor DEFAULT_BACK_COLOR = clWhite;

static const char NEW_PAGE_MARKER[] = "<------------------------------ PAGE ------------------------------>";

// function prototype definitions
#include "proto.h"

#endif
