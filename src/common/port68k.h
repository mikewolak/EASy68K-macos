/***********************************************************************
 *
 *      port68k.h
 *      C99 portability shim for the EASy68K macOS port.
 *
 *      The original EASy68K core was built with Borland C++ Builder and
 *      leaned on the VCL (vcl.h, system.hpp) for a few small things:
 *        - the AnsiString string class
 *        - Application->MessageBox(...) error popups
 *        - the TColor type + cl* colour constants (editor syntax colours)
 *
 *      This header provides plain-C99 stand-ins so the assembler and
 *      simulator cores build with a normal C compiler, with no GUI
 *      dependency. The Cocoa GUI supplies real implementations of the
 *      host hooks; the CLI tools supply simple stderr-based ones.
 *
 ***********************************************************************/
#ifndef PORT68K_H
#define PORT68K_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdbool.h>
#include <stdint.h>
#include <time.h>
#include <strings.h>   /* strcasecmp / strncasecmp */

/* Borland C++ Builder spelled the case-insensitive string compares strcmpi /
 * strncmpi; the C standard library on macOS uses strcasecmp / strncasecmp. */
#define strcmpi  strcasecmp
#define strncmpi strncasecmp
#define stricmp  strcasecmp
#define strnicmp strncasecmp

/* ------------------------------------------------------------------ *
 *  Editor colour types (only meaningful to the GUI; the core merely
 *  stores them in option structs). Represented as 0x00BBGGRR like the
 *  VCL TColor, but the assembler never interprets the value.
 * ------------------------------------------------------------------ */
typedef uint32_t TColor;

#define clBlack   0x000000
#define clWhite   0xFFFFFF
#define clRed     0x0000FF
#define clGreen   0x008000
#define clBlue    0xFF0000
#define clOlive   0x008080
#define clPurple  0x800080
#define clMaroon  0x000080
#define clTeal    0x808000
#define clGray    0x808080

/* Win32 MessageBox flag, kept so legacy call sites read naturally. */
#ifndef MB_OK
#define MB_OK 0
#endif

/* ------------------------------------------------------------------ *
 *  Host hooks. The core reports user-facing errors through hostError()
 *  instead of Application->MessageBox(). A host (CLI or Cocoa app)
 *  installs a callback; the default prints to stderr.
 * ------------------------------------------------------------------ */
typedef void (*host_error_fn)(const char *message, const char *title);

void host_set_error_handler(host_error_fn fn);
void hostError(const char *message, const char *title);

/* Report an assembly diagnostic (error or warning) to the host UI. In the
 * original Borland build this populated the editor's clickable error list;
 * the Cocoa app installs a handler that does the same. The CLI default
 * prints to stderr.
 *   lineNum     : source line number, or -1 if none
 *   message     : human-readable text (trailing newline already trimmed)
 *   includeFile : name of the include file the error is in, or "" for the
 *                 main source file
 */
typedef void (*host_report_error_fn)(int lineNum, const char *message,
                                      const char *includeFile);

void host_set_report_error_handler(host_report_error_fn fn);
void hostReportError(int lineNum, const char *message, const char *includeFile);

/* Called when an assembly finishes, with the final warning and error counts.
 * In the Borland build this updated the Assembler dialog's status labels and
 * enabled the Execute button; the Cocoa app installs an equivalent handler.
 * The CLI default does nothing (it reports counts itself). */
typedef void (*host_assemble_done_fn)(int warnings, int errors);

void host_set_assemble_done_handler(host_assemble_done_fn fn);
void hostAssembleDone(int warnings, int errors);

#endif /* PORT68K_H */
