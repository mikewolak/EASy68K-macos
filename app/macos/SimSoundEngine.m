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
//  SimSoundEngine.m
//
//  Low-latency audio output through a lock-free SPSC ring buffer (pro/synth
//  topology): a single output AudioUnit (HALOutput) render callback DRAINS the
//  ring into the device and writes silence on underrun — no locks, allocations
//  or polyphony on the real-time thread. Producers (the TRAP sound tasks, or a
//  future synth/MIDI voice) push interleaved-stereo float frames at the device
//  rate into the ring. WAVs are converted once to that format.
//
#import "SimSoundEngine.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>
#include <stdatomic.h>

// Persisted output device + L/R channel routing.
#define K_AUDIO_UID @"AudioDeviceUID"
#define K_AUDIO_CHL @"AudioChannelL"
#define K_AUDIO_CHR @"AudioChannelR"
#define CANON_RATE  44100.0

#define RING_FRAMES (1u << 16)          // 65536 frames (~1.5 s @ 44.1k), power of 2
#define RING_FLOATS (RING_FRAMES * 2u)  // interleaved stereo
#define RING_MASK   (RING_FLOATS - 1u)

#define NSLOTS 256

static float gRing[RING_FLOATS];
static _Atomic unsigned long gWrite = 0;   // monotonic float index (producer)
static _Atomic unsigned long gRead  = 0;   // monotonic float index (consumer/RT)

typedef struct { const float *samples; long frames; } Slot;
static Slot gSlots[NSLOTS];

// ---- real-time render callback: drain the ring, silence on underrun ----
static OSStatus simRender(void *ref, AudioUnitRenderActionFlags *flags,
                          const AudioTimeStamp *ts, UInt32 bus, UInt32 nFrames,
                          AudioBufferList *io) {
    (void)ref; (void)ts; (void)bus;
    float *out = (float *)io->mBuffers[0].mData;
    unsigned long want = (unsigned long)nFrames * 2u;
    unsigned long w = atomic_load_explicit(&gWrite, memory_order_acquire);
    unsigned long r = atomic_load_explicit(&gRead, memory_order_relaxed);
    unsigned long avail = w - r;
    unsigned long n = avail < want ? avail : want;
    for (unsigned long i = 0; i < n; i++)   out[i] = gRing[(r + i) & RING_MASK];
    for (unsigned long i = n; i < want; i++) out[i] = 0.0f;    // underrun -> silence
    atomic_store_explicit(&gRead, r + n, memory_order_release);
    if (n == 0 && flags) *flags |= kAudioUnitRenderAction_OutputIsSilence;
    return noErr;
}

@implementation SimSoundEngine {
    AudioUnit      _unit;
    double         _outRate;
    NSMutableArray<NSData *> *_retain;
    NSMutableDictionary<NSString *, NSValue *> *_byName;
    NSLock        *_lock;
    dispatch_source_t _loopTimer;       // tops up the ring for a looping sound
    AudioDeviceID  _deviceID;           // 0 = system default output
    int            _chL, _chR;          // device channels feeding L / R
}

+ (instancetype)shared {
    static SimSoundEngine *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [SimSoundEngine new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _lock = [NSLock new];
        _retain = [NSMutableArray array];
        _byName = [NSMutableDictionary dictionary];
        _outRate = CANON_RATE;          // fixed canonical rate; HAL resamples to device
        NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
        _chL = [u objectForKey:K_AUDIO_CHL] ? (int)[u integerForKey:K_AUDIO_CHL] : 0;  // ch 1
        _chR = [u objectForKey:K_AUDIO_CHR] ? (int)[u integerForKey:K_AUDIO_CHR] : 1;  // ch 2
        NSString *uid = [u stringForKey:K_AUDIO_UID];
        _deviceID = uid.length ? [self deviceForUID:uid] : 0;
        [self buildUnit];
    }
    return self;
}

- (void)buildUnit {
    AudioComponentDescription desc = {0};
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_HALOutput;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (!comp || AudioComponentInstanceNew(comp, &_unit) != noErr) { _unit = NULL; return; }
    [self configureUnit];
}

