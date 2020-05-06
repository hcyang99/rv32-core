/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  visual_testbench.v                                  //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline        //
//                   for the visual debugger                           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

`define VISUAL_DEBUGGER

extern void initcurses(int,int,int,int,int,int,int);
extern void flushproc();
extern void waitforresponse();
extern void initmem();
extern int get_instr_at_pc(int);
extern int not_valid_pc(int);

module testbench();

    // ------------------------- wire & variable declarations -------------------------
    logic   clock;
    logic   reset;
    logic [31:0] clock_count;
    logic [31:0] instr_count;
	int          wb_fileno;

	logic [1:0]  proc2mem_command;
	logic [`XLEN-1:0] proc2mem_addr;
	logic [63:0] proc2mem_data;
	logic  [3:0] mem2proc_response;
	logic [63:0] mem2proc_data;
	logic  [3:0] mem2proc_tag;
	logic  [1:0]     proc2mem_size;

	logic  [3:0] pipeline_completed_insts;
	EXCEPTION_CODE   pipeline_error_status;
	logic  [4:0] pipeline_commit_wr_idx;
	logic [`XLEN-1:0] pipeline_commit_wr_data;
	logic        pipeline_commit_wr_en;
	logic [`XLEN-1:0] pipeline_commit_NPC;
  logic [`WAYS-1:0] [`XLEN-1:0] 	PC_out;

// if
	logic [`WAYS-1:0]	if_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] if_IR_out;
// id
	logic [`WAYS-1:0]	id_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] id_IR_out;
	logic [`WAYS-1:0]	id_opa_valid;
	logic [`WAYS-1:0]	id_opb_valid;

