.ORIG x3000

;RST R1
;ADD R1, R1, #2 ; R1 = 2
;RST R2
;SUB R2, R2, 10 ; R2 = -10
;MLT R2, R1, R2 ; R2 = -20
;RST R3
;SUB R3, R3, 4 ; R3 = -4
;EXP R3, R3, R1 ; R3 = 16

MLT R1, R2, R3
HALT

;CYPH R1, R2
.END