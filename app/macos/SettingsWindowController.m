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
//  SettingsWindowController.m
//
#import "SettingsWindowController.h"
#import "E68Theme.h"
#import "E68BrushedView.h"
#import "SimSoundEngine.h"
#import "SimMidiEngine.h"

#define K_MIDI_IN_NAME  @"MidiInputName"
#define K_MIDI_OUT_NAME @"MidiOutputName"

@implementation SettingsWindowController {
    NSSlider      *_fontSlider;
    NSTextField   *_fontValue;
    NSPopUpButton *_audioDevicePopup;
    NSPopUpButton *_leftChPopup;
    NSPopUpButton *_rightChPopup;
    NSPopUpButton *_midiInPopup;
    NSPopUpButton *_midiOutPopup;
}

+ (void)showSettings {
    static SettingsWindowController *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SettingsWindowController alloc] initWithWindow:nil]; });
    [shared buildIfNeeded];
    [shared populateDevices];          // refresh device lists (hot-plug aware)
    [shared.window center];
    [shared showWindow:nil];
    [shared.window makeKeyAndOrderFront:nil];
    [shared syncFromTheme];
}

- (void)buildIfNeeded {
    if (self.window) return;

    NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 400)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
        backing:NSBackingStoreBuffered defer:NO];
    w.title = @"Settings";
    w.releasedWhenClosed = NO;
    self.window = w;
    [E68BrushedView installInWindow:w];
    NSView *root = w.contentView;

    NSTextField *title = [NSTextField labelWithString:@"Settings"];
    title.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:title];

    NSBox *sep = [[NSBox alloc] initWithFrame:NSZeroRect];
    sep.boxType = NSBoxSeparator;
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:sep];

    NSTextField *fontLbl = [NSTextField labelWithString:@"Font size"];
    fontLbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    fontLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:fontLbl];

    _fontSlider = [NSSlider sliderWithValue:[E68Theme shared].fontSize minValue:8 maxValue:28
                                     target:self action:@selector(fontSliderChanged:)];
    _fontSlider.numberOfTickMarks = 21;
    _fontSlider.allowsTickMarkValuesOnly = YES;
    _fontSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:_fontSlider];

    _fontValue = [NSTextField labelWithString:@"12 pt"];
    _fontValue.alignment = NSTextAlignmentRight;
    _fontValue.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
    _fontValue.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:_fontValue];

    NSButton *reset = [NSButton buttonWithTitle:@"Reset" target:self action:@selector(resetFont:)];
    reset.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:reset];

    // --- Audio & MIDI section ---
    NSBox *sep2 = [[NSBox alloc] initWithFrame:NSZeroRect];
    sep2.boxType = NSBoxSeparator; sep2.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:sep2];

    NSTextField *amLbl = [NSTextField labelWithString:@"Audio & MIDI"];
    amLbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    amLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:amLbl];

    NSTextField *devLbl = [self formLabel:@"Output device"];
    _audioDevicePopup = [self popupAction:@selector(audioDeviceChanged:)];
    NSTextField *chLbl = [self formLabel:@"Left / Right"];
    _leftChPopup  = [self popupAction:@selector(channelsChanged:)];
    _rightChPopup = [self popupAction:@selector(channelsChanged:)];
    NSTextField *midiLbl = [self formLabel:@"MIDI input"];
    _midiInPopup = [self popupAction:@selector(midiInputChanged:)];
    NSTextField *midiOutLbl = [self formLabel:@"MIDI output"];
    _midiOutPopup = [self popupAction:@selector(midiOutputChanged:)];
    for (NSView *v in @[devLbl, _audioDevicePopup, chLbl, _leftChPopup, _rightChPopup,
                        midiLbl, _midiInPopup, midiOutLbl, _midiOutPopup])
        [root addSubview:v];

    NSTextField *hint = [NSTextField labelWithString:@"Tip: ⌘+ / ⌘− to resize, ⌘0 to reset."];
    hint.font = [NSFont systemFontOfSize:11];
    hint.textColor = NSColor.tertiaryLabelColor;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:hint];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:root.topAnchor constant:18],
        [title.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],

        [sep.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [sep.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
        [sep.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],

        [fontLbl.topAnchor constraintEqualToAnchor:sep.bottomAnchor constant:20],
        [fontLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],

        [_fontSlider.centerYAnchor constraintEqualToAnchor:fontLbl.centerYAnchor],
        [_fontSlider.leadingAnchor constraintEqualToAnchor:fontLbl.trailingAnchor constant:16],
        [_fontSlider.widthAnchor constraintEqualToConstant:220],

        [_fontValue.centerYAnchor constraintEqualToAnchor:fontLbl.centerYAnchor],
        [_fontValue.leadingAnchor constraintEqualToAnchor:_fontSlider.trailingAnchor constant:12],
        [_fontValue.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],

        [reset.topAnchor constraintEqualToAnchor:fontLbl.bottomAnchor constant:14],
        [reset.leadingAnchor constraintEqualToAnchor:_fontSlider.leadingAnchor],

        [sep2.topAnchor constraintEqualToAnchor:reset.bottomAnchor constant:18],
        [sep2.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
        [sep2.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],
        [amLbl.topAnchor constraintEqualToAnchor:sep2.bottomAnchor constant:12],
        [amLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],

        [devLbl.topAnchor constraintEqualToAnchor:amLbl.bottomAnchor constant:14],
        [devLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
        [devLbl.widthAnchor constraintEqualToConstant:90],
        [_audioDevicePopup.centerYAnchor constraintEqualToAnchor:devLbl.centerYAnchor],
        [_audioDevicePopup.leadingAnchor constraintEqualToAnchor:devLbl.trailingAnchor constant:10],
        [_audioDevicePopup.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],

        [chLbl.topAnchor constraintEqualToAnchor:devLbl.bottomAnchor constant:12],
        [chLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
        [chLbl.widthAnchor constraintEqualToConstant:90],
        [_leftChPopup.centerYAnchor constraintEqualToAnchor:chLbl.centerYAnchor],
        [_leftChPopup.leadingAnchor constraintEqualToAnchor:chLbl.trailingAnchor constant:10],
        [_leftChPopup.widthAnchor constraintEqualToConstant:165],
        [_rightChPopup.centerYAnchor constraintEqualToAnchor:chLbl.centerYAnchor],
        [_rightChPopup.leadingAnchor constraintEqualToAnchor:_leftChPopup.trailingAnchor constant:8],
        [_rightChPopup.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],

        [midiLbl.topAnchor constraintEqualToAnchor:chLbl.bottomAnchor constant:12],
        [midiLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
        [midiLbl.widthAnchor constraintEqualToConstant:90],
        [_midiInPopup.centerYAnchor constraintEqualToAnchor:midiLbl.centerYAnchor],
        [_midiInPopup.leadingAnchor constraintEqualToAnchor:midiLbl.trailingAnchor constant:10],
        [_midiInPopup.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],

        [midiOutLbl.topAnchor constraintEqualToAnchor:midiLbl.bottomAnchor constant:12],
        [midiOutLbl.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
        [midiOutLbl.widthAnchor constraintEqualToConstant:90],
        [_midiOutPopup.centerYAnchor constraintEqualToAnchor:midiOutLbl.centerYAnchor],
        [_midiOutPopup.leadingAnchor constraintEqualToAnchor:midiOutLbl.trailingAnchor constant:10],
        [_midiOutPopup.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],

        [hint.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-16],
        [hint.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncFromTheme)
                                                 name:E68ThemeChangedNotification object:nil];
}

- (NSTextField *)formLabel:(NSString *)s {
    NSTextField *l = [NSTextField labelWithString:s];
    l.font = [NSFont systemFontOfSize:12];
    l.alignment = NSTextAlignmentRight;
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}
- (NSPopUpButton *)popupAction:(SEL)action {
    NSPopUpButton *p = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    p.target = self; p.action = action;
    p.translatesAutoresizingMaskIntoConstraints = NO;
    return p;
}

- (void)populateDevices {
    SimSoundEngine *snd = [SimSoundEngine shared];
    // audio output devices
    [_audioDevicePopup removeAllItems];
    NSString *curUID = [snd currentDeviceUID];
    for (NSDictionary *d in [snd outputDevices]) {
        [_audioDevicePopup addItemWithTitle:d[@"name"]];
        _audioDevicePopup.lastItem.representedObject = d[@"uid"];
        if ([d[@"uid"] isEqualToString:curUID]) [_audioDevicePopup selectItem:_audioDevicePopup.lastItem];
    }
    [self populateChannels];

    // MIDI inputs (read-only use of the existing engine)
    SimMidiEngine *midi = [SimMidiEngine shared];
    [midi initMIDI];
    [_midiInPopup removeAllItems];
    [_midiInPopup addItemWithTitle:@"None"];
    NSString *savedIn = [[NSUserDefaults standardUserDefaults] stringForKey:K_MIDI_IN_NAME];
    for (int i = 0; i < [midi sourceCount]; i++) {
        char buf[256] = {0};
        [midi sourceName:i into:buf max:sizeof(buf)];
        NSString *name = [NSString stringWithUTF8String:buf];
        [_midiInPopup addItemWithTitle:name];
        if ([name isEqualToString:savedIn]) [_midiInPopup selectItemWithTitle:name];
    }
    // MIDI outputs (destinations)
    [_midiOutPopup removeAllItems];
    [_midiOutPopup addItemWithTitle:@"None"];
    NSString *savedOut = [[NSUserDefaults standardUserDefaults] stringForKey:K_MIDI_OUT_NAME];
    for (int i = 0; i < [midi destinationCount]; i++) {
        char buf[256] = {0};
        [midi destinationName:i into:buf max:sizeof(buf)];
        NSString *name = [NSString stringWithUTF8String:buf];
        [_midiOutPopup addItemWithTitle:name];
        if ([name isEqualToString:savedOut]) [_midiOutPopup selectItemWithTitle:name];
    }
}

- (void)populateChannels {
    int nCh = [[SimSoundEngine shared] deviceChannelCount];
    if (nCh < 1) nCh = 2;
    [_leftChPopup removeAllItems]; [_rightChPopup removeAllItems];
    for (int i = 0; i < nCh; i++) {
        [_leftChPopup  addItemWithTitle:[NSString stringWithFormat:@"L → Ch %d", i + 1]];
        [_rightChPopup addItemWithTitle:[NSString stringWithFormat:@"R → Ch %d", i + 1]];
    }
    int L = [[SimSoundEngine shared] leftChannel], R = [[SimSoundEngine shared] rightChannel];
    if (L >= 0 && L < nCh) [_leftChPopup  selectItemAtIndex:L];
    if (R >= 0 && R < nCh) [_rightChPopup selectItemAtIndex:R];
}

- (void)audioDeviceChanged:(NSPopUpButton *)p {
    [[SimSoundEngine shared] selectDeviceUID:(p.selectedItem.representedObject ?: @"")];
    [self populateChannels];
}
- (void)channelsChanged:(id)sender {
    [[SimSoundEngine shared] setLeftChannel:(int)_leftChPopup.indexOfSelectedItem
                                      right:(int)_rightChPopup.indexOfSelectedItem];
}
- (void)midiInputChanged:(NSPopUpButton *)p {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    if (p.indexOfSelectedItem <= 0) { [u removeObjectForKey:K_MIDI_IN_NAME]; return; }
    [u setObject:p.titleOfSelectedItem forKey:K_MIDI_IN_NAME];
    [[SimMidiEngine shared] openSource:(int)(p.indexOfSelectedItem - 1)];  // -1 skips "None"
}
- (void)midiOutputChanged:(NSPopUpButton *)p {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    if (p.indexOfSelectedItem <= 0) { [u removeObjectForKey:K_MIDI_OUT_NAME]; return; }
    [u setObject:p.titleOfSelectedItem forKey:K_MIDI_OUT_NAME];
    [[SimMidiEngine shared] openDestination:(int)(p.indexOfSelectedItem - 1)];
}

// Called from the app delegate at launch: re-open the remembered MIDI input
// (the audio device/channels are restored by SimSoundEngine's own init).
+ (void)restoreSavedDevices {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    NSString *savedIn = [u stringForKey:K_MIDI_IN_NAME];
    NSString *savedOut = [u stringForKey:K_MIDI_OUT_NAME];
    if (!savedIn.length && !savedOut.length) return;
    SimMidiEngine *midi = [SimMidiEngine shared];
    [midi initMIDI];
    for (int i = 0; savedIn.length && i < [midi sourceCount]; i++) {
        char buf[256] = {0}; [midi sourceName:i into:buf max:sizeof(buf)];
        if ([[NSString stringWithUTF8String:buf] isEqualToString:savedIn]) { [midi openSource:i]; break; }
    }
    for (int i = 0; savedOut.length && i < [midi destinationCount]; i++) {
        char buf[256] = {0}; [midi destinationName:i into:buf max:sizeof(buf)];
        if ([[NSString stringWithUTF8String:buf] isEqualToString:savedOut]) { [midi openDestination:i]; break; }
    }
}

- (void)syncFromTheme {
    CGFloat s = [E68Theme shared].fontSize;
    _fontSlider.doubleValue = s;
    _fontValue.stringValue = [NSString stringWithFormat:@"%d pt", (int)s];
}

- (void)fontSliderChanged:(NSSlider *)sender {
    [E68Theme shared].fontSize = sender.doubleValue;   // posts the notification
}
- (void)resetFont:(id)sender { [[E68Theme shared] resetFontSize]; }

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

@end
