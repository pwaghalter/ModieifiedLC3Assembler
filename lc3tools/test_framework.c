#include <stdio.h>

int a_output[100];
int idx = 0;

void write_value(int);
void subtract(int, int, int);
int read_val (const char* s, int* vptr, int bits);

typedef enum ccode_t ccode_t;
enum ccode_t {
    CC_    = 0,
    CC_P   = 0x0200,
    CC_Z   = 0x0400,
    CC_N   = 0x0800
};

typedef enum operands_t operands_t;
enum operands_t {
    O_RRR, O_RRI,
    O_RR,  O_RI,  O_RL,
    O_R,   O_I,   O_L,   O_S,
    O_,
    NUM_OPERANDS
};



void test_sub_distinct_rrr() {
    int r1 = 1;
    int r2 = 2;
    int r3 = 3;
    operands_t operand = O_RRR;
    subtract(r1, r2, r3);

    printf("SUB RRR TEST. Distinct registers\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x92FF);
    printf("line num %d: %d\n", 1, a_output[1]==0x1261);
    printf("line num %d: %d\n", 2, a_output[2]==0x1242);
    printf("Test Complete\n");
}

void test_mlt_distinct_rrr() {
    int r1 = 1;
    int r2 = 2;
    int r3 = 3;
    operands_t operand = O_RRR;
    subtract(r1, r2, r3);

    printf("SUB RRR TEST. Distinct registers\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x92FF);
    printf("line num %d: %d\n", 1, a_output[1]==0x1261);
    printf("line num %d: %d\n", 2, a_output[2]==0x1242);
    printf("Test Complete\n");
}

int main(void) {
    test_sub();
}
void subtract(int r1, int r2, int r3) {

    #include "subtract_rrr.h"
}

void write_value (int val)
{
    a_output[idx] = val;
    idx++;
}