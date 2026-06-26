//
//  SyntaxHighlighter.h
//  EASy68K — 68000 assembly syntax highlighting for an NSTextStorage.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// Applies 68000 assembly syntax colouring. Attach as the text view's
// NSTextStorage delegate; it re-highlights the edited paragraph(s) on change.
@interface SyntaxHighlighter : NSObject <NSTextStorageDelegate>

@property (nonatomic, strong) NSFont *font;

// Re-highlight an explicit range (used for the initial pass after loading).
- (void)highlightRange:(NSRange)range inStorage:(NSTextStorage *)storage;
- (void)highlightAll:(NSTextStorage *)storage;

@end

NS_ASSUME_NONNULL_END
