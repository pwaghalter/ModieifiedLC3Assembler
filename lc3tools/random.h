    // get random number
    srand(time(NULL));
    int r = rand();

    // store random number in r1
    inst.ccode = (CC_N | CC_Z | CC_P);
    write_value (inst.ccode | (0x001));
    write_value(r);
    write_value (0x2000 | (r1 << 9) | (0xFFE & 0x1FF));