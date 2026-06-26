/***************************** 68000 SIMULATOR ****************************

File Name: bpointexpr.h
Debugger Component

C99 port of the original C++ BPointExpr class: a logical expression that
combines individual breakpoints (postfix form). Class -> struct; methods
-> BPointExpr_* functions. The display string (originally an AnsiString)
is held in a fixed char buffer.

***************************************************************************/
#ifndef BPOINT_EXPR_H
#define BPOINT_EXPR_H

#include <stdbool.h>
#include "def.h"        // MAX_LB_NODES

#define BP_EXPR_STR_MAX 256

typedef struct BPointExpr {
    int  id;                          // Uniquely identifies the expression
    int  postfix_expr[MAX_LB_NODES];
    int  infix_expr[MAX_LB_NODES];
    int  p_count;                     // valid postfix_expr elements
    int  i_count;
    char expr[BP_EXPR_STR_MAX];       // expression stored linearly for display
    int  count;                       // required number of times conditions met
    bool isBrk;                       // has the break condition been met?
    bool isEnab;                      // is the expression being tested?
} BPointExpr;

void BPointExpr_init(BPointExpr *e);

int  BPointExpr_getId(BPointExpr *e);
void BPointExpr_setId(BPointExpr *e, int id);
void BPointExpr_setPostfixExpr(BPointExpr *e, int *postfix, int pcount);
void BPointExpr_getPostfixExpr(BPointExpr *e, int *postfix, int *pcount);
void BPointExpr_setInfixExpr(BPointExpr *e, int *infix, int icount);
void BPointExpr_getInfixExpr(BPointExpr *e, int *infix, int *icount);
const char *BPointExpr_getExprString(BPointExpr *e);
void BPointExpr_setExprString(BPointExpr *e, const char *expr);
int  BPointExpr_getCount(BPointExpr *e);
void BPointExpr_setCount(BPointExpr *e, int count);
bool BPointExpr_isEnabled(BPointExpr *e);
void BPointExpr_setEnabled(BPointExpr *e, bool isEnab);
bool BPointExpr_isBreak(BPointExpr *e);

#endif