// (Re)apply device, format, channel map and callback, then init + start. Called
// at startup and whenever the device or channel routing changes.
- (void)configureUnit {
    if (!_unit) return;
    AudioOutputUnitStop(_unit);
    AudioUnitUninitialize(_unit);

    if (_deviceID)
        AudioUnitSetProperty(_unit, kAudioOutputUnitProperty_CurrentDevice,
                             kAudioUnitScope_Global, 0, &_deviceID, sizeof(_deviceID));

    AudioStreamBasicDescription fmt = {0};
    fmt.mSampleRate = CANON_RATE;
    fmt.mFormatID = kAudioFormatLinearPCM;
    fmt.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;  // interleaved
    fmt.mChannelsPerFrame = 2;
    fmt.mBitsPerChannel = 32;
    fmt.mFramesPerPacket = 1;
    fmt.mBytesPerFrame = 2 * sizeof(float);
    fmt.mBytesPerPacket = fmt.mBytesPerFrame;
    AudioUnitSetProperty(_unit, kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input, 0, &fmt, sizeof(fmt));

    UInt32 maxFrames = 256;   // low-latency slice
    AudioUnitSetProperty(_unit, kAudioUnitProperty_MaximumFramesPerSlice,
                         kAudioUnitScope_Global, 0, &maxFrames, sizeof(maxFrames));

    AURenderCallbackStruct cb = { .inputProc = simRender, .inputProcRefCon = NULL };
    AudioUnitSetProperty(_unit, kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input, 0, &cb, sizeof(cb));

    [self applyChannelMap];   // route our L/R to the chosen device channels

    if (AudioUnitInitialize(_unit) == noErr) AudioOutputUnitStart(_unit);
}

// Map our 2 source channels (0=L, 1=R) onto the device's output channels.
- (void)applyChannelMap {
    if (!_unit) return;
    AudioStreamBasicDescription outf = {0}; UInt32 sz = sizeof(outf);
    if (AudioUnitGetProperty(_unit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Output, 0, &outf, &sz) != noErr) return;
    int nOut = (int)outf.mChannelsPerFrame;
    if (nOut < 1) return;
    SInt32 *map = (SInt32 *)calloc(nOut, sizeof(SInt32));
    for (int i = 0; i < nOut; i++) map[i] = -1;            // -1 = silence
    if (_chL >= 0 && _chL < nOut) map[_chL] = 0;           // device ch chL <- our L
    if (_chR >= 0 && _chR < nOut) map[_chR] = 1;           // device ch chR <- our R
    AudioUnitSetProperty(_unit, kAudioOutputUnitProperty_ChannelMap,
                         kAudioUnitScope_Output, 0, map, (UInt32)(nOut * sizeof(SInt32)));
    free(map);
}

#pragma mark device + channel selection

