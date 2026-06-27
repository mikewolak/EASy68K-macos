//---------------------------------------------------------------------------
//   macOS C99 port (BSD sockets) of the original Winsock Net.cpp.
//   Original author: Chuck Kelly, Monroe County Community College.
//
//   The TRAP #15 networking tasks (100-107) drive these. Winsock maps almost
//   1:1 onto BSD sockets: SOCKET->int, INVALID_SOCKET/SOCKET_ERROR->-1,
//   closesocket->close, ioctlsocket(FIONBIO)->fcntl(O_NONBLOCK),
//   WSAGetLastError->errno, WSAE*->E*. Sockets are non-blocking, so the 68K
//   program polls receive until data arrives.
//---------------------------------------------------------------------------

#include "net.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>

static int                sock = -1;
static int                ret = 0;
static struct sockaddr_in remote, local;
static int                netInitialized = 0;
static int                bound = 0;
static char               mode = UNINITIALIZED;
static int                type = UNCONNECTED;

static int setNonBlocking(int s) {
  int fl = fcntl(s, F_GETFL, 0);
  if (fl < 0) return -1;
  return fcntl(s, F_SETFL, fl | O_NONBLOCK);
}

//---------------------------------------------------------------------------
// Initialize network. protocol = UDP or TCP, port = local/remote port.
int netInit(int port, int protocol)
{
  if (netInitialized)            // currently initialized -> close and start over
    netCloseSockets();
  mode = UNINITIALIZED;

  switch (protocol) {
    case UDP:
      sock = socket(AF_INET, SOCK_DGRAM, 0);
      if (sock < 0) return ((errno << 16) + NET_INVALID_SOCKET);
      type = UDP;
      break;
    case TCP:
      sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
      if (sock < 0) return ((errno << 16) + NET_INVALID_SOCKET);
      type = UNCONNECTED_TCP;
      break;
    default:
      return NET_INIT_FAILED;
  }

  if (setNonBlocking(sock) < 0)
    return ((errno << 16) + NET_INVALID_SOCKET);

  memset(&local, 0, sizeof(local));
  memset(&remote, 0, sizeof(remote));
  local.sin_family  = AF_INET;
  local.sin_port    = htons((unsigned short)port);
  remote.sin_family = AF_INET;
  remote.sin_port   = htons((unsigned short)port);

  netInitialized = 1;
  return NET_OK;
}

//---------------------------------------------------------------------------
// Setup network as a server (bind; TCP listens later in netReadData).
int netCreateServer(int port, int protocol)
{
  int status = netInit(port, protocol);
  if (status != NET_OK)
    return status;

  local.sin_addr.s_addr = htonl(INADDR_ANY);     // listen on all addresses
  if (bind(sock, (struct sockaddr *)&local, sizeof(local)) < 0)
    return ((errno << 16) + NET_BIND_FAILED);

  bound = 1;
  mode  = SERVER;
  return NET_OK;
}

//---------------------------------------------------------------------------
// Setup network as a client. *server = dotted-quad IP or hostname; on a
// hostname it is rewritten to the resolved dotted-quad.
int netCreateClient(char *server, int port, int protocol)
{
  int status, timeout = 5000;       // try to connect for ~5 s
  char localIP[16] = "127.0.0.1";
  struct hostent *host;

  status = netInit(port, protocol);
  if (status != NET_OK)
    return status;

  // resolve a hostname if `server` is not a dotted-quad
  remote.sin_addr.s_addr = inet_addr(server);
  if (remote.sin_addr.s_addr == INADDR_NONE) {
    host = gethostbyname(server);
    if (host == NULL)
      return NET_DOMAIN_NOT_FOUND;
    memcpy(&remote.sin_addr, host->h_addr_list[0], (size_t)host->h_length);
    strncpy(server, inet_ntoa(remote.sin_addr), 16);   // return resolved IP
  }

  netLocalIP(localIP);
  local.sin_addr.s_addr = inet_addr(localIP);
  mode = CLIENT;

  // non-blocking connect for TCP: first attempt -> EINPROGRESS, then EALREADY,
  // finally EISCONN when established (UDP skips this entirely)
  while (type == UNCONNECTED_TCP && timeout > 0) {
    ret = connect(sock, (struct sockaddr *)&remote, sizeof(remote));
    if (ret < 0) {
      int e = errno;
      if (e == EISCONN) { ret = 0; type = CONNECTED_TCP; }
      else if (e == EWOULDBLOCK || e == EAGAIN || e == EALREADY || e == EINPROGRESS) {
        usleep(500 * 1000);          // wait 500 ms before the next attempt
        timeout -= 500;
      } else
        return ((e << 16) + NET_ERROR);
    } else {
      type = CONNECTED_TCP;          // connected immediately
    }
  }
  return NET_OK;
}

//---------------------------------------------------------------------------
// Send data to remote. Returns NET_OK; *size = bytes actually sent (may be 0).
int netSendData(char *data, unsigned int *size, char *remoteIP)
{
  int sendSize = (int)*size;
  *size = 0;

  if (mode == SERVER)
    remote.sin_addr.s_addr = inet_addr(remoteIP);

  if (mode == CLIENT && type == UNCONNECTED_TCP) {
    ret = connect(sock, (struct sockaddr *)&remote, sizeof(remote));
    if (ret < 0) {
      int e = errno;
      if (e == EISCONN) { ret = 0; type = CONNECTED_TCP; }
      else if (e == EWOULDBLOCK || e == EAGAIN || e == EALREADY || e == EINPROGRESS)
        return NET_OK;               // not connected yet
      else
        return ((e << 16) + NET_ERROR);
    } else {
      type = CONNECTED_TCP;
    }
  }

  ret = sendto(sock, data, sendSize, 0, (struct sockaddr *)&remote, sizeof(remote));
  if (ret < 0)
    return ((errno << 16) + NET_ERROR);
  bound = 1;                         // sendto auto-binds if unbound
  *size = (unsigned int)ret;
  return NET_OK;
}

//---------------------------------------------------------------------------
// Send data to remote IP and port (UDP datagram to a specific port).
int netSendDataPort(char *data, unsigned int *size, char *remoteIP, unsigned short port)
{
  int sendSize = (int)*size;
  *size = 0;

  if (mode == SERVER) {
    remote.sin_addr.s_addr = inet_addr(remoteIP);
    remote.sin_port = htons(port);
  }

  if (mode == CLIENT && type == UNCONNECTED_TCP) {
    ret = connect(sock, (struct sockaddr *)&remote, sizeof(remote));
    if (ret < 0) {
      int e = errno;
      if (e == EISCONN) { ret = 0; type = CONNECTED_TCP; }
      else if (e == EWOULDBLOCK || e == EAGAIN || e == EALREADY || e == EINPROGRESS)
        return NET_OK;
      else
        return ((e << 16) + NET_ERROR);
    } else {
      type = CONNECTED_TCP;
    }
  }

  ret = sendto(sock, data, sendSize, 0, (struct sockaddr *)&remote, sizeof(remote));
  if (ret < 0)
    return ((errno << 16) + NET_ERROR);
  bound = 1;
  *size = (unsigned int)ret;
  return NET_OK;
}

//---------------------------------------------------------------------------
// TCP server: accept a pending connection (non-blocking). Returns 1 if a
// connection is up, 0 if still waiting, <0 (negated status) on error.
static int acceptIfServer(void)
{
  if (mode == SERVER && type == UNCONNECTED_TCP) {
    if (listen(sock, 1) < 0)
      return -(((errno) << 16) + NET_ERROR);
    int tempSock = accept(sock, NULL, NULL);
    if (tempSock < 0) {
      int e = errno;
      if (e != EWOULDBLOCK && e != EAGAIN)
        return -(((e) << 16) + NET_ERROR);
      return 0;                      // no connection yet
    }
    close(sock);                     // drop the listening socket
    sock = tempSock;                 // client connected
    setNonBlocking(sock);
    type = CONNECTED_TCP;
  }
  return 1;
}

//---------------------------------------------------------------------------
// Read data, return sender's IP. Non-blocking: *size = bytes read (may be 0).
int netReadData(char *data, unsigned int *size, char *senderIP)
{
  int readSize = (int)*size;
  *size = 0;
  if (!bound)
    return NET_OK;

  int acc = acceptIfServer();
  if (acc < 0) return -acc;          // propagate error status
  if (acc == 0) return NET_OK;       // server still waiting

  if (mode == CLIENT && type == UNCONNECTED_TCP)
    return NET_OK;                   // not connected yet

  if (sock >= 0) {
    socklen_t rs = sizeof(remote);
    ret = recvfrom(sock, data, readSize, 0, (struct sockaddr *)&remote, &rs);
    if (ret < 0) {
      int e = errno;
      if (e != EWOULDBLOCK && e != EAGAIN)
        return ((e << 16) + NET_ERROR);
      ret = 0;
    } else if (ret == 0 && type == CONNECTED_TCP) {
      return ((REMOTE_DISCONNECT << 16) + NET_ERROR);   // graceful close
    }
    if (ret)
      strncpy(senderIP, inet_ntoa(remote.sin_addr), IP_SIZE);
    *size = (unsigned int)ret;
  }
  return NET_OK;
}

//---------------------------------------------------------------------------
// Read data, return sender's IP and port.
int netReadDataPort(char *data, unsigned int *size, char *senderIP, unsigned short *port)
{
  int readSize = (int)*size;
  *size = 0;
  if (!bound)
    return NET_OK;

  int acc = acceptIfServer();
  if (acc < 0) return -acc;
  if (acc == 0) return NET_OK;

  if (mode == CLIENT && type == UNCONNECTED_TCP)
    return NET_OK;

  if (sock >= 0) {
    socklen_t rs = sizeof(remote);
    ret = recvfrom(sock, data, readSize, 0, (struct sockaddr *)&remote, &rs);
    if (ret < 0) {
      int e = errno;
      if (e != EWOULDBLOCK && e != EAGAIN)
        return ((e << 16) + NET_ERROR);
      ret = 0;
    } else if (ret == 0 && type == CONNECTED_TCP) {
      return ((REMOTE_DISCONNECT << 16) + NET_ERROR);
    }
    if (ret) {
      strncpy(senderIP, inet_ntoa(remote.sin_addr), IP_SIZE);
      *port = ntohs(remote.sin_port);
    }
    *size = (unsigned int)ret;
  }
  return NET_OK;
}

//---------------------------------------------------------------------------
// Close socket.
int netCloseSockets(void)
{
  type = UNCONNECTED;
  if (sock >= 0) {
    if (close(sock) < 0) {
      int e = errno;
      if (e != EWOULDBLOCK)
        return ((e << 16) + NET_ERROR);
    }
  }
  sock = -1;
  netInitialized = 0;
  bound = 0;
  return NET_OK;
}

//---------------------------------------------------------------------------
// Get this machine's IP address as a string.
int netLocalIP(char *localIP)
{
  char hostName[256];
  struct hostent *host;

  if (gethostname(hostName, sizeof(hostName)) < 0) {
    strcpy(localIP, "127.0.0.1");
    return NET_OK;
  }
  host = gethostbyname(hostName);
  if (host == NULL) {
    strcpy(localIP, "127.0.0.1");           // fallback (offline / no DNS)
    return NET_OK;
  }
  strncpy(localIP, inet_ntoa(*(struct in_addr *)host->h_addr_list[0]), IP_SIZE);
  return NET_OK;
}
