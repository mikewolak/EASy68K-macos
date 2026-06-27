//---------------------------------------------------------------------------
// Network file definitions
//
// macOS C99 port (BSD sockets) of the original Winsock Net.cpp.
// Original author: Chuck Kelly, Monroe County Community College.
//---------------------------------------------------------------------------

#ifndef netH
#define netH

#include <stdio.h>

// network
#define DEFAULT_PORT            48161
#define DEFAULT_BUFFER_LENGTH    4096
#define UNINITIALIZED               0
#define SERVER                      1
#define CLIENT                      2
#define UNCONNECTED                -1
#define UDP                         0
#define TCP                         1
#define UNCONNECTED_TCP             2
#define CONNECTED_TCP               3

// status codes (enum so the header is safe to include from many C files —
// file-scope `const int` has external linkage in C and would multiply-define)
enum {
  NET_OK                       = 0,
  NET_ERROR                    = 1,
  NET_INIT_FAILED              = 2,
  NET_INVALID_SOCKET           = 3,
  NET_GET_HOST_BY_NAME_FAILED  = 4,
  NET_BIND_FAILED              = 5,
  NET_CONNECT_FAILED           = 6,
  NET_ADDR_IN_USE              = 7,
  NET_DOMAIN_NOT_FOUND         = 8,
  REMOTE_DISCONNECT            = 0x2775
};

#define NET_UDP   0
#define NET_TCP   1
#define IP_SIZE  16

// prototypes (no __fastcall; C++ reference params become pointers; the two
// overloaded send/read variants get distinct names for C)
int netInit(int port, int protocol);
int netCreateServer(int port, int protocol);
int netCreateClient(char *server, int port, int protocol);
int netLocalIP(char *localIP);
int netSendData(char *data, unsigned int *size, char *remoteIP);
int netReadData(char *data, unsigned int *size, char *senderIP);
int netSendDataPort(char *data, unsigned int *size, char *remoteIP, unsigned short port);
int netReadDataPort(char *data, unsigned int *size, char *senderIP, unsigned short *port);
int netCloseSockets(void);

//---------------------------------------------------------------------------
#endif
