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
//  SimSerialEngine.m
//
#import "SimSerialEngine.h"
#import "SimIntController.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/serial/IOSerialKeys.h>
#include <termios.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>

NSString * const E68SerialPortsChangedNotification = @"E68SerialPortsChanged";

#define MAX_COMM 16
#define K_SER_PORT @"SerialPortPath"
#define K_SER_BAUD @"SerialBaudIndex"

// EASy68K baud index -> bits/sec (B57600/B115200/B230400 exist on macOS; the
// non-standard rates pass through as raw integers, accepted by USB-serial drivers).
static speed_t baudFromIndex(int i) {
    switch (i) {
        case 1:  return B110;   case 2:  return B300;    case 3:  return B600;
        case 4:  return B1200;  case 5:  return B2400;   case 6:  return B4800;
        case 8:  return B19200; case 9:  return B38400;  case 10: return 56000;
        case 11: return B57600; case 12: return B115200; case 13: return 128000;
        case 14: return 256000; case 0: case 7: default: return B9600;
    }
}

// hot-plug: drain the iterator (required to re-arm) and tell the UI to refresh
static void portsChanged(void *refcon, io_iterator_t iter) {
    (void)refcon;
    io_object_t o;
    while ((o = IOIteratorNext(iter))) IOObjectRelease(o);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:E68SerialPortsChangedNotification object:nil];
    });
}

@implementation SimSerialEngine {
    int _fd[MAX_COMM];
    IONotificationPortRef _notify;
    io_iterator_t _addIter, _rmIter;
    dispatch_source_t _rxPoll;          // raises the serial-RX IRQ when data waits
}

+ (instancetype)shared {
    static SimSerialEngine *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [SimSerialEngine new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        for (int i = 0; i < MAX_COMM; i++) _fd[i] = -1;
        NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
        _selectedPortPath = [u stringForKey:K_SER_PORT];
        _baudIndex = [u objectForKey:K_SER_BAUD] ? (int)[u integerForKey:K_SER_BAUD] : 7; // 9600
        [self startHotPlugWatch];
        [self startRxPoller];
    }
    return self;
}

// Poll open ports for inbound data; raise the serial-RX IRQ when the program
// has serial-RX interrupts enabled (no-op otherwise). The program's ISR reads
// the data via readComm, which clears the device buffer.
- (void)startRxPoller {
    _rxPoll = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
        dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0));
    dispatch_source_set_timer(_rxPoll, DISPATCH_TIME_NOW, 2 * NSEC_PER_MSEC, 1 * NSEC_PER_MSEC);
    __weak SimSerialEngine *weak = self;
    dispatch_source_set_event_handler(_rxPoll, ^{ [weak rxPollTick]; });
    dispatch_resume(_rxPoll);
}
- (void)rxPollTick {
    if (!simIntEnabled(SIM_INT_SER_RX)) return;
    for (int i = 0; i < MAX_COMM; i++) {
        int avail = 0;
        if (_fd[i] >= 0 && ioctl(_fd[i], FIONREAD, &avail) == 0 && avail > 0) {
            simIntNotify(SIM_INT_SER_RX);
            break;
        }
    }
}

- (void)startHotPlugWatch {
    _notify = IONotificationPortCreate(kIOMainPortDefault);
    if (!_notify) return;
    CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(_notify), kCFRunLoopDefaultMode);
    // kIOFirstMatchNotification = device arrived, kIOTerminatedNotification = removed.
    // Each registration fires once for existing devices — portsChanged drains to arm.
    CFMutableDictionaryRef m1 = IOServiceMatching(kIOSerialBSDServiceValue);
    IOServiceAddMatchingNotification(_notify, kIOFirstMatchNotification, m1, portsChanged, (__bridge void *)self, &_addIter);
    portsChanged((__bridge void *)self, _addIter);
    CFMutableDictionaryRef m2 = IOServiceMatching(kIOSerialBSDServiceValue);
    IOServiceAddMatchingNotification(_notify, kIOTerminatedNotification, m2, portsChanged, (__bridge void *)self, &_rmIter);
    portsChanged((__bridge void *)self, _rmIter);
}

#pragma mark enumeration

- (NSArray<NSDictionary<NSString *, id> *> *)availablePorts {
    NSMutableArray *ports = [NSMutableArray array];
    CFMutableDictionaryRef match = IOServiceMatching(kIOSerialBSDServiceValue);
    CFDictionarySetValue(match, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes));
    io_iterator_t iter;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, match, &iter) != KERN_SUCCESS) return ports;
    io_object_t svc;
    while ((svc = IOIteratorNext(iter))) {
        CFTypeRef path = IORegistryEntryCreateCFProperty(svc, CFSTR(kIOCalloutDeviceKey), kCFAllocatorDefault, 0);
        CFTypeRef name = IORegistryEntryCreateCFProperty(svc, CFSTR(kIOTTYDeviceKey), kCFAllocatorDefault, 0);
        if (path) {
            NSString *p = (__bridge NSString *)path;
            NSString *n = name ? (__bridge NSString *)name : p.lastPathComponent;
            [ports addObject:@{ @"path": p, @"name": n }];
        }
        if (path) CFRelease(path);
        if (name) CFRelease(name);
        IOObjectRelease(svc);
    }
    IOObjectRelease(iter);
    return ports;
}

