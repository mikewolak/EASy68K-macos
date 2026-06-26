//
//  SimRemoteServer.h
//  EASy68K — small localhost HTTP control server so the whole app can be
//  driven remotely (open/edit/assemble/run/step + read registers, memory,
//  console). Intended for automation and testing.
//
#import <Foundation/Foundation.h>

@interface SimRemoteServer : NSObject
+ (instancetype)sharedServer;
- (void)startOnPort:(uint16_t)port;   // default 8068
@end