static NSString *cfStrProp(AudioObjectID obj, AudioObjectPropertySelector sel) {
    AudioObjectPropertyAddress a = { sel, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    CFStringRef s = NULL; UInt32 sz = sizeof(s);
    if (AudioObjectGetPropertyData(obj, &a, 0, NULL, &sz, &s) != noErr || !s) return nil;
    return (__bridge_transfer NSString *)s;
}

- (int)outputChannelsOf:(AudioDeviceID)dev {
    AudioObjectPropertyAddress a = { kAudioDevicePropertyStreamConfiguration,
                                     kAudioDevicePropertyScopeOutput, kAudioObjectPropertyElementMain };
    UInt32 sz = 0;
    if (dev == 0 || AudioObjectGetPropertyDataSize(dev, &a, 0, NULL, &sz) != noErr) return 0;
    AudioBufferList *bl = (AudioBufferList *)malloc(sz);
    int ch = 0;
    if (AudioObjectGetPropertyData(dev, &a, 0, NULL, &sz, bl) == noErr)
        for (UInt32 i = 0; i < bl->mNumberBuffers; i++) ch += bl->mBuffers[i].mNumberChannels;
    free(bl);
    return ch;
}

- (AudioDeviceID)defaultOutputDevice {
    AudioObjectPropertyAddress a = { kAudioHardwarePropertyDefaultOutputDevice,
                                     kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    AudioDeviceID d = 0; UInt32 sz = sizeof(d);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, 0, NULL, &sz, &d);
    return d;
}

- (AudioDeviceID)deviceForUID:(NSString *)uid {
    if (!uid.length) return 0;
    AudioObjectPropertyAddress a = { kAudioHardwarePropertyTranslateUIDToDevice,
                                     kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    CFStringRef cf = (__bridge CFStringRef)uid;
    AudioDeviceID d = 0; UInt32 sz = sizeof(d);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, sizeof(cf), &cf, &sz, &d);
    return d;
}

- (NSArray<NSDictionary<NSString *, id> *> *)outputDevices {
    NSMutableArray *out = [NSMutableArray array];
    AudioObjectPropertyAddress a = { kAudioHardwarePropertyDevices,
                                     kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    UInt32 sz = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &a, 0, NULL, &sz) != noErr) return out;
    int n = (int)(sz / sizeof(AudioDeviceID));
    AudioDeviceID *ids = (AudioDeviceID *)malloc(sz);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, 0, NULL, &sz, ids) == noErr) {
        for (int i = 0; i < n; i++) {
            int ch = [self outputChannelsOf:ids[i]];
            if (ch <= 0) continue;            // output devices only
            NSString *name = cfStrProp(ids[i], kAudioObjectPropertyName);
            NSString *uid  = cfStrProp(ids[i], kAudioDevicePropertyDeviceUID);
            [out addObject:@{ @"name": name ?: @"?", @"uid": uid ?: @"", @"channels": @(ch) }];
        }
    }
    free(ids);
    return out;
}

- (NSString *)currentDeviceUID {
    AudioDeviceID d = _deviceID ? _deviceID : [self defaultOutputDevice];
    return cfStrProp(d, kAudioDevicePropertyDeviceUID) ?: @"";
}

- (void)selectDeviceUID:(NSString *)uid {
    _deviceID = [self deviceForUID:uid];
    [[NSUserDefaults standardUserDefaults] setObject:(uid ?: @"") forKey:K_AUDIO_UID];
    [self configureUnit];
}

- (int)deviceChannelCount {
    AudioDeviceID d = _deviceID ? _deviceID : [self defaultOutputDevice];
    return [self outputChannelsOf:d];
}
- (int)leftChannel  { return _chL; }
- (int)rightChannel { return _chR; }
- (void)setLeftChannel:(int)L right:(int)R {
    _chL = L; _chR = R;
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    [u setInteger:L forKey:K_AUDIO_CHL];
    [u setInteger:R forKey:K_AUDIO_CHR];
    [self configureUnit];
}

#pragma mark ring producer

// Push interleaved-stereo float frames into the ring (drops overflow).
- (void)pushFrames:(const float *)samples count:(long)frames {
    if (!samples || frames <= 0) return;
    unsigned long want = (unsigned long)frames * 2u;
    unsigned long w = atomic_load_explicit(&gWrite, memory_order_relaxed);
    unsigned long r = atomic_load_explicit(&gRead, memory_order_acquire);
    unsigned long space = RING_FLOATS - (w - r);
    unsigned long n = want < space ? want : space;
    for (unsigned long i = 0; i < n; i++) gRing[(w + i) & RING_MASK] = samples[i];
    atomic_store_explicit(&gWrite, w + n, memory_order_release);
}

- (void)clearRing { atomic_store_explicit(&gRead, atomic_load_explicit(&gWrite, memory_order_acquire), memory_order_release); }

- (void)stopLoop { if (_loopTimer) { dispatch_source_cancel(_loopTimer); _loopTimer = nil; } }

#pragma mark loading