#pragma mark persisted selection

- (void)setSelectedPortPath:(NSString *)p {
    _selectedPortPath = [p copy];
    [[NSUserDefaults standardUserDefaults] setObject:(p ?: @"") forKey:K_SER_PORT];
}
- (void)setBaudIndex:(int)b {
    _baudIndex = b;
    [[NSUserDefaults standardUserDefaults] setInteger:b forKey:K_SER_BAUD];
}

#pragma mark TRAP comm tasks

// Resolve the device to open: an explicit /dev path from the program wins,
// otherwise the port chosen in Settings.
- (NSString *)resolvePath:(const char *)portName {
    if (portName && portName[0]) {
        NSString *p = [NSString stringWithUTF8String:portName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) return p;   // explicit device wins
    }
    return self.selectedPortPath;
}

- (int)openComm:(int)cid path:(const char *)portName {
    if (cid < 0 || cid >= MAX_COMM) return 1;
    if (_fd[cid] >= 0) [self closeComm:cid];
    NSString *path = [self resolvePath:portName];
    if (!path.length) return 2;
    int fd = open(path.fileSystemRepresentation, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd < 0) return 2;
    struct termios t;
    if (tcgetattr(fd, &t) == 0) {
        cfmakeraw(&t);
        t.c_cflag |= CLOCAL | CREAD;
        cfsetspeed(&t, baudFromIndex(self.baudIndex));
        tcsetattr(fd, TCSANOW, &t);
    }
    _fd[cid] = fd;
    return 0;
}

- (int)setParams:(int)cid settings:(int)settings {
    if (cid < 0 || cid >= MAX_COMM) return 1;
    if (_fd[cid] < 0) return 3;
    int baud   = settings & 0xFF;
    int parity = (settings & 0x300) >> 8;     // 0=N 1=O 2=E 3=M
    int dbits  = (settings & 0xC00) >> 10;    // 0=8 1=7 2=6
    int sbits  = (settings & 0x1000) >> 12;   // 0=1 1=2
    struct termios t;
    if (tcgetattr(_fd[cid], &t) != 0) return 2;
    cfmakeraw(&t);
    t.c_cflag |= CLOCAL | CREAD;
    t.c_cflag &= ~CSIZE;
    t.c_cflag |= (dbits == 1) ? CS7 : (dbits == 2) ? CS6 : CS8;
    if (parity == 0)      t.c_cflag &= ~PARENB;
    else if (parity == 2) { t.c_cflag |= PARENB; t.c_cflag &= ~PARODD; }   // even
    else                  t.c_cflag |= PARENB | PARODD;                    // odd/mark
    if (sbits) t.c_cflag |= CSTOPB; else t.c_cflag &= ~CSTOPB;
    cfsetspeed(&t, baudFromIndex(baud));
    self.baudIndex = baud;
    if (tcsetattr(_fd[cid], TCSANOW, &t) != 0) return 2;
    return 0;
}

- (int)readComm:(int)cid buf:(char *)buf count:(unsigned char *)n {
    if (cid < 0 || cid >= MAX_COMM) return 1;
    if (_fd[cid] < 0) return 3;
    ssize_t got = read(_fd[cid], buf, *n);
    if (got < 0) { if (errno == EAGAIN || errno == EWOULDBLOCK) got = 0; else return 2; }
    buf[got] = 0;                 // null-terminate
    *n = (unsigned char)got;
    return 0;
}

- (int)sendComm:(int)cid buf:(const char *)buf count:(unsigned char *)n {
    if (cid < 0 || cid >= MAX_COMM) return 1;
    if (_fd[cid] < 0) return 3;
    ssize_t sent = write(_fd[cid], buf, *n);
    if (sent < 0) { if (errno == EAGAIN || errno == EWOULDBLOCK) sent = 0; else return 2; }
    *n = (unsigned char)sent;
    simIntNotify(SIM_INT_SER_TX);     // transmitter ready again (no-op if disabled)
    return 0;
}

- (void)closeComm:(int)cid {
    if (cid < 0 || cid >= MAX_COMM) return;
    if (_fd[cid] >= 0) { close(_fd[cid]); _fd[cid] = -1; }
}

@end
