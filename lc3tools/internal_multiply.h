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