// id_ex
	logic [`WAYS-1:0]	id_ex_valid_inst;
	logic [`WAYS-1:0] [`XLEN-1:0] id_ex_IR;
	logic [`WAYS-1:0]	id_ex_opa_valid;
	logic [`WAYS-1:0]	id_ex_opb_valid;
	logic [`WAYS-1:0][`XLEN-1:0] id_ex_rs1_value;
	logic [`WAYS-1:0][`XLEN-1:0] id_ex_rs2_value;

// rob
	logic except;
	logic [`WAYS-1:0]	rob_direction_out;
    logic [`WAYS-1:0] [`XLEN-1:0] rob_PC_out;
	logic [$clog2(`ROB):0]  rob_num_free;
	logic [`WAYS-1:0] [4:0]    dest_ARN_out;
	logic [`WAYS-1:0]          valid_out;

// rs	
	logic [`WAYS-1:0]    rs_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] rs_IR_out;
    logic [$clog2(`RS):0]    rs_num_is_free;
	logic [`RS-1:0]		rs_load_in_hub;
	logic [`RS-1:0]		rs_is_free_hub;
	logic [`RS-1:0]		rs_ready_hub;

// ex_stage
	logic [`WAYS-1:0]    ex_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] ex_alu_result_out;
	logic [`WAYS-1:0] 	ALU_occupied;
	logic [`WAYS-1:0] 	brand_result;

    //counter used for when processor infinite loops, forces termination
    logic [63:0] debug_counter;




// ------------------------- module instances ------------------------- 

processor core(
// Inputs
    .clock                      (clock),
    .reset                      (reset),
    .mem2proc_response          (mem2proc_response),
    .mem2proc_data              (mem2proc_data),
    .mem2proc_tag               (mem2proc_tag),

// Outputs
    .proc2mem_command           (proc2mem_command),
    .proc2mem_addr              (proc2mem_addr),
    .proc2mem_data              (proc2mem_data),
    .proc2mem_size              (proc2mem_size),

    .pipeline_completed_insts  	(pipeline_completed_insts),
    .pipeline_error_status   	(pipeline_error_status),
    .pipeline_commit_wr_idx 	(pipeline_commit_wr_idx),
    .pipeline_commit_wr_data 	(pipeline_commit_wr_data),
    .pipeline_commit_wr_en      (pipeline_commit_wr_en),
    .pipeline_commit_NPC 	    (pipeline_commit_NPC),
    .PC_out                      (PC_out),
  
// newly-added for debugging
    .if_valid_inst_out,
    .if_IR_out,

    .id_valid_inst_out,
    .id_IR_out,
    .id_opa_valid,
    .id_opb_valid,

    .id_ex_valid_inst,
    .id_ex_IR,
    .id_ex_opa_valid,
    .id_ex_opb_valid,
    .id_ex_rs1_value,
    .id_ex_rs2_value,

    .except,
    .rob_direction_out,
    .rob_PC_out,
    .rob_num_free,
    .dest_ARN_out,
    .valid_out,
	
    .rs_valid_inst_out,
    .rs_IR_out,
    .rs_num_is_free,
    .rs_load_in_hub(rs_load_in_hub),
    .rs_is_free_hub(rs_is_free_hub),
    .rs_ready_hub(rs_ready_hub),

    .ex_valid_inst_out,
    .ex_alu_result_out,
    .ALU_occupied,
    .brand_result
);


// Instantiate the Data Memory
mem memory (
// Inputs
    .clk               (clock),
    .proc2mem_command  (proc2mem_command),
    .proc2mem_addr     (proc2mem_addr),
    .proc2mem_data     (proc2mem_data),
`ifndef CACHE_MODE
    .proc2mem_size     (proc2mem_size),
`endif

// Outputs
    .mem2proc_response (mem2proc_response),
    .mem2proc_data     (mem2proc_data),
    .mem2proc_tag      (mem2proc_tag)
);


  // Generate System Clock
  always
  begin
    #(`VERILOG_CLOCK_PERIOD/2.0);
    clock = ~clock;
  end

  // Count the number of posedges and number of instructions completed
  // till simulation ends
  always @(posedge clock)
  begin
    if(reset)
    begin
      clock_count <= `SD 0;
      instr_count <= `SD 0;
    end
    else
    begin
      clock_count <= `SD (clock_count + 1);
      instr_count <= `SD (instr_count + pipeline_completed_insts);
    end
  end  

  initial
  begin
    clock = 0;
    reset = 0;
    debug_counter = 0;

    // Call to initialize visual debugger
    // *Note that after this, all stdout output goes to visual debugger*
    // each argument is number of registers/signals for the group
    // (n_ways, rs_size, rob_size, prf_size, num_regs, xlen)
    initcurses(`WAYS, `RS, `ROB, `PRF, `LSQSZ, `REGS, `XLEN);

    // Pulse the reset signal
    reset = 1'b1;
    @(posedge clock);
    @(posedge clock);

    // Read program contents into memory array
    $readmemh("program.mem", memory.unified_memory);

    @(posedge clock);
    @(posedge clock);
    `SD;
    // This reset is at an odd time to avoid the pos & neg clock edges
    reset = 1'b0;
  end

  always @(negedge clock)
  begin
      if(reset) begin
          debug_counter <= `SD 0;
      end
    if(!reset)
    begin
      `SD;
      `SD;

      // deal with any halting conditions
      if(pipeline_error_status != NO_ERROR && pipeline_error_status != LOAD_ACCESS_FAULT)
      begin
        #100
        $display("\nDONE\n");
        waitforresponse();
        flushproc();
        $finish;
      end
      debug_counter <= `SD (debug_counter + 1);
    end
  end 

  // This block is where we dump all of the signals that we care about to
  // the visual debugger.  Notice this happens at *every* clock edge.
  always @(clock) begin
    #2;

    // Dump clock and time onto stdout
    $display("c %d %d",clock,clock_count);
    //$display("t%8.0f",$time);
    //$display("z%h",reset);

    // dump ARF contents
    //$write("a");
    //for(int i = 0; i < 32; i=i+1)
    //begin
      //$write("%h", pipeline_0.id_stage_0.regf_0.registers[i]);
    //end
    //$display("");

    // dump IR information so we can see which instruction
    // is in each stage
    //$write("p");
    //$write("%h%h%h%h%h%h%h%h%h%h ",
            // TODO: ask about what to print from the pipeline here
            //pipeline_0.if_IR_out, pipeline_0.if_valid_inst_out,
            //pipeline_0.if_id_IR,  pipeline_0.if_id_valid_inst,
            //pipeline_0.id_ex_IR,  pipeline_0.id_ex_valid_inst,
            //pipeline_0.ex_mem_IR, pipeline_0.ex_mem_valid_inst,
            //pipeline_0.mem_wb_IR, pipeline_0.mem_wb_valid_inst);
    //$display("");
    
    // Dump interesting register/signal contents onto stdout
    // format is "<reg group prefix><name> <width in hex chars>:<data>"
    // Current register groups (and prefixes) are:
    // f: IF   d: ID   s: RS   o: ROB    r: RAT   v: misc. reg

    // IF signals
    for(int i = 0; i < `WAYS; i++) begin
        $display("f%d %d %h %h",
            i,
            core.if_packet[i].inst.inst,
            core.if_packet[i].valid,
            core.if_packet[i].PC);
    end

    // ID signals
    for(int i = 0; i < `WAYS; i++) begin
        $display("d%d %d %h %h",
            i,
            core.id_packet[i].inst.inst,
            core.id_packet[i].valid,
            core.id_packet[i].PC);
    end


    // ROB signals
    $display("op %d %d %d",
        core.Rob.num_free,
        core.Rob.head,
        core.Rob.tail);

    for(int i = 0; i < `ROB; i++) begin
        $display("o%d", i);
        $display("o%d %h %h %h %h %h %h %h %h %h %h %h",
            i,
            core.Rob.entries[i].dest_ARN,
            core.Rob.entries[i].dest_PRN,
            core.Rob.entries[i].reg_write,
            core.Rob.entries[i].is_branch,
            core.Rob.entries[i].PC,
            core.Rob.entries[i].target,
            core.Rob.entries[i].branch_direction,
            core.Rob.entries[i].mispredicted,
            core.Rob.entries[i].done,
            core.Rob.entries[i].illegal,
            core.Rob.entries[i].halt);
    end

    // RS signals
    $display("sp %d", core.Rs.num_is_free);
    for(int i = 0; i < `RS; i++) begin
        $display("s%d %d %h %h %h %h %h %h %h",
            i,
            core.Rs.rs_packet_out_hub[i].alu_func,
            core.Rs.opa_valid_reg[i],
            core.Rs.rs_packet_out_hub[i].rs1_value,
            core.Rs.opb_valid_reg[i],
            core.Rs.rs_packet_out_hub[i].rs2_value,
            core.Rs.rs_packet_out_hub[i].dest_PRF_idx,
            core.Rs.rs_packet_out_hub[i].rob_idx,
            core.Rs.rs_packet_out_hub[i].PC);
    end

    // RAT and RRAT signals
    for(int i = 0; i < 32; i++) begin
        $display("ra%d %h %h",
            i,
            core.id_stage_0.rat.RAT_reg_out[i],
            core.id_stage_0.rat.RRAT_reg_out[i]);
    end
    for(int i = 0; i < `PRF; i++) begin
        $display("r%d %h %h %h %h",
            i,
            core.id_stage_0.rat.free_RAT_reg_out[i],
            core.id_stage_0.rat.valid_RAT_reg_out[i],
            core.id_stage_0.rat.free_RRAT_reg_out[i],
            core.id_stage_0.rat.valid_RRAT_reg_out[i]);
    end


    // PRF signals
    for(int i = 0; i <`PRF; i++) begin
        $display("p%d %h", i, core.id_stage_0.prf.registers[i]);
    end


    // LSQ signals
    $display("q%h %h",
      core.DMEM_0.LSQ_0.sq_head,
      core.DMEM_0.LSQ_0.sq_tail);

    // LQ signals
    for(int i = 0; i < `LSQSZ; i++) begin
      $display("ql%d %h %h %h %h %h %h %h %h %h",
        i,
        core.DMEM_0.LSQ_0.lq.ld_sz_reg[i],
        core.DMEM_0.LSQ_0.lq.ld_ROB_idx_reg[i],
        core.DMEM_0.LSQ_0.lq.ld_PRF_idx_reg[i],
        core.DMEM_0.LSQ_0.lq.ld_free[i],
        core.DMEM_0.LSQ_0.lq.ld_addr_ready_reg[i],
        core.DMEM_0.LSQ_0.lq.ld_addr_reg[i],
        core.DMEM_0.LSQ_0.lq.ld_is_signed_reg[i],
        core.DMEM_0.LSQ_0.lq.sq_tail_old[i],
        core.DMEM_0.LSQ_0.lq.ld_data_reg[i]);
    end

    for(int i = 0; i < `LSQSZ; i++) begin
      $display("qs%d %h %h %h %h %h %h %h",
        i,
        core.DMEM_0.LSQ_0.sq.size_reg[i],
        core.DMEM_0.LSQ_0.sq.data_reg[i],
        core.DMEM_0.LSQ_0.sq.data_valid_reg[i],
        core.DMEM_0.LSQ_0.sq.ROB_idx_reg[i],
        core.DMEM_0.LSQ_0.sq.addr_reg[i],
        core.DMEM_0.LSQ_0.sq.addr_valid_reg[i],
        core.DMEM_0.LSQ_0.sq.valid_reg[i]);
    end


/*
    // IF signals (6) - prefix 'f'
    $display("fNPC 8:%h",          pipeline_0.if_packet.NPC);
    $display("fIR 8:%h",            pipeline_0.if_packet.inst);
    $display("fImem_addr 8:%h",    pipeline_0.if_stage_0.proc2Imem_addr);
    $display("fPC_en 1:%h",         pipeline_0.if_stage_0.PC_enable);
    $display("fPC_reg 8:%h",       pipeline_0.if_stage_0.PC_reg);
    $display("fif_valid 1:%h",      pipeline_0.if_packet.valid);

    // IF/ID signals (4) - prefix 'g'
    $display("genable 1:%h",        pipeline_0.if_id_enable);
    $display("gNPC 16:%h",          pipeline_0.if_id_packet.NPC);
    $display("gIR 8:%h",            pipeline_0.if_id_packet.inst);
    $display("gvalid 1:%h",         pipeline_0.if_id_packet.valid);

    // ID signals (13) - prefix 'd'
    $display("drs1 8:%h",         pipeline_0.id_packet.rs1_value);
    $display("drs2 8:%h",         pipeline_0.id_packet.rs2_value);
    $display("ddest_reg 2:%h",      pipeline_0.id_packet.dest_reg_idx);
    $display("drd_mem 1:%h",        pipeline_0.id_packet.rd_mem);
    $display("dwr_mem 1:%h",        pipeline_0.id_packet.wr_mem);
    $display("dopa_sel 1:%h",       pipeline_0.id_packet.opa_select);
    $display("dopb_sel 1:%h",       pipeline_0.id_packet.opb_select);
    $display("dalu_func 2:%h",      pipeline_0.id_packet.alu_func);
    $display("dcond_br 1:%h",       pipeline_0.id_packet.cond_branch);
    $display("duncond_br 1:%h",     pipeline_0.id_packet.uncond_branch);
    $display("dhalt 1:%h",          pipeline_0.id_packet.halt);
    $display("dillegal 1:%h",       pipeline_0.id_packet.illegal);
    $display("dvalid 1:%h",         pipeline_0.id_packet.valid);

    // ID/EX signals (17) - prefix 'h'
    $display("henable 1:%h",        pipeline_0.id_ex_enable);
    $display("hNPC 16:%h",          pipeline_0.id_ex_packet.NPC); 
    $display("hIR 8:%h",            pipeline_0.id_ex_packet.inst); 
    $display("hrs1 8:%h",          pipeline_0.id_ex_packet.rs1_value); 
    $display("hrs2 8:%h",          pipeline_0.id_ex_packet.rs2_value); 
    $display("hdest_reg 2:%h",      pipeline_0.id_ex_packet.dest_reg_idx);
    $display("hrd_mem 1:%h",        pipeline_0.id_ex_packet.rd_mem);
    $display("hwr_mem 1:%h",        pipeline_0.id_ex_packet.wr_mem);
    $display("hopa_sel 1:%h",       pipeline_0.id_ex_packet.opa_select);
    $display("hopb_sel 1:%h",       pipeline_0.id_ex_packet.opb_select);
    $display("halu_func 2:%h",      pipeline_0.id_ex_packet.alu_func);
    $display("hcond_br 1:%h",       pipeline_0.id_ex_packet.cond_branch);
    $display("huncond_br 1:%h",     pipeline_0.id_ex_packet.uncond_branch);
    $display("hhalt 1:%h",          pipeline_0.id_ex_packet.halt);
    $display("hillegal 1:%h",       pipeline_0.id_ex_packet.illegal);
    $display("hvalid 1:%h",         pipeline_0.id_ex_packet.valid);
    $display("hcsr_op 1:%h",        pipeline_0.id_ex_packet.csr_op);


    // EX signals (4) - prefix 'e'
    $display("eopa_mux 8:%h",      pipeline_0.ex_stage_0.opa_mux_out);
    $display("eopb_mux 8:%h",      pipeline_0.ex_stage_0.opb_mux_out);
    $display("ealu_result 8:%h",   pipeline_0.ex_packet.alu_result);
    $display("etake_branch 1:%h",   pipeline_0.ex_packet.take_branch);

    // EX/MEM signals (14) - prefix 'i'
    $display("ienable 1:%h",        pipeline_0.ex_mem_enable);
    $display("iNPC 8:%h",          pipeline_0.ex_mem_packet.NPC);
    $display("iIR 8:%h",            pipeline_0.ex_mem_IR);
    $display("irs2 8:%h",          pipeline_0.ex_mem_packet.rs2_value);
    $display("ialu_result 8:%h",   pipeline_0.ex_mem_packet.alu_result);
    $display("idest_reg 2:%h",      pipeline_0.ex_mem_packet.dest_reg_idx);
    $display("ird_mem 1:%h",        pipeline_0.ex_mem_packet.rd_mem);
    $display("iwr_mem 1:%h",        pipeline_0.ex_mem_packet.wr_mem);
    $display("itake_branch 1:%h",   pipeline_0.ex_mem_packet.take_branch);
    $display("ihalt 1:%h",          pipeline_0.ex_mem_packet.halt);
    $display("iillegal 1:%h",       pipeline_0.ex_mem_packet.illegal);
    $display("ivalid 1:%h",         pipeline_0.ex_mem_packet.valid);
    $display("icsr_op 1:%h",        pipeline_0.ex_mem_packet.csr_op);
    $display("imem_size 1:%h",      pipeline_0.ex_mem_packet.mem_size);

    // MEM signals (5) - prefix 'm'
    $display("mmem_data 16:%h",     pipeline_0.mem2proc_data);
    $display("mresult_out 8:%h",   pipeline_0.mem_result_out);
    $display("m2Dmem_data 16:%h",   pipeline_0.proc2mem_data);
    $display("m2Dmem_addr 8:%h",   pipeline_0.proc2Dmem_addr);
    $display("m2Dmem_cmd 1:%h",     pipeline_0.proc2Dmem_command);

    // MEM/WB signals (9) - prefix 'j'
    $display("jenable 1:%h",        pipeline_0.mem_wb_enable);
    $display("jNPC 8:%h",          pipeline_0.mem_wb_NPC);
    $display("jIR 8:%h",            pipeline_0.mem_wb_IR);
    $display("jresult 8:%h",       pipeline_0.mem_wb_result);
    $display("jdest_reg 2:%h",      pipeline_0.mem_wb_dest_reg_idx);
    $display("jtake_branch 1:%h",   pipeline_0.mem_wb_take_branch);
    $display("jhalt 1:%h",          pipeline_0.mem_wb_halt);
    $display("jillegal 1:%h",       pipeline_0.mem_wb_illegal);
    $display("jvalid 1:%h",         pipeline_0.mem_wb_valid_inst);

    // WB signals (3) - prefix 'w'
    $display("wwr_data 8:%h",      pipeline_0.wb_reg_wr_data_out);
    $display("wwr_idx 2:%h",        pipeline_0.wb_reg_wr_idx_out);
    $display("wwr_en 1:%h",         pipeline_0.wb_reg_wr_en_out);

    // Misc signals(2) - prefix 'v'
    $display("vcompleted 1:%h",     pipeline_0.pipeline_completed_insts);
    $display("vpipe_err 1:%h",      pipeline_error_status);
*/

    // must come last
    $display("break");

    // This is a blocking call to allow the debugger to control when we
    // advance the simulation

    waitforresponse();
  end
endmodule
