
    srand(time(NULL)); // get private key
    int shift = rand();
    while ((shift & 0x1F) == 0) {
        shift = rand();
    }
    
    // save contents of R0 to restore
    int R0 = 0;
    write_value (0x3000 | (R0 << 9) | 0x001);
    inst.ccode = (CC_N | CC_Z | CC_P);
    write_value (inst.ccode | 0x001);
    write_value (0x0000);

    int store_spot = 0x1B; // #30 offset
    for (int i=0x00; i<0x0A; i++) {
        write_value (0xF023); // read char
        write_value (0x1020 | (R0 << 9) | (R0 << 6) | (shift & 0x1F)); // encrypt char
        write_value (0x3000 | (R0 << 9) | (store_spot - (2*i))); // store encrypted char
    }

    // blkws to write encrpyted chars
    for (int i=0; i<11; i++) {
        write_value(0x000);
    }

    // write encrypted string to console
    write_value (0xE000 | (R0 << 9) | (0xFF4 & 0x1FF)); // LEA, R0, address of string
    write_value (0xF022);

    if (r1 != R0 && r2 != R0) {
        // write address of encrypted string to r2
        write_value (0x1020 | (r2 << 9) | (R0 << 6) | (0x00 & 0x1F)); // ADD R2, R0, #0

        // write private key to R1
        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F)); // RST R1
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (shift & 0x1F)); // ADD R1, R1, private_key

        //restore R0
        write_value (0x2000 | (R0 << 9) | (0xFD0 & 0x1FF));
    }
    else if (r1 == R0) {
        // write address of encrypted string to r2
        write_value (0x1020 | (r2 << 9) | (R0 << 6) | (0x00 & 0x1F)); // ADD R2, R0, #0

        // write private key to R1
        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F)); // RST R1
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (shift & 0x1F)); // ADD R1, R1, private_key
    }
    else { // r2  == R0
        // write private key to R1
        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F)); // RST R1
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (shift & 0x1F)); // ADD R1, R1, private_key
    }

    // set condition code based on mem address
    write_value (0x1020 | (r2 << 9) | (r2 << 6) | (0x00 & 0x1F)); // ADD R2, R2, #0