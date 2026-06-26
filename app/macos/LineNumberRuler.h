//
//  LineNumberRuler.h
//  EASy68K — a line-number gutter for the editor's NSScrollView.
//
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface LineNumberRuler : NSRulerView
- (instancetype)initWithTextView:(NSTextView *)textView;
@end

NS_ASSUME_NONNULL_END