- (Slot)decode:(NSString *)path {
    Slot empty = {NULL, 0};
    NSError *err = nil;
    AVAudioFile *file = [[AVAudioFile alloc] initForReading:[NSURL fileURLWithPath:path] error:&err];
    if (!file) return empty;
    AVAudioFormat *src = file.processingFormat;
    AVAudioPCMBuffer *in = [[AVAudioPCMBuffer alloc] initWithPCMFormat:src
        frameCapacity:(AVAudioFrameCount)file.length];
    if (![file readIntoBuffer:in error:&err] || in.frameLength == 0) return empty;

    AVAudioFormat *dst = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
        sampleRate:_outRate channels:2 interleaved:YES];
    AVAudioConverter *conv = [[AVAudioConverter alloc] initFromFormat:src toFormat:dst];
    if (!conv) return empty;
    double ratio = _outRate / src.sampleRate;
    AVAudioFrameCount cap = (AVAudioFrameCount)(in.frameLength * ratio) + 8192;
    AVAudioPCMBuffer *outb = [[AVAudioPCMBuffer alloc] initWithPCMFormat:dst frameCapacity:cap];
    __block BOOL fed = NO;
    AVAudioConverterOutputStatus st = [conv convertToBuffer:outb error:&err
        withInputFromBlock:^AVAudioBuffer *(AVAudioPacketCount need, AVAudioConverterInputStatus *status) {
            if (fed) { *status = AVAudioConverterInputStatus_NoDataNow; return nil; }
            fed = YES; *status = AVAudioConverterInputStatus_HaveData; return in;
        }];
    // Accept any non-error status with output — InputRanDry just means the whole
    // (finite) WAV was consumed. AVAudioFile/AVAudioConverter handle ANY input
    // sample rate, bit depth and channel count, resampling to the device format.
    if (st == AVAudioConverterOutputStatus_Error || outb.frameLength == 0) return empty;

    long frames = outb.frameLength;
    NSMutableData *d = [NSMutableData dataWithBytes:outb.audioBufferList->mBuffers[0].mData
                                            length:(size_t)frames * 2 * sizeof(float)];
    [_lock lock]; [_retain addObject:d]; [_lock unlock];
    Slot s = { (const float *)d.bytes, frames };
    return s;
}

- (NSString *)resolve:(NSString *)name {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([name isAbsolutePath] && [fm fileExistsAtPath:name]) return name;
    if (self.baseDirectory) {
        NSString *p = [self.baseDirectory stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:p]) return p;
    }
    return name;
}

#pragma mark TRAP API

- (int)loadSound:(NSString *)fileName index:(int)index {
    if (index < 0 || index >= NSLOTS) return 0;
    Slot s = [self decode:[self resolve:fileName]];
    if (!s.samples) return 0;
    gSlots[index] = s;
    _byName[fileName] = [NSValue valueWithBytes:&s objCType:@encode(Slot)];
    return 1;
}

- (int)playFile:(NSString *)fileName {
    NSValue *val = _byName[fileName];
    Slot s = {NULL, 0};
    if (val) [val getValue:&s];
    else { s = [self decode:[self resolve:fileName]]; if (s.samples) _byName[fileName] = [NSValue valueWithBytes:&s objCType:@encode(Slot)]; }
    [self stopLoop];
    [self pushFrames:s.samples count:s.frames];
    return s.samples ? 1 : 0;
}
- (int)playIndex:(int)index {
    if (index < 0 || index >= NSLOTS) return 0;
    Slot s = gSlots[index];
    [self stopLoop];
    [self pushFrames:s.samples count:s.frames];
    return s.samples ? 1 : 0;
}

- (void)control:(int)control index:(int)index {
    if (index < 0 || index >= NSLOTS) return;
    Slot s = gSlots[index];
    if (control == 0) { [self stopLoop]; [self clearRing]; return; }       // stop
    if (control == 2) {                                                    // loop
        [self stopLoop];
        if (!s.samples) return;
        [self pushFrames:s.samples count:s.frames];
        double period = (double)s.frames / _outRate;
        _loopTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
            dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0));
        dispatch_source_set_timer(_loopTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(period*NSEC_PER_SEC)),
                                  (uint64_t)(period*NSEC_PER_SEC), (uint64_t)(period*NSEC_PER_SEC/10));
        __weak SimSoundEngine *weak = self;
        Slot cap = s;
        dispatch_source_set_event_handler(_loopTimer, ^{ [weak pushFrames:cap.samples count:cap.frames]; });
        dispatch_resume(_loopTimer);
        return;
    }
    [self pushFrames:s.samples count:s.frames];                            // play
}

- (void)resetSounds { [self stopLoop]; [self clearRing]; }

@end
