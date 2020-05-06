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
	li	x1, 0xfd
	slli	x3,	x3,	8 #48	30
	or	x3,	x3,	x1 #52	34
	li	x4, 0xb50
	slli	x4,	x4,	12 #60	3c
	li	x1, 0x4f3
	or	x4,	x4,	x1 #68	44
	li	x1, 0x2d
	slli	x4,	x4,	0x4 #76	4c
	or	x4,	x4,	x1 #80	50
	li	x5, 0
    wfi