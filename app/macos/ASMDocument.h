//
//  ASMDocument.h
//  EASy68K — document model for a .X68 68000 assembly source file.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASMDocument : NSDocument
@property (nonatomic, copy) NSString *text;        // source content
@end

NS_ASSUME_NONNULL_END
