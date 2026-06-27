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
 * easybin.h — C99 port of the EASyBIN (v2.5.0) file-I/O core: load an
 * S-record or raw binary into a 16 MB buffer, and save a byte range as raw
 * binary (with optional EPROM even/odd/quad split) or as an S-record file.
 */
#ifndef EASYBIN_H
#define EASYBIN_H

#define EB_MEMSIZE 0x01000000u   /* 16 MB address space, matches EASyBIN MEMSIZE */

/* The 16 MB working buffer (lazily allocated, zero-filled). */
unsigned char *eb_memory(void);
unsigned int   eb_memsize(void);
void           eb_clear(void);

/* Load a Motorola S-record file. On success returns 0 and fills the low/high
 * data addresses, the start address (S7/8/9) and the S0 description text.
 * On error returns -1 and writes a message into err. */
int eb_load_srec(const char *path,
                 unsigned int *outLow, unsigned int *outHigh, unsigned int *outStart,
                 char *s0desc, int s0len, char *err, int errlen);

/* Load a raw binary file into the buffer at firstAddr. split is 0/2/4: with
 * 2 or 4 the bytes are spread every 2nd/4th address (recombining EPROM dumps).
 * Returns the number of bytes consumed, or -1 on error (err filled). */
int eb_load_binary(const char *path, unsigned int firstAddr, int split,
                   char *err, int errlen);

/* Save `length` bytes from fromAddr as raw binary. split 0 writes one file at
 * `path`; split 2 writes path_0/path_1 (even/odd); split 4 writes path_0..path_3.
 * Returns 0 on success, -1 on error (err filled). */
int eb_save_binary(const char *path, unsigned int fromAddr, unsigned int length,
                   int split, char *err, int errlen);

/* Save the range fromAddr..toAddr (inclusive) as a Motorola S-record file with
 * an EASyBIN S0 description and an S7 start record. Returns 0 / -1 (err). */
int eb_save_srecord(const char *path, unsigned int fromAddr, unsigned int toAddr,
                    unsigned int startAddr, char *err, int errlen);

#endif
