    // clear r1, which will hold the answer
    write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F)); // RST r1

    // if temp_r1 is zero, done.
    write_value (0x1020 | (temp_r1 << 9) | (temp_r1 << 6) | (0x00 & 0x1F)); // ADD temp_r2, temp_r2, #0
    inst.ccode = (CC_Z);
    write_value (inst.ccode | (0x00A));
    
    //if temp_r2 is zero, done.
    write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x00 & 0x1F)); // ADD temp_r2, temp_r2, #0
    inst.ccode = CC_Z;
    write_value (inst.ccode | 0x008);

    // if temp_r2 > 0, skip negating 
    inst.ccode = CC_P;
    write_value (inst.ccode | (0x004));
    
    // if temp_r2 < 0, negate it and temp_r1
    write_value (0x903F | (temp_r2 << 9) | (temp_r2 << 6));
    write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x01 & 0x1F));

    write_value (0x903F | (temp_r1 << 9) | (temp_r1 << 6));
    write_value (0x1020 | (temp_r1 << 9) | (temp_r1 << 6) | (0x01 & 0x1F));

    // do the actual multiplication
    // r1 = r1 + temp_r1
    write_value (0x1000 | (r1 << 9) | (r1 << 6) | temp_r1);

    // decrement counter
    write_value (0x1020 | (temp_r2 << 9) | (temp_r2 << 6) | (0x1F));

    // if counter > 0, loop again
    inst.ccode = CC_P;
    write_value (inst.ccode | (0xFFD & 0x1FF));