/*
    This program will calculate the factorial for numbers 2 to 12.

    x1 is the return address
    x3 and x5 are counters,
    x4 is the accumulator
    x6 is a constant,
*/
        li      x5,     1
        li      x6,     12
start:  beq     x5,     x6,     finish
        addi    x5,     x5,     1
        jal     x1,     f1
        j       start
finish: wfi
f1:     li      x3,     1
        li      x4,     1
loop:   beq     x3,     x5,     return
        addi    x3,     x3,     1
        mul     x4,     x3,     x4
        j       loop
return: jr      x1
