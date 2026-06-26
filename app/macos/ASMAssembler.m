//
//  ASMAssembler.m
//  EASy68K — Objective-C bridge over libasm68k.
//
#import "ASMAssembler.h"
#import "port68k.h"

// We deliberately do NOT include asm.h here: its identifiers (BYTE_SIZE,
// Fixed, move, link, ...) collide with macOS system headers once Cocoa is
// imported. Declare only the assembler's public entry point and option
// flags from libasm68k.
extern int assembleFile(char fileName[], char tempName[], const char *workName);

// Assembler option flags + counts (globals.c).
extern bool listFlag, objFlag, CEXflag, BITflag, CREflag, MEXflag, SEXflag, WARflag;
extern int  errorCount, warningCount;

@implementation ASMDiagnostic @end
@implementation ASMResult @end

// The C host hooks can't capture an Objective-C object, so during a (single,
// synchronous, main-thread) assemble we collect into these statics.
static NSMutableArray<ASMDiagnostic *> *gDiagnostics;
static NSMutableString *gMessageLog;

static void collectReportError(int lineNum, const char *message, const char *includeFile) {
    ASMDiagnostic *d = [ASMDiagnostic new];
    d.line = lineNum;
    d.message = message ? [NSString stringWithUTF8String:message] : @"";
    d.file = (includeFile && includeFile[0]) ? [NSString stringWithUTF8String:includeFile] : nil;
    [gDiagnostics addObject:d];
}

static void collectError(const char *message, const char *title) {
    [gMessageLog appendFormat:@"%s: %s\n", title ? title : "Error", message ? message : ""];
}

@implementation ASMAssembler

- (ASMResult *)assembleSource:(NSString *)source workPath:(NSString *)workPath {
    gDiagnostics = [NSMutableArray array];
    gMessageLog  = [NSMutableString string];

    // Default options match a standard EASy68K assemble.
    listFlag = true; objFlag = true; WARflag = true;
    CEXflag = false; BITflag = false; CREflag = false; MEXflag = false; SEXflag = false;

    host_set_report_error_handler(collectReportError);
    host_set_error_handler(collectError);

    // Write the editor text to a temp .X68 source. Output (.S68/.L68) is
    // derived from workPath by the assembler's changeFileExt().
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *srcPath  = [tmpDir stringByAppendingPathComponent:@"EASy68K_src.X68"];
    NSString *tempPath = [tmpDir stringByAppendingPathComponent:@"EASy68K_tmp.X68"];
    [source writeToFile:srcPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    errorCount = warningCount = 0;
    assembleFile((char *)srcPath.fileSystemRepresentation,
                 (char *)tempPath.fileSystemRepresentation,
                 workPath.fileSystemRepresentation);

    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:srcPath error:nil];

    // Restore default handlers.
    host_set_report_error_handler(NULL);
    host_set_error_handler(NULL);

    ASMResult *r = [ASMResult new];
    r.errorCount = errorCount;
    r.warningCount = warningCount;
    r.diagnostics = [gDiagnostics copy];
    r.messageLog = [gMessageLog copy];
    r.listingPath = [[workPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"L68"];
    r.objectPath  = [[workPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"S68"];
    gDiagnostics = nil; gMessageLog = nil;
    return r;
}

@end
