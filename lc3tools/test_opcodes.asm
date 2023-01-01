.ORIG x3000

;AND R1, R1, #0
;ADD R1, R1, #5 ; R1 = 5
;LD R2, #1 ; R2 = mem[x3004]
;LEA R3, #1 ; R3 = x3005
;AND R4, R4, #-1 ; R4 = 0
;ADD R4, R4, #3
;SUB R4, R4, R1 ; R4 = -2
;EXP R3, R4, R4 ; R3 = x3005 (no negative exponents allowed)
;LDR R5, R3, #0 ; R5 = x1923
;OR R1, R3, R1 ; R1 = x3005

; EXP R1, R2, R3 ; done pos, r2<0, r3<0, r2=0, r3=0
; EXP R1, R2, R2 done pos, r2<0, r2=0
; EXP R1, R1, R2 done pos, r2<0, r3<0, r2=0, r3=0
; EXP R1, R2, R1 done pos, r2<0, r3<0, r2=0, r3=0
; EXP R1, R1, R1 done pos, r1<0, r1=0

;spot RAND R1
;SUB R1, R2, R3
;BRnzp spot

; SUB R1, R2, R3 done pos, r2<0, r3<0, r2=0, r3=0
; SUB R1, R2, R2 ; done pos, r2<0, r2=0
; SUB R1, R1, R2 ; done pos, r2<0, r3<0, r2=0, r3=0
; SUB R1, R2, R1 ; done pos, r2<0, r3<0, r2=0, r3=0
; SUB R1, R1, R1 ; done pos, r1<0, r1=0

RAND R1, R1
HALT
.END