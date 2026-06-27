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
//  SimRemoteServer.m
//  EASy68K — localhost HTTP control server.
//
#import "SimRemoteServer.h"
#import "SimController.h"
#import "ASMDocument.h"
#import "EASyBINController.h"
#import <Cocoa/Cocoa.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

@implementation SimRemoteServer {
    int _listenFD;
}

+ (instancetype)sharedServer {
    static SimRemoteServer *s; static dispatch_once_t o;
    dispatch_once(&o, ^{ s = [SimRemoteServer new]; });
    return s;
}

- (void)startOnPort:(uint16_t)port {
    if (port == 0) port = 8068;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [self runServer:port];
    });
}

- (void)runServer:(uint16_t)port {
    // Try the requested port, then a few alternates if it is busy. A fresh
    // socket is created for each attempt (a socket can't be re-bound after a
    // failed bind).
    BOOL bound = NO;
    for (int attempt = 0; attempt < 12 && !bound; attempt++) {
        _listenFD = socket(AF_INET, SOCK_STREAM, 0);
        if (_listenFD < 0) continue;
        int yes = 1; setsockopt(_listenFD, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
        struct sockaddr_in addr = {0};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);   // localhost only
        addr.sin_port = htons(port + attempt);
        if (bind(_listenFD, (struct sockaddr *)&addr, sizeof(addr)) == 0) {
            port = port + attempt; bound = YES;
        } else {
            close(_listenFD);
        }
    }
    if (!bound) { NSLog(@"[remote] could not bind a control port near %d", port); return; }
    listen(_listenFD, 8);
    NSLog(@"[remote] EASy68K control server on http://127.0.0.1:%d", port);
    while (1) {
        int fd = accept(_listenFD, NULL, NULL);
        if (fd < 0) continue;
        @autoreleasepool { [self handleClient:fd]; }
        close(fd);
    }
}

- (void)handleClient:(int)fd {
    // Read the full request (headers + optional body).
    NSMutableData *req = [NSMutableData data];
    char buf[4096];
    ssize_t n;
    NSInteger headerEnd = -1, contentLength = 0;
    while ((n = read(fd, buf, sizeof(buf))) > 0) {
        [req appendBytes:buf length:n];
        NSString *s = [[NSString alloc] initWithData:req encoding:NSUTF8StringEncoding] ?: @"";
        if (headerEnd < 0) {
            NSRange r = [s rangeOfString:@"\r\n\r\n"];
            if (r.location != NSNotFound) {
                headerEnd = r.location + r.length;
                NSRange cr = [s rangeOfString:@"Content-Length:" options:NSCaseInsensitiveSearch];
                if (cr.location != NSNotFound) {
                    NSString *rest = [s substringFromIndex:cr.location + cr.length];
                    contentLength = [rest integerValue];
                }
            }
        }
        if (headerEnd >= 0 && (NSInteger)req.length >= headerEnd + contentLength) break;
        if (n < (ssize_t)sizeof(buf)) break;
    }
    NSString *full = [[NSString alloc] initWithData:req encoding:NSUTF8StringEncoding] ?: @"";
    if (full.length == 0) return;

    // Parse request line.
    NSArray *lines = [full componentsSeparatedByString:@"\r\n"];
    NSArray *rl = [lines.firstObject componentsSeparatedByString:@" "];
    if (rl.count < 2) { [self send:fd status:400 type:@"text/plain" body:[@"bad request" dataUsingEncoding:NSUTF8StringEncoding]]; return; }
    NSString *method = rl[0];
    NSString *target = rl[1];
    NSString *path = target; NSString *query = @"";
    NSRange q = [target rangeOfString:@"?"];
    if (q.location != NSNotFound) { path = [target substringToIndex:q.location]; query = [target substringFromIndex:q.location+1]; }
    NSString *body = headerEnd >= 0 && (NSInteger)full.length >= headerEnd ? [full substringFromIndex:headerEnd] : @"";

    [self route:fd method:method path:path query:[self parseQuery:query] body:body];
}

- (NSDictionary *)parseQuery:(NSString *)q {
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    for (NSString *pair in [q componentsSeparatedByString:@"&"]) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        if (kv.count == 2) m[kv[0]] = [kv[1] stringByRemovingPercentEncoding] ?: kv[1];
    }
    return m;
}

// Run a block on the main thread synchronously and return its value.
static id mainSync(id (^block)(void)) {
    __block id result = nil;
    if ([NSThread isMainThread]) return block();
    dispatch_sync(dispatch_get_main_queue(), ^{ result = block(); });
    return result;
}

- (ASMDocument *)frontDoc {
    id doc = [NSDocumentController sharedDocumentController].currentDocument;
    if (!doc) doc = [[NSDocumentController sharedDocumentController].documents firstObject];
    return [doc isKindOfClass:[ASMDocument class]] ? doc : nil;
}

