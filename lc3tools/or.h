    // locate temp registers
    if (operands == O_RRI) {
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
        
    // save temp registers
    write_value (0x3000 | (temp_r1 << 9) | 0x002);
    write_value (0x3000 | (temp_r2 << 9) | 0x002);
    inst.ccode = (CC_N | CC_Z | CC_P);
    write_value (inst.ccode | (0x002));
    write_value (0x0000);
    write_value (0x0000);

    // set temp registers
    write_value (0x1020 | (temp_r1 << 9) | (r2 << 6) | (0x00 & 0x1F)); //ADD temp_r1, r2, #0

    if (operands == O_RRI) {
        /* Check or read immediate range (error in first pass
		prevents execution of second, so never fails). */
	    (void)read_val (o3, &val, 5);

        write_value (0x5020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x0 & 0x1F)); // AND temp_r2, temp_r2, #0
        write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (val & 0x1F)); // ADD temp_r2, temp_r2, val
    }
    else {
        write_value (0x1020 | (temp_r2 << 9) | (r3 << 6) | (0x00 & 0x1F)); // ADD temp_r2, r3, #0
    }

    // actual OR
	write_value (0x903F | (temp_r1 << 9) | (temp_r1 << 6)); // NOT temp_r1, temp_r1
    write_value (0x903F | (temp_r2 << 9) | (temp_r2 << 6)); // NOT temp_r2, temp_r2
    write_value (0x5000 | (r1 << 9) | (temp_r1 << 6) | temp_r2); // AND r1, temp_r1, temp_r2
    write_value (0x903F | (r1 << 9) | (r1 << 6)); // NOT r1, r1

    // restore temp registers
    if (operands == O_RRI) {
        write_value (0x2000 | (temp_r1 << 9) | (0xFF6 & 0x1FF));
        write_value (0x2000 | (temp_r2 << 9) | (0xFF6 & 0x1FF));
    }
    else {
        write_value (0x2000 | (temp_r1 << 9) | (0xFF7 & 0x1FF));
        write_value (0x2000 | (temp_r2 << 9) | (0xFF7 & 0x1FF));
    }
        
    // restore condition codes
    write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F));