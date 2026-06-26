/*
 * EASy68K for macOS
 *
 * Copyright (c) 2026 mikewolak@gmail.com  —  Epromfoundry, Inc.
 * All rights reserved.
 *
 * ****  NOT FOR COMMERCIAL USE  ****
 * This software is licensed for PERSONAL and EDUCATIONAL use ONLY.
 * Any commercial use, sale, or distribution for profit is STRICTLY
 * PROHIBITED without the prior written permission of Epromfoundry, Inc.
 */

//
//  SimLogBridge.m
//
#import "SimLogBridge.h"
#import "SimListingView.h"
#import <stdio.h>

extern FILE *ElogFile;   // the open execution-log file (globals.c)

static SimListingView *gListing;

void simlog_set_listing(void *listingView) { gListing = (__bridge SimListingView *)listingView; }

int simlog_emit_source(uint32_t addr) {
    if (!gListing || !ElogFile) return 0;
    NSString *line = [gListing instructionLineForAddress:addr];
    if (!line.length) return 0;
    fprintf(ElogFile, "%s\n", line.UTF8String ?: "");
    return 1;
}
