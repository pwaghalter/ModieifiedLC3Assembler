        if (operands == O_RRI) {
	    	/* Check or read immediate range (error in first pass
		   prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);

            if (val < 0) {
                // print error message! how to accomplish this in the RRR case??
                printf("Warning: Negative exponents are not supported. Exponent is: %d.\n", val);
                break; // replace this with BR straight to the end - will I have to change my screenshots??? easier to put it in a switch in my test code
            }

            // find temporary registers
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
            // if there is a negative exponent, no-op
            write_value (0x1020 | (r3 << 9) | (r3 << 6) | (0x00 & 0x1F));
            inst.ccode = CC_N;
            write_value (inst.ccode | 0x025); // BRn to the end

            // locate temporary registers
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

        // save contents of those three temp registers - should abstract these lines into a method since they will be reused often?
        write_value (0x3000 | (temp_r1 << 9) | 0x003);
        write_value (0x3000 | (temp_r2 << 9) | 0x003);
        write_value (0x3000 | (temp_r3 << 9) | 0x003); 
        write_value (0x0E00 | 0x003);
        write_value (0x0000);
        write_value (0x0000);
        write_value (0x0000);

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
        write_value (0x0A00 | (0xFEC & 0x1FF));

        // restore temp registers
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
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F));  
