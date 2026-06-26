/***************************** 68000 SIMULATOR ****************************

File Name: bpointexpr.c
Debugger Component

C99 port of BPointExpr.cpp. Evaluates a postfix breakpoint expression.

***************************************************************************/

#include <string.h>
#include "extern.h"
#include "bpointexpr.h"
#include "bpoint.h"

void BPointExpr_init(BPointExpr *e) {
    e->id = 0; e->p_count = 0; e->i_count = 0;
    e->expr[0] = '\0'; e->count = 0; e->isBrk = false; e->isEnab = false;
}

int  BPointExpr_getId(BPointExpr *e)            { return e->id; }
void BPointExpr_setId(BPointExpr *e, int id)    { e->id = id; }

void BPointExpr_setPostfixExpr(BPointExpr *e, int *postfix, int pcount) {
    e->p_count = pcount;
    for (int p = 0; p < pcount; p++) e->postfix_expr[p] = postfix[p];
}
void BPointExpr_getPostfixExpr(BPointExpr *e, int *postfix, int *pcount) {
    *pcount = e->p_count;
    for (int p = 0; p < e->p_count; p++) postfix[p] = e->postfix_expr[p];
}
void BPointExpr_setInfixExpr(BPointExpr *e, int *infix, int icount) {
    e->i_count = icount;
    for (int i = 0; i < icount; i++) e->infix_expr[i] = infix[i];
}
void BPointExpr_getInfixExpr(BPointExpr *e, int *infix, int *icount) {
    *icount = e->i_count;
    for (int i = 0; i < e->i_count; i++) infix[i] = e->infix_expr[i];
}

const char *BPointExpr_getExprString(BPointExpr *e) { return e->expr; }
void BPointExpr_setExprString(BPointExpr *e, const char *expr) {
    strncpy(e->expr, expr, BP_EXPR_STR_MAX-1);
    e->expr[BP_EXPR_STR_MAX-1] = '\0';
}

int  BPointExpr_getCount(BPointExpr *e)          { return e->count; }
void BPointExpr_setCount(BPointExpr *e, int c)   { e->count = c; }
bool BPointExpr_isEnabled(BPointExpr *e)         { return e->isEnab; }
void BPointExpr_setEnabled(BPointExpr *e, bool en) { e->isEnab = en; }

// Evaluate the postfix breakpoint expression left to right.
bool BPointExpr_isBreak(BPointExpr *e) {
    // If the breakpoint is turned off, then don't process
    if (!e->isEnab)
        return false;

    // Operand stack (fixed depth; postfix length is bounded by MAX_LB_NODES)
    bool s_operand[MAX_LB_NODES + 1];
    int  sp = 0;
    int  curToken;

    // Read the postfix expression from left to right.
    for (int ex = 0; ex < e->p_count; ex++) {
        curToken = e->postfix_expr[ex];

        // If the token is an operand, push its breakpoint result.
        if (curToken >= 0 && curToken < MAX_BPOINTS) {
            s_operand[sp++] = BPoint_isBreak(&breakPoints[curToken]);
        } else {
            // Operator: pop two operands, apply, push result.
            bool aCondition = s_operand[--sp];
            bool bCondition = s_operand[--sp];
            bool curCondition = false;
            switch (curToken) {
                case MAX_BPOINTS + AND_OP:
                    curCondition = aCondition && bCondition;
                    break;
                case MAX_BPOINTS + OR_OP:
                    curCondition = aCondition || bCondition;
                    break;
                default:
                    curCondition = false;
                    break;
            }
            s_operand[sp++] = curCondition;
        }
    }

    // At the end, pop the result.
    e->isBrk = s_operand[--sp];

    // Verify the condition has been met the specified number of times.
    if (e->isBrk) bpCountCond[e->id]++;
    e->isBrk = (e->count == bpCountCond[e->id]);
    if (e->isBrk) bpCountCond[e->id] = 0;   // Reset counter for next iteration.
    return e->isBrk;
}