- (void)route:(int)fd method:(NSString *)method path:(NSString *)path
        query:(NSDictionary *)query body:(NSString *)body {
    // NOTE: [SimController sharedController] must be created/used on the main
    // thread only, so every access happens inside a mainSync() block.

    // --- plain-text reads ---
    if ([path isEqualToString:@"/console"]) {
        NSString *t = mainSync(^{ return [[SimController sharedController] remoteConsole]; });
        return [self sendText:fd text:t];
    }
    if ([path isEqualToString:@"/memory"]) {
        uint32_t addr = (uint32_t)strtoul([query[@"addr"] UTF8String] ?: "1000", NULL, 16);
        int len = query[@"len"] ? [query[@"len"] intValue] : 256;
        NSString *t = mainSync(^{ return [[SimController sharedController] remoteMemoryAt:addr length:len]; });
        return [self sendText:fd text:t];
    }
    if ([path isEqualToString:@"/source"] && [method isEqualToString:@"GET"]) {
        NSString *t = mainSync(^{ ASMDocument *d = [self frontDoc]; return d ? [d remoteSourceText] : @""; });
        return [self sendText:fd text:t];
    }
    if ([path isEqualToString:@"/bin/memory"]) {     // EASyBIN buffer dump
        uint32_t addr = (uint32_t)strtoul([query[@"addr"] UTF8String] ?: "0", NULL, 16);
        int len = query[@"len"] ? [query[@"len"] intValue] : 256;
        NSString *t = mainSync(^{ return [[EASyBINController shared] remoteMemoryAt:addr length:len]; });
        return [self sendText:fd text:t];
    }

    // --- JSON / action endpoints ---
    NSDictionary *result = mainSync(^id{
        SimController *sim = [SimController sharedController];
        ASMDocument *d = [self frontDoc];
        if ([path isEqualToString:@"/status"] || [path isEqualToString:@"/registers"])
            return [sim remoteState];
        if ([path isEqualToString:@"/open"]) {
            NSString *p = query[@"path"] ?: body;
            NSURL *u = [NSURL fileURLWithPath:[p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
            [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:u display:YES completionHandler:^(NSDocument *doc, BOOL already, NSError *e){}];
            return @{ @"opened": u.path ?: @"" };
        }
        if ([path isEqualToString:@"/source"]) { // POST
            if (!d) return @{ @"error": @"no document" };
            [d remoteSetSourceText:body];
            return @{ @"ok": @YES, @"length": @(body.length) };
        }
        if ([path isEqualToString:@"/save"]) {
            if (!d) return @{ @"error": @"no document" };
            [d saveDocument:nil];
            return @{ @"ok": @YES, @"path": d.fileURL.path ?: @"" };
        }
        if ([path isEqualToString:@"/assemble"]) {
            if (!d) return @{ @"error": @"no document" };
            return [d remoteAssemble];
        }
        if ([path isEqualToString:@"/run"]) {     // editor: assemble + open sim + run
            if (!d) return @{ @"error": @"no document" };
            [d remoteRunInSimulator];
            return @{ @"ok": @YES };
        }
        if ([path isEqualToString:@"/sim/load"]) { [sim remoteLoad:(query[@"path"] ?: body) title:nil]; return @{ @"ok": @YES }; }
        if ([path isEqualToString:@"/sim/run"])   { [sim remoteRun];   return @{ @"ok": @YES }; }
        if ([path isEqualToString:@"/sim/step"])  { [sim remoteStep];  return [sim remoteState]; }
        if ([path isEqualToString:@"/sim/stop"])  { [sim remoteStop];  return @{ @"ok": @YES }; }
        if ([path isEqualToString:@"/sim/reset"]) { [sim remoteReset]; return [sim remoteState]; }
        if ([path isEqualToString:@"/sim/input"]) { [sim remoteInput:(query[@"text"] ?: body)]; return @{ @"ok": @YES }; }

        // --- EASyBIN binary/S-record utility (no modal panels) ---
        if ([path hasPrefix:@"/bin/"]) {
            EASyBINController *bin = [EASyBINController shared];
            uint32_t (^hx)(NSString *, const char *) = ^uint32_t(NSString *k, const char *def) {
                return (uint32_t)strtoul([query[k] UTF8String] ?: def, NULL, 16); };
            int split = query[@"split"] ? [query[@"split"] intValue] : 0;
            NSString *p = query[@"path"] ?: body;
            if ([path isEqualToString:@"/bin/load-srec"]) return [bin remoteLoadSrec:p];
            if ([path isEqualToString:@"/bin/load-bin"])  return [bin remoteLoadBinary:p addr:hx(@"addr", "1000") split:split];
            if ([path isEqualToString:@"/bin/save-bin"])  return [bin remoteSaveBinary:p from:hx(@"from", "1000") length:hx(@"len", "100") split:split];
            if ([path isEqualToString:@"/bin/save-srec"]) return [bin remoteSaveSrec:p from:hx(@"from", "1000") to:hx(@"to", "10FF") start:hx(@"start", "1000")];
        }
        if ([path isEqualToString:@"/"])
            return @{ @"app": @"EASy68K", @"endpoints": @[@"/status",@"/registers",@"/memory?addr=&len=",@"/console",
                       @"/source (GET/POST)",@"/open?path=",@"/save",@"/assemble",@"/run",
                       @"/sim/load",@"/sim/run",@"/sim/step",@"/sim/stop",@"/sim/reset",@"/sim/input",
                       @"/bin/memory?addr=&len=",@"/bin/load-srec?path=",@"/bin/load-bin?path=&addr=&split=",
                       @"/bin/save-bin?path=&from=&len=&split=",@"/bin/save-srec?path=&from=&to=&start="] };
        return nil;
    });

    if (!result) { [self send:fd status:404 type:@"text/plain" body:[@"not found" dataUsingEncoding:NSUTF8StringEncoding]]; return; }
    NSData *json = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
    [self send:fd status:200 type:@"application/json" body:json];
}

- (void)sendText:(int)fd text:(NSString *)t {
    [self send:fd status:200 type:@"text/plain; charset=utf-8" body:[(t ?: @"") dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)send:(int)fd status:(int)code type:(NSString *)type body:(NSData *)body {
    NSString *head = [NSString stringWithFormat:
        @"HTTP/1.1 %d OK\r\nContent-Type: %@\r\nContent-Length: %lu\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n",
        code, type, (unsigned long)body.length];
    NSMutableData *out = [[head dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    [out appendData:body];
    const char *p = out.bytes; size_t left = out.length;
    while (left > 0) { ssize_t w = write(fd, p, left); if (w <= 0) break; p += w; left -= w; }
}

@end
