	li	x2, 0x8
start:	li	x3, 0x27bb
	slli	x3,	x3,	16 #8	8
	li	x1, 0x2ee6
	or	x3,	x3,	x1 #16	10
	li	x1, 0x87b
	slli	x3,	x3,	12 #24	18
	or	x3,	x3,	x1 #28	1c
	li	x1, 0x0b0
	slli	x3,	x3,	12 #36	24
	or	x3,	x3,	x1 #40	28
    wfi