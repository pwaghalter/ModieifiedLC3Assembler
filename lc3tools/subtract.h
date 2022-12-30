if (operands == O_RRI) {
	    	/* Check or read immediate range (error in first pass
		   prevents execution of second, so never fails). */
	        (void)read_val (o3, &val, 5);
            write_value (0x1020 | (r1 << 9) | (r2 << 6) | ((val*-1) & 0x1F)); 
	    } else {
            // abstracted to method for reuse in other cases
            #include "subtract_rrr.h"
        }