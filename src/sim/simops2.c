
/***************************** 68000 SIMULATOR ****************************

File Name: SIMOPS2.C

This file contains various routines for simulator operation

   Modified: Chuck Kelly
             Monroe County Community College
             http://www.monroeccc.edu/ckelly

***************************************************************************/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "extern.h"
#include "simhost.h"

extern int ROMStart, ROMEnd, ReadStart, ReadEnd;
extern int ProtectedStart, ProtectedEnd, InvalidStart, InvalidEnd;
extern bool ROMMap, ReadMap, ProtectedMap, InvalidMap;

#define	MODIFY_DATA	0
#define	MODIFY_MEMORY	1

//-----------------------------------------------------------------------
// Close all files
void closeFiles(short *result)
{
  *result = F_SUCCESS;
  for (int i=0; i<MAXFILES; i++) {  // clear file structures
    if (files[i].fp != NULL) {
      if(fclose(files[i].fp) == EOF)
        *result = F_ERROR;
      files[i].fp = NULL;
    }
  }
}

//-----------------------------------------------------------------------
// Other file operations.
// mode == 0, does file exist?
//   all other values reserved.
// result:
//    F_ERROR - file does not exist
//    F_SUCCESS - file exists and may be written to
//    F_READONLY - file exists but is read only
void fileOp(int32_t *mode, char *fname, short *result)
{
  FILE *fp;
  *result = F_ERROR;                    // default to error
  fp = fopen(fname, "r+b");             // try to open file for update
  if (fp != NULL) {                     // if success
    *result = F_SUCCESS;
  } else {
    fp = fopen(fname, "rb");            // try to open file for read only
    if (fp != NULL) {                   // if success
      *result = F_READONLY;
    }
  }
  fclose(fp);
}

//-----------------------------------------------------------------------
// Open existing file
void openFile(int32_t *fn, char *fname, short *result)
{
  *result = F_ERROR;                    // default to error
  *fn = -1;                             // "
  for (int i=0; i<MAXFILES; i++) {      // find empty file pointer
    if (files[i].fp == NULL) {          // if this file structure is empty
      files[i].fp = fopen(fname, "r+b"); // try to open file for update
      if (files[i].fp != NULL) {        // if success
        strcpy(files[i].name,fname);    // save name of file to file structure
        *result = F_SUCCESS;
        *fn = i;                        // file number is array position
        break;
      }
      files[i].fp = fopen(fname, "rb"); // try to open file for read only
      if (files[i].fp != NULL) {        // if success
        strcpy(files[i].name,fname);    // save name of file to file structure
        *result = F_READONLY;
        *fn = i;                        // file number is array position
        break;
      }
    }
  }
}

//-----------------------------------------------------------------------
// Open new file
void newFile(int32_t *fn, char *fname, short *result)
{
  *result = F_ERROR;                    // default to error
  *fn = -1;                             // "
  for (int i=0; i<MAXFILES; i++) {      // find empty file pointer
    if (files[i].fp == NULL) {          // if this file structure is empty
      files[i].fp = fopen(fname, "w+b"); // open file
      if (files[i].fp != NULL) {        // if success
        strcpy(files[i].name,fname);    // save name of file to file structure
        *result = F_SUCCESS;
        *fn = i;                        // file number is array position
        break;
      }
    }
  }
}

//-----------------------------------------------------------------------
// Read from file
void readFile(int32_t fn, char *buf, unsigned int *size, short *result)
{
  *result = F_ERROR;            // default to error
  if (fn < 0 || fn >= MAXFILES) // if invalid file pointer
    return;
  if (files[fn].fp == NULL)     // if invalid file pointer
    return;

  unsigned int r = fread(buf, 1, *size, files[fn].fp);  // read from file

  if (r < 1) {                  // if error or EOF
    if (feof(files[fn].fp))
      *result = F_EOF;
    else
      *result = F_ERROR;
  } else {
    *result = F_SUCCESS;
    *size = r;                  // number of bytes read
  }

}

//-----------------------------------------------------------------------
// Write to file
void writeFile(int32_t fn, char *buf, unsigned int size, short *result)
{
  *result = F_ERROR;            // default to error
  if (fn < 0 || fn >= MAXFILES) // if invalid file pointer
    return;
  if (files[fn].fp == NULL)     // if invalid file pointer
    return;

  unsigned int r = fwrite(buf, size, 1, files[fn].fp);

  if (r >= 1)                   // if success
    *result = F_SUCCESS;
}

