
    srand(time(NULL)); // get private key
    int shift = rand();

    // save contents of R0 to restore later
    int R0 = 0;
    write_value (0x3000 | (R0 << 9) | 0x001);
    inst.ccode = (CC_N | CC_Z | CC_P);
    write_value (inst.ccode | 0x001);
    write_value (0x0000);

    int store_spot = 0x1B; // #30
    for (int i=0x00; i<0x0A; i++) {
        write_value (0xF023);
        write_value (0x1020 | (0 << 9) | (0 << 6) | (shift & 0x1F)); // ADD shift to R0
        write_value (0x3000 | (0 << 9) | (store_spot - (3*i) + i)); // ST R0 to just after code in mem
    }

    for (int i=0; i<11; i++) {
        write_value(0x000);
    }
    write_value (0xE000 | (0 << 9) | (0xFF4 & 0x1FF)); // LEA R0, #1
    write_value (0xF022); // write the string to the console


    if (r1 != R0 && r2 != R0) {
        write_value (0x5020 | (r2 << 9) | (r2 << 6) | (0x00 & 0x1F));
        write_value (0x1000 | (r2 << 9) | (r2 << 6) | (R0));

        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F)); // clear r1
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (shift & 0x1F)); // write the private key to specified register - should not be R0
        
        //restore R0
        write_value (0x2000 | (R0 << 9) | (0xFCF & 0x1FF));
    }
    else if (r1 == R0) {
        // write the address the string can be found to r2
        write_value (0x5020 | (r2 << 9) | (r2 << 6) | (0x00 & 0x1F));
        write_value (0x1000 | (r2 << 9) | (r2 << 6) | (R0));

        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F)); // clear r1
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (shift & 0x1F)); // write the private key to specified register - should not be R0
    }
    else { // r2  == R0 - this works.
        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F)); // clear r1
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (shift & 0x1F)); // write the private key to specified register - should not be R0
    }