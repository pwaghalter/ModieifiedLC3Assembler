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
    OP_ADD, OP_AND, OP_BR, OP_EXP, OP_JMP, OP_JSR, OP_JSRR, OP_LD, OP_LDI, OP_LDR,
    OP_LEA, OP_MLT, OP_MOV, OP_NOT, OP_OR, OP_RAND, OP_RST, OP_RTI, OP_ST, OP_STI, 
    OP_STR, OP_SUB, OP_TRAP, OP_EQL, OP_SHFT,

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
    "ADD", "AND", "BR", "EXP", "JMP", "JSR", "JSRR", "LD", "LDI", "LDR", "LEA", "MLT", "MOV",
    "NOT", "OR", "RAND", "RST", "RTI", "ST", "STI", "STR", "SUB", "TRAP", "EQL", "SHFT",

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
    0x003, /* EXP: RRR or RRI formats only */
    0x020, /* JMP: R format only           */
    0x0C0, /* JSR: I or L formats only     */
    0x020, /* JSRR: R format only          */
    0x018, /* LD: RI or RL formats only    */
    0x018, /* LDI: RI or RL formats only   */
    0x002, /* LDR: RRI format only         */
    0x018, /* LEA: RI or RL formats only   */
    0x003, /* MLT: RRR or RRI formats only */
    0x004, /* MOV: RR format only          */
    0x004, /* NOT: RR format only          */
    0x003, /* OR: RRR or RRI formats only  */
    0x004, /* RAND: RR format only          */
    0x020, /* RST: R format only           */
    0x200, /* RTI: no operands allowed     */
    0x018, /* ST: RI or RL formats only    */
    0x018, /* STI: RI or RL formats only   */
    0x002, /* STR: RRI format only         */
    0x003, /* SUB: RRR or RRI formats only */
    0x040, /* TRAP: I format only          */
    0x003, /* EQL: RRR or RRI formats only */
    0x002, /* SHFT: RRI format only        */

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
static void internal_subtract(int, int, int);
static void internal_multiply(int, int, int);
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
EXP       {inst.op = OP_EXP;   BEGIN (ls_operands);}
JMP       {inst.op = OP_JMP;   BEGIN (ls_operands);}
JSRR      {inst.op = OP_JSRR;  BEGIN (ls_operands);}
JSR       {inst.op = OP_JSR;   BEGIN (ls_operands);}
LDI       {inst.op = OP_LDI;   BEGIN (ls_operands);}
LDR       {inst.op = OP_LDR;   BEGIN (ls_operands);}
LD        {inst.op = OP_LD;    BEGIN (ls_operands);}
LEA       {inst.op = OP_LEA;   BEGIN (ls_operands);}
MLT       {inst.op = OP_MLT;   BEGIN (ls_operands);}
MOV       {inst.op = OP_MOV;   BEGIN (ls_operands);}
NOT       {inst.op = OP_NOT;   BEGIN (ls_operands);}
OR        {inst.op = OP_OR;    BEGIN (ls_operands);}
RAND      {inst.op = OP_RAND;  BEGIN (ls_operands);}
RST       {inst.op = OP_RST;   BEGIN (ls_operands);}
RTI       {inst.op = OP_RTI;   BEGIN (ls_operands);}
STI       {inst.op = OP_STI;   BEGIN (ls_operands);}
STR       {inst.op = OP_STR;   BEGIN (ls_operands);}
ST        {inst.op = OP_ST;    BEGIN (ls_operands);}
SUB       {inst.op = OP_SUB;   BEGIN (ls_operands);}
TRAP      {inst.op = OP_TRAP;  BEGIN (ls_operands);}
EQL       {inst.op = OP_EQL;   BEGIN (ls_operands);}
SHFT      {inst.op = OP_SHFT;  BEGIN (ls_operands);}

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
read_val (const char* s, int* vptr, int bits) // vptr == val pointer aka points to val so we can get the val back to whoever called it
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
    int temp_r1 = 0;
    int temp_r2 = 1;
    int temp_r3 = 0;

    const unsigned char* o1;
    const unsigned char* o2;
    const unsigned char* o3;
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
    // if we made it here, we are past .orig instruction and have a real one to execute
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
    case OP_SHFT:
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
	    if (operands == O_I) {
            printf("Warning: immediate offsets are not compatible with LC3++. We suggest using labels instead.\n");
	        (void)read_val (o1, &val, 9); // see the issue here and with all offsets is that we're messing with them by adding tons of code!!! no longer 1:1 mapping of assembler to machine code
            num_errors++;
        }
	    else /* O_L aka label */
	        val = find_label (o1, 9);
	    write_value (inst.ccode | (val & 0x1FF));
	    break;
    case OP_EXP: // must be posivite, no negative exponents allowed!
        // EXP R1, R2, #3 means R1 = R2 ** #3
        
        if (operands == O_RRI) {
	    	/* Check or read immediate range (error in first pass
		   prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);

            if (val < 0) {
                // print error message! how to accomplish this in the RRR case??
                printf("Warning: Negative exponents are not supported. Exponent is: %d.\n", val);
                //num_errors++; - should prob do the same thing in both cases aka do nothing/no op
                break;
            }

            // find three temporary registers
            while (temp_r1 == r1 || temp_r1 == r2) {
                temp_r1++;
            }
            while (temp_r2 == r1 || temp_r2 == r2 || temp_r2 == temp_r1) {
                temp_r2++;
            }
            while (temp_r3 == r1 || temp_r3 == r2 || temp_r3 == temp_r1 || temp_r3 == temp_r2) {
                temp_r3++;
            }
        }
        else {
            write_value (0x1020 | (r3 << 9) | (r3 << 6) | (0x00 & 0x1F)); // ADD r3, r3, #0
            // if result of that is negative then skip to the end - aka if there is a negative exponent
            inst.ccode = CC_N;
            //write_value (0x0800 | 0x023); // BRn to the end.
            write_value (inst.ccode | 0x025);

            while (temp_r1 == r1 || temp_r1 == r2 || temp_r1 == r3) {
                temp_r1++;
            }
             while (temp_r2 == r1 || temp_r2 == r2 || temp_r2 == r3 || temp_r2 == temp_r1) {
                temp_r2++;
            }
            while (temp_r3 == r1 || temp_r3 == r2 || temp_r3 == r3 || temp_r3 == temp_r1 || temp_r3 == temp_r2) {
               temp_r3++;
            }
        }

        // save contents of those three temp registers - should abstract these lines into a method since they will be reused often
        write_value (0x3000 | (temp_r1 << 9) | 0x003); // save temp_r1 to three lines later
        write_value (0x3000 | (temp_r2 << 9) | 0x003); // save temp_r2 to three lines later
        write_value (0x3000 | (temp_r3 << 9) | 0x003); // save temp_r2 to three lines later

        write_value (0x0E00 | 0x003); // BRnzp three lines so the saved lines don't execute
        write_value (0x0000); // basically a .blkw - save this spot so we can save temp_r1 here
        write_value (0x0000); // basically a .blkw - save this spot so we can save temp_r2 here
        write_value (0x0000); // basically a .blkw - save this spot so we can save temp_r3 here

        // set temp_r1 = r2
        // set temp_r2 = r3 or val
        write_value (0x1020 | (temp_r1 << 9) | (r2 << 6) | (0x00 & 0x1F)); // ADD temp_r1, r2, #0

        if (operands == O_RRI) {
            write_value (0x5020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x00 & 0x1F)); // clear temp_r2
            write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (val & 0x1F)); // add temp_r2, temp_r2, #val

            write_value (0x5020 | (temp_r3 << 9) | (temp_r3 << 6) | (0x00 & 0x1F)); // clear temp_r3
        }
        else{
            write_value (0x1020 | (temp_r2 << 9) | (r3 << 6) | (0x00 & 0x1F)); // ADD temp_r2, r3, #0
        }

        // clear r1
        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F)); // clear temp_r3
        // add 1 to r1
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F)); // ADD r1, r1, #1

        write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x00 & 0x1F)); // ADD temp_r2, temp_r2, #0
        
        // if exp == 0, r1 = 1, BRz END - the CC will be set to this already from prev op
        inst.ccode = CC_Z;
        write_value (inst.ccode | 0x014);
    
        write_value (0x1020 | (temp_r3 << 9) | (r1 << 6) | (0x00 & 0x1F)); // ADD temp_r3, r1, #0
        
        // save contents of temp_r1 so it can be restored
        write_value (0x3000 | (temp_r1 << 9) | (0x001 & 0x1FF));
        write_value (0x0E00 | 0x001); // BRnzp one line so the saved line doesn't execute
        write_value (0x0000); // .blkw
                
        // r1 = temp_r3 * temp_r1
        internal_multiply(r1, temp_r3, temp_r1);
        
        // restore temp_r1
        write_value (0x2000 | (temp_r1 << 9) | (0xFF1 & 0x1FF));

        // decrement temp_r2
        write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (0xFF & 0x1F)); // ADD temp_r3, r3, #-1

        // if zero, then we're done. If not, multiply again
        write_value (0x0A00 | (0xFEC & 0x1FF)); // BRnp to multiply again

        // restore temp_r1, temp_r2, temp_r3 - shouldn't this need to be a diff case if RRI?
        if (operands == O_RRI) {
            write_value (0x2000 | (temp_r1 << 9) | (0xFE0 & 0x1FF));
            write_value (0x2000 | (temp_r2 << 9) | (0xFE0 & 0x1FF));
            write_value (0x2000 | (temp_r3 << 9) | (0xFE0 & 0x1FF));
        }
        else {
            write_value (0x2000 | (temp_r1 << 9) | (0xFE2 & 0x1FF));
            write_value (0x2000 | (temp_r2 << 9) | (0xFE2 & 0x1FF));
            write_value (0x2000 | (temp_r3 << 9) | (0xFE2 & 0x1FF));
        }
        // reset condition codes
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F)); // ADD r1, r1, #0

        break;

	case OP_JMP:
	    write_value (0xC000 | (r1 << 6));
	    break;
	case OP_JSR:
	    if (operands == O_I) {
            printf("Warning: immediate offsets are not compatible with LC3++. We suggest using labels instead.\n");
	        (void)read_val (o1, &val, 11);
            num_errors++;
        }
	    else /* O_L */
	        val = find_label (o1, 11);
	    write_value (0x4800 | (val & 0x7FF));
	    break;
	case OP_JSRR:
	    write_value (0x4000 | (r1 << 6));
	    break;
	case OP_LD:
        if (operands == O_RI) {
            printf("Warning: immediate offsets are not compatible with LC3++. We suggest using labels instead.\n");
            num_errors++;
        }	    write_value (0x2000 | (r1 << 9) | (val & 0x1FF));
	    break;
	case OP_LDI:
        if (operands == O_RI) {
            printf("Warning: immediate offsets are not compatible with LC3++. We suggest using labels instead.\n");
            num_errors++;
        }
	    write_value (0xA000 | (r1 << 9) | (val & 0x1FF));
	    break;
	case OP_LDR:
	    (void)read_val (o3, &val, 6);
	    write_value (0x6000 | (r1 << 9) | (r2 << 6) | (val & 0x3F));
	    break;
	case OP_LEA:
        if (operands == O_RI) {
            printf("Warning: immediate offsets are not compatible with LC3++. We suggest using labels instead.\n");
            num_errors++;
        }
	    write_value (0xE000 | (r1 << 9) | (val & 0x1FF));
	    break;

    case OP_MLT:
        // no matter what, we will use three registers for simplicity of code/readability
        // we need two temporary registers: r2, r3, and one to keep track of negativeness
        
        // find three temporary registers
        if (operands == O_RRI) {
            /* Check or read immediate range (error in first pass
		    prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);

            while (temp_r1 == r1 || temp_r1 == r2) {
                temp_r1++;
            }
            while (temp_r2 == r1 || temp_r2 == r2 || temp_r2 == temp_r1) {
                temp_r2++;
            }
        }
        else {
            while (temp_r1 == r1 || temp_r1 == r2 || temp_r1 == r3) {
                temp_r1++;
            }
             while (temp_r2 == r1 || temp_r2 == r2 || temp_r2 == r3 || temp_r2 == temp_r1) {
                temp_r2++;
            }
        }

        // save contents of those three temp registers
        write_value (0x3000 | (temp_r1 << 9) | 0x002); // save temp_r1 to three lines later
        write_value (0x3000 | (temp_r2 << 9) | 0x002); // save temp_r2 to three lines later
        inst.ccode = (CC_N | CC_Z | CC_P);
        write_value (inst.ccode | 0x002); // BRnzp three lines so the saved lines don't execute 
        write_value (0x0000); // basically a .blkw - save this spot so we can save temp_r1 here
        write_value (0x0000); // basically a .blkw - save this spot so we can save temp_r2 here

        write_value (0x1020 | (temp_r1 << 9) | (r2 << 6) | (0x00 & 0x1F)); // ADD temp_r1, r2, #0

        if (operands == O_RRI) {
            write_value (0x5020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x00 & 0x1F)); // clear temp_r2
            write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (val & 0x1F)); // add temp_r2, temp_r2, #val
        }
        else{ // RRR
            write_value (0x1020 | (temp_r2 << 9) | (r3 << 6) | (0x00 & 0x1F)); // ADD temp_r2, r3, #0
        }

        // business logic abstracted to a method for reuse in other ops
        internal_multiply(r1, temp_r1, temp_r2);

        // restore all temp registers
        if (operands == O_RRI) {
            write_value (0x2000 | (temp_r1 << 9) | (0xFED & 0x1FF)); // LD temp_r1
            write_value (0x2000 | (temp_r2 << 9) | (0xFED & 0x1FF)); // LD temp_r2
        }
        else {
            write_value (0x2000 | (temp_r1 << 9) | (0xFEE & 0x1FF)); // LD temp_r1
            write_value (0x2000 | (temp_r2 << 9) | (0xFEE & 0x1FF)); // LD temp_r2
        }

        // ADD r1, r1, #0 to restore condition codes
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F));
        break; 


    case OP_EQL: // need to either skip the one not executing or else idk maybe use real C if statements
        
        // this does not work because you cannot restore the temp register since you will branch away! let's just stick with MOV.
        if (operands == O_RRI) {
            while (temp_r1 == r1 || temp_r1 == r2) {
                temp_r1++;
            }
        }
        else{
            while (temp_r1 == r1 || temp_r1 == r2 || temp_r1 == r3) {
                temp_r1++;
            }
        }
        
        // save temp registers
        write_value (0x3000 | (temp_r1 << 9) | 0x001); // save temp_r1 to three lines later
        inst.ccode = (CC_N | CC_Z | CC_P);
        write_value (inst.ccode | 0x001); // BRnzp three lines so the saved lines don't execute 
        write_value (0x0000); // basically a .blkw - save this spot so we can save temp_r1 here
        
        // 1. subtract
        internal_subtract(temp_r1, r1, r2);

        // if not zero, not equal so don't branch, go straight to restoring registers
        inst.ccode = (CC_N | CC_P);
        write_value(inst.ccode | 0x05);

        // if zero, r1 == r2 so branch to specified location
        // first, restore temp register
        write_value (0x2000 | (temp_r1 << 9) | (0xFFA & 0x1FF));
        
        int r7 = 7;
        if (operands == O_RRI) {
            // save PC in R7 for linkage
            inst.ccode = (CC_N | CC_P | CC_Z); // unconditionally jump
            write_value (inst.ccode | 0x001); // BRnzp three lines so the saved lines don't execute 
            write_value ((code_loc + 3)); // store the current pc + 2 (don't want to return to an unconditional jump)
            write_value (0x2000 | (r7 << 9) | (0xFFE & 0x1FF)); 

            // read val and jump that many spots
            write_value (inst.ccode | ((val + 3) & 0x1FF)); // this won't work bc there will need to be lines afterwards to restore the registers if not eql, so that throws off where to jump to.
            write_value (inst.ccode | 0x01); // if/when return from subroutine, don't try restoring the temp register again
        }
        else {
            write_value (0x4000 | (r3 << 6)); //JSRR R3
            write_value (inst.ccode | 0x01); // if/when return from subroutine, don't try restoring the temp register again
        }

        // restore temp register
        write_value (0x2000 | (temp_r1 << 9) | (0xFF8 & 0x1FF));

        break;

    case OP_MOV:
	    write_value (0x6000 | (r2 << 9) | (r2 << 6) | (0 & 0x3F));
        write_value (0x7000 | (r2 << 9) | (r1 << 6) | (0 & 0x3F));
        break;
	case OP_NOT:
	    write_value (0x903F | (r1 << 9) | (r2 << 6));
	    break;
    

    case OP_OR: // P OR Q  = NOT (NOT(P) AND NOT(Q))

        if (operands == O_RRI) {
            // locate a register not used in this op
            while (temp_r1 == r1 || temp_r1 == r2) {
                temp_r1++;
            }
            // locate a register not used in this op
            while (temp_r2 == r1 || temp_r2 == r2) {
                temp_r2++;
            }
        }
        else {
            // locate a register not used in this op
            while (temp_r1 == r1 || temp_r1 == r2 || temp_r1 == r3) {
                temp_r1++;
            }
            // locate a register not used in this op
            while (temp_r2 == r1 || temp_r2 == r2 || temp_r2 == r3) {
                temp_r2++;
            }
        }
        
        // need to save 2 registers:

        write_value (0x3000 | (temp_r1 << 9) | 0x002); // save temp_r1 to three lines later
        write_value (0x3000 | (temp_r2 << 9) | 0x002); // save temp_r2 to three lines later
        write_value (0x0E00 | (0x002)); // BRnzp two lines so the saved lines don't execute
        write_value (0x0000); // basically a .blkw - save this spot so we can save temp_r1 here
        write_value (0x0000); // basically a .blkw - save this spot so we can save temp_r2 here

        write_value (0x1020 | (temp_r1 << 9) | (r2 << 6) | (0x00 & 0x1F)); //ADD temp_r, r3, #0
        

        // get value for temp_r2
        if (operands == O_RRI) {
            /* Check or read immediate range (error in first pass
		    prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);

            // clear temp_r2
            write_value (0x5020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x0 & 0x1F)); // AND temp_r2, temp_r2, #0

            write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (val & 0x1F)); //ADD temp_r2, temp_r2, val
        }
        else {
            write_value (0x1020 | (temp_r2 << 9) | (r3 << 6) | (0x00 & 0x1F)); //ADD temp_r, r3, #0
        }
        // P = NOT P
	    write_value (0x903F | (temp_r1 << 9) | (temp_r1 << 6));

        // Q = NOT Q
        write_value (0x903F | (temp_r2 << 9) | (temp_r2 << 6));

        // DestR = P AND Q
        write_value (0x5000 | (r1 << 9) | (temp_r1 << 6) | temp_r2);

        // DestR = NOT DestR
        write_value (0x903F | (r1 << 9) | (r1 << 6));

        // restore temp_r1 and temp_r2
        if (operands == O_RRI) {
            write_value (0x2000 | (temp_r1 << 9) | (0xFF6 & 0x1FF));
            write_value (0x2000 | (temp_r2 << 9) | (0xFF6 & 0x1FF));
        }
        else {
            write_value (0x2000 | (temp_r1 << 9) | (0xFF7 & 0x1FF));
            write_value (0x2000 | (temp_r2 << 9) | (0xFF7 & 0x1FF));
        }
        
        // add 0 to r1 to set condition codes correctly
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F)); // ADD DestR, DestR, #1

        break;
    case OP_RAND: // needs to be RR: R1 = destR, R2 = seed {linear cong. generator}
        // works for R1 == R1 and R1 != R1
        
        while ((temp_r1 == r1) || (temp_r1 == r2)) {
            temp_r1++;
        }

        while ((temp_r2 == r1) | (temp_r2 == r2) | (temp_r2 == temp_r1)) {
            temp_r2++;
        }

        // Save temp_r's contents
        write_value (0x3000 | (temp_r1 << 9) | 0x002); // save temp_r1 to two lines later
        write_value (0x3000 | (temp_r2 << 9) | 0x002); // save temp_r2 to two lines later

        write_value (0x0E00 | (0x005)); // BRnzp #5

        write_value(0x0000); // .blkw
        write_value(0x0000); // .blkw

        // .FILL prime num
        write_value(0x7D03); // coprime with modulus
        //write_value(0x003); // use a tiny prime for now for ease of visual testing

        // .FILL const num
        write_value(0x0444); // constant to add to seed, smaller than modulus

        write_value(0x7FC3); // modulus

        // LD temp_r2, modulus
        write_value (0x2000 | (temp_r2 << 9) | (0xFFE & 0x1FF));

        // temp_r1 = seed
        write_value (0x5020 | (temp_r1 << 9) | (temp_r1 << 6) | (0x00 & 0x1F)); // clear temp_r2
        write_value (0x1000 | (temp_r1 << 9) | (temp_r1 << 6) | (r2));

        // Subtract temp_r1 = modulus - seed. If result is negative, negate result and use that as the seed.
        internal_subtract(temp_r1, temp_r2, temp_r1);

        inst.ccode = (CC_P | CC_Z); // if modulus - seed >= 0, valid seed, don't negate
        write_value (inst.ccode | (0x002 & 0x1FF));

        // negate temp_r1 - this will be the new seed, now we know for sure seed < modulus
        write_value (0x903F | (temp_r1 << 9) | (temp_r1 << 6));
        write_value (0x1020 | (temp_r1 << 9) | (temp_r1 << 6) | (0x01 & 0x1F));

        // LD temp_r2, prime_num
        write_value (0x2000 | (temp_r2 << 9) | (0xFF3 & 0x1FF));

        // ans = seed * prime_num
        internal_multiply(r1, temp_r1, temp_r2);

        // LD temp_r2, const_num
        write_value (0x2000 | (temp_r2 << 9) | (0xFE6 & 0x1FF));

        // ans = ans + const
        write_value (0x1000 | (r1 << 9) | (r1 << 6) | (temp_r2));

        // LD temp_r2, modulus
        write_value (0x2000 | (temp_r2 << 9) | (0xFE5 & 0x1FF));

        // ans = ans & modulus
        write_value (0x5000 | (r1 << 9) | (r1 << 6) | temp_r2);

        // restore temp registers
        write_value (0x2000 | (temp_r1 << 9) | (0xFDF & 0x1FF));
        write_value (0x2000 | (temp_r2 << 9) | (0xFDF & 0x1FF));
        break;

    case OP_RST:
        // AND register with zero
        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F));
        break;

	case OP_RTI:
	    write_value (0x8000);
	    break;
	case OP_ST:
        if (operands == O_RI) {
            printf("Warning: immediate offsets are not compatible with LC3++. We suggest using labels instead.\n");
            num_errors++;
        }
	    write_value (0x3000 | (r1 << 9) | (val & 0x1FF));
	    break;
	case OP_STI:
        if (operands == O_RI) {
            printf("Warning: immediate offsets are not compatible with LC3++. We suggest using labels instead.\n");
            num_errors++;
        }
	    write_value (0xB000 | (r1 << 9) | (val & 0x1FF));
	    break;
	case OP_STR:
	    (void)read_val (o3, &val, 6);
	    write_value (0x7000 | (r1 << 9) | (r2 << 6) | (val & 0x3F));
	    break;
    case OP_SUB:
        
        if (operands == O_RRI) {
	    	/* Check or read immediate range (error in first pass
		   prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);
            write_value (0x1020 | (r1 << 9) | (r2 << 6) | ((val*-1) & 0x1F)); 
	    } else {
            // abstracted to method for reuse in other cases
            internal_subtract(r1, r2, r3);
        }
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

int get_temp_r(int r1, int r2, int r3) {
    int temp_r = 0;
    while (temp_r == r1 || temp_r == r2 || temp_r == r3) {
        temp_r++;
    }
    return temp_r;
}

static void
internal_multiply(int r1, int temp_r1, int temp_r2) {

    // clear r1 which will hold the answer
    write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F));

    // if temp_r1 is zero, just go to the end
    write_value (0x1020 | (temp_r1 << 9) | (temp_r1 << 6) | (0x00 & 0x1F)); // ADD temp_r2, temp_r2, #0
    inst.ccode = (CC_Z);
    write_value (inst.ccode | (0x00A));
    
    // if temp_r2 is negative, it needs to be negated for calculation purposes
    // also negate temp_r1 in this case, then the negatives are all taken care of
    write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x00 & 0x1F)); // ADD temp_r2, temp_r2, #0

    // BRz past the loop if temp_r2 is zero, since this means the answer is just zero
    inst.ccode = CC_Z;
    write_value (inst.ccode | 0x008);

    // BRp #4 to skip negating if not needed
    inst.ccode = CC_P;
    write_value (inst.ccode | (0x004));
    
    // negate temp_r2 so we can do mult properly
    write_value (0x903F | (temp_r2 << 9) | (temp_r2 << 6)); // not sr2, sr2
    write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x01 & 0x1F)); // ADD sr2, sr2, #1
    write_value (0x903F | (temp_r1 << 9) | (temp_r1 << 6)); // not sr1, sr1
    write_value (0x1020 | (temp_r1 << 9) | (temp_r1 << 6) | (0x01 & 0x1F)); // ADD sr1, sr1, #1

    // do the actual multiplication
    // r1 = r1 + SR1
    write_value (0x1000 | (r1 << 9) | (r1 << 6) | temp_r1);

    // decrement temp_r2
    write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x1F & 0x1F));

    // BR positive to top of loop
    //write_value (0x0300 | (0xFFD & 0x1FF));
    inst.ccode = CC_P;
    write_value (inst.ccode | (0xFFD & 0x1FF)); // i think this works
}

static void
internal_subtract(int r1, int r2, int r3) {
    if (r1 == r2 && r2 == r3) {
        // rst r1
        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F));
    }
    else if (r1 != r2) {
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