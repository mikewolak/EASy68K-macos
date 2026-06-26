/***************************** 68000 SIMULATOR ****************************

File Name: net_stub.c

Minimal stub for the networking entry point the simulator core references.
The full Berkeley/Winsock implementation (net.c) belongs to the host I/O
device; the portable core only needs netCloseSockets() during reset.

***************************************************************************/

int netCloseSockets(void)
{
    return 0;
}
