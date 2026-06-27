/***********************************************************************
 *
 *      sim68k.c
 *      Command-line front end for the EASy68K simulator core (libsim68k).
 *
 *      Loads a 68000 S-record (.S68) into a fresh 16 MB address space and
 *      runs it to completion, with TRAP #15 console I/O on stdin/stdout.
 *      This is the headless equivalent of the Sim68K GUI's run loop.
 *
 ***********************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "def.h"          // MEMSIZE, SUCCESS
#include "simhost.h"

/* ---- simulator core entry points (run.c / startsim.c / simops2.c) ---- */
extern void initSim(void);
extern int  loadSrec(char *name);
extern int  runprog(void);

/* ---- simulator state (globals.c) ---- */
extern char     *memory;
extern int32_t   PC, OLD_PC;
extern int32_t   D[], A[];
extern short     SR;
extern uint64_t  cycles;
extern bool      halt, runMode, trace, sstep, stopInstruction;
extern int       exceptions;
extern bool      bitfield;

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s program.S68\n", argv[0]);
        return 2;
    }

    install_cli_host();

    /* Allocate the 68000's 16 MB address space. */
    memory = (char *)calloc(MEMSIZE, 1);
    if (!memory) {
        fprintf(stderr, "sim68k: out of memory allocating 68000 address space\n");
        return 1;
    }

    exceptions = 1;             // enable exception processing (vectored)
    bitfield   = true;          // allow 68020 bitfield instructions
    initSim();                  // reset CPU + simulator state

    if (loadSrec(argv[1]) != SUCCESS) {
        fprintf(stderr, "sim68k: failed to load '%s'\n", argv[1]);
        free(memory);
        return 1;
    }
    OLD_PC = PC;        // prime the current-instruction tracker to the start
                        // address so the first relative branch resolves right

    /* Run continuously until the program halts (SIMHALT / TRAP #15 task 9)
     * or a breakpoint forces trace mode. runprog() executes one instruction
     * per call and manages halt/trace/breakpoint state. */
    trace = false;
    sstep = false;
    halt  = false;
    stopInstruction = false;
    runMode = true;

    while (runMode && !halt)
        runprog();

    fprintf(stderr, "\n--- halted: PC=%08X  SR=%04X  cycles=%llu ---\n",
            (unsigned)PC, (unsigned short)SR, (unsigned long long)cycles);

    free(memory);
    return 0;
}
