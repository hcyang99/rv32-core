/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline.v                                          //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline togeather.                      //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __PIPELINE_V__
`define __PIPELINE_V__

`timescale 1ns/100ps

module pipeline (

	input         clock,                    // System clock
	input         reset,                    // System reset
	input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	output logic [1:0]  proc2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr,      // Address sent to memory
	output logic [63:0] proc2mem_data,      // Data sent to memory
	output MEM_SIZE proc2mem_size,          // data size sent to memory

	output logic [3:0]  pipeline_completed_insts,
	output EXCEPTION_CODE   pipeline_error_status,
	output logic [4:0]  pipeline_commit_wr_idx,
	output logic [`XLEN-1:0] pipeline_commit_wr_data,
	output logic        pipeline_commit_wr_en,
	output logic [`XLEN-1:0] pipeline_commit_NPC,
	
	
	// testing hooks (these must be exported so we can test
	// the synthesized version) data is tested by looking at
	// the final values in memory
	
	
	// Outputs from IF-Stage 
	output logic [`XLEN-1:0] if_NPC_out,
	output logic [31:0] if_IR_out,
	output logic        if_valid_inst_out,
	
	// Outputs from IF/ID Pipeline Register
	output logic [`XLEN-1:0] if_id_NPC,
	output logic [31:0] if_id_IR,
	output logic        if_id_valid_inst,
	
	
	// Outputs from ID/EX Pipeline Register
	output logic [`XLEN-1:0] id_ex_NPC,
	output logic [31:0] id_ex_IR,
	output logic        id_ex_valid_inst,
	
	
	// Outputs from EX/MEM Pipeline Register
	output logic [`XLEN-1:0] ex_mem_NPC,
	output logic [31:0] ex_mem_IR,
	output logic        ex_mem_valid_inst,
	
	
	// Outputs from MEM/WB Pipeline Register
	output logic [`XLEN-1:0] mem_wb_NPC,
	output logic [31:0] mem_wb_IR,
	output logic        mem_wb_valid_inst

);

	// Pipeline register enables
	logic   if_id_enable, id_ex_enable, ex_mem_enable, mem_wb_enable;
	
	// Outputs from IF-Stage
	logic [`XLEN-1:0] proc2Imem_addr;
	IF_ID_PACKET[`WAYS-1 : 0] if_packet;

	// Outputs from IF/ID Pipeline Register
	IF_ID_PACKET[`WAYS-1 : 0] if_id_packet;

	// Outputs from ID stage
	ID_EX_PACKET [`WAYS-1 : 0] id_packet;

	logic stall;
	logic [`WAYS-1:0]	inst_next_valid;

	logic [`WAYS-1:0]	opa_valid;
	logic [`WAYS-1:0]	opb_valid;


	// Outputs from ID/Rob Pipeline Register
	ID_EX_PACKET[`WAYS-1 : 0] id_ex_packet;
	logic rob_is_full;
	
  logic [`WAYS-1:0] [4:0]        							    dest_ARN;
  logic [`WAYS-1:0] [$clog2(`PRF)-1:0]            dest_PRN;
  logic [`WAYS-1:0]                               reg_write;
  logic [`WAYS-1:0]                               is_branch;
  logic [`WAYS-1:0]                               valid;
  logic [`WAYS-1:0] [`XLEN-1:0]                   PC;
  logic [`WAYS-1:0] [`XLEN-1:0]                   target;
  logic [`WAYS-1:0]                               branch_direction;

	ID_EX_PACKET [`WAYS-1 : 0] 								id_packet_tmp;
//	logic 																					stall_tmp;							
//	logic [`WAYS-1:0]																inst_next_valid_tmp;

	logic [`WAYS-1:0]																opa_valid_tmp;
	logic [`WAYS-1:0]																opb_valid_tmp;
	logic [`WAYS-1:0]																reg_write_tmp;
	


	// Outputs from Rob-Stage
  logic [$clog2(`ROB)-1:0]                 next_tail;
  logic [`WAYS-1:0] [4:0] 						    dest_ARN_out;
  logic [`WAYS-1:0] [$clog2(`PRF)-1:0]    dest_PRN_out;
  logic [`WAYS-1:0]                        valid_out;
  logic [$clog2(`ROB):0]                   next_num_free;
	logic mis_predict;

	// Outputs from Rs-Stage
  ID_EX_PACKET [`WAYS-1:0]             rs_packet_out;

  logic [$clog2(`RS):0]                num_is_free;




	// Outputs from EX-Stage
	EX_MEM_PACKET[`WAYS-1 : 0] ex_packet;
		logic [`WAYS-1:0] 							ALU_occupied;

	// Outputs from EX/MEM Pipeline Register
	EX_MEM_PACKET ex_mem_packet;

	// Outputs from MEM-Stage
	logic [`XLEN-1:0] mem_result_out;
	logic [`XLEN-1:0] proc2Dmem_addr;
	logic [`XLEN-1:0] proc2Dmem_data;
	logic [1:0]  proc2Dmem_command;
	MEM_SIZE proc2Dmem_size;

	// Outputs from MEM/WB Pipeline Register
	logic        mem_wb_halt;
	logic        mem_wb_illegal;
	logic  [4:0] mem_wb_dest_reg_idx;
	logic [`XLEN-1:0] mem_wb_result;
	logic        mem_wb_take_branch;
	
	// Outputs from WB-Stage  (These loop back to the register file in ID)
	logic [`XLEN-1:0] wb_reg_wr_data_out;
	logic  [4:0] wb_reg_wr_idx_out;
	logic        wb_reg_wr_en_out;
	
	assign pipeline_completed_insts = {3'b0, mem_wb_valid_inst};
	assign pipeline_error_status =  mem_wb_illegal             ? ILLEGAL_INST :
	                                mem_wb_halt                ? HALTED_ON_WFI :
	                                (mem2proc_response==4'h0)  ? LOAD_ACCESS_FAULT :
	                                NO_ERROR;
	
	assign pipeline_commit_wr_idx = wb_reg_wr_idx_out;
	assign pipeline_commit_wr_data = wb_reg_wr_data_out;
	assign pipeline_commit_wr_en = wb_reg_wr_en_out;
	assign pipeline_commit_NPC = mem_wb_NPC;
	
	assign proc2mem_command =
	     (proc2Dmem_command == BUS_NONE) ? BUS_LOAD : proc2Dmem_command;
	assign proc2mem_addr =
	     (proc2Dmem_command == BUS_NONE) ? proc2Imem_addr : proc2Dmem_addr;
	//if it's an instruction, then load a double word (64 bits)
	assign proc2mem_size =
	     (proc2Dmem_command == BUS_NONE) ? DOUBLE : proc2Dmem_size;
	assign proc2mem_data = {32'b0, proc2Dmem_data};

//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////

	//these are debug signals that are now included in the packet,
	//breaking them out to support the legacy debug modes
	assign if_NPC_out        = if_packet.NPC;
	assign if_IR_out         = if_packet.inst;
	assign if_valid_inst_out = if_packet.valid;
	
	if_stage if_stage_0 (
		// Inputs
		.clock (clock),
		.reset (reset),
		.mem_wb_valid_inst(mem_wb_valid_inst),
		.ex_mem_take_branch(ex_mem_packet.take_branch),
		.ex_mem_target_pc(ex_mem_packet.alu_result),
		.Imem2proc_data(mem2proc_data),
		
		// Outputs
		.proc2Imem_addr(proc2Imem_addr),
		.if_packet_out(if_packet)
	);


//////////////////////////////////////////////////
//                                              //
//            IF/ID Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

//	assign if_id_NPC        = if_id_packet.NPC;
//	assign if_id_IR         = if_id_packet.inst;
//	assign if_id_valid_inst = if_id_packet.valid;



	assign if_id_enable = ~stall & ~rob_is_full;
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset | rob_is_full) begin 
			if_id_packet <= `SD 0;
		end else begin// if (reset)
			if (if_id_enable) begin
				if_id_packet <= `SD if_packet; 
			end else if (stall) begin
				for(int i = 0; i < `WAYS; i = i + 1)begin
					if_id_packet[i].valid <= `SD inst_next_valid[i];
				end
			end
		end
	end // always

   
//////////////////////////////////////////////////
//                                              //
//                  ID-Stage                    //
//                                              //
//////////////////////////////////////////////////
	
	id_stage id_stage_0 (// Inputs
		.clock(clock),
		.reset(reset),

		.reg_idx_wr_CDB(),
		.wr_en_CDB(),

		.if_id_packet_in(if_id_packet),
		
		// Outputs
		.stall,
		.inst_next_valid,
		.id_packet_out(id_packet),
		.opa_valid,
		.opb_valid,
		.dest_arn_valid(reg_write)

	);


//////////////////////////////////////////////////
//                                              //
//            ID/ROB Pipeline Register          //
//                                              //
//////////////////////////////////////////////////

//	assign id_ex_NPC        = id_ex_packet.NPC;
//	assign id_ex_IR         = id_ex_packet.inst;
//	assign id_ex_valid_inst = id_ex_packet.valid;
assign rob_is_full = next_num_free < `WAYS;

always_ff@(posedge clock) begin
	if(rob_is_full) begin
		id_packet_tmp 			<= `SD id_packet | id_packet_tmp;
//		stall_tmp						<= `SD stall | stall_tmp;
//		inst_next_valid_tmp <= `SD inst_next_valid | inst_next_valid_tmp;
		opa_valid_tmp				<= `SD opa_valid | opa_valid_tmp;
		opb_valid_tmp				<= `SD opb_valid | opb_valid_tmp;
		reg_write_tmp				<= `SD reg_write | reg_write_tmp;
	end else begin
		id_packet_tmp <= `SD 0;
		opa_valid_tmp <= `SD 0;
		opb_valid_tmp <= `SD 0;
		reg_write_tmp <= `SD 0;
	end
end



	assign id_ex_enable = ~rob_is_full;
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset | rob_is_full) begin
			id_ex_packet <= `SD 0;
		end else begin // if (reset)
			if (id_ex_enable) begin
				if(id_packet_tmp) begin
	//				if(stall_tmp) begin
						// previous is stall
						id_ex_packet 		<= `SD id_packet_tmp | id_packet;
						stall						<= `SD stall | stall_tmp;
						inst_next_valid <= `SD inst_next_valid | inst_next_valid_tmp;
						opa_valid				<= `SD opa_valid | opa_valid_tmp;
						opb_valid				<= `SD opb_valid | opb_valid_tmp;
						reg_write				<= `SD reg_write | reg_write_tmp;					
				end else    id_ex_packet <= `SD id_packet;
			end
		end // else: !if(reset)
	end // always


//////////////////////////////////////////////////
//                                              //
//                   ROB-Stage                  //
//                                              //
//////////////////////////////////////////////////
generate
  for(genvar i = 0; i < `WAYS; i = i + 1) begin
		assign dest_ARN[i]  = id_ex_packet[i].inst.r.rd;
		assign dest_PRN[i]  = id_ex_packet[i].dest_PRF_idx;
		assign is_branch[i] = id_ex_packet[i].cond_branch | id_ex_packet[i].uncond_branch;
		assign valid[i]     = id_ex_packet[i].valid;
		assign PC[i]				= id_ex_packet[i].PC;
		assign target[i]		= id_ex_packet[i].NPC;
		assign branch_direction[i] = 0;		
	end
endgenerate



  rob Rob(
    .clock,
    .reset,

    // wire declarations for rob inputs/outputs
    .CDB_ROB_idx(),
    .CDB_valid(),
    .CDB_direction(),
    .CDB_target(),

    .dest_ARN,
    .dest_PRN,
    .reg_write,
    .is_branch,
    .valid,
    .PC,
    .target,
    .branch_direction,

    .next_tail,
    .dest_ARN_out,
    .dest_PRN_out,
    .valid_out,
    .next_num_free,
		.mis_predict
);
//////////////////////////////////////////////////
//                                              //
//                   RS-Stage                   //
//                                              //
//////////////////////////////////////////////////

 RS Rs (
        // inputs
        .clock,
        .reset,
        .CDB_Data,
        .CDB_PRF_idx,
        .CDB_valid,
        .opa_valid_in(opa_valid),
        .opb_valid_in(opb_valid),
        .id_rs_packet_in(id_ex_packet),                            
        .load_in(1),
        .ALU_occupied,

        // output
        .rs_packet_out,

        .num_is_free

    );






//////////////////////////////////////////////////
//                                              //
//                  EX-Stage                    //
//                                              //
//////////////////////////////////////////////////
	ex_stage ex_stage_0 (
		// Inputs
		.clock(clock),
		.reset(reset),
		.id_ex_packet_in(id_ex_packet),
		// Outputs
		.ex_packet_out(ex_packet)
		.occupied_hub(ALU_occupied)
	);


//////////////////////////////////////////////////
//                                              //
//           EX/MEM Pipeline Register           //
//                                              //
//////////////////////////////////////////////////
	
	assign ex_mem_NPC        = ex_mem_packet.NPC;
	assign ex_mem_valid_inst = ex_mem_packet.valid;

	assign ex_mem_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			ex_mem_IR     <= `SD `NOP;
			ex_mem_packet <= `SD 0;
		end else begin
			if (ex_mem_enable)   begin
				// these are forwarded directly from ID/EX registers, only for debugging purposes
				ex_mem_IR     <= `SD id_ex_IR;
				// EX outputs
				ex_mem_packet <= `SD ex_packet;
			end // if
		end // else: !if(reset)
	end // always

   
//////////////////////////////////////////////////
//                                              //
//                 MEM-Stage                    //
//                                              //
//////////////////////////////////////////////////
	mem_stage mem_stage_0 (// Inputs
		.clock(clock),
		.reset(reset),
		.ex_mem_packet_in(ex_mem_packet),
		.Dmem2proc_data(mem2proc_data[`XLEN-1:0]),
		
		// Outputs
		.mem_result_out(mem_result_out),
		.proc2Dmem_command(proc2Dmem_command),
		.proc2Dmem_size(proc2Dmem_size),
		.proc2Dmem_addr(proc2Dmem_addr),
		.proc2Dmem_data(proc2Dmem_data)
	);


//////////////////////////////////////////////////
//                                              //
//           MEM/WB Pipeline Register           //
//                                              //
//////////////////////////////////////////////////
	assign mem_wb_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			mem_wb_NPC          <= `SD 0;
			mem_wb_IR           <= `SD `NOP;
			mem_wb_halt         <= `SD 0;
			mem_wb_illegal      <= `SD 0;
			mem_wb_valid_inst   <= `SD 0;
			mem_wb_dest_reg_idx <= `SD `ZERO_REG;
			mem_wb_take_branch  <= `SD 0;
			mem_wb_result       <= `SD 0;
		end else begin
			if (mem_wb_enable) begin
				// these are forwarded directly from EX/MEM latches
				mem_wb_NPC          <= `SD ex_mem_packet.NPC;
				mem_wb_IR           <= `SD ex_mem_IR;
				mem_wb_halt         <= `SD ex_mem_packet.halt;
				mem_wb_illegal      <= `SD ex_mem_packet.illegal;
				mem_wb_valid_inst   <= `SD ex_mem_packet.valid;
				mem_wb_dest_reg_idx <= `SD ex_mem_packet.dest_reg_idx;
				mem_wb_take_branch  <= `SD ex_mem_packet.take_branch;
				// these are results of MEM stage
				mem_wb_result       <= `SD mem_result_out;
			end // if
		end // else: !if(reset)
	end // always


//////////////////////////////////////////////////
//                                              //
//                  WB-Stage                    //
//                                              //
//////////////////////////////////////////////////
	wb_stage wb_stage_0 (
		// Inputs
		.clock(clock),
		.reset(reset),
		.mem_wb_NPC(mem_wb_NPC),
		.mem_wb_result(mem_wb_result),
		.mem_wb_dest_reg_idx(mem_wb_dest_reg_idx),
		.mem_wb_take_branch(mem_wb_take_branch),
		.mem_wb_valid_inst(mem_wb_valid_inst),
		
		// Outputs
		.reg_wr_data_out(wb_reg_wr_data_out),
		.reg_wr_idx_out(wb_reg_wr_idx_out),
		.reg_wr_en_out(wb_reg_wr_en_out)
	);

endmodule  // module verisimple
`endif // __PIPELINE_V__