//-----------------------------------------------------------------------
// Position file pointer
void positionFile(int32_t fn, int offset, short *result)
{
  *result = F_ERROR;            // default to error
  if (fn < 0 || fn >= MAXFILES) // if invalid file pointer
    return;
  if (files[fn].fp == NULL)     // if invalid file pointer
    return;

  int r = fseek(files[fn].fp, offset, SEEK_SET);

  if (r == 0)                   // if success
    *result = F_SUCCESS;
}

//-----------------------------------------------------------------------
// Close file
void closeFile(int32_t fn, short *result)
{
  *result = F_ERROR;            // default to error
  if (fn < 0 || fn >= MAXFILES) // if invalid file pointer
    return;
  if (files[fn].fp == NULL)     // if invalid file pointer
    return;

  int r = fclose(files[fn].fp);
  if (r == 0)
    *result = F_SUCCESS;
  files[fn].fp = NULL;          // clear file pointer
}

//-----------------------------------------------------------------------
// Delete file
void deleteFile(char *fname, short *result)
{
  *result = F_ERROR;            // default to error
  if (remove(fname) == 0)
    *result = F_SUCCESS;
}

//-----------------------------------------------------------------------
// Load S Record file
//                               /-version number
//          module name         / /-revision number                     checksum
//S0  0000 6 8 K P R O G       2 0 C R E A T E D   B Y   E A S Y 6 8 K /
//S021000036384B50524F47202020323043524541544544204259204541535936384B6D
//S0  0000             R O M   0 0 0 0 0 0 , 0 0 0 0 0 0cc
//S0  0000           R E A D   0 0 0 0 0 0 , 0 0 0 0 0 0cc
//S0  0000 P R O T E C T E D   0 0 0 0 0 0 , 0 0 0 0 0 0cc
//S0  0000     I N V A L I D   0 0 0 0 0 0 , 0 0 0 0 0 0cc
//S0nn0000
int loadSrec(char *name)        // load memory with contents of s_record file
{
  FILE *fp;
  int bytecount, line, loc, end__of__file;
  char s_byte[4], s_type, nambuf[40];
  char *bufptr, *bufend;
  uchar checksum;
  char str[256];                 // S0 description, built up byte by byte
  int  strLen;
  const char EASy68K_HEADER[] = "S0 = 68KPROG   20CREATED BY EASY68K";
  bool EASy68Kv2_0_SRecord = false;
  bool sRecError = false;
  bool skipRecord;              // used to skip loading record data

  {
    fp = fopen(name, "rt");
    if (fp == NULL) {             // if file cannot be opened, print message
      snprintf(buffer, sizeof(buffer), "error: cannot open file %s", name), simMessage(buffer);
      return FAILURE;
    }

    line = 0;
    end__of__file = false;
    s_type = 0;

    while (fgets(lbuf, SREC_MAX, fp) != NULL) { // read file until end
      bufptr = lbuf;
      checksum = 0;
      skipRecord = false;
      line++;
      sscanf (lbuf, "S%c%2x", &s_type, &bytecount);
      bufptr += 4;
      checksum += bytecount;
      switch (s_type) {         // what type of S record ?
        // S0  Description of S-Record
        case '0' :
          skipRecord = true;    // don't load S0 data
          for (bufend = bufptr; *bufend != '\0'; bufend++);  // put bufend at end of line
          if (sscanf(bufptr,"%04x", &loc) != 1) // 2 byte address
            sRecError = true;
          else
            bufptr += 4;
          strcpy(str, "S0 = ");
          strLen = 5;
          while (sscanf(bufptr,"%2x",&s_byte)) {
            bufptr += 2;
            checksum += s_byte[0];
            if ((bufptr + 2) >= bufend) break;  // if checksum byte
              if (s_byte[0] >= ' ' && s_byte[0] <= '~') // if displayable
                str[strLen++] = s_byte[0];      // add character to str
              else
                str[strLen++] = '.';            // use '.' for non displayable
          }
          str[strLen] = '\0';
          checksum = ~checksum &0xFF;
          if(checksum)                          // if checksum not 0
          {
            snprintf(buffer, sizeof(buffer), "Checksum error on line %d...",line);
            simMessage(buffer);
          }
          simMessage(str);
          if(EASy68Kv2_0_SRecord)       // if this is an EASy68K 2.0 SRecord file
          {
            // Set memory map from the S0 description (1-indexed Borland
            // SubString(6,9) == str[5..13]; SubString(16,6)/SubString(23,6)
            // are the 6-hex-digit start/end addresses). Sets core map state
            // and notifies the host's hardware display.
            // Does not erase existing map if no map specified.
            int mapStart = (int)strtol((char[]){str[15],str[16],str[17],str[18],str[19],str[20],'\0'}, NULL, 16);
            int mapEnd   = (int)strtol((char[]){str[22],str[23],str[24],str[25],str[26],str[27],'\0'}, NULL, 16);
            if(strLen >= 28 && strncmp(&str[5], "      ROM", 9) == 0) {        // ROM range
              ROMMap = true; ROMStart = mapStart; ROMEnd = mapEnd;
              simHardwareSetMap(0, mapStart, mapEnd);
            } else if(strLen >= 28 && strncmp(&str[5], "     READ", 9) == 0) { // Read/Only range
              ReadMap = true; ReadStart = mapStart; ReadEnd = mapEnd;
              simHardwareSetMap(1, mapStart, mapEnd);
            } else if(strLen >= 28 && strncmp(&str[5], "PROTECTED", 9) == 0) { // Protected range
              ProtectedMap = true; ProtectedStart = mapStart; ProtectedEnd = mapEnd;
              simHardwareSetMap(2, mapStart, mapEnd);
            } else if(strLen >= 28 && strncmp(&str[5], "  INVALID", 9) == 0) { // Invalid range
              InvalidMap = true; InvalidStart = mapStart; InvalidEnd = mapEnd;
              simHardwareSetMap(3, mapStart, mapEnd);
            }
          }else if(strcmp(str, EASy68K_HEADER) == 0)
            EASy68Kv2_0_SRecord = true;
          str[0] = '\0';
          break;
        // S1 2-byte address
        case '1' :
          if (sscanf(bufptr,"%04x", &loc) != 1)
            sRecError = true;
          else
            bufptr += 4;
          break;
        // S2 3-byte address
        case '2' :
          if (sscanf(bufptr,"%06x", &loc) != 1)
            sRecError = true;
          else
            bufptr += 6;
          break;
        // S3 4-byte address
        case '3' :
          if (sscanf(bufptr,"%08x", &loc) != 1)
            sRecError = true;
          else
            bufptr += 8;
          break;
        // S5 length count
        case '5' :
          skipRecord = true;      // ignore
          break;
        // S7 4-byte starting address
        case '7' :
          if (sscanf(bufptr,"%08x", &loc) != 1)
            sRecError = true;
          else {
            PC = loc;
            end__of__file = true;
          }
          break;
        // S8 3-byte starting address
        case '8' :
          if (sscanf(bufptr,"%06x", &loc) != 1)
            sRecError = true;
          else {
            PC = loc;
            end__of__file = true;
          }
          break;
        // S9 2-byte starting address
        case '9' :
          if (sscanf(bufptr,"%04x", &loc) != 1)
            sRecError = true;
          else {
            PC = loc;
            end__of__file = true;
          }
          break;
        default :  sRecError = true;
      }
      if (end__of__file) break;
      if (sRecError) break;
      if (!skipRecord)
      {
        checksum += loc&0xFF;
        checksum += (loc&0xFF00)>>8;
        checksum += (loc&0xFF0000)>>16;
        checksum += (loc&0xFF000000)>>24;
        for (bufend = bufptr; *bufend != '\0'; bufend++);  // put bufend at end of line
        while (sscanf(bufptr,"%02x",&s_byte)) {
          bufptr += 2;
          checksum += s_byte[0];
          if ((bufptr + 2) >= bufend) break;    // if checksum byte
          if ((loc < 0) || (loc > (MEMSIZE - 1))) {
            snprintf(buffer, sizeof(buffer), "Invalid Address on line %d...",line), simMessage(buffer);
            sRecError = true;
            break;
          }
          else
            memory[loc++ & ADDRMASK] = s_byte[0];
        }
        checksum = ~checksum &0xFF;
        if(checksum)                    // if checksum not 0
          snprintf(buffer, sizeof(buffer), "Checksum error on line %d...",line), simMessage(buffer);
        if (sRecError) break;
      }
    } // endw read until end of file
    if (sRecError)                     // if error reading file, print message
    {
      snprintf(buffer, sizeof(buffer), "Invalid data on line %d of .S68 file...",line), simMessage(buffer);
      snprintf(buffer, sizeof(buffer), "%d: %s", line, lbuf), simMessage(buffer);    // *ck 12-3-2005
      snprintf(buffer, sizeof(buffer), "Remainder of load stopped..."), simMessage(buffer);
    }else{
      snprintf(buffer, sizeof(buffer), ".S68 file read successful"), simMessage(buffer);
    }
    fclose(fp);			// close file specified
    return SUCCESS;
    }
}


