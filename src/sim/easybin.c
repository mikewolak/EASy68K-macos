/*
 * EASy68K for macOS
 *
 * Copyright (c) 2026 mikewolak@gmail.com  —  Epromfoundry, Inc.
 * All rights reserved.
 *
 * ****  NOT FOR COMMERCIAL USE  ****
 * This software is licensed for PERSONAL and EDUCATIONAL use ONLY.
 */

/*
 * easybin.c — C99 port of EASyBIN v2.5.0 fileIO.cpp (Chuck Kelly).
 * Operates on a private 16 MB buffer, independent of the simulator's memory.
 */
#include "easybin.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAXBUF 1024

static unsigned char *ebMem = NULL;

unsigned char *eb_memory(void) {
    if (!ebMem) ebMem = (unsigned char *)calloc(EB_MEMSIZE, 1);
    return ebMem;
}
unsigned int eb_memsize(void) { return EB_MEMSIZE; }
void eb_clear(void) { if (ebMem) memset(ebMem, 0, EB_MEMSIZE); }

/* ---------------------------------------------------------------- load S-rec */
int eb_load_srec(const char *path,
                 unsigned int *outLow, unsigned int *outHigh, unsigned int *outStart,
                 char *s0desc, int s0len, char *err, int errlen)
{
    unsigned char *memory = eb_memory();
    FILE *fp = fopen(path, "rt");
    if (!fp) { snprintf(err, errlen, "Cannot open file: %s", path); return -1; }

    char lbuf[MAXBUF];
    int line = 0, eof = 0, sRecError = 0;
    unsigned int loc, lowAddr = 0xFFFFFFFFu, highAddr = 0, startAddr = 0;
    char s_type = 0;
    if (s0desc && s0len) s0desc[0] = '\0';

    while (fgets(lbuf, MAXBUF, fp) != NULL) {
        char *bufptr = lbuf, *bufend;
        unsigned int byteVal;
        int bytecount = 0;
        line++;
        if (sscanf(lbuf, "S%c%2x", &s_type, &bytecount) < 1) { sRecError = 1; break; }
        bufptr += 4;                                   /* past 'S', type, count */

        switch (s_type) {
            case '0': {                                /* description record */
                for (bufend = bufptr; *bufend != '\0'; bufend++) ;
                bufptr += 4;                           /* skip empty address */
                while (sscanf(bufptr, "%2x", &byteVal) == 1) {
                    bufptr += 2;
                    if ((bufptr + 2) >= bufend) break;
                    char c = (byteVal >= ' ' && byteVal <= '~') ? (char)byteVal : '.';
                    int n = (int)strlen(s0desc ? s0desc : "");
                    if (s0desc && n < s0len - 1) { s0desc[n] = c; s0desc[n+1] = '\0'; }
                }
                break;
            }
            case '1': if (sscanf(bufptr, "%4x",  &loc) != 1) sRecError = 1; else bufptr += 4; break;
            case '2': if (sscanf(bufptr, "%6x",  &loc) != 1) sRecError = 1; else bufptr += 6; break;
            case '3': if (sscanf(bufptr, "%8x",  &loc) != 1) sRecError = 1; else bufptr += 8; break;
            case '5': break;                           /* record count — ignore */
            case '7': if (sscanf(bufptr, "%8x",  &loc) != 1) sRecError = 1; else { startAddr = loc; eof = 1; } break;
            case '8': if (sscanf(bufptr, "%6x",  &loc) != 1) sRecError = 1; else { startAddr = loc; eof = 1; } break;
            case '9': if (sscanf(bufptr, "%4x",  &loc) != 1) sRecError = 1; else { startAddr = loc; eof = 1; } break;
            default:  sRecError = 1;
        }
        if (eof || sRecError) break;

        for (bufend = bufptr; *bufend != '\0'; bufend++) ;
        while (sscanf(bufptr, "%2x", &byteVal) == 1) {
            bufptr += 2;
            if ((bufptr + 2) >= bufend) break;         /* last 2 chars = checksum */
            if (loc > (EB_MEMSIZE - 1)) {
                snprintf(err, errlen, "Address exceeds $FFFFFF on line %d", line);
                sRecError = 1; break;
            }
            if (loc < lowAddr)  lowAddr  = loc;
            if (loc > highAddr) highAddr = loc;
            memory[loc++] = (unsigned char)byteVal;
        }
        if (sRecError) break;
    }
    fclose(fp);

    if (sRecError) {
        if (!err[0]) snprintf(err, errlen, "Invalid data on line %d", line);
        return -1;
    }
    if (lowAddr == 0xFFFFFFFFu) { snprintf(err, errlen, "No data records found"); return -1; }
    if (outLow)   *outLow   = lowAddr;
    if (outHigh)  *outHigh  = highAddr;
    if (outStart) *outStart = startAddr ? startAddr : lowAddr;
    return 0;
}

/* --------------------------------------------------------------- load binary */
int eb_load_binary(const char *path, unsigned int firstAddr, int split,
                   char *err, int errlen)
{
    unsigned char *memory = eb_memory();
    FILE *fp = fopen(path, "rb");
    if (!fp) { snprintf(err, errlen, "Cannot open file: %s", path); return -1; }
    if (split == 0) split = 1;                         /* step 1, 2 or 4 */

    unsigned int addr = firstAddr;
    int size = 0, ch;
    while ((ch = fgetc(fp)) != EOF && addr < EB_MEMSIZE) {
        memory[addr] = (unsigned char)ch;
        addr += (unsigned)split;
        size += split;
    }
    fclose(fp);
    return size;
}

