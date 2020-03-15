PIC_LD=ld

ARCHIVE_OBJS=
ARCHIVE_OBJS += _1647_archive_1.so
_1647_archive_1.so : archive.0/_1647_archive_1.a
	@$(AR) -s $<
	@$(PIC_LD) -shared  -o .//../syn_simv.daidir//_1647_archive_1.so --whole-archive $< --no-whole-archive
	@rm -f $@
	@ln -sf .//../syn_simv.daidir//_1647_archive_1.so $@






%.o: %.c
	$(CC_CG) $(CFLAGS_CG) -c -o $@ $<
CU_UDP_OBJS = \
objs/udps/hUcmi.o objs/udps/GLrQJ.o objs/udps/PjGxs.o objs/udps/MzHq6.o objs/udps/guAtk.o  \
objs/udps/aKVa7.o objs/udps/dKp3B.o objs/udps/F8ezs.o 

CU_LVL_OBJS = \
SIM_l.o 

MAIN_OBJS = \
objs/amcQw_d.o 

CU_OBJS = $(MAIN_OBJS) $(ARCHIVE_OBJS) $(CU_UDP_OBJS) $(CU_LVL_OBJS)

