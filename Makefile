# Given no targets, 'make' will default to building 'simv', the simulated version
# of the pipeline

# make          <- compile (and run) simv if needed

# As shortcuts, any of the following will build if necessary and then run the
# specified target

# make sim      <- runs simv (after compiling simv if needed)
# make dve      <- runs DVE interactively (after compiling it if needed)
#                                

# make clean    <- remove files created during compilations (but not synthesis)
# make nuke     <- remove all files created during compilation and synthesis
#
# synthesis command not included in this Makefile
#

################################################################################
## CONFIGURATION
################################################################################

VCS = SW_VCS=2017.12-SP2-1 vcs -sverilog +vc -Mupdate -line -full64 +define+DEBUG=1
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

# SIMULATION CONFIG

SIMFILES	= verilog/rs.sv module_provided/psl_get.v sys_defs.svh
TESTBENCH	= testbench/rs_final_test.sv sys_defs.svh

# SYNTHESIS CONFIG
SYNFILES	= RS.vg

# COVERAGE CONFIG
COVERAGE	= line+tgl+cond

# Passed through to .tcl scripts:
export CLOCK_NET_NAME = clock
export RESET_NET_NAME = reset
export CLOCK_PERIOD = 10	# TODO: You will want to make this more aggresive

################################################################################
## RULES
################################################################################

# Default target:
all:	simv
	./simv | tee program.out

.PHONY: all

# Simulation:

sim:	simv $(ASSEMBLED)
	./simv | tee sim_program.out

simv:	$(HEADERS) $(SIMFILES) $(TESTBENCH)
	$(VCS) $^ -o simv

coverage:	
	vcs -V -sverilog +vc -Mupdate -line -full64 +vcs+vcdpluson -debug_pp -cm $(COVERAGE) $(SIMFILES) $(TESTBENCH) -o simv
	./simv -cm $(COVERAGE)
	urg -dir simv.vdb -format text

.PHONY: sim

# Debugging

dve_simv:	$(HEADERS) $(SIMFILES) $(TESTBENCH)
	$(VCS) +memcbk $^ -o $@ -gui

dve:	dve_simv $(ASSEMBLED)
	./$<

dve_syn:   $(HEADERS) $(SYNFILES) $(TESTBENCH) $(LIB)
	$(VCS) +memcbk $^ -o $@ -gui
	./dve_syn

clean:
	rm -rvf simv *.daidir csrc vcs.key program.out \
	syn_simv syn_simv.daidir syn_program.out \
	dve *.vpd *.vcd *.dump ucli.key \
	cm.log *.vdb urgReport

nuke:	clean
	rm -rvf *.vg *.rep *.db *.chk *.log *.out DVEfiles/

.PHONY: clean nuke dve

# Synthesis

syn_simv:	$(SYNFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SYNFILES) $(LIB) -o syn_simv

syn:	syn_simv
	./syn_simv | tee syn_program.out

RS_Line.vg: verilog/RS_Line.sv synth/RS_Line.tcl
	dc_shell-t -f synth/RS_Line.tcl | tee RS_Line.out

RS.vg: verilog/rs.sv RS_Line.vg synth/rs.tcl 
	dc_shell-t -f synth/rs.tcl | tee rs.out
