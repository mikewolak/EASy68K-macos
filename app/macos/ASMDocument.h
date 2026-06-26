//
//  ASMDocument.h
//  EASy68K — document model for a .X68 68000 assembly source file.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASMDocument : NSDocument
@property (nonatomic, copy) NSString *text;        // source content

// ---- Remote control (HTTP control server; main thread) ----
- (NSString *)remoteSourceText;
- (void)remoteSetSourceText:(NSString *)text;
- (NSDictionary *)remoteAssemble;          // {diagnostics:[{line,message}], count}
- (void)remoteRunInSimulator;
@end

NS_ASSUME_NONNULL_END
