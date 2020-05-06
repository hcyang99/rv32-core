/*
    This test case runs the hailstone sequence for inputs from 0 to 21
    x1 is a temporary register
    x2 is a counter counting from 0 to 21,
    x3 is the number being modified by f2 and f3,
    x4 is the return address,
    x5 and x6 are constants
  $r5 = 1
  $r6 = 21
*/
	li	x5, 0x1
    li  x6, 0x15
    li  x2, 0x1
start:    beq   x2,     x6,     finish
    addi    x3,     x2,     0
    jalr    x4,     x0,     32
    addi    x2,     x2,     1
    beq     x0,     x0,     start
f1:     beq x3,     x5,     return
    ori     x1,     x3,     1
    beq     x1,     x5,     f3
    beq     x0,     x0,     f2
return: jalr    x1,     x4,     0
f2:     srli    x3,    x3,    1
    beq     x0,     x0,     f1
f3:     addi    x1,     x3,     0
    addi    x3,     x3,     0
    addi    x3,     x3,     1
    beq     x0,     x0,     f1
finish: wfi
