
/***************************** 68000 SIMULATOR ****************************

File Name: PROTO.H
Version: 1.0

This file contains function prototype definitions for all functions
	in the program

***************************************************************************/



int MOVE(void );
int MOVEP(void );
int MOVEA(void );
int MOVE_FR_SR(void );
int MOVE_TO_CCR(void );
int MOVE_TO_SR(void );
int MOVEM(void );
int MOVE_USP(void );
int MOVEQ(void );
int EXG(void );
int LEA(void );
int PEA(void );
int LINK(void );
int UNLK(void );
int ADD(void );
int ADDA(void );
int ADDI(void );
int ADDQ(void );
int ADDX(void );
int SUB(void );
int SUBA(void );
int SUBI(void );
int SUBQ(void );
int SUBX(void );
int DIVS(void );
int DIVU(void );
int MULS(void );
int MULU(void );
int NEG(void );
int NEGX(void );
int CMP(void );
int CMPA(void );
int CMPI(void );
int CMPM(void );
int TST(void );
int CLR(void );
int EXT(void );
int ABCD(void );
int SBCD(void );
int NBCD(void );
int AND(void );
int ANDI(void );
int ANDI_TO_CCR(void );
int ANDI_TO_SR(void );
int OR(void );
int ORI(void );
int ORI_TO_CCR(void );
int ORI_TO_SR(void );
int EOR(void );
int EORI(void );
int EORI_TO_CCR(void );
int EORI_TO_SR(void );
int NOT(void );
int SHIFT_ROT(void );
int SWAP(void );
int BIT_OP(void );
int TAS(void );
int BCC(void );
int DBCC(void );
int SCC(void );
int BRA(void );
int BSR(void );
int JMP(void );
int JSR(void );
int RTE(void );
int RTR(void );
int RTS(void );
int NOP(void );
int CHK(void );
int ILLEGAL(void );
int RESET(void );
int STOP(void );
int TRAP(void );
int TRAPV(void );
int LINE1010();        //CK v2.3
int LINE1111();        //CK v2.3

void    at(int y,int x);
char    chk_buf(void );
int     gethelp(void );
void    home();
int     parse(char *str,char * *ptrbuf,int maxcnt);
int     runprog();
int     show_topics(void );
//int clrscr(void);
int iswhite(char c,char *qflag);
int decode_size(int32_t *result);
int eff_addr(int32_t size,int mask,int add_times);
int eff_addr_noread(int32_t size,int mask,int add_times);
int exec_inst(void );
void exceptionHandler(int, int32_t, int);
void irqHandler();
void cmderr();
void setdis();
void scrshow();
int mdis(void );
int selbp(void );
int dbpoint(void );
int memread(int loc,int MASK);
int memwrite(int loc,int32_t value);
int alter(void );
int hex_to_dec(void );
int dec_to_hex(void );
int intmod(void );
int portmod(void );
int pcmod(void );
int changemem(int32_t oldval,int32_t *result);
int mmod(void );
int regmod(char *regpntr,int data_or_mem);

// file handling
void closeFiles(short *result);
void openFile(int32_t *fn, char *name, short *result);
void newFile(int32_t *fn, char *name, short *result);
void readFile(int32_t fn, char *buf, unsigned int *size, short *result);
void writeFile(int32_t fn, char *buf, unsigned int size, short *result);
void positionFile(int32_t fn, int offset, short *result);
void closeFile(int32_t fn, short *result);
void deleteFile(char *buf, short *result);
int loadSrec(char *);
void fileOp(int32_t *mode, char *fname, short *result);


int clear(void );
char *getText(int word,char *prompt);
int same(char *str1,char *str2);
int eval(char *string);
int eval2(char *string,int32_t *result);
int getval(int word,char *prompt);
int strcopy(char *str1,char *str2);
char *mkfname(char *cp1,char *cp2,char *outbuf);
int pchange(char oldval);
int to_2s_comp(int32_t number,int32_t size,int32_t *result);
int from_2s_comp(int32_t number,int32_t size,int32_t *result);
int sign_extend(int number,int32_t size_from,int32_t *result);
void inc_cyc(int num);
int eff_addr_code(int inst,int start);
int a_reg(int reg_num);
int mem_put(int32_t data,int loc,int32_t size);
int mem_req(int loc,int32_t size,int32_t *result);
int mem_request(int32_t *loc,int32_t size,int32_t *result);
void put(int32_t *dest,int32_t source,int32_t size);
void reg_put(int32_t *dest,int32_t source,int32_t size);
void value_of(int32_t *EA,int32_t *EV,int32_t size);
int cc_update(int x,int n,int z,int v,int c,int32_t source,int32_t dest,int32_t result,int32_t size,int r);
int check_condition(int condition);
//uint flip(uint *n);
//uint flip(uint &n);
ushort flip(ushort *);

void windowLine();
void scrollWindow();
int scan(char *, char *[], int);       /* scan up to maxcnt words in str */
void save_cursor();
void restore_cursor();
void initSim();
void finishSim();
void errmess();		/* error message for invalid input */
void startSim();
void DFcommand();        // shows register display
void initPrint();
void haltSimulator();
int memoryMapCheck(maptype mapt, int loc, int bytes);


