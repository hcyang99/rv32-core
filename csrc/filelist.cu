PIC_LD=ld

ARCHIVE_OBJS=
<<<<<<< HEAD
ARCHIVE_OBJS += _17612_archive_1.so
_17612_archive_1.so : archive.7/_17612_archive_1.a
	@$(AR) -s $<
	@$(PIC_LD) -shared  -o .//../dve.daidir//_17612_archive_1.so --whole-archive $< --no-whole-archive
	@rm -f $@
	@ln -sf .//../dve.daidir//_17612_archive_1.so $@
=======
ARCHIVE_OBJS += _30149_archive_1.so
_30149_archive_1.so : archive.5/_30149_archive_1.a
	@$(AR) -s $<
	@$(PIC_LD) -shared  -o .//../dve.daidir//_30149_archive_1.so --whole-archive $< --no-whole-archive
	@rm -f $@
	@ln -sf .//../dve.daidir//_30149_archive_1.so $@


ARCHIVE_OBJS += _prev_archive_1.so
_prev_archive_1.so : archive.5/_prev_archive_1.a
	@$(AR) -s $<
	@$(PIC_LD) -shared  -o .//../dve.daidir//_prev_archive_1.so --whole-archive $< --no-whole-archive
	@rm -f $@
	@ln -sf .//../dve.daidir//_prev_archive_1.so $@
>>>>>>> 18d2b6230823c7a5f44f734d9b4ef82ddbd2cd0a



VCS_ARC0 =_csrc0.so

VCS_OBJS0 =objs/amcQw_d.o 



%.o: %.c
	$(CC_CG) $(CFLAGS_CG) -c -o $@ $<

$(VCS_ARC0) : $(VCS_OBJS0)
	$(PIC_LD) -shared  -o .//../dve.daidir//$(VCS_ARC0) $(VCS_OBJS0)
	rm -f $(VCS_ARC0)
	@ln -sf .//../dve.daidir//$(VCS_ARC0) $(VCS_ARC0)

CU_UDP_OBJS = \


CU_LVL_OBJS = \
SIM_l.o 

MAIN_OBJS = \


CU_OBJS = $(MAIN_OBJS) $(ARCHIVE_OBJS) $(VCS_ARC0) $(CU_UDP_OBJS) $(CU_LVL_OBJS)

