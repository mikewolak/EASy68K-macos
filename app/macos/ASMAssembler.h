//
//  ASMAssembler.h
//  EASy68K — Objective-C bridge over the C99 assembler core (libasm68k).
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// One assembler diagnostic (error or warning).
@interface ASMDiagnostic : NSObject
@property (nonatomic) NSInteger line;       // source line, or -1
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy, nullable) NSString *file;  // include file, or nil
@end

// Result of assembling a source file.
@interface ASMResult : NSObject
@property (nonatomic) NSInteger errorCount;
@property (nonatomic) NSInteger warningCount;
@property (nonatomic, strong) NSArray<ASMDiagnostic *> *diagnostics;
@property (nonatomic, copy, nullable) NSString *listingPath;   // .L68
@property (nonatomic, copy, nullable) NSString *objectPath;    // .S68
@property (nonatomic, copy, nullable) NSString *messageLog;    // human-readable summary
@end

@interface ASMAssembler : NSObject

// Assemble the source text (saving it next to workPath's basename to derive
// .S68 / .L68). workPath should be the document's path (or a chosen name).
// Runs synchronously; safe to call on the main thread for typical programs.
- (ASMResult *)assembleSource:(NSString *)source workPath:(NSString *)workPath;

@end

NS_ASSUME_NONNULL_END
