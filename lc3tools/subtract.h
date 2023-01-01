if (operands == O_RRI) {
	/* Check or read immediate range (error in first pass
	prevents execution of second, so never fails). */
	(void)read_val (o3, &val, 5);
    write_value (0x1020 | (r1 << 9) | (r2 << 6) | ((val*-1) & 0x1F)); // ADD r1, r2, -val
} 
else {
    if (r1 == r2 && r2 == r3) {
        // rst r1
        write_value (0x5020 | (r1 << 9) | (r1 << 6) | (0x0 & 0x1F));
    }
    else if (r1 != r2) {
        // r1 = -r3
        write_value (0x903F | (r1 << 9) | (r3 << 6));
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F));

        // r1 = r1 + r2
        write_value (0x1000 | (r1 << 9) | (r1 << 6) | r2);
    }
    else { // r1 == r2
        // r1 = -r2
        write_value (0x903F | (r1 << 9) | (r2 << 6));
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F));

        // r1 = r1 + r3
        write_value (0x1000 | (r1 << 9) | (r1 << 6) | r3);
                
        // r1 = -r1
        write_value (0x903F | (r1 << 9) | (r1 << 6));
        write_value (0x1020 | (r1 << 9) | (r1 << 6) | (0x01 & 0x1F));
    }
}