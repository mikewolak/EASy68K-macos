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
//  SimMidiEngine.m
//
#import "SimMidiEngine.h"
#import "SimIntController.h"
#import <CoreMIDI/CoreMIDI.h>
#include <stdatomic.h>

static void midiNotify(const MIDINotification *msg, void *ctx);
static void midiRead(const MIDIPacketList *pkts, void *ctx, void *srcRef);

@interface SimMidiEngine ()
- (void)markChanged;
- (void)enqueueRX:(const unsigned char *)bytes length:(int)len;
@end

@implementation SimMidiEngine {
    MIDIClientRef   _client;
    MIDIPortRef     _outPort, _inPort;
    MIDIEndpointRef _dest;          // selected output destination
    NSMutableData  *_rxQueue;       // received raw MIDI bytes
    NSLock         *_rxLock;
    atomic_int_least32_t _changed;
    BOOL            _ready;
}

+ (instancetype)shared {
    static SimMidiEngine *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [SimMidiEngine new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) { _rxQueue = [NSMutableData data]; _rxLock = [NSLock new]; }
    return self;
}

- (int)initMIDI {
    if (!_ready) {
        OSStatus st = MIDIClientCreate(CFSTR("EASy68K"), midiNotify, (__bridge void *)self, &_client);
        if (st != noErr) return 0;
        MIDIOutputPortCreate(_client, CFSTR("EASy68K Out"), &_outPort);
        MIDIInputPortCreate(_client, CFSTR("EASy68K In"), midiRead, (__bridge void *)self, &_inPort);
        _ready = YES;
    }
    return [self destinationCount];
}

- (int)destinationCount { return (int)MIDIGetNumberOfDestinations(); }
- (int)sourceCount      { return (int)MIDIGetNumberOfSources(); }

- (int)nameOf:(MIDIObjectRef)obj into:(char *)buf max:(int)max {
    if (!obj || !buf || max <= 0) return 0;
    CFStringRef name = NULL;
    if (MIDIObjectGetStringProperty(obj, kMIDIPropertyDisplayName, &name) != noErr || !name) return 0;
    char tmp[256] = {0};
    CFStringGetCString(name, tmp, sizeof(tmp), kCFStringEncodingUTF8);
    CFRelease(name);
    int n = (int)strlen(tmp); if (n > max - 1) n = max - 1;
    memcpy(buf, tmp, n); buf[n] = '\0';
    return n;
}
- (int)destinationName:(int)index into:(char *)buf max:(int)max {
    return [self nameOf:MIDIGetDestination((ItemCount)index) into:buf max:max];
}
- (int)sourceName:(int)index into:(char *)buf max:(int)max {
    return [self nameOf:MIDIGetSource((ItemCount)index) into:buf max:max];
}

- (int)openDestination:(int)index {
    if (index < 0 || index >= [self destinationCount]) return 0;
    _dest = MIDIGetDestination((ItemCount)index);
    return _dest ? 1 : 0;
}
- (int)openSource:(int)index {
    if (index < 0 || index >= [self sourceCount]) return 0;
    MIDIEndpointRef src = MIDIGetSource((ItemCount)index);
    if (!src) return 0;
    return MIDIPortConnectSource(_inPort, src, NULL) == noErr ? 1 : 0;
}

- (int)send:(const unsigned char *)bytes length:(int)len {
    if (!_dest || !bytes || len <= 0) return 0;
    Byte storage[1024];
    MIDIPacketList *pl = (MIDIPacketList *)storage;
    MIDIPacket *pkt = MIDIPacketListInit(pl);
    int n = len > 256 ? 256 : len;
    pkt = MIDIPacketListAdd(pl, sizeof(storage), pkt, 0, n, bytes);
    if (!pkt) return 0;
    int sent = MIDISend(_outPort, _dest, pl) == noErr ? n : 0;
    simIntNotify(SIM_INT_MIDI_TX);    // transmitter ready again (no-op if disabled)
    return sent;
}

- (void)enqueueRX:(const unsigned char *)bytes length:(int)len {
    [_rxLock lock]; [_rxQueue appendBytes:bytes length:len]; [_rxLock unlock];
    simIntNotify(SIM_INT_MIDI_RX);    // data received (no-op if disabled)
}
- (int)receiveInto:(unsigned char *)buf max:(int)max {
    if (!buf || max <= 0) return 0;
    [_rxLock lock];
    int n = (int)MIN((NSUInteger)max, _rxQueue.length);
    if (n > 0) {
        memcpy(buf, _rxQueue.bytes, n);
        [_rxQueue replaceBytesInRange:NSMakeRange(0, n) withBytes:NULL length:0];
    }
    [_rxLock unlock];
    return n;
}

- (int)devicesChanged { return atomic_exchange(&_changed, 0); }
- (void)markChanged   { atomic_store(&_changed, 1); }

@end

static void midiNotify(const MIDINotification *msg, void *ctx) {
    if (msg->messageID == kMIDIMsgSetupChanged)
        [(__bridge SimMidiEngine *)ctx markChanged];
}
static void midiRead(const MIDIPacketList *pkts, void *ctx, void *srcRef) {
    SimMidiEngine *e = (__bridge SimMidiEngine *)ctx;
    const MIDIPacket *p = &pkts->packet[0];
    for (UInt32 i = 0; i < pkts->numPackets; i++) {
        [e enqueueRX:p->data length:p->length];
        p = MIDIPacketNext(p);
    }
}
