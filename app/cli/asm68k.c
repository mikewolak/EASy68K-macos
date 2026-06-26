/***********************************************************************
 *
 *      asm68k.c
 *      Command-line front end for the EASy68K assembler core (libasm68k).
 *
 *      Assembles a 68000 .X68 source file, producing an .S68 S-record file
 *      and an .L68 listing file, exactly as the EASy68K editor's
 *      "Assemble" command does. This is the headless equivalent of the
 *      Edit68K GUI's mnuDoAssemblerClick() handler.
 *
 ***********************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libgen.h>

#include "asm.h"
#include "port68k.h"

/* Assembler option flags (defined in globals.c). The editor sets these from
 * the Options dialog before each assembly; we set them from CLI switches. */
extern bool listFlag;   // create .L68 listing file
extern bool objFlag;    // create .S68 S-record file
extern bool CEXflag;    // expand constants in listing
extern bool BITflag;    // assemble bitfield instructions
extern bool CREflag;    // add cross-reference symbol table to listing
extern bool MEXflag;    // expand macro calls in listing
extern bool SEXflag;    // expand structured code in listing
extern bool WARflag;    // show warnings

extern int errorCount, warningCount;

static void usage(const char *prog)
{
    fprintf(stderr,
        "EASy68K assembler (%s)\n"
        "usage: %s [options] source.X68\n"
        "\n"
        "  Produces source.S68 (S-record) and source.L68 (listing).\n"
        "\n"
        "options:\n"
        "  -l, --no-list      do not generate the .L68 listing file\n"
        "  -s, --no-srec      do not generate the .S68 S-record file\n"
        "  -c, --expand-const expand constants in the listing\n"
        "  -b, --bitfield     enable 68020 bitfield instructions\n"
        "  -x, --cross-ref    append cross-reference symbol table to listing\n"
        "  -m, --expand-macro expand macro calls in the listing\n"
        "  -e, --expand-struc expand structured code in the listing\n"
        "  -w, --no-warnings  suppress warning messages\n"
        "  -h, --help         show this help\n",
        VERSION, prog);
}

int main(int argc, char **argv)
{
    /* Defaults match a standard EASy68K assemble: listing + S-record on,
     * warnings on, all expansion/cross-reference options off. */
    listFlag = true;
    objFlag  = true;
    CEXflag  = false;
    BITflag  = false;
    CREflag  = false;
    MEXflag  = false;
    SEXflag  = false;
    WARflag  = true;

    const char *sourcePath = NULL;

    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
        if (a[0] != '-') {
            if (sourcePath) { fprintf(stderr, "error: multiple source files given\n"); return 2; }
            sourcePath = a;
        } else if (!strcmp(a, "-l") || !strcmp(a, "--no-list"))      listFlag = false;
        else if (!strcmp(a, "-s") || !strcmp(a, "--no-srec"))        objFlag  = false;
        else if (!strcmp(a, "-c") || !strcmp(a, "--expand-const"))   CEXflag  = true;
        else if (!strcmp(a, "-b") || !strcmp(a, "--bitfield"))       BITflag  = true;
        else if (!strcmp(a, "-x") || !strcmp(a, "--cross-ref"))      CREflag  = true;
        else if (!strcmp(a, "-m") || !strcmp(a, "--expand-macro"))   MEXflag  = true;
        else if (!strcmp(a, "-e") || !strcmp(a, "--expand-struc"))   SEXflag  = true;
        else if (!strcmp(a, "-w") || !strcmp(a, "--no-warnings"))    WARflag  = false;
        else if (!strcmp(a, "-h") || !strcmp(a, "--help"))         { usage(argv[0]); return 0; }
        else { fprintf(stderr, "error: unknown option '%s'\n", a); usage(argv[0]); return 2; }
    }

    if (!sourcePath) { usage(argv[0]); return 2; }

    /* The assembler needs a writable temporary file for macro/structured-code
     * expansion (the editor used "EASy68Km.tmp" beside the source). */
    char tempPath[1024];
    snprintf(tempPath, sizeof(tempPath), "%s.easytmp", sourcePath);

    int rc = assembleFile((char *)sourcePath, tempPath, sourcePath);

    remove(tempPath);   /* clean up the expansion temp file */

    if (rc == SEVERE) {
        fprintf(stderr, "asm68k: could not assemble '%s'\n", sourcePath);
        return 1;
    }

    printf("%s: %d error%s, %d warning%s\n",
           sourcePath,
           errorCount,   errorCount   == 1 ? "" : "s",
           warningCount, warningCount == 1 ? "" : "s");

    return errorCount > 0 ? 1 : 0;
}
