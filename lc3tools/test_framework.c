#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int a_output[100];
int idx = 0;

typedef enum ccode_t ccode_t;
enum ccode_t {
    CC_    = 0,
    CC_P   = 0x0200,
    CC_Z   = 0x0400,
    CC_N   = 0x0800
};

typedef struct inst_t inst_t;
struct inst_t {
    // opcode_t op;
    ccode_t  ccode;
};

inst_t inst;

typedef enum operands_t operands_t;
enum operands_t {
    O_RRR, O_RRI,
    O_RR,  O_RI,  O_RL,
    O_R,   O_I,   O_L,   O_S,
    O_,
    NUM_OPERANDS
};

void write_value(int);
void multiply(int r1, int r2, int r3, int val, operands_t operands, int temp_r1, int temp_r2, int temp_r3, inst_t inst, char o3[]);
void subtract(int r1, int r2, int r3, int val, operands_t operands, inst_t inst, char o3[]);
void or(int r1, int r2, int r3, int val, operands_t operands, int temp_r1, int temp_r2, int temp_r3, inst_t inst, char o3[]);
void exponent(int r1, int r2, int r3, int val, operands_t operands, int temp_r1, int temp_r2, int temp_r3, inst_t inst, char o3[]);
void internal_multiply(int r1, int temp_r1, int temp_r);
void cyph(int r1, int r2);
void reset(int r1);
void test_rst();
void test_sub_rrr_distinct();
void test_sub_rrr_second_eq_last();
void test_sub_rrr_first_eq_second();
void test_sub_rrr_first_eq_last();
void test_sub_rrr_all_eq();
void test_sub_rri();
void test_mlt_rrr();
void test_mlt_rri();
void test_or_rri();
void test_or_rrr();
void test_exp_rrr();
void test_exp_rri();
void test_cyph_no_r0();
void test_cyph_r0_last();
void test_cyph_r0_first();

int read_val (const char* s, int* vptr, int bits);

int main(void) {
    test_rst();
    test_sub_rrr_distinct();
    test_sub_rrr_second_eq_last();
    test_sub_rrr_first_eq_second();
    test_sub_rrr_first_eq_last();
    test_sub_rrr_all_eq();
    test_sub_rri();
    test_mlt_rrr();
    test_mlt_rri();
    test_or_rri();
    test_or_rrr();
    test_exp_rrr();
    test_exp_rri();
    test_cyph_no_r0();
    test_cyph_r0_last();
    test_cyph_r0_first();
}

void test_sub_rrr_distinct() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 2;
    int r3 = 3;
    int val = 0;
    char o3[] = "#2";

    operands_t operands = O_RRR;

    inst_t inst;
    inst.ccode = CC_;

    subtract(r1, r2, r3, val, operands, inst, o3);

    printf("SUB RRR TEST. Distinct registers\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x92FF);
    printf("line num %d: %d\n", 1, a_output[1]==0x1261);
    printf("line num %d: %d\n", 2, a_output[2]==0x1242);
    printf("Test Complete\n");
}

void test_sub_rrr_second_eq_last() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 2;
    int r3 = 2;
    int val = 0;
    char o3[] = "#2";

    operands_t operands = O_RRR;

    inst_t inst;
    inst.ccode = CC_;

    subtract(r1, r2, r3, val, operands, inst, o3);

    printf("SUB RRR TEST. Second register same as last\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x92BF);
    printf("line num %d: %d\n", 1, a_output[1]==0x1261);
    printf("line num %d: %d\n", 2, a_output[2]==0x1242);
}
void test_sub_rrr_first_eq_second() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 1;
    int r3 = 2;
    int val = 0;
    char o3[] = "#2";

    operands_t operands = O_RRR;

    inst_t inst;
    inst.ccode = CC_;

    subtract(r1, r2, r3, val, operands, inst, o3);

    printf("SUB RRR TEST. First register same as second\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x927F);
    printf("line num %d: %d\n", 1, a_output[1]==0x1261);
    printf("line num %d: %d\n", 2, a_output[2]==0x1242);
    printf("line num %d: %d\n", 3, a_output[3]==0x927F);
    printf("line num %d: %d\n", 4, a_output[4]==0x1261);
}

