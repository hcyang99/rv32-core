EECS 470 BEST PERFORMING PROJECT WN2020
Group Members: Alvin Bahri, Haichao Yang, Wesley Shen, Yiqiu Sun, Yongle Liu

Arbitary superscalar out-of-order RV32 core, with instruction prefetching and write-back no-write-allocate DCache.

Only 16-bit memory address space used. Floating point not implemented.

See Makefile for usage. Requires VCS etc. to simulate.

Number of superscalar ways can be changed via the `WAYS macro in sys_defs.svh. Currently 3. Tested for 2-8. It is known to be not working with `WAYS == 1.

