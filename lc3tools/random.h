
    // get temp registers
    while ((temp_r1 == r1) || (temp_r1 == r2)) {
        temp_r1++;
    }
    while ((temp_r2 == r1) || (temp_r2 == r2) || (temp_r2 == temp_r1)) {
        temp_r2++;
    }

    // Save temp_r's contents
    write_value (0x3000 | (temp_r1 << 9) | 0x002);
    write_value (0x3000 | (temp_r2 << 9) | 0x002);
    inst.ccode = (CC_N | CC_Z | CC_P);
    write_value (inst.ccode | (0x005));
    write_value(0x0000);
    write_value(0x0000);

    // .FILL prime num, coprime with modulus
    write_value(0x7D03);

    // .FILL constant to add to seed, smaller than modulus
    write_value(0x0444);

    // .FILL modulus
    write_value(0x7FC3);

    // LD temp_r2, modulus
    write_value (0x2000 | (temp_r2 << 9) | (0xFFE & 0x1FF));

    // temp_r1 = seed
    write_value (0x5020 | (temp_r1 << 9) | (temp_r1 << 6) | (0x00 & 0x1F)); // clear temp_r2
    write_value (0x1000 | (temp_r1 << 9) | (temp_r1 << 6) | (r2));

    /* Seed must be smaller than modulus. To ensure this, subtract modulus-seed. 
    If the result is negative, i.e. seed > modulus, negate the result and use it as the seed. */

    // negate temp_r1
    write_value (0x903F | (temp_r1 << 9) | (temp_r1 << 6));
    write_value (0x1020 | (temp_r1 << 9) | (temp_r1 << 6) | (0x01 & 0x1F));
    // add temp_r1 = temp_r1 + temp_r2
    write_value (0x1000 | (temp_r1 << 9) | (temp_r1 << 6) | temp_r2);

    inst.ccode = (CC_P | CC_Z); // if (modulus - seed) >= 0, valid seed, don't negate
    write_value (inst.ccode | (0x002 & 0x1FF));

    // negate temp_r1 - this will be the new seed, now we know for sure seed < modulus
    write_value (0x903F | (temp_r1 << 9) | (temp_r1 << 6));
    write_value (0x1020 | (temp_r1 << 9) | (temp_r1 << 6) | (0x01 & 0x1F));

    // LD temp_r2, prime_num
    write_value (0x2000 | (temp_r2 << 9) | (0xFF3 & 0x1FF));

    // r1 = seed * prime_num
    internal_multiply(r1, temp_r1, temp_r2);

    // LD temp_r2, const_num
    write_value (0x2000 | (temp_r2 << 9) | (0xFE6 & 0x1FF));

    // r1 = r1 + const
    write_value (0x1000 | (r1 << 9) | (r1 << 6) | (temp_r2));

    // LD temp_r2, modulus
    write_value (0x2000 | (temp_r2 << 9) | (0xFE5 & 0x1FF));

    // r1 = r1 & modulus
    write_value (0x5000 | (r1 << 9) | (r1 << 6) | temp_r2);

    // restore temp registers
    write_value (0x2000 | (temp_r1 << 9) | (0xFDF & 0x1FF));
    write_value (0x2000 | (temp_r2 << 9) | (0xFDF & 0x1FF));

    // restore condition codes
    write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x00 & 0x1F));