void test_sub_rrr_first_eq_last() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 2;
    int r3 = 1;
    int val = 0;
    char o3[] = "#2";

    operands_t operands = O_RRR;

    inst_t inst;
    inst.ccode = CC_;

    subtract(r1, r2, r3, val, operands, inst, o3);

    printf("SUB RRR TEST. First register same as second\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x927F);
    printf("line num %d: %d\n", 1, a_output[1]==0x1261);
    printf("line num %d: %d\n", 2, a_output[2]==0x1242);
}

void test_sub_rrr_all_eq() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 1;
    int r3 = 1;
    int val = 0;
    char o3[] = "#2";

    operands_t operands = O_RRR;

    inst_t inst;
    inst.ccode = CC_;

    subtract(r1, r2, r3, val, operands, inst, o3);

    printf("SUB RRR TEST. All registers the same\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x5260);
}

void test_sub_rri() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 2;
    int r3 = 3;
    int val = 0;
    char o3[] = "#2";

    operands_t operands = O_RRI;

    inst_t inst;
    inst.ccode = CC_;

    subtract(r1, r2, r3, val, operands, inst, o3);

    printf("SUB RRI TEST. Distinct registers\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x12BE);
    printf("Test Complete\n");
}

void test_rst() {
    idx = 0; //reset each time
    int r1 = 1;
    
    reset(r1);
    
    printf("RST TEST\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x5260);
    printf("Test Complete\n");
}

void test_mlt_rrr() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 2;
    int r3 = 3;
    int val = 0;
    char o3[] = "#2";
    int temp_r1 = 0;
    int temp_r2 = 0;
    int temp_r3 = 0;

    operands_t operands = O_RRR;

    inst_t inst;
    inst.ccode = CC_;
     
    multiply(r1, r2, r3, val, operands, temp_r1, temp_r2, temp_r3, inst, o3);

    printf("MLT RRR TEST. Distinct registers\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x3002);
    printf("line num %d: %d\n", 1, a_output[1]==0x3802);
    printf("line num %d: %d\n", 2, a_output[2]==0x0E02);
    printf("line num %d: %d\n", 3, a_output[3]==0x0000);
    printf("line num %d: %d\n", 4, a_output[4]==0x0000);
    printf("line num %d: %d\n", 5, a_output[5]==0x10A0);
    printf("line num %d: %d\n", 6, a_output[6]==0x18E0);
    printf("line num %d: %d\n", 7, a_output[7]==0x5260);
    printf("line num %d: %d\n", 8, a_output[8]==0x1020);
    printf("line num %d: %d\n", 9, a_output[9]==0x040A);
    printf("line num %d: %d\n", 10, a_output[10]==0x1920);
    printf("line num %d: %d\n", 11, a_output[11]==0x0408);
    printf("line num %d: %d\n", 12, a_output[12]==0x0204);
    printf("line num %d: %d\n", 13, a_output[13]==0x993F);
    printf("line num %d: %d\n", 14, a_output[14]==0x1921);
    printf("line num %d: %d\n", 15, a_output[15]==0x903F);
    printf("line num %d: %d\n", 16, a_output[16]==0x1021);
    printf("line num %d: %d\n", 17, a_output[17]==0x1240);
    printf("line num %d: %d\n", 18, a_output[18]==0x193F);
    printf("line num %d: %d\n", 19, a_output[19]==0x03FD);
    printf("line num %d: %d\n", 20, a_output[20]==0x21EE);
    printf("line num %d: %d\n", 21, a_output[21]==0x29EE);
    printf("line num %d: %d\n", 22, a_output[22]==0x1260);
    printf("Test Complete\n");
}

void test_mlt_rri() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 2;
    int r3 = 3;
    int val = 0;
    char o3[] = "#2";
    int temp_r1 = 0;
    int temp_r2 = 0;
    int temp_r3 = 0;

    operands_t operands = O_RRI;

    inst_t inst;
    inst.ccode = CC_;
     
    multiply(r1, r2, r3, val, operands, temp_r1, temp_r2, temp_r3, inst, o3);

    printf("MLT RRI TEST. Distinct registers\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x3002);
    printf("line num %d: %d\n", 1, a_output[1]==0x3602);
    printf("line num %d: %d\n", 2, a_output[2]==0x0E02);
    printf("line num %d: %d\n", 3, a_output[3]==0x0000);
    printf("line num %d: %d\n", 4, a_output[4]==0x0000);
    printf("line num %d: %d\n", 5, a_output[5]==0x10A0);
    printf("line num %d: %d\n", 6, a_output[6]==0x56E0);
    printf("line num %d: %d\n", 7, a_output[7]==0x16E2);
    printf("line num %d: %d\n", 8, a_output[8]==0x05260);
    printf("line num %d: %d\n", 9, a_output[9]==0x1020);
    printf("line num %d: %d\n", 10, a_output[10]==0x040A);
    printf("line num %d: %d\n", 11, a_output[11]==0x16E0);
    printf("line num %d: %d\n", 12, a_output[12]==0x0408);
    printf("line num %d: %d\n", 13, a_output[13]==0x0204);
    printf("line num %d: %d\n", 14, a_output[14]==0x96FF);
    printf("line num %d: %d\n", 15, a_output[15]==0x16E1);
    printf("line num %d: %d\n", 16, a_output[16]==0x903F);
    printf("line num %d: %d\n", 17, a_output[17]==0x1021);
    printf("line num %d: %d\n", 18, a_output[18]==0x1240);
    printf("line num %d: %d\n", 19, a_output[19]==0x16FF);
    printf("line num %d: %d\n", 20, a_output[20]==0x03FD);
    printf("line num %d: %d\n", 21, a_output[21]==0x21ED);
    printf("line num %d: %d\n", 22, a_output[22]==0x27ED);
    printf("line num %d: %d\n", 23, a_output[23]==0x1260);
    printf("Test Complete\n");
}

void test_or_rrr() {
    idx = 0;
    int r1 = 1;
    int r2 = 2;
    int r3 = 3;
    int val = 0;
    char o3[] = "#2";
    int temp_r1 = 0;
    int temp_r2 = 0;
    int temp_r3 = 0;

    operands_t operands = O_RRR;

    inst_t inst;
    inst.ccode = CC_;
     
    or(r1, r2, r3, val, operands, temp_r1, temp_r2, temp_r3, inst, o3);

    printf("OR RRR TEST. Distinct registers\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x3002);
    printf("line num %d: %d\n", 1, a_output[1]==0x3802);
    printf("line num %d: %d\n", 2, a_output[2]==0x0E02);
    printf("line num %d: %d\n", 3, a_output[3]==0x0000);
    printf("line num %d: %d\n", 4, a_output[4]==0x0000);
    printf("line num %d: %d\n", 5, a_output[5]==0x10A0);
    printf("line num %d: %d\n", 6, a_output[6]==0x18E0);
    printf("line num %d: %d\n", 7, a_output[7]==0x903F);
    printf("line num %d: %d\n", 8, a_output[8]==0x993F);
    printf("line num %d: %d\n", 9, a_output[9]==0x5204);
    printf("line num %d: %d\n", 10, a_output[10]==0x927F);
    printf("line num %d: %d\n", 11, a_output[11]==0x21F7);
    printf("line num %d: %d\n", 12, a_output[12]==0x29F7);
    printf("line num %d: %d\n", 13, a_output[13]==0x1260);
    printf("Test Complete\n");
}

void test_or_rri() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 2;
    int r3 = 3;
    int val = 0;
    char o3[] = "#2";
    int temp_r1 = 0;
    int temp_r2 = 0;
    int temp_r3 = 0;

    operands_t operands = O_RRI;

    inst_t inst;
    inst.ccode = CC_;
     
    or(r1, r2, r3, val, operands, temp_r1, temp_r2, temp_r3, inst, o3);

    printf("OR RRI TEST. Distinct registers\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x3002);
    printf("line num %d: %d\n", 1, a_output[1]==0x3602);
    printf("line num %d: %d\n", 2, a_output[2]==0x0E02);
    printf("line num %d: %d\n", 3, a_output[3]==0x0000);
    printf("line num %d: %d\n", 4, a_output[4]==0x0000);
    printf("line num %d: %d\n", 5, a_output[5]==0x10A0);
    printf("line num %d: %d\n", 6, a_output[6]==0x56E0);
    printf("line num %d: %d\n", 7, a_output[7]==0x16E2);
    printf("line num %d: %d\n", 8, a_output[8]==0x903F);
    printf("line num %d: %d\n", 9, a_output[9]==0x96FF);
    printf("line num %d: %d\n", 10, a_output[10]==0x5203);
    printf("line num %d: %d\n", 11, a_output[11]==0x927F);
    printf("line num %d: %d\n", 12, a_output[12]==0x21F6);
    printf("line num %d: %d\n", 13, a_output[13]==0x27F6);
    printf("line num %d: %d\n", 14, a_output[14]==0x1260);
    printf("Test Complete\n");
}

void test_exp_rri() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 2;
    int r3 = 3;
    int val = 0;
    char o3[] = "#2";
    int temp_r1 = 0;
    int temp_r2 = 0;
    int temp_r3 = 0;

    int pt =0; // do this if have time
    operands_t operands = O_RRI;

    inst_t inst;
    // inst.ccode = CC_;
    
    exponent(r1, r2, r3, val, operands, temp_r1, temp_r2, temp_r3, inst, o3);

    printf("EXP RRI TEST\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x3003);
    printf("line num %d: %d\n", 1, a_output[1]==0x3603);
    printf("line num %d: %d\n", 2, a_output[2]==0x3803);
    printf("line num %d: %d\n", 3, a_output[3]==0x0E03);
    printf("line num %d: %d\n", 4, a_output[4]==0x0000);
    printf("line num %d: %d\n", 5, a_output[5]==0x0000);
    printf("line num %d: %d\n", 6, a_output[6]==0x0000);
    printf("line num %d: %d\n", 7, a_output[7]==0x10A0);
    printf("line num %d: %d\n", 8, a_output[8]==0x56E0);
    printf("line num %d: %d\n", 9, a_output[9]==0x16E2);
    printf("line num %d: %d\n", 11, a_output[10]==0x5260);
    printf("line num %d: %d\n", 12, a_output[11]==0x1261);
    printf("line num %d: %d\n", 13, a_output[12]==0x16E0);
    printf("line num %d: %d\n", 14, a_output[13]==0x0414);
    printf("line num %d: %d\n", 15, a_output[14]==0x1860);
    printf("line num %d: %d\n", 16, a_output[15]==0x3001);
    printf("line num %d: %d\n", 17, a_output[16]==0x0E01);
    printf("line num %d: %d\n", 18, a_output[17]==0x0000);
    printf("line num %d: %d\n", 19, a_output[18]==0x5260);
    printf("line num %d: %d\n", 20, a_output[19]==0x1920);
    printf("line num %d: %d\n", 21, a_output[20]==0x040A);
    printf("line num %d: %d\n", 22, a_output[21]==0x1020);
    printf("line num %d: %d\n", 23, a_output[22]==0x0408);
    printf("line num %d: %d\n", 24, a_output[23]==0x0204);
    printf("line num %d: %d\n", 25, a_output[24]==0x903F);
    printf("line num %d: %d\n", 26, a_output[25]==0x1021);
    printf("line num %d: %d\n", 27, a_output[26]==0x993F);
    printf("line num %d: %d\n", 28, a_output[27]==0x1921);
    printf("line num %d: %d\n", 29, a_output[28]==0x1244);
    printf("line num %d: %d\n", 30, a_output[29]==0x103F);
    printf("line num %d: %d\n", 31, a_output[30]==0x03FD);
    printf("line num %d: %d\n", 32, a_output[31]==0x21F1);
    printf("line num %d: %d\n", 33, a_output[32]==0x16FF);
    printf("line num %d: %d\n", 34, a_output[33]==0x0BEC);
    printf("line num %d: %d\n", 35, a_output[34]==0x21E1);
    printf("line num %d: %d\n", 36, a_output[35]==0x27E1);
    printf("line num %d: %d\n", 37, a_output[36]==0x29E1);
    printf("line num %d: %d\n", 38, a_output[37]==0x1260);
    printf("Test Complete\n");
}

void test_exp_rrr() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 2;
    int r3 = 3;
    int val = 0;
    char o3[] = "#2";
    int temp_r1 = 0;
    int temp_r2 = 0;
    int temp_r3 = 0;

    operands_t operands = O_RRR;

    inst_t inst;
    
    exponent(r1, r2, r3, val, operands, temp_r1, temp_r2, temp_r3, inst, o3);

    printf("EXP RRR TEST\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x16E0);
    printf("line num %d: %d\n", 1, a_output[1]==0x0825);
    printf("line num %d: %d\n", 2, a_output[2]==0x3003);
    printf("line num %d: %d\n", 3, a_output[3]==0x3803);
    printf("line num %d: %d\n", 4, a_output[4]==0x3A03);
    printf("line num %d: %d\n", 5, a_output[5]==0x0E03);
    printf("line num %d: %d\n", 6, a_output[6]==0x0000);
    printf("line num %d: %d\n", 7, a_output[7]==0x0000);
    printf("line num %d: %d\n", 8, a_output[8]==0x0000);
    printf("line num %d: %d\n", 9, a_output[9]==0x10A0);
    printf("line num %d: %d\n", 10, a_output[10]==0x18E0);
    printf("line num %d: %d\n", 11, a_output[11]==0x5260);
    printf("line num %d: %d\n", 12, a_output[12]==0x1261);
    printf("line num %d: %d\n", 13, a_output[13]==0x1920);
    printf("line num %d: %d\n", 14, a_output[14]==0x0414);
    printf("line num %d: %d\n", 15, a_output[15]==0x1A60);
    printf("line num %d: %d\n", 16, a_output[16]==0x3001);
    printf("line num %d: %d\n", 17, a_output[17]==0x0E01);
    printf("line num %d: %d\n", 18, a_output[18]==0x0000);
    printf("line num %d: %d\n", 19, a_output[19]==0x5260);
    printf("line num %d: %d\n", 20, a_output[20]==0x1B60);
    printf("line num %d: %d\n", 21, a_output[21]==0x040A);
    printf("line num %d: %d\n", 22, a_output[22]==0x1020);
    printf("line num %d: %d\n", 23, a_output[23]==0x0408);
    printf("line num %d: %d\n", 24, a_output[24]==0x0204);
    printf("line num %d: %d\n", 25, a_output[25]==0x903F);
    printf("line num %d: %d\n", 26, a_output[26]==0x1021);
    printf("line num %d: %d\n", 27, a_output[27]==0x9B7F);
    printf("line num %d: %d\n", 28, a_output[28]==0x1B61);
    printf("line num %d: %d\n", 29, a_output[29]==0x1245);
    printf("line num %d: %d\n", 30, a_output[30]==0x103F);
    printf("line num %d: %d\n", 31, a_output[31]==0x03FD);
    printf("line num %d: %d\n", 32, a_output[32]==0x21F1);
    printf("line num %d: %d\n", 33, a_output[33]==0x193F);
    printf("line num %d: %d\n", 34, a_output[34]==0x0BEC);
    printf("line num %d: %d\n", 35, a_output[35]==0x21E2);
    printf("line num %d: %d\n", 36, a_output[36]==0x29E2);
    printf("line num %d: %d\n", 37, a_output[37]==0x2BE2);
    printf("line num %d: %d\n", 38, a_output[38]==0x1260);
    printf("Test Complete\n");
}
void test_cyph_no_r0() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 2;
    cyph(r1, r2);

    printf("CYPH TEST\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x3001);
    printf("line num %d: %d\n", 1, a_output[1]==0x0E01);
    printf("line num %d: %d\n", 2, a_output[2]==0x0000);
    printf("line num %d: %d\n", 3, a_output[3]==0xF023);
    printf("line num %d: %d\n", 4, a_output[5]==0x301B);
    printf("line num %d: %d\n", 5, a_output[6]==0xF023);
    printf("line num %d: %d\n", 8, a_output[8]==0x3019);
    printf("line num %d: %d\n", 9, a_output[9]==0xF023);
    printf("line num %d: %d\n", 11, a_output[11]==0x3017);
    printf("line num %d: %d\n", 12, a_output[12]==0xF023);
    printf("line num %d: %d\n", 14, a_output[14]==0x3015);
    printf("line num %d: %d\n", 15, a_output[15]==0xF023);
    printf("line num %d: %d\n", 17, a_output[17]==0x3013);
    printf("line num %d: %d\n", 18, a_output[18]==0xF023);
    printf("line num %d: %d\n", 20, a_output[20]==0x3011);
    printf("line num %d: %d\n", 21, a_output[21]==0xF023);
    printf("line num %d: %d\n", 23, a_output[23]==0x300F);
    printf("line num %d: %d\n", 24, a_output[24]==0xF023);
    printf("line num %d: %d\n", 26, a_output[26]==0x300D);
    printf("line num %d: %d\n", 27, a_output[27]==0xF023);
    printf("line num %d: %d\n", 29, a_output[29]==0x300B);
    printf("line num %d: %d\n", 30, a_output[30]==0xF023);
    printf("line num %d: %d\n", 32, a_output[32]==0x3009);
    for (int i=33; i<=43; i++){
        printf("line num %d: %d\n", i, a_output[i]==0x0000);
    }
    printf("line num %d: %d\n", 44, a_output[44]==0xE1F4);
    printf("line num %d: %d\n", 45, a_output[45]==0xF022);
    printf("line num %d: %d\n", 46, a_output[46]==0x1420);
    printf("line num %d: %d\n", 47, a_output[47]==0x5260);
    printf("line num %d: %d\n", 49, a_output[49]==0x21D0);
    printf("Test Complete\n");
}

void test_cyph_r0_last() {
    idx = 0; //reset each time
    int r1 = 1;
    int r2 = 0;
    cyph(r1, r2);

    printf("CYPH TEST R1, R0\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x3001);
    printf("line num %d: %d\n", 1, a_output[1]==0x0E01);
    printf("line num %d: %d\n", 2, a_output[2]==0x0000);
    printf("line num %d: %d\n", 3, a_output[3]==0xF023);
    printf("line num %d: %d\n", 4, a_output[5]==0x301B);
    printf("line num %d: %d\n", 5, a_output[6]==0xF023);
    printf("line num %d: %d\n", 8, a_output[8]==0x3019);
    printf("line num %d: %d\n", 9, a_output[9]==0xF023);
    printf("line num %d: %d\n", 11, a_output[11]==0x3017);
    printf("line num %d: %d\n", 12, a_output[12]==0xF023);
    printf("line num %d: %d\n", 14, a_output[14]==0x3015);
    printf("line num %d: %d\n", 15, a_output[15]==0xF023);
    printf("line num %d: %d\n", 17, a_output[17]==0x3013);
    printf("line num %d: %d\n", 18, a_output[18]==0xF023);
    printf("line num %d: %d\n", 20, a_output[20]==0x3011);
    printf("line num %d: %d\n", 21, a_output[21]==0xF023);
    printf("line num %d: %d\n", 23, a_output[23]==0x300F);
    printf("line num %d: %d\n", 24, a_output[24]==0xF023);
    printf("line num %d: %d\n", 26, a_output[26]==0x300D);
    printf("line num %d: %d\n", 27, a_output[27]==0xF023);
    printf("line num %d: %d\n", 29, a_output[29]==0x300B);
    printf("line num %d: %d\n", 30, a_output[30]==0xF023);
    printf("line num %d: %d\n", 32, a_output[32]==0x3009);
    for (int i=33; i<=43; i++){
        printf("line num %d: %d\n", i, a_output[i]==0x0000);
    }
    printf("line num %d: %d\n", 44, a_output[44]==0xE1F4);
    printf("line num %d: %d\n", 45, a_output[45]==0xF022);
    printf("line num %d: %d\n", 46, a_output[46]==0x5260);
    printf("Test Complete\n");
}

void test_cyph_r0_first() {
    idx = 0; //reset each time
    int r1 = 0;
    int r2 = 1;
    cyph(r1, r2);

    printf("CYPH TEST R0, R1\n");
    printf("line num %d: %d\n", 0, a_output[0]==0x3001);
    printf("line num %d: %d\n", 1, a_output[1]==0x0E01);
    printf("line num %d: %d\n", 2, a_output[2]==0x0000);
    printf("line num %d: %d\n", 3, a_output[3]==0xF023);
    printf("line num %d: %d\n", 4, a_output[5]==0x301B);
    printf("line num %d: %d\n", 5, a_output[6]==0xF023);
    printf("line num %d: %d\n", 8, a_output[8]==0x3019);
    printf("line num %d: %d\n", 9, a_output[9]==0xF023);
    printf("line num %d: %d\n", 11, a_output[11]==0x3017);
    printf("line num %d: %d\n", 12, a_output[12]==0xF023);
    printf("line num %d: %d\n", 14, a_output[14]==0x3015);
    printf("line num %d: %d\n", 15, a_output[15]==0xF023);
    printf("line num %d: %d\n", 17, a_output[17]==0x3013);
    printf("line num %d: %d\n", 18, a_output[18]==0xF023);
    printf("line num %d: %d\n", 20, a_output[20]==0x3011);
    printf("line num %d: %d\n", 21, a_output[21]==0xF023);
    printf("line num %d: %d\n", 23, a_output[23]==0x300F);
    printf("line num %d: %d\n", 24, a_output[24]==0xF023);
    printf("line num %d: %d\n", 26, a_output[26]==0x300D);
    printf("line num %d: %d\n", 27, a_output[27]==0xF023);
    printf("line num %d: %d\n", 29, a_output[29]==0x300B);
    printf("line num %d: %d\n", 30, a_output[30]==0xF023);
    printf("line num %d: %d\n", 32, a_output[32]==0x3009);
    for (int i=33; i<=43; i++){
        printf("line num %d: %d\n", i, a_output[i]==0x0000);
    }
    printf("line num %d: %d\n", 44, a_output[44]==0xE1F4);
    printf("line num %d: %d\n", 45, a_output[45]==0xF022);
    printf("line num %d: %d\n", 46, a_output[46]==0x1220);
    printf("line num %d: %d\n", 47, a_output[47]==0x5020);

    printf("Test Complete\n");
}

void multiply(int r1, int r2, int r3, int val, operands_t operands, int temp_r1, int temp_r2, int temp_r3, inst_t inst, char o3[]) {
    #include "multiply.h"
}

void reset(int r1) {
    #include "reset.h"
}

void subtract(int r1, int r2, int r3, int val, operands_t operands, inst_t inst, char o3[]) {
    #include "subtract.h"
}

void or(int r1, int r2, int r3, int val, operands_t operands, int temp_r1, int temp_r2, int temp_r3, inst_t inst, char o3[]) {
    #include "or.h"
}

void exponent(int r1, int r2, int r3, int val, operands_t operands, int temp_r1, int temp_r2, int temp_r3, inst_t inst, char o3[]) {
    int x = 1;
    switch(x) {
        case 1:
        #include "exponent.h"
    }
}

void cyph(int r1, int r2) {
    #include "cyph.h"
}

void write_value (int val) {
    a_output[idx] = val;
    idx++;
}

// built in read val too complicated for testing
int read_val(const char* s, int* vptr, int bits) {
    char* trash;
    long v;

    if (*s == 'x' || *s == 'X')
	v = strtol (s + 1, &trash, 16);
    else {
	if (*s == '#')
	    s++;
	v = strtol (s, &trash, 10);
    }
    if (0x10000 > v && 0x8000 <= v)
        v |= -65536L;   /* handles 64-bit longs properly */
    if (v < -(1L << (bits - 1)) || v >= (1L << bits)) {
	return -1;
    }
    if ((v & (1UL << (bits - 1))) != 0)
	v |= ~((1UL << bits) - 1);
    *vptr = v;
    return 0;
}

void internal_multiply(int r1, int temp_r1, int temp_r2) {
    #include "internal_multiply.h"
}

void internal_subtract(int r1, int r2, int r3) {
    #include "subtract_rrr.h"
}