        srand(time(NULL));
        int shift = rand();

        write_value (0x3000 | (0 << 9) | 0x001); // save R0 to one line later
        inst.ccode = (CC_N | CC_Z | CC_P);
        write_value (inst.ccode | 0x001); // BRnzp three lines so the saved lines don't execute 
        write_value (0x0000); // basically a .blkw - save this spot so we can save temp_r1 here

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
        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F)); // clear r1
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (shift & 0x1F)); // write the private key to specified register - should not be R0