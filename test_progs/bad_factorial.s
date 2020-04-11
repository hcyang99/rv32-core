/*
    This program will calculate the factorial for numbers 2 to 12.
    
    This will done very poorly. Each factorial will be calculated in a
    different function so as reduce branching and increase pressure on
    the functional units and the CDB.

    Also this has a buttload of jalr
    
    Below, f2-f12 refer to the ad-hoc factorial functions.
    
    x3 is a counter
    x4 is the accumulator
    x7 is the return address
    x8 is a temp register
*/
f2:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
f3:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
f4:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
f5:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
f6:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
f7:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
f8:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
f9:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
f10:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
f11:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
f12:     li      x3,     1
    li      x4,     1
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    addi    x3,     x3,     1
    mul     x4,     x3,     x4
    wfi
