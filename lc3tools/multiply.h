    // find temporary registers
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

    // save contents of temp registers
    write_value (0x3000 | (temp_r1 << 9) | 0x002);
    write_value (0x3000 | (temp_r2 << 9) | 0x002);
    inst.ccode = (CC_N | CC_Z | CC_P);
    write_value (inst.ccode | 0x002);
    write_value (0x0000);
    write_value (0x0000);

    // load temp registers with operands
    write_value (0x1020 | (temp_r1 << 9) | (r2 << 6) | (0x00 & 0x1F)); // ADD temp_r1, r2, #0
    if (operands == O_RRI) {
        write_value (0x5020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x00 & 0x1F)); // clear temp_r2
        write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (val & 0x1F)); // add temp_r2, temp_r2, #val
    }
    else{
        write_value (0x1020 | (temp_r2 << 9) | (r3 << 6) | (0x00 & 0x1F)); // ADD temp_r2, r3, #0
    }

    // logic abstracted for reuse in other ops
    #include "internal_multiply.h"

    // restore temp registers
    if (operands == O_RRI) {
        write_value (0x2000 | (temp_r1 << 9) | (0xFED & 0x1FF));
        write_value (0x2000 | (temp_r2 << 9) | (0xFED & 0x1FF));
    }
    else {
        write_value (0x2000 | (temp_r1 << 9) | (0xFEE & 0x1FF));
        write_value (0x2000 | (temp_r2 << 9) | (0xFEE & 0x1FF));
    }

    //restore condition codes
    write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F));