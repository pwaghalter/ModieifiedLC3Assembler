/*									tab:8
 *
 * lc3.f - lexer for the LC-3 assembler
 *
 * "Copyright (c) 2003 by Steven S. Lumetta."
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written 
 * agreement is hereby granted, provided that the above copyright notice
 * and the following two paragraphs appear in all copies of this software,
 * that the files COPYING and NO_WARRANTY are included verbatim with
 * any distribution, and that the contents of the file README are included
 * verbatim as part of a file named README with any distribution.
 * 
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE TO ANY PARTY FOR DIRECT, 
 * INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT 
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE AUTHOR 
 * HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE AUTHOR SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT 
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 * A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" 
 * BASIS, AND THE AUTHOR NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, 
 * UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Author:	    Steve Lumetta
 * Version:	    1
 * Creation Date:   18 October 2003
 * Filename:	    lc3.f
 * History:
 *	SSL	1	18 October 2003
 *		Copyright notices and Gnu Public License marker added.
 */

%option noyywrap nounput

%{

/* questions...

should the assembler allow colons after label names?  are the colons
part of the label?  Currently I allow only alpha followed by alphanum and _.

*/

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "symbol.h"

typedef enum opcode_t opcode_t;
enum opcode_t {
    /* no opcode seen (yet) */
    OP_NONE,

    /* real instruction opcodes */
    OP_ADD, OP_AND, OP_BR, OP_JMP, OP_JSR, OP_JSRR, OP_LD, OP_LDI, OP_LDR,
    OP_LEA, OP_NOT, OP_RTI, OP_ST, OP_STI, OP_STR, OP_TRAP, OP_SUB, OP_RST,
    OP_MLT, OP_EQL, OP_MOV,

    /* trap pseudo-ops */
    OP_GETC, OP_HALT, OP_IN, OP_OUT, OP_PUTS, OP_PUTSP,

    /* non-trap pseudo-ops */
    OP_FILL, OP_RET, OP_STRINGZ,

    /* directives */
    OP_BLKW, OP_END, OP_ORIG, 

    NUM_OPS
};

static const char* const opnames[NUM_OPS] = {
    /* no opcode seen (yet) */
    "missing opcode",

    /* real instruction opcodes */
    "ADD", "AND", "BR", "JMP", "JSR", "JSRR", "LD", "LDI", "LDR", "LEA",
    "NOT", "RTI", "ST", "STI", "STR", "TRAP", "SUB", "RST", "MLT", "EQL", "MOV",

    /* trap pseudo-ops */
    "GETC", "HALT", "IN", "OUT", "PUTS", "PUTSP",

    /* non-trap pseudo-ops */
    ".FILL", "RET", ".STRINGZ",

    /* directives */
    ".BLKW", ".END", ".ORIG",
};

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

static const int op_format_ok[NUM_OPS] = {
    /* no opcode seen (yet) */
    0x200, /* no opcode, no operands       */

    /* real instruction formats */
    0x003, /* ADD: RRR or RRI formats only */
    0x003, /* AND: RRR or RRI formats only */
    0x0C0, /* BR: I or L formats only      */
    0x020, /* JMP: R format only           */
    0x0C0, /* JSR: I or L formats only     */
    0x020, /* JSRR: R format only          */
    0x018, /* LD: RI or RL formats only    */
    0x018, /* LDI: RI or RL formats only   */
    0x002, /* LDR: RRI format only         */
    0x018, /* LEA: RI or RL formats only   */
    0x004, /* NOT: RR format only          */
    0x200, /* RTI: no operands allowed     */
    0x018, /* ST: RI or RL formats only    */
    0x018, /* STI: RI or RL formats only   */
    0x002, /* STR: RRI format only         */
    0x040, /* TRAP: I format only          */
    0x003, /* SUB: RRR or RRI formats only */
    0x020, /* RST: R format only           */
    0x003, /* MLT: RRR or RRI formats only */
    0x003, /* EQL: RRR or RRI formats only */
    0x004,  /* MOV: RR format only           */
      
    /* trap pseudo-op formats (no operands) */
    0x200, /* GETC: no operands allowed    */
    0x200, /* HALT: no operands allowed    */
    0x200, /* IN: no operands allowed      */
    0x200, /* OUT: no operands allowed     */
    0x200, /* PUTS: no operands allowed    */
    0x200, /* PUTSP: no operands allowed   */

    /* non-trap pseudo-op formats */
    0x0C0, /* .FILL: I or L formats only   */
    0x200, /* RET: no operands allowed     */
    0x100, /* .STRINGZ: S format only      */

    /* directive formats */
    0x040, /* .BLKW: I format only         */
    0x200, /* .END: no operands allowed    */
    0x040  /* .ORIG: I format only         */
};

typedef enum pre_parse_t pre_parse_t;
enum pre_parse_t {
    NO_PP =  0,
    PP_R1 =  1,
    PP_R2 =  2,
    PP_R3 =  4,
    PP_I2 =  8,
    PP_L2 = 16
};

static const pre_parse_t pre_parse[NUM_OPERANDS] = {
    (PP_R1 | PP_R2 | PP_R3), /* O_RRR */
    (PP_R1 | PP_R2),         /* O_RRI */
    (PP_R1 | PP_R2),         /* O_RR  */
    (PP_R1 | PP_I2),         /* O_RI  */
    (PP_R1 | PP_L2),         /* O_RL  */
    PP_R1,                   /* O_R   */
    NO_PP,                   /* O_I   */
    NO_PP,                   /* O_L   */
    NO_PP,                   /* O_S   */
    NO_PP                    /* O_    */
};

typedef struct inst_t inst_t;
struct inst_t {
    opcode_t op;
    ccode_t  ccode;
};

static int pass, line_num, num_errors, saw_orig, code_loc, saw_end;
static inst_t inst;
static FILE* symout;
static FILE* objout;

static void new_inst_line ();
static void bad_operands ();
static void unterminated_string ();
static void bad_line ();
static void line_ignored ();
static void parse_ccode (const char*);
static void generate_instruction (operands_t, const char*);
static void found_label (const char* lname);

%}

/* condition code specification */
CCODE    [Nn]?[Zz]?[Pp]?

/* operand types */
REGISTER [rR][0-7]
HEX      [xX][-]?[0-9a-fA-F]+
DECIMAL  [#]?[-]?[0-9]+
IMMED    {HEX}|{DECIMAL}
LABEL    [A-Za-z][A-Za-z_0-9]*
STRING   \"([^\"]*|(\\\"))*\"
UTSTRING \"[^\n\r]*

/* operand and white space specification */
SPACE     [ \t]
OP_SEP    {SPACE}*,{SPACE}*
COMMENT   [;][^\n\r]*
EMPTYLINE {SPACE}*{COMMENT}?
ENDLINE   {EMPTYLINE}\r?\n\r?

/* operand formats */
O_RRR  {SPACE}+{REGISTER}{OP_SEP}{REGISTER}{OP_SEP}{REGISTER}{ENDLINE}
O_RRI  {SPACE}+{REGISTER}{OP_SEP}{REGISTER}{OP_SEP}{IMMED}{ENDLINE}
O_RR   {SPACE}+{REGISTER}{OP_SEP}{REGISTER}{ENDLINE}
O_RI   {SPACE}+{REGISTER}{OP_SEP}{IMMED}{ENDLINE}
O_RL   {SPACE}+{REGISTER}{OP_SEP}{LABEL}{ENDLINE}
O_R    {SPACE}+{REGISTER}{ENDLINE}
O_I    {SPACE}+{IMMED}{ENDLINE}
O_L    {SPACE}+{LABEL}{ENDLINE}
O_S    {SPACE}+{STRING}{ENDLINE}
O_UTS  {SPACE}+{UTSTRING}{ENDLINE}
O_     {ENDLINE}

/* need to define YY_INPUT... */

/* exclusive lexing states to read operands, eat garbage lines, and
   check for extra text after .END directive */
%x ls_operands ls_garbage ls_finished

%%

    /* rules for real instruction opcodes */
ADD       {inst.op = OP_ADD;   BEGIN (ls_operands);}
AND       {inst.op = OP_AND;   BEGIN (ls_operands);}
BR{CCODE} {inst.op = OP_BR;    parse_ccode (yytext + 2); BEGIN (ls_operands);}
JMP       {inst.op = OP_JMP;   BEGIN (ls_operands);}
JSRR      {inst.op = OP_JSRR;  BEGIN (ls_operands);}
JSR       {inst.op = OP_JSR;   BEGIN (ls_operands);}
LDI       {inst.op = OP_LDI;   BEGIN (ls_operands);}
LDR       {inst.op = OP_LDR;   BEGIN (ls_operands);}
LD        {inst.op = OP_LD;    BEGIN (ls_operands);}
LEA       {inst.op = OP_LEA;   BEGIN (ls_operands);}
NOT       {inst.op = OP_NOT;   BEGIN (ls_operands);}
RTI       {inst.op = OP_RTI;   BEGIN (ls_operands);}
STI       {inst.op = OP_STI;   BEGIN (ls_operands);}
STR       {inst.op = OP_STR;   BEGIN (ls_operands);}
ST        {inst.op = OP_ST;    BEGIN (ls_operands);}
TRAP      {inst.op = OP_TRAP;  BEGIN (ls_operands);}
SUB       {inst.op = OP_SUB;   BEGIN (ls_operands);}
RST       {inst.op = OP_RST;   BEGIN (ls_operands);}
MLT       {inst.op = OP_MLT;   BEGIN (ls_operands);}
EQL       {inst.op = OP_EQL;   BEGIN (ls_operands);}
MOV       {inst.op = OP_MOV;   BEGIN (ls_operands);}
      
    /* rules for trap pseudo-ols */
GETC      {inst.op = OP_GETC;  BEGIN (ls_operands);}
HALT      {inst.op = OP_HALT;  BEGIN (ls_operands);}
IN        {inst.op = OP_IN;    BEGIN (ls_operands);}
OUT       {inst.op = OP_OUT;   BEGIN (ls_operands);}
PUTS      {inst.op = OP_PUTS;  BEGIN (ls_operands);}
PUTSP     {inst.op = OP_PUTSP; BEGIN (ls_operands);}

    /* rules for non-trap pseudo-ops */
\.FILL    {inst.op = OP_FILL;  BEGIN (ls_operands);}
RET       {inst.op = OP_RET;   BEGIN (ls_operands);}
\.STRINGZ {inst.op = OP_STRINGZ; BEGIN (ls_operands);}

    /* rules for directives */
\.BLKW    {inst.op = OP_BLKW; BEGIN (ls_operands);}
\.END     {saw_end = 1;       BEGIN (ls_finished);}
\.ORIG    {inst.op = OP_ORIG; BEGIN (ls_operands);}

    /* rules for operand formats */
<ls_operands>{O_RRR} {generate_instruction (O_RRR, yytext); BEGIN (0);}
<ls_operands>{O_RRI} {generate_instruction (O_RRI, yytext); BEGIN (0);}
<ls_operands>{O_RR}  {generate_instruction (O_RR, yytext);  BEGIN (0);}
<ls_operands>{O_RI}  {generate_instruction (O_RI, yytext);  BEGIN (0);}
<ls_operands>{O_RL}  {generate_instruction (O_RL, yytext);  BEGIN (0);}
<ls_operands>{O_R}   {generate_instruction (O_R, yytext);   BEGIN (0);}
<ls_operands>{O_I}   {generate_instruction (O_I, yytext);   BEGIN (0);}
<ls_operands>{O_L}   {generate_instruction (O_L, yytext);   BEGIN (0);}
<ls_operands>{O_S}   {generate_instruction (O_S, yytext);   BEGIN (0);}
<ls_operands>{O_}    {generate_instruction (O_, yytext);    BEGIN (0);}

    /* eat excess white space */
{SPACE}+ {}  
{ENDLINE} {new_inst_line (); /* a blank line */ }

    /* labels, with or without subsequent colons */\
    /* 
       the colon form is used in some examples in the second edition
       of the book, but may be removed in the third; it also allows 
       labels to use opcode and pseudo-op names, etc., however.
     */
{LABEL}          {found_label (yytext);}
{LABEL}{SPACE}*: {found_label (yytext);}

    /* error handling??? */
<ls_operands>{O_UTS} {unterminated_string (); BEGIN (0);}
<ls_operands>[^\n\r]*{ENDLINE} {bad_operands (); BEGIN (0);}
{O_RRR}|{O_RRI}|{O_RR}|{O_RI}|{O_RL}|{O_R}|{O_I}|{O_S}|{O_UTS} {
    bad_operands ();
}

. {BEGIN (ls_garbage);}
<ls_garbage>[^\n\r]*{ENDLINE} {bad_line (); BEGIN (0);}

    /* parsing after the .END directive */
<ls_finished>{ENDLINE}|{EMPTYLINE}     {new_inst_line (); /* a blank line  */}
<ls_finished>.*({ENDLINE}|{EMPTYLINE}) {line_ignored (); return 0;}

%%

int
main (int argc, char** argv)
{
    int len;
    char* ext;
    char* fname;

    if (argc != 2) {
        fprintf (stderr, "usage: %s <ASM filename>\n", argv[0]);
	return 1;
    }

    /* Make our own copy of the filename. */
    len = strlen (argv[1]);
    if ((fname = malloc (len + 5)) == NULL) {
        perror ("malloc");
	return 3;
    }
    strcpy (fname, argv[1]);

    /* Check for .asm extension; if not found, add it. */
    if ((ext = strrchr (fname, '.')) == NULL || strcmp (ext, ".asm") != 0) {
	ext = fname + len;
        strcpy (ext, ".asm");
    }

    /* Open input file. */
    if ((lc3in = fopen (fname, "r")) == NULL) {
        fprintf (stderr, "Could not open %s for reading.\n", fname);
	return 2;
    }

    /* Open output files. */
    strcpy (ext, ".obj");
    if ((objout = fopen (fname, "w")) == NULL) {
        fprintf (stderr, "Could not open %s for writing.\n", fname);
	return 2;
    }
    strcpy (ext, ".sym");
    if ((symout = fopen (fname, "w")) == NULL) {
        fprintf (stderr, "Could not open %s for writing.\n", fname);
	return 2;
    }
    /* FIXME: Do we really need to exactly match old format for compatibility 
       with Windows simulator? */
    fprintf (symout, "// Symbol table\n");
    fprintf (symout, "// Scope level 0:\n");
    fprintf (symout, "//\tSymbol Name       Page Address\n");
    fprintf (symout, "//\t----------------  ------------\n");

    puts ("STARTING PASS 1");
    pass = 1;
    line_num = 0;
    num_errors = 0;
    saw_orig = 0;
    code_loc = 0x3000;
    saw_end = 0;
    new_inst_line ();
    yylex ();
    if (saw_orig == 0) {
        if (num_errors == 0 && !saw_end)
	    fprintf (stderr, "%3d: file contains only comments\n", line_num);
        else {
	    if (saw_end == 0)
		fprintf (stderr, "%3d: no .ORIG or .END directive found\n", 
			 line_num);
	    else
		fprintf (stderr, "%3d: no .ORIG directive found\n", line_num);
	}
	num_errors++;
    } else if (saw_end == 0 ) {
	fprintf (stderr, "%3d: no .END directive found\n", line_num);
	num_errors++;
    }
    printf ("%d errors found in first pass.\n", num_errors);
    if (num_errors > 0)
    	return 1;
    if (fseek (lc3in, 0, SEEK_SET) != 0) {
        perror ("fseek to start of ASM file");
	return 3;
    }
    yyrestart (lc3in);
    /* Return lexer to initial state.  It is otherwise left in ls_finished
       if an .END directive was seen. */
    BEGIN (0);

    puts ("STARTING PASS 2");
    pass = 2;
    line_num = 0;
    num_errors = 0;
    saw_orig = 0;
    code_loc = 0x3000;
    saw_end = 0;
    new_inst_line ();
    yylex ();
    printf ("%d errors found in second pass.\n", num_errors);
    if (num_errors > 0)
    	return 1;

    fprintf (symout, "\n");
    fclose (symout);
    fclose (objout);

    return 0;
}

static void
new_inst_line () 
{
    inst.op = OP_NONE;
    inst.ccode = CC_;
    line_num++;
}

static void
bad_operands ()
{
    fprintf (stderr, "%3d: illegal operands for %s\n",
	     line_num, opnames[inst.op]);
    num_errors++;
    new_inst_line ();
}

static void
unterminated_string ()
{
    fprintf (stderr, "%3d: unterminated string\n", line_num);
    num_errors++;
    new_inst_line ();
}

static void 
bad_line ()
{
    fprintf (stderr, "%3d: contains unrecognizable characters\n",
	     line_num);
    num_errors++;
    new_inst_line ();
}

static void 
line_ignored ()
{
    if (pass == 1)
	fprintf (stderr, "%3d: WARNING: all text after .END ignored\n",
		 line_num);
}

static int
read_val (const char* s, int* vptr, int bits)
{
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
	fprintf (stderr, "%3d: constant outside of allowed range\n", line_num);
	num_errors++;
	return -1;
    }
    if ((v & (1UL << (bits - 1))) != 0)
	v |= ~((1UL << bits) - 1);
    *vptr = v;
    return 0;
}

static void
write_value (int val) // write the instruction and increment code pointer
{
    unsigned char out[2];

    code_loc = (code_loc + 1) & 0xFFFF;
    if (pass == 1)
        return;
    /* FIXME: just htons... */
    out[0] = (val >> 8);
    out[1] = (val & 0xFF);
    fwrite (out, 2, 1, objout);
}

static char*
sym_name (const char* name)
{
    unsigned char* local = strdup (name);
    unsigned char* cut;

    /* Not fast, but no limit on label length...who cares? */
    for (cut = local; *cut != 0 && !isspace (*cut) && *cut != ':'; cut++);
    *cut = 0;

    return local;
}

static int
find_label (const char* optarg, int bits)
{
    unsigned char* local;
    symbol_t* label;
    int limit, value;

    if (pass == 1)
        return 0;

    local = sym_name (optarg);
    label = find_symbol (local, NULL);
    if (label != NULL) {
	value = label->addr;
	if (bits != 16) { /* Everything except 16 bits is PC-relative. */
	    limit = (1L << (bits - 1));
	    value -= code_loc + 1;
	    if (value < -limit || value >= limit) {
	        fprintf (stderr, "%3d: label \"%s\" at distance %d (allowed "
			 "range is %d to %d)\n", line_num, local, value,
			 -limit, limit - 1);
	        goto bad_label;
	    }
	    return value;
	}
	free (local);
        return label->addr;
    }
    fprintf (stderr, "%3d: unknown label \"%s\"\n", line_num, local);

bad_label:
    num_errors++;
    free (local);
    return 0;
}

static void 
generate_instruction (operands_t operands, const char* opstr)
{
    int val, r1, r2, r3;
    const unsigned char* o1;
    const unsigned char* o2;
    const unsigned char* o3; // o3 points to a char aka it holds the mem address of a char
    const unsigned char* str;

    if ((op_format_ok[inst.op] & (1UL << operands)) == 0) {
	bad_operands ();
	return;
    }
    o1 = opstr;
    while (isspace (*o1)) o1++;
    if ((o2 = strchr (o1, ',')) != NULL) {
        o2++;
	while (isspace (*o2)) o2++;
	if ((o3 = strchr (o2, ',')) != NULL) {
	    o3++;
	    while (isspace (*o3)) o3++;
	}
    } else
    	o3 = NULL;
    if (inst.op == OP_ORIG) {
	if (saw_orig == 0) {
	    if (read_val (o1, &code_loc, 16) == -1)
		/* Pick a value; the error prevents code generation. */
		code_loc = 0x3000; 
	    else {
	        write_value (code_loc);
		code_loc--; /* Starting point doesnt count as code. */
	    }
	    saw_orig = 1;
	} else if (saw_orig == 1) {
	    fprintf (stderr, "%3d: multiple .ORIG directives found\n",
		     line_num);
	    saw_orig = 2;
	}
	new_inst_line ();
	return;
    }
    if (saw_orig == 0) {
	fprintf (stderr, "%3d: instruction appears before .ORIG\n",
		 line_num);
	num_errors++;
	new_inst_line ();
	saw_orig = 2;
	return;
    }
    if ((pre_parse[operands] & PP_R1) != 0)
        r1 = o1[1] - '0';
    if ((pre_parse[operands] & PP_R2) != 0)
        r2 = o2[1] - '0';
    if ((pre_parse[operands] & PP_R3) != 0)
        r3 = o3[1] - '0';
    if ((pre_parse[operands] & PP_I2) != 0)
        (void)read_val (o2, &val, 9);
    if ((pre_parse[operands] & PP_L2) != 0)
        val = find_label (o2, 9);

    switch (inst.op) {
	/* Generate real instruction opcodes. */
	case OP_ADD:
	    if (operands == O_RRI) {
	    	/* Check or read immediate range (error in first pass
		   prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);
		write_value (0x1020 | (r1 << 9) | (r2 << 6) | (val & 0x1F));
	    } else
		write_value (0x1000 | (r1 << 9) | (r2 << 6) | r3);
        break;

    case OP_SUB:
        
        // 3. do normal addition
        if (operands == O_RRI) {
	    	/* Check or read immediate range (error in first pass
		   prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);

            write_value (0x1020 | (r1 << 9) | (r2 << 6) | ((val*-1) & 0x1F)); 
            // 1. not: 
            // need to clear a register, put the imm5 val in, then not it - how can i make sure that the register isn't used for anythign else?
            //write_value (0x903F | (r1 << 9) | (r2 << 6));

		    //write_value (0x1020 | (r1 << 9) | (r2 << 6) | (val & 0x1F));
	    } else {

            if (r1 == r2 && r2 == r3) { // this case works
                // rst r1
                write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F));
            }
            else if (r1 != r2) { // maybe abstract this to a fxn? why bother repeating in the next else
                // r1 = -r3
                write_value (0x903F | (r1 << 9) | (r3 << 6));
                write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F));

                // r1 = r1 + r2
                 write_value (0x1000 | (r1 << 9) | (r1 << 6) | r2);
            }

            else { // r1 == r2
                // r1 = -r2
                write_value (0x903F | (r1 << 9) | (r2 << 6));
                write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F));

                // r1 = r1 + r3
                write_value (0x1000 | (r1 << 9) | (r1 << 6) | r3);
                
                // r1 = -r1
                write_value (0x903F | (r1 << 9) | (r1 << 6));
                write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F));
            }
        }
        break;
        
    case OP_RST:
        // AND register with zero
        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F));
        break;

    //case OP_MLT:
        /* printf("o1 %s\n", o1);
        printf("o2 %s\n", o2);
        printf("o3 %x\n", &o3); */

      //  write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F)); //why would I clear R1? what if its the same as R2? what the heck?

        //if (operands == O_RRI) {
	    	/* Check or read immediate range (error in first pass
		   prevents execution of second, so never fails). */
	      //  (void)read_val (o3, &val, 5);
            //int negative = 0; // still need to check if SR1 is negative. ugh.

           // if (val < 0) {
            //    negative = 1;
             //   val *= -1;
          //  }

            // MLT R1, R2, #3 means you want R1 = R2 * #3
           // for (int i=0; i < val; i++) {
            //    write_value (0x1000 | (r1 << 9) | (r1 << 6) | r2);
            //}

           // if (negative == 1) { // need to figure out how to increment negative based on val in SR1
                // negate and add 1 to DestR akak R1
            //    write_value (0x903F | (r1 << 9) | (r1 << 6));
            //    write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F));
            //}
        //}

        //else { // MLT R1, R2, R3 means you want R1 = R2 * R3
            // RST R1 (will hold answer) - no need to repeat this which is done above
            // write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F));

            // can i save value in r3 and if thats not destR, re load it? what abour MLT R0, R0, R0? i think it would still work - this wouldn't work anyways since we need multiple registers at work in the program so regardless we need multiple cases
            // R1 = R1 + R2
            //write_value (0x1000 | (r1 << 9) | (r1 << 6) | r2);

            // R3 = R3 - 1 -> maybe this should be done in a new register; can't just save and restore bc what if want answer in one of the operands?
            //write_value (0x1020 | (r3 << 9) | (r3 << 6) | (0x1F & 0x1F));

            // BR not negative to top of loop
            //write_value (0x0700 | (0xFFD & 0x1FF)); // the part after the or is where to BR to...
        //}
        //break;


    case OP_MLT:
        // check R3/imm5 neg by adding zero
        // BRzp #1
        // add neg_count += 1
        // save contents of R3 if RRR/imm5
        // negate R3/imm5
        // add 1 to R3/imm5 {now R3/imm5 is positive}
        // check R2 neg by adding zero
        // BRzp #4
        // add neg_count += 1

            

        if (operands == O_RRI) {
	    	/* Check or read immediate range (error in first pass
		   prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);
        
            if (r1 != r2 ) {
                write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F)); // clear destR

                

                int negative = 0;

                // MLT R1, R2, #3 means you want R1 = R2 * #3 hey should I maybe possibly do this with a loop in lc3? or is it not worth it? does it save lines of lc3 code? no right since i'd need a register to act as a loop counter?
                if (val < 0) {
                    val *= -1;
                    negative = 1;
                    //write_value (0x1020 | (neg_count_reg << 9) | (neg_count_reg << 6) | (0x01 & 0x1F)); // ADD 1 to neg_count_reg
                }
                
                // no need to check if R2 is negative, since that will be auto factored into the mult. It only matters if val is neg,
                // since it behaves as the counter and needs to be positive so it can be decremented in the loop - then if it was neg
                // we factor that in at the end and negate the final answer
                
                // do the actual multiplication
                for (int i=0; i < val; i++) {
                    write_value (0x1000 | (r1 << 9) | (r1 << 6) | r2);
                }

                if (negative == 1) { // negate 
                    write_value (0x903F | (r1 << 9) | (r1 << 6));
                    write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F));
                }
            }
            else {
                int temp_r = 0;

                // locate a register not used in this multiplication
                while (temp_r == r1 || temp_r == r2 || temp_r == r3) {
                    temp_r++;
                }

                // ST contents of temporary register
                write_value (0x3000 | (temp_r << 9) | ((val + 0x00E) & 0x1FF)); // need to figure out where this gets stored, def end of program

                // add contents of R1/R2 (which are the same) into temp_r
                write_value (0x1020 | (temp_r << 9) | (r2 << 6) | (0x00 & 0x1F)); //ADD temp_r, r1, #0
                
                int negative = 0;

                // MLT R1, R2, #3 means you want R1 = R2 * #3 hey should I maybe possibly do this with a loop in lc3? or is it not worth it? does it save lines of lc3 code? no right since i'd need a register to act as a loop counter?
                if (val < 0) {
                    val *= -1;
                    negative = 1;
                }
                
                // no need to check if R2 is negative, since that will be auto factored into the mult. It only matters if val is neg,
                // since it behaves as the counter and needs to be positive so it can be decremented in the loop - then if it was neg
                // we factor that in at the end and negate the final answer
                
                // do the actual multiplication
                for (int i=0; i < val - 1; i++) { // to enable code reuse, instead of making this val - 1, clear R1
                    write_value (0x1000 | (r1 << 9) | (temp_r << 6) | r2);
                }

                if (negative == 1) { // negate 
                    write_value (0x903F | (r1 << 9) | (r1 << 6));
                    write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F));
                }

                // restore temp_r
                write_value (0x2000 | (temp_r << 9) | (0x001 & 0x1FF)); // LD temp_r, wherever it was stored
            }
        }
        else { // case RRR - still need to handle negatives!
            int destR = r1;
            int sr1 = r2;
            int sr2 = r3;

            // there are 5 cases: DestR!=SR1!=SR2; DestR==SR1; DestR==SR2; SR1==SR2; DestR==SR1==SR2;

            // if (r1==r2 || r1==r3 || r2==r3) { // in any special cases, we will need a temp register
            // decided to always use a temp register so as to avoid having complexity of whether resotring SR2 when using as counter
            // in the normal case, or whether restoring temp_r; instead always use tempR and restore that

            // locate a register not used in this multiplication
            int temp_r = 0;
            while (temp_r == r1 || temp_r == r2 || temp_r == r3) {
                temp_r++;
            }
            
            // save contents of temp_r
            write_value (0x3000 | (temp_r << 9) | ((val + 0x00E) & 0x1FF)); // need to figure out where this gets stored, def end of program
            

            int neg_count_r = 0;
            while (neg_count_r == r1 || neg_count_r == r2 || neg_count_r == r3 || neg_count_r == temp_r) {
                neg_count_r++;
            }
            // save contents of neg_count_r
            write_value (0x3000 | (neg_count_r << 9) | ((val + 0x00F) & 0x1FF)); // need to figure out where this gets stored, def end of program

            // clear neg_count_r
            write_value (0x5020 | (neg_count_r << 9) | (neg_count_r << 6) | (0x0 & 0x1F)); // AND neg_count_r, neg_count_r, #0
            
            // case 1: all registers distinct - no new assignments required
            if ((r1 != r2) && (r2 != r3) && (r1 != r3)) { // this has the same code handling as cases 3 and 4, should group together aka just have this be the standard unless one of the other 2 special cases happen
                // load contents of r3 into temp_r
                write_value (0x1020 | (temp_r << 9) | (r3 << 6) | (0x00 & 0x1F)); //ADD temp_r, r3, #0

                // set variable SR2 = temp_r
                sr2 = temp_r;
                // at the end, restore temp_r
            }
            
            // case 5: DestR == SR1 == SR2
            else if (r1 == r2 && r2 == r3) {
                int temp_r2 = 0;
                
                // locate a second register not used in this multiplication
                while (temp_r2 == r1 || temp_r2 == r2 || temp_r2 == r3 || temp_r2 == temp_r || temp_r2 == neg_count_r) {
                    temp_r2++;
                    printf("temp r2 = %d", temp_r2);
                }

                // save contents of temp_r2
                write_value (0x3000 | (temp_r2 << 9) | ((val + 0x00E) & 0x1FF)); // need to figure out where this gets stored, def end of program

                // load contents of r3 into temp_r
                write_value (0x1020 | (temp_r << 9) | (r3 << 6) | (0x00 & 0x1F)); //ADD temp_r, r3, #0

                // load contents of r3 into temp_r2
                write_value (0x1020 | (temp_r2 << 9) | (r3 << 6) | (0x00 & 0x1F)); //ADD temp_r2, r3, #0

                sr1 = temp_r;
                sr2 = temp_r2;
            }

            // case 2: DestR == SR1. EX: MLT R4, R4, R5
            else if (r1 == r2) {
                
                // load contents of r2 into temp_r
                write_value (0x1020 | (temp_r << 9) | (r2 << 6) | (0x00 & 0x1F)); //ADD temp_r, r2, #0

                // set variable SR2 = temp_r
                sr2 = temp_r;
                sr1 = r3;
                // at the end, restore temp_r
            }

            // case 3: DestR == SR2. EX: MLT R4, R5, R4 
            // case 4: SR1 == SR2. EX: MLT R4, R5, R5 {same fix works for case 3 and case 4}
            else if (r1 == r3 || r2 == r3) {
                // load contents of r3 into temp_r
                write_value (0x1020 | (temp_r << 9) | (r3 << 6) | (0x00 & 0x1F)); //ADD temp_r, r3, #0

                // set variable SR2 = temp_r
                sr2 = temp_r;
                // at the end, restore temp_r
            }

            // if SR2 is negative, it needs to be negated for calculation purposes and then the answer should be negated as well
            write_value (0x1020 | (sr2 << 9) | (sr2 << 6) | (0x00 & 0x1F)); // ADD SR2, SR2, #0
            
            // BRzp #1
            write_value (0x0600 | (0x003));
            write_value (0x1020 | (neg_count_r << 9) | (neg_count_r << 6) | (0x01 & 0x1F)); // ADD neg_count_r, neg_count_r, #1
    
            // negate SR2 so we can do mult properly
            write_value (0x903F | (sr2 << 9) | (sr2 << 6)); // not sr2, sr2
            write_value (0x1020 | (sr2 << 9) | (sr2 << 6) | (0x01 & 0x1F)); // ADD sr2, sr2, #1

            // do the actual multiplication
            // RST R1 (will hold answer) - no need to repeat this which is done above
            write_value (0x5020 | (destR << 9) | (destR << 6) | (0x0 & 0x1F));

            // DestR = DestR + SR1
            write_value (0x1000 | (destR << 9) | (destR << 6) | sr1);

            // SR2 = SR2 - 1
            write_value (0x1020 | (sr2 << 9) | (sr2 << 6) | (0x1F & 0x1F));

            // BR positive to top of loop
            write_value (0x0300 | (0xFFD & 0x1FF));

            // check whether we will need to negate the answer
            // this will only happen if neg_count_r == 1
            write_value (0x1020 | (neg_count_r << 9) | (neg_count_r << 6) | (0xFF & 0x1F)); // ADD neg_count_r, neg_count_r, #-1

            // BRnp #2 aka don't negate if neg_count_r != 1
            write_value (0x0A00 | (0x002));

            // Negate DestR
            write_value (0x903F | (destR << 9) | (destR << 6));

            // ADD 1 to Dest R
            write_value (0x1020 | (destR << 9) | (destR << 6) | (0x01 & 0x1F)); // ADD DestR, DestR, #1

        }
        break;






















    case OP_EQL: // need to either skip the one not executing or else idk maybe use real C if statements
        if (operands == O_RRI) {
            /* Check or read immediate range (error in first pass
		   prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);
        } else { // RRR addressing
            // 1. subtract
            write_value (0x903F | (r3 << 9) | (r3 << 6));
            //printf("r1 %d\n", r1*-1);
            write_value (0x1020 | (r3 << 9) | (r3 << 6) | (0x01 & 0x1F)); // & 0x1F gets the last five bits in the instr
		    write_value (0x1000 | (r1 << 9) | (r2 << 6) | r3);

            // BRz skip two instruction - maybe instead just do a C ifs statement and eihter clear r1 or set = 1?
            write_value (0x0A01);// | (0x001 & 0x1FF));

            // if ans was neg or pos then skip to here and store 1 in dest R
            write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F));
            write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F)); // & 0x1F gets the last five bits in the instr
            // 2. if zero, then they are equal and put 1 in dest R
            // clear R1 - can't just do this at start in case one of the operands is the dest register bc then we'd be clearing it
            write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F));


            // 3. if not zero, then they are not equal and put 0 in dest R
            // doing these loads will set CC so if they're eq it'll be 1 and if not it'll be zero - akin to return codes
        }
        break;
    
    case OP_MOV:
	    write_value (0x6000 | (r2 << 9) | (r2 << 6) | (0 & 0x3F));
        write_value (0x7000 | (r2 << 9) | (r1 << 6) | (0 & 0x3F));
        break;

	case OP_AND:
	    if (operands == O_RRI) {
	    	/* Check or read immediate range (error in first pass
		   prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);
		write_value (0x5020 | (r1 << 9) | (r2 << 6) | (val & 0x1F));
	    } else
		write_value (0x5000 | (r1 << 9) | (r2 << 6) | r3);
	    break;
	case OP_BR:
	    if (operands == O_I)
	        (void)read_val (o1, &val, 9);
	    else /* O_L */
	        val = find_label (o1, 9);
	    write_value (inst.ccode | (val & 0x1FF));
	    break;
	case OP_JMP:
	    write_value (0xC000 | (r1 << 6));
	    break;
	case OP_JSR:
	    if (operands == O_I)
	        (void)read_val (o1, &val, 11);
	    else /* O_L */
	        val = find_label (o1, 11);
	    write_value (0x4800 | (val & 0x7FF));
	    break;
	case OP_JSRR:
	    write_value (0x4000 | (r1 << 6));
	    break;
	case OP_LD:
	    write_value (0x2000 | (r1 << 9) | (val & 0x1FF));
	    break;
	case OP_LDI:
	    write_value (0xA000 | (r1 << 9) | (val & 0x1FF));
	    break;
	case OP_LDR:
	    (void)read_val (o3, &val, 6);
	    write_value (0x6000 | (r1 << 9) | (r2 << 6) | (val & 0x3F));
	    break;
	case OP_LEA:
	    write_value (0xE000 | (r1 << 9) | (val & 0x1FF));
	    break;
	case OP_NOT:
	    write_value (0x903F | (r1 << 9) | (r2 << 6));
	    break;
	case OP_RTI:
	    write_value (0x8000);
	    break;
	case OP_ST:
	    write_value (0x3000 | (r1 << 9) | (val & 0x1FF));
	    break;
	case OP_STI:
	    write_value (0xB000 | (r1 << 9) | (val & 0x1FF));
	    break;
	case OP_STR:
	    (void)read_val (o3, &val, 6);
	    write_value (0x7000 | (r1 << 9) | (r2 << 6) | (val & 0x3F));
	    break;
	case OP_TRAP:
	    (void)read_val (o1, &val, 8);
	    write_value (0xF000 | (val & 0xFF));
	    break;

	/* Generate trap pseudo-ops. */
	case OP_GETC:  write_value (0xF020); break;
	case OP_HALT:  write_value (0xF025); break;
	case OP_IN:    write_value (0xF023); break;
	case OP_OUT:   write_value (0xF021); break;
	case OP_PUTS:  write_value (0xF022); break;
	case OP_PUTSP: write_value (0xF024); break;

	/* Generate non-trap pseudo-ops. */
    	case OP_FILL:
	    if (operands == O_I) {
		(void)read_val (o1, &val, 16);
		val &= 0xFFFF;
	    } else /* O_L */
		val = find_label (o1, 16);
	    write_value (val);
    	    break;
	case OP_RET:   
	    write_value (0xC1C0); 
	    break;
	case OP_STRINGZ:
	    /* We must count locations written in pass 1;
	       write_value squashes the writes. */
	    for (str = o1 + 1; str[0] != '\"'; str++) {
		if (str[0] == '\\') {
		    switch (str[1]) {
			case 'a': write_value ('\a'); str++; break;
			case 'b': write_value ('\b'); str++; break;
			case 'e': write_value ('\e'); str++; break;
			case 'f': write_value ('\f'); str++; break;
			case 'n': write_value ('\n'); str++; break;
			case 'r': write_value ('\r'); str++; break;
			case 't': write_value ('\t'); str++; break;
			case 'v': write_value ('\v'); str++; break;
			case '\\': write_value ('\\'); str++; break;
			case '\"': write_value ('\"'); str++; break;
			/* FIXME: support others too? */
			default: write_value (str[1]); str++; break;
		    }
		} else {
		    if (str[0] == '\n')
		        line_num++;
		    write_value (*str);
		}
	    }
	    write_value (0);
	    break;
	case OP_BLKW:
	    (void)read_val (o1, &val, 16);
	    val &= 0xFFFF;
	    while (val-- > 0)
	        write_value (0x0000);
	    break;
	
	/* Handled earlier or never used, so never seen here. */
	case OP_NONE:
        case OP_ORIG:
        case OP_END:
	case NUM_OPS:
	    break;
    }
    new_inst_line ();
}

static void 
parse_ccode (const char* ccstr)
{
    if (*ccstr == 'N' || *ccstr == 'n') {
	inst.ccode |= CC_N;
        ccstr++;
    }
    if (*ccstr == 'Z' || *ccstr == 'z') {
	inst.ccode |= CC_Z;
        ccstr++;
    }
    if (*ccstr == 'P' || *ccstr == 'p')
	inst.ccode |= CC_P;

    /* special case: map BR to BRnzp */
    if (inst.ccode == CC_)
        inst.ccode = CC_P | CC_Z | CC_N;
}

static void
found_label (const char* lname) 
{
    unsigned char* local = sym_name (lname);

    if (pass == 1) {
	if (saw_orig == 0) {
	    fprintf (stderr, "%3d: label appears before .ORIG\n", line_num);
	    num_errors++;
	} else if (add_symbol (local, code_loc, 0) == -1) {
	    fprintf (stderr, "%3d: label %s has already appeared\n", 
	    	     line_num, local);
	    num_errors++;
	} else
	    fprintf (symout, "//\t%-16s  %04X\n", local, code_loc);
    }

    free (local);
}

