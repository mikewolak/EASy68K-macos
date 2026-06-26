/***********************************************************************
 *
 *      port68k.c
 *      Default implementations of the C99 portability host hooks.
 *
 ***********************************************************************/
#include "port68k.h"

static void default_error_handler(const char *message, const char *title)
{
    fprintf(stderr, "%s: %s\n", title ? title : "Error", message ? message : "");
}

static host_error_fn g_error_handler = default_error_handler;

void host_set_error_handler(host_error_fn fn)
{
    g_error_handler = fn ? fn : default_error_handler;
}

void hostError(const char *message, const char *title)
{
    if (g_error_handler)
        g_error_handler(message, title);
}

static void default_report_error(int lineNum, const char *message,
                                 const char *includeFile)
{
    if (includeFile && includeFile[0])
        fprintf(stderr, "%s ", includeFile);
    if (lineNum >= 0)
        fprintf(stderr, "Line %d: ", lineNum);
    fprintf(stderr, "%s\n", message ? message : "");
}

static host_report_error_fn g_report_error_handler = default_report_error;

void host_set_report_error_handler(host_report_error_fn fn)
{
    g_report_error_handler = fn ? fn : default_report_error;
}

void hostReportError(int lineNum, const char *message, const char *includeFile)
{
    if (g_report_error_handler)
        g_report_error_handler(lineNum, message, includeFile);
}

static void default_assemble_done(int warnings, int errors)
{
    (void)warnings;
    (void)errors;
}

static host_assemble_done_fn g_assemble_done_handler = default_assemble_done;

void host_set_assemble_done_handler(host_assemble_done_fn fn)
{
    g_assemble_done_handler = fn ? fn : default_assemble_done;
}

void hostAssembleDone(int warnings, int errors)
{
    if (g_assemble_done_handler)
        g_assemble_done_handler(warnings, errors);
}