/* --------------------------------------------------------------- save binary */
/* Build "<base>_<n><ext>" from a path. */
static void split_name(const char *path, int n, char *out, int outlen) {
    const char *dot = strrchr(path, '.');
    const char *slash = strrchr(path, '/');
    if (dot && (!slash || dot > slash))
        snprintf(out, outlen, "%.*s_%d%s", (int)(dot - path), path, n, dot);
    else
        snprintf(out, outlen, "%s_%d", path, n);
}

int eb_save_binary(const char *path, unsigned int fromAddr, unsigned int length,
                   int split, char *err, int errlen)
{
    unsigned char *memory = eb_memory();
    unsigned int toAddr = fromAddr + length;           /* exclusive */
    if (length == 0 || toAddr > EB_MEMSIZE) {
        snprintf(err, errlen, "Invalid memory range."); return -1;
    }

    FILE *f[4] = {0,0,0,0};
    char nm[1100];
    if (split == 0) {
        f[0] = fopen(path, "wb");
    } else {
        split_name(path, 0, nm, sizeof nm); f[0] = fopen(nm, "wb");
        split_name(path, 1, nm, sizeof nm); f[1] = fopen(nm, "wb");
        if (split > 2) {
            split_name(path, 2, nm, sizeof nm); f[2] = fopen(nm, "wb");
            split_name(path, 3, nm, sizeof nm); f[3] = fopen(nm, "wb");
        }
    }
    int need = (split == 0) ? 1 : (split > 2 ? 4 : 2);
    for (int i = 0; i < need; i++)
        if (!f[i]) { snprintf(err, errlen, "Error creating output file.");
                     for (int j = 0; j < 4; j++) if (f[j]) fclose(f[j]); return -1; }

    if (split == 0) {
        fwrite(&memory[fromAddr], 1, length, f[0]);
    } else {
        unsigned int i = 0, last = toAddr - 1;          /* inclusive last addr */
        while (i < length) {
            fputc(memory[fromAddr + i], f[0]);
            if (split == 2) {
                if (fromAddr + i + 1 <= last) fputc(memory[fromAddr + i + 1], f[1]);
                i += 2;
            } else {                                    /* split == 4 */
                if (fromAddr + i + 1 <= last) fputc(memory[fromAddr + i + 1], f[1]);
                if (fromAddr + i + 2 <= last) fputc(memory[fromAddr + i + 2], f[2]);
                if (fromAddr + i + 3 <= last) fputc(memory[fromAddr + i + 3], f[3]);
                i += 4;
            }
        }
    }
    for (int i = 0; i < 4; i++) if (f[i]) fclose(f[i]);
    return 0;
}

/* -------------------------------------------------------------- save S-record */
/* Fill in the byte count and append the checksum + newline (EASyBIN finish()). */
static void srec_finish(char *sRec, int bytes) {
    char byteC[4];
    snprintf(byteC, sizeof byteC, "%02X", bytes & 0xFF);
    sRec[2] = byteC[0]; sRec[3] = byteC[1];            /* byte count field */
    unsigned char checksum = 0;
    char *p = sRec + 2;
    for (int i = 0; i < bytes; i++) {
        unsigned int v;
        sscanf(p, "%2x", &v); p += 2;
        checksum += (unsigned char)v;
    }
    sprintf(p, "%02X\n", (~checksum) & 0xFF);
}

int eb_save_srecord(const char *path, unsigned int fromAddr, unsigned int toAddr,
                    unsigned int startAddr, char *err, int errlen)
{
    unsigned char *memory = eb_memory();
    if (fromAddr > toAddr || (toAddr - fromAddr) >= EB_MEMSIZE) {
        snprintf(err, errlen, "Invalid memory range."); return -1;
    }
    FILE *o = fopen(path, "wt");
    if (!o) { snprintf(err, errlen, "Error creating %s", path); return -1; }

    const int SRECDATA = 32;                            /* data bytes per record */
    char sRecord[128];
    unsigned int outLength = toAddr - fromAddr + 1;
    unsigned int sRecAddr = fromAddr, dataCount = 0;

    /* S0 description: "CREATED BY EASYBIN" */
    strcpy(sRecord, "S0210000535245434F5244202020313143524541544544204259204541535942494E");
    srec_finish(sRecord, 0x21);
    fputs(sRecord, o);

    while (dataCount < outLength) {
        unsigned int byteCount;
        if ((sRecAddr & 0xFFFFu) == sRecAddr)        { sprintf(sRecord, "S1  %04X",  sRecAddr); byteCount = 2; }
        else if ((sRecAddr & 0xFFFFFFu) == sRecAddr) { sprintf(sRecord, "S2  %06X",  sRecAddr); byteCount = 3; }
        else                                          { sprintf(sRecord, "S3  %08X",  sRecAddr); byteCount = 4; }
        char *p = sRecord + 4 + byteCount * 2;
        unsigned int sRecData = 0;
        while (sRecData < (unsigned)SRECDATA && dataCount < outLength) {
            sprintf(p, "%02X", memory[sRecAddr++]); p += 2;
            sRecData++; dataCount++;
        }
        srec_finish(sRecord, sRecData + byteCount + 1);
        fputs(sRecord, o);
    }

    sprintf(sRecord, "S7  %08X", startAddr);            /* start record */
    srec_finish(sRecord, 5);
    fputs(sRecord, o);
    fclose(o);
    return 0;
}
