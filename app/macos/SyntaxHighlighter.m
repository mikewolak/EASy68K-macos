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
//  SyntaxHighlighter.m
//  EASy68K — 68000 assembly syntax highlighting.
//
#import "SyntaxHighlighter.h"

@implementation SyntaxHighlighter {
    NSRegularExpression *_reLabel;
    NSRegularExpression *_reInstr;
    NSRegularExpression *_reDirective;
    NSRegularExpression *_reRegister;
    NSRegularExpression *_reNumber;
    NSRegularExpression *_reString;
    NSRegularExpression *_reCommentSemi;
    NSRegularExpression *_reCommentStar;
    NSColor *_cText, *_cLabel, *_cInstr, *_cDirective, *_cRegister, *_cNumber, *_cString, *_cComment;
}

- (instancetype)init {
    if ((self = [super init])) {
        _font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];

        // Colour scheme — system colours so it adapts to light/dark mode.
        _cText      = NSColor.labelColor;
        _cLabel     = NSColor.systemPurpleColor;
        _cInstr     = NSColor.systemBlueColor;
        _cDirective = NSColor.systemPinkColor;
        _cRegister  = NSColor.systemTealColor;
        _cNumber    = NSColor.systemOrangeColor;
        _cString    = NSColor.systemRedColor;
        _cComment   = NSColor.systemGreenColor;

        // 68000 instruction mnemonics (incl. Bcc/DBcc/Scc condition variants)
        // and EASy68K structured keywords.
        NSString *instr =
          @"ABCD|ADDA|ADDI|ADDQ|ADDX|ADD|ANDI|AND|ASL|ASR|"
           "BCHG|BCLR|BSET|BTST|BRA|BSR|"
           "B(HS|LO|CC|CS|EQ|NE|VC|VS|PL|MI|GE|LT|GT|LE|HI|LS|T|F)|"
           "CHK|CLR|CMPA|CMPI|CMPM|CMP|"
           "DBRA|DB(T|F|HI|LS|CC|CS|NE|EQ|VC|VS|PL|MI|GE|LT|GT|LE)|"
           "DIVS|DIVU|EORI|EOR|EXG|EXT|ILLEGAL|JMP|JSR|LEA|LINK|LSL|LSR|"
           "MOVEA|MOVEM|MOVEP|MOVEQ|MOVE|MULS|MULU|NBCD|NEGX|NEG|NOP|NOT|"
           "ORI|OR|PEA|RESET|ROXL|ROXR|ROL|ROR|RTE|RTR|RTS|SBCD|"
           "S(T|F|HI|LS|CC|CS|NE|EQ|VC|VS|PL|MI|GE|LT|GT|LE)|"
           "STOP|SUBA|SUBI|SUBQ|SUBX|SUB|SWAP|TAS|TRAPV|TRAP|TST|UNLK|"
           "SIMHALT|"
           "IF|ELSE|ENDI|WHILE|ENDW|REPEAT|UNTIL|FOR|ENDF|DBLOOP|UNLESS";

        // Assembler directives.
        NSString *directive =
          @"ORG|RORG|END|EQU|SET|DCB|DC|DS|OFFSET|REG|INCLUDE|INCBIN|"
           "OPT|PAGE|LIST|NOLIST|SECTION|MACRO|ENDM|MEXIT|"
           "IFEQ|IFNE|IFGE|IFGT|IFLE|IFLT|IFC|IFNC|ENDC|FAIL|"
           "MEMORY|CMPLST|NOPAGE";

        NSRegularExpressionOptions ci = NSRegularExpressionCaseInsensitive;
        _reInstr     = [self re:[NSString stringWithFormat:@"(?<![A-Za-z0-9_.])(%@)(?![A-Za-z0-9_])", instr] opts:ci];
        _reDirective = [self re:[NSString stringWithFormat:@"(?<![A-Za-z0-9_.])(%@)(?![A-Za-z0-9_])", directive] opts:ci];
        _reRegister  = [self re:@"(?<![A-Za-z0-9_])(D[0-7]|A[0-7]|SP|PC|SR|CCR|USP)(?![A-Za-z0-9_])" opts:ci];
        _reNumber    = [self re:@"(\\$[0-9A-Fa-f]+|%[01]+|#?-?\\b[0-9]+\\b)" opts:0];
        _reString    = [self re:@"'[^'\\n]*'" opts:0];
        _reLabel     = [self re:@"^[A-Za-z_][A-Za-z0-9_]*" opts:NSRegularExpressionAnchorsMatchLines];
        _reCommentSemi = [self re:@";[^\\n]*" opts:0];
        _reCommentStar = [self re:@"^\\*[^\\n]*" opts:NSRegularExpressionAnchorsMatchLines];
    }
    return self;
}

- (NSRegularExpression *)re:(NSString *)pat opts:(NSRegularExpressionOptions)o {
    return [NSRegularExpression regularExpressionWithPattern:pat options:o error:nil];
}

- (void)setFont:(NSFont *)font {
    _font = font;
}

#pragma mark - Highlighting

- (void)applyRE:(NSRegularExpression *)re color:(NSColor *)color
       toString:(NSString *)str storage:(NSTextStorage *)storage range:(NSRange)range {
    [re enumerateMatchesInString:str options:0 range:range
                      usingBlock:^(NSTextCheckingResult *m, NSMatchingFlags f, BOOL *stop) {
        [storage addAttribute:NSForegroundColorAttributeName value:color range:m.range];
    }];
}

- (void)highlightRange:(NSRange)range inStorage:(NSTextStorage *)storage {
    NSString *str = storage.string;
    if (range.location + range.length > str.length)
        range = NSMakeRange(0, str.length);
    if (range.length == 0) return;

    // NOTE: do NOT wrap in beginEditing/endEditing — this method is called
    // from the textStorage:didProcessEditing: delegate, which is already
    // inside an editing transaction; nesting one there breaks glyph layout.

    // Base attributes.
    [storage addAttribute:NSFontAttributeName value:_font range:range];
    [storage addAttribute:NSForegroundColorAttributeName value:_cText range:range];

    // Token classes, general first.
    [self applyRE:_reLabel     color:_cLabel     toString:str storage:storage range:range];
    [self applyRE:_reInstr     color:_cInstr     toString:str storage:storage range:range];
    [self applyRE:_reDirective color:_cDirective toString:str storage:storage range:range];
    [self applyRE:_reRegister  color:_cRegister  toString:str storage:storage range:range];
    [self applyRE:_reNumber    color:_cNumber    toString:str storage:storage range:range];
    [self applyRE:_reString    color:_cString    toString:str storage:storage range:range];
    // Comments win over everything else.
    [self applyRE:_reCommentSemi color:_cComment toString:str storage:storage range:range];
    [self applyRE:_reCommentStar color:_cComment toString:str storage:storage range:range];
}

- (void)highlightAll:(NSTextStorage *)storage {
    [self highlightRange:NSMakeRange(0, storage.length) inStorage:storage];
}

#pragma mark - NSTextStorageDelegate

- (void)textStorage:(NSTextStorage *)textStorage
 didProcessEditing:(NSTextStorageEditActions)editedMask
             range:(NSRange)editedRange
    changeInLength:(NSInteger)delta {
    if (!(editedMask & NSTextStorageEditedCharacters)) return;
    // Re-highlight the paragraph(s) touched by the edit.
    NSRange para = [textStorage.string lineRangeForRange:editedRange];
    [self highlightRange:para inStorage:textStorage];
}

@end
