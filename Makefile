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

#SIMFILES	= verilog/rs.sv module_provided/psl_get.v sys_defs.svh
#TESTBENCH	= testbench/rs_final_test.sv sys_defs.svh

#SIMFILES	= verilog/RS_Line.sv sys_defs.svh
#TESTBENCH	= testbench/rs_line_test.sv sys_defs.svh

HEADERS 	= sys_defs.svh ISA.svh 
SOURCES 	= verilog/rs.sv

SIMFILES 	= sys_defs.svh ISA.svh verilog/ex_stage.sv verilog/mult.sv
TESTBENCH   = testbench/ex_stage_test.sv


# SYNTHESIS CONFIG
#SYNFILES	= RS.vg
SYNFILES 	= RS_Line.vg
#SYNFILES  = ex_stage.vg


# COVERAGE CONFIG
COVERAGE	= line+tgl+cond
DESIGN_NAME = RS

# Passed through to .tcl scripts:

export HEADERS
export SOURCES
export CLOCK_NET_NAME = clock
export RESET_NET_NAME = reset
export CLOCK_PERIOD = 10	# TODO: You will want to make this more aggresive

export DESIGN_NAME


#//export DESIGN_NAME = RS_Line

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

# test
RS_Line.vg: verilog/rs.sv synth/syn.tcl
	dc_shell-t -f synth/syn.tcl | tee RS_Line.out

RS.vg: verilog/rs.sv RS_Line.vg synth/rs.tcl 
	dc_shell-t -f synth/rs.tcl | tee rs.out

mult_stage.vg: verilog/mult.sv synth/syn.tcl
	dc_shell-t -f synth/syn.tcl | tee mult_stage.out

mult.vg: verilog/mult.sv mult_stage.vg synth/syn.tcl
	dc_shell-t -f synth/syn.tcl | tee mult.out

alu.vg: verilog/ex_stage.sv mult.vg synth/syn.tcl
	dc_shell-t -f synth/syn.tcl | tee alu.out

brcond.vg: verilog/ex_stage.sv synth/syn.tcl
	dc_shell-t -f synth/syn.tcl | tee brcond.out

ex_stage.vg: verilog/ex_stage.sv alu.vg brcond.vg synth/syn.tcl
	dc_shell-t -f synth/syn.tcl | tee ex_stage.out



#alu.vg: 
#export DESIGN_NAME = alu
#	verilog/ex_stage.sv  synth/syn.tcl 