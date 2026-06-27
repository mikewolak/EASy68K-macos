*-----------------------------------------------------------------
* MCP self-connect test
* The 68K program opens a TCP client to the simulator's OWN remote
* control server (127.0.0.1:8077), sends an HTTP request and prints
* the response. Exercises TRAP #15 net tasks 100/102/103/104.
*   settings D1 = (port<<16) | type ; TCP=1, port 8077=$1F8D
*-----------------------------------------------------------------
        ORG     $1000
START
        LEA     SERVER,A2          * server IP string
        MOVE.L  #$1F8D0001,D1      * port 8077 (<<16) | TCP(1)
        MOVE.B  #100,D0            * createNetClient
        TRAP    #15
        TST.L   D0
        BNE     FAIL

        LEA     REQUEST,A1         * send the HTTP request
        LEA     SERVER,A2
        MOVE.L  #REQLEN,D1
        MOVE.B  #102,D0            * sendNet
        TRAP    #15
        TST.L   D0
        BNE     FAIL

        MOVE.L  #300000,D7         * poll/timeout counter
RECVLP
        LEA     BUFFER,A1
        LEA     SENDER,A2
        MOVE.L  #255,D1            * max bytes to read
        MOVE.B  #103,D0            * receiveNet
        TRAP    #15
        TST.L   D0
        BNE     DONE               * nonzero incl. remote-disconnect
        TST.L   D1
        BEQ     NODATA
        LEA     BUFFER,A1          * null-terminate at D1 bytes
        MOVE.L  D1,D2
        CLR.B   0(A1,D2.L)
        MOVE.B  #14,D0             * display string, no CRLF
        TRAP    #15
        MOVE.L  #300000,D7         * reset timeout, keep reading
        BRA     RECVLP
NODATA
        SUBQ.L  #1,D7
        BNE     RECVLP
        LEA     MSGTIME,A1
        MOVE.B  #13,D0
        TRAP    #15
        BRA     CLOSE
DONE
        LEA     MSGDONE,A1
        MOVE.B  #13,D0
        TRAP    #15
        BRA     CLOSE
FAIL
        LEA     MSGFAIL,A1
        MOVE.B  #13,D0
        TRAP    #15
CLOSE
        MOVE.B  #104,D0            * closeNetConnection
        TRAP    #15
        SIMHALT

SERVER  DC.B    '127.0.0.1',0
REQUEST DC.B    'GET /status HTTP/1.0',13,10,13,10
REQLEN  EQU     *-REQUEST
        DS.W    0
MSGFAIL DC.B    'NET ERROR (D0 set)',0
MSGDONE DC.B    13,10,'-- CONNECTION CLOSED --',0
MSGTIME DC.B    13,10,'-- TIMEOUT (no data) --',0
        DS.W    0
BUFFER  DS.B    260
SENDER  DS.B    16
        END     START
