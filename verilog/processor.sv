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

module processor (

	input         clock,                    // System clock
	input         reset,                    // System reset

	input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	output logic [1:0]  			proc2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] 		proc2mem_addr,      // Address sent to memory
	output logic [63:0] 			proc2mem_data,      // Data sent to memory
	output logic [1:0] 			proc2mem_size,          // data size sent to memory

	output logic [3:0]  					pipeline_completed_insts,
	output EXCEPTION_CODE   				pipeline_error_status,
	output logic [4:0]  					pipeline_commit_wr_idx,
	output logic [`XLEN-1:0] 				pipeline_commit_wr_data,
	output logic        					pipeline_commit_wr_en,
	output logic [`XLEN-1:0] 				pipeline_commit_NPC,
	output logic [`WAYS-1:0] [`XLEN-1:0] 	PC_out,
// newly-added, for debugging
// if
	output logic [`WAYS-1:0]	if_valid_inst_out,
	output logic [`WAYS-1:0] [`XLEN-1:0] if_IR_out,
// id
	output logic [`WAYS-1:0]	id_valid_inst_out,
	output logic [`WAYS-1:0] [`XLEN-1:0] id_IR_out,
	output logic [`WAYS-1:0]	id_opa_valid,
	output logic [`WAYS-1:0]	id_opb_valid,

// id_ex
	output logic [`WAYS-1:0]	id_ex_valid_inst,
	output logic [`WAYS-1:0] [`XLEN-1:0] id_ex_IR,
	output logic [`WAYS-1:0]	id_ex_opa_valid,
	output logic [`WAYS-1:0]	id_ex_opb_valid,
	output logic [`WAYS-1:0][`XLEN-1:0] id_ex_rs1_value,
	output logic [`WAYS-1:0][`XLEN-1:0] id_ex_rs2_value,

// rob
	output logic except,
	output logic [`WAYS-1:0]	rob_direction_out,
    output logic [`WAYS-1:0] [`XLEN-1:0] rob_PC_out,
	output logic [$clog2(`ROB):0]  rob_num_free,
	output logic [`WAYS-1:0] [4:0]    dest_ARN_out,    	
	output logic [`WAYS-1:0]          valid_out,

// rs	
	output logic [`WAYS-1:0]    rs_valid_inst_out,
	output logic [`WAYS-1:0] [`XLEN-1:0] rs_IR_out,
    output logic [$clog2(`RS):0]    rs_num_is_free,
	output logic [`RS-1:0]		rs_load_in_hub,
	output logic [`RS-1:0]		rs_is_free_hub,
	output logic [`RS-1:0]		rs_ready_hub,	

// ex_stage
	output logic [`WAYS-1:0]    ex_valid_inst_out,
	output logic [`WAYS-1:0] [`XLEN-1:0] ex_alu_result_out,
	output logic [`WAYS-1:0] 	ALU_occupied,
	output logic [`WAYS-1:0] 	brand_result

);


    // between processor and icache controller
    logic [`WAYS-1:0] [63:0] 	icache_to_proc_data;
    logic [`WAYS-1:0] 				icache_to_proc_data_valid;
    logic [`WAYS-1:0] [31:0] 	proc_to_icache_addr;
    logic [`WAYS-1:0] 				proc_to_icache_en;


    // between icache controller and icache mem
    logic [4:0] 						icache_to_cachemem_index;
    logic [7:0] 						icache_to_cachemem_tag;
    logic 								icache_to_cachemem_en;
    logic [`WAYS:0] [4:0] 			icache_to_cachemem_rd_idx;
    logic [`WAYS:0] [7:0] 			icache_to_cachemem_rd_tag;
    logic [`WAYS:0][63:0] 			cachemem_to_icache_data;
    logic [`WAYS:0] 					cachemem_to_icache_valid;

    // between icache controller and mem
    logic [1:0] 						icache_to_mem_command;
    logic [`XLEN-1:0] 					icache_to_mem_addr;    // should be output of the pipeline
    logic [3:0] 						mem_to_icache_response;
    logic [3:0] 						mem_to_icache_tag;

    // between icache mem and mem
    logic [63:0] mem_to_cachemem_data; // should be input of the pipeline

	// between dcache controller and mem
    logic [3:0] 						mem_to_dcache_response;
    logic [3:0] 						mem_to_dcache_tag;
    logic [63:0] 						cachemem_to_dcache_data;

		// Pipeline register enables
	logic   if_id_enable, id_ex_enable;

		// Outputs from IF-Stage
	IF_ID_PACKET[`WAYS-1 : 0] if_packet;

	// Outputs from ID stage
	ID_EX_PACKET [`WAYS-1 : 0] 		id_packet;
	logic [`WAYS-1:0]				id_sign_out;
	// Outputs from ID/Rob&RS Pipeline Register
	logic rob_is_full;
	logic rs_is_full;
  	logic [`WAYS-1:0] [4:0]        				  	dest_ARN;
  	logic [`WAYS-1:0] [$clog2(`PRF)-1:0]            dest_PRN;
  	logic [`WAYS-1:0]                               id_reg_write;
  	logic [`WAYS-1:0]                               is_branch;
  	logic [`WAYS-1:0]                               valid;
  	logic [`WAYS-1:0]                               illegal;
  	logic [`WAYS-1:0]                               halt;
  	logic [`WAYS-1:0] [`XLEN-1:0]                   PC;
  	logic [`WAYS-1:0] [`XLEN-1:0]                   target;
    logic [`WAYS-1:0] [1:0]     				ld_st_size;
	logic [`WAYS-1:0] [`XLEN-1:0]   				st_data;
	logic [`WAYS-1:0] [$clog2(`ROB)-1:0] 			ROB_idx;

	ID_EX_PACKET [`WAYS-1:0] 						id_ex_packet;
	logic [`WAYS-1:0]								id_ex_sign;

	logic [`WAYS-1:0]								id_ex_reg_write;
	
    logic [`XLEN-1:0]                       		id_ex_next_PC;

    logic [`WAYS-1:0]                       		id_ex_predictions;
	logic [`WAYS-1:0] [$clog2(`PRF)-1:0]			ld_ex_prf_idx;
    logic [`WAYS-1:0]                               id_ex_is_store;

    // Wires for Branch Predictor
    logic [`XLEN-1:0]                       		id_next_PC;

    logic [`WAYS-1:0]                       		id_predictions;

	// Wires for ALU-LSQ
	logic [`WAYS-1:0]                         	ALU_is_valid;
	logic [`WAYS-1:0] [$clog2(`ROB)-1:0]		ALU_ROB_idx;
	logic [`WAYS-1:0]                         	ALU_is_ls;
	logic [`WAYS-1:0] [`XLEN-1:0]               ALU_data;

	// Wires for id-LSQ
    logic [`WAYS-1:0] [1:0]     			id_ex_ld_st_size;
	logic [`WAYS-1:0]               			st_en;
	logic [`WAYS-1:0] [$clog2(`ROB)-1:0]        st_ROB_idx;
    logic [`WAYS-1:0]                           ld_en;

	// output for LSQ
	logic sq_is_full;
	logic lq_is_full;

    logic [$clog2(`LSQSZ):0]           sq_num_free;
    logic [$clog2(`LSQSZ):0]           lq_num_free;

  	logic                                lq_CDB_direction;
  	logic [31:0]                         lq_CDB_target;

    logic [`XLEN-1:0]                    lq_CDB_Data;
  	logic [$clog2(`PRF)-1:0]             lq_CDB_PRF_idx;

  	logic [`WAYS-1:0]                    lq_CDB_valid;
	logic [$clog2(`ROB)-1:0]             lq_CDB_ROB_idx;

  // Outputs from Rob-Stage
  	logic [$clog2(`ROB)-1:0]                  tail;
	logic [$clog2(`ROB)-1:0]                  next_tail;


  	logic [`WAYS-1:0] [$clog2(`PRF)-1:0]      dest_PRN_out;

  	logic [$clog2(`ROB):0]                    num_free;
	logic [$clog2(`ROB):0]					  next_num_free;
  	logic [`XLEN-1:0]                         except_next_PC;

  	logic [`WAYS-1:0]                         direction_out;
  	logic [`WAYS-1:0] [`XLEN-1:0]             target_out;
  	logic [`WAYS-1:0]                         valid_update;


    logic                                     illegal_out;
    logic                                     halt_out;
	logic [$clog2(`WAYS):0]                   num_committed;
	logic									  commit_st;

	// Outputs from Rs-Stage
  ID_EX_PACKET [`WAYS-1:0]             rs_packet_out;

  logic [$clog2(`RS):0]                	num_is_free;
  logic [$clog2(`RS):0] 				num_is_free_next;

// Outputs from Rs_ex_register
	ID_EX_PACKET[`WAYS-1 : 0]      ex_packet_in;
	ID_EX_PACKET[`WAYS-1 : 0]      ex_packet_in_tmp;

// Outputs from EX-Stage
	EX_MEM_PACKET[`WAYS-1 : 0]      ex_packet_out;

// CDB wires
  	logic [`WAYS-1:0]                			CDB_mem_addr_valid;
  	logic [`WAYS-1:0] [`XLEN-1:0]               CDB_Data;
  	logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx;
  	logic [`WAYS-1:0]                           CDB_valid;
	logic [`WAYS-1:0] [$clog2(`ROB)-1:0]        CDB_ROB_idx;
  	logic [`WAYS-1:0]                           CDB_direction;
  	logic [`WAYS-1:0] [`XLEN-1:0]               CDB_target;
	logic [`WAYS-1:0]							CDB_reg_write;
	logic [`WAYS-1:0]							CDB_is_load_from_ex;
	logic [`WAYS-1:0]                           CDB_is_branch;
  	logic [`WAYS-1:0] [`XLEN-1:0]               CDB_PC;

// output of dmem
    logic [1:0]                          Dmem_command;
    logic [15:0]                         Dmem_addr;
    logic [1:0]                      Dmem_size;
    logic [63:0]              			 Dmem_data;

//-------------------------------------------------------------
	assign pipeline_completed_insts = {{(4-$clog2(`WAYS)){1'b0}},num_committed};
	assign pipeline_error_status =  illegal_out             ? ILLEGAL_INST :
	                                halt_out                ? HALTED_ON_WFI :
	                                (mem2proc_response==4'h0)  ? LOAD_ACCESS_FAULT :
	                                NO_ERROR;


//////////////////////////////////////////////////
//                                              //
//               mem_arbiter                    //
//                                              //
//////////////////////////////////////////////////



 	mem_arbiter mem_arbiter_0(
    // Icache inputs
    .Icache_addr_in (icache_to_mem_addr),
    .Icache_command_in (icache_to_mem_command),

    // Dcache inputs
	.Dcache_addr_in ({16'b0,Dmem_addr}),
    .Dcache_data_in (Dmem_data),
    .Dcache_command_in (Dmem_command),
	.Dmem_size_in (Dmem_size),
    // Mem inputs
    .mem_tag_in (mem2proc_tag),
    .mem_data_in (mem2proc_data),
    .mem_response_in (mem2proc_response),

    // Icache outputs
    .Icache_tag_out (mem_to_icache_tag),
    .Icache_data_out (mem_to_cachemem_data),
    .Icache_response_out (mem_to_icache_response),

    // Dcache outputs
    .Dcache_tag_out (mem_to_dcache_tag),
    .Dcache_data_out (cachemem_to_dcache_data),
    .Dcache_response_out (mem_to_dcache_response),

    // Mem outputs
    .mem_addr_out (proc2mem_addr),
    .mem_data_out (proc2mem_data),
    .mem_command_out (proc2mem_command),
	.mem_size_out (proc2mem_size)
);




//////////////////////////////////////////////////
//                                              //
//                  CDB                         //
//                                              //
//////////////////////////////////////////////////


  	generate
      	for(genvar i = 0; i < `WAYS; i = i + 1) begin
		  	assign CDB_mem_addr_valid[i] = ~lq_CDB_valid[i] & ex_packet_out[i].valid & (ex_packet_out[i].rd_mem) | (ex_packet_out[i].wr_mem); 
			assign CDB_reg_write[i]      = lq_CDB_valid[i] | (ex_packet_out[i].valid & ~CDB_mem_addr_valid[i] & ex_packet_out[i].reg_write);  // whether this CDB data will be written to a register
			assign CDB_valid[i]     	 = lq_CDB_valid[i] | ex_packet_out[i].valid; // wether it is a valid inst
			assign CDB_direction[i] 	 = lq_CDB_valid[i]? 0 : ex_packet_out[i].take_branch; // whether this CDB's inst will be taking branch
			assign CDB_Data[i]      	 = lq_CDB_valid[i]? lq_CDB_Data:  ex_packet_out[i].take_branch ? ex_packet_out[i].NPC : ex_packet_out[i].alu_result ;
			assign CDB_PRF_idx[i]   	 = lq_CDB_valid[i]? lq_CDB_PRF_idx : ex_packet_out[i].dest_PRF_idx;
			assign CDB_ROB_idx[i]   	 = lq_CDB_valid[i]? lq_CDB_ROB_idx : ex_packet_out[i].rob_idx; // the rob index of the CDB's inst
			assign CDB_target[i]    	 = lq_CDB_valid[i]? 0: ex_packet_out[i].take_branch ? ex_packet_out[i].alu_result: ex_packet_out[i].NPC ;  // if  			
			assign CDB_is_load_from_ex[i]= ~lq_CDB_valid[i] & ex_packet_out[i].valid & ex_packet_out[i].rd_mem;
			assign CDB_PC[i]             = ex_packet_out[i].NPC-4;
		end
	endgenerate

//////////////////////////////////////////////////
//                                              //
//               icache                         //
//                                              //
//////////////////////////////////////////////////




	assign proc_to_icache_en = {`WAYS{1'b1}};

    icache icache_0(
        .clock(clock),
        .reset(reset),

        .Imem2proc_response(mem_to_icache_response),
        .Imem2proc_tag(mem_to_icache_tag),

        .proc2Icache_addr(proc_to_icache_addr),
        .proc2Icache_en(proc_to_icache_en),
        .cachemem_data(cachemem_to_icache_data), // read an instruction when it's not in a cache put it inside a cache
        .cachemem_valid(cachemem_to_icache_valid),

// output
        .proc2Imem_command(icache_to_mem_command), 
        .proc2Imem_addr(icache_to_mem_addr),

        .Icache_data_out(icache_to_proc_data), // value is memory[proc2Icache_addr]
        .Icache_valid_out(icache_to_proc_data_valid),      // when this is high

        .rd_idx(icache_to_cachemem_rd_idx),
        .rd_tag(icache_to_cachemem_rd_tag),

        .current_index(icache_to_cachemem_index),
        .current_tag(icache_to_cachemem_tag),
        .data_write_enable(icache_to_cachemem_en)
    );

    cache cache_0(
        .clock(clock),
        .reset(reset), 

        .wr_en(icache_to_cachemem_en),
        .wr_idx(icache_to_cachemem_index),
        .wr_tag(icache_to_cachemem_tag),
        .wr_data(mem_to_cachemem_data), 

        .rd_idx(icache_to_cachemem_rd_idx),
        .rd_tag(icache_to_cachemem_rd_tag),

        .rd_data(cachemem_to_icache_data),
        .rd_valid(cachemem_to_icache_valid)
    );

//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////

	//these are debug signals that are now included in the packet,
	//breaking them out to support the legacy debug modes
//	assign if_NPC_out        = if_packet.NPC;
generate
 for(genvar i = 0; i < `WAYS; i = i + 1) begin
	assign if_IR_out[i]         = if_packet[i].inst;
	assign if_valid_inst_out[i] = if_packet[i].valid;
 end
endgenerate

	if_stage if_stage_0 (
		// Inputs
		.clock (clock),
		.reset (reset),
		.stall(rob_is_full|rs_is_full|lq_is_full|sq_is_full),

		.pc_predicted(id_next_PC),
		.rob_take_branch(except),
		.rob_target_pc(except_next_PC),

		.Icache2proc_data(icache_to_proc_data),
        .Icache2proc_valid(icache_to_proc_data_valid),
		
		// Outputs
		.proc2Icache_addr(proc_to_icache_addr),
		.if_packet_out(if_packet)
	);

//////////////////////////////////////////////////
//                                              //
//                  ID-Stage                    //
//                                              //
//////////////////////////////////////////////////
generate
 for(genvar i = 0; i < `WAYS; i = i + 1) begin
	assign id_IR_out[i]         = id_packet[i].inst;
	assign id_valid_inst_out[i] = id_packet[i].valid;
 end
endgenerate
	

	id_stage id_stage_0 (// Inputs
		.clock(clock),
		.reset(reset),

		.reg_idx_wr_CDB(CDB_PRF_idx),
		.wr_en_CDB(CDB_reg_write),
		.wr_dat_CDB(CDB_Data),

        .RRAT_ARF_idx (dest_ARN_out),  // ARF # to be renamed, from ROB
        .RRAT_idx_valid (valid_out),
        .RRAT_PRF_idx (dest_PRN_out),
        .except (except),

		.if_id_packet_in(if_packet),

//-----------------branch predictor-----------------------------

        .PC_update(CDB_PC),
        .direction_update(CDB_direction),
	

        .target_update(CDB_target),
        .valid_update(CDB_valid & CDB_is_branch),
//output
        .next_PC(id_next_PC),
        .predictions(id_predictions),

//--------------------------------------------------------------
		// Outputs
		.id_packet_out(id_packet),
		.sign_out	(id_sign_out),
		.opa_valid (id_opa_valid),
		.opb_valid (id_opb_valid)
	);


//////////////////////////////////////////////////
//                                              //
//       ID/ROB & RS Pipeline Register          //
//                                              //
//////////////////////////////////////////////////

generate
 for(genvar i = 0; i < `WAYS; i = i + 1) begin
	assign id_ex_IR[i]         = id_ex_packet[i].inst;
	assign id_ex_valid_inst[i] = id_ex_packet[i].valid;
	assign id_ex_rs1_value[i]  = id_ex_packet[i].rs1_value;
	assign id_ex_rs2_value[i]  = id_ex_packet[i].rs2_value;
 end
endgenerate


assign rob_is_full = next_num_free < 2*`WAYS;
assign rs_is_full  = num_is_free_next < `WAYS;

assign id_ex_enable = ~rob_is_full & ~rs_is_full & ~lq_is_full & ~ sq_is_full & ~except;
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset | rob_is_full | rs_is_full | lq_is_full | sq_is_full | except) begin
			id_ex_packet 		<= `SD 0;
			id_ex_next_PC 		<= `SD 0;
			id_ex_predictions 	<= `SD {`WAYS{1'b0}};
			id_ex_opa_valid		<= `SD 0;
			id_ex_opb_valid		<= `SD 0;
			id_ex_sign			<= `SD 0;
		end else begin // if (reset)
			if (id_ex_enable) begin
				id_ex_packet 		<= `SD id_packet;
				id_ex_next_PC       <= `SD id_next_PC;
				id_ex_predictions	<= `SD id_predictions ;//| id_predictions_tmp;
				id_ex_opa_valid		<= `SD id_opa_valid;
				id_ex_opb_valid		<= `SD id_opb_valid;
				id_ex_sign			<= `SD id_sign_out;
				for(int i = 0; i < `WAYS; i = i + 1) begin
					id_ex_packet[i].rob_idx <= `SD (next_tail + i)%`ROB;
				end
			end
		end // else: !if(reset)
	end // always

//////////////////////////////////////////////////
//                                              //
//                   LSQ                        //
//                                              //
//////////////////////////////////////////////////

generate
	for(genvar i = 0; i < `WAYS; i = i + 1)begin
		assign ALU_is_valid[i] 	= ex_packet_out[i].valid;
		assign ALU_ROB_idx[i]	= ex_packet_out[i].rob_idx;
		assign ALU_is_ls[i] 	= ex_packet_out[i].rd_mem | ex_packet_out[i].wr_mem;
		assign ALU_data[i]		= ex_packet_out[i].alu_result;

		assign ROB_idx[i]		= id_ex_packet[i].rob_idx;
		assign st_data[i]		= id_ex_packet[i].rs2_value;
		assign st_en[i]			= id_ex_packet[i].wr_mem & id_ex_packet[i].valid;
		assign ld_en[i]			= id_ex_packet[i].rd_mem & id_ex_packet[i].valid;
		assign ld_ex_prf_idx[i]	= id_ex_packet[i].dest_PRF_idx;
		assign id_ex_ld_st_size[i] = id_ex_packet[i].mem_size;
	end
endgenerate

assign sq_is_full = sq_num_free < `WAYS+1;
assign lq_is_full = lq_num_free < `WAYS+1;


DMEM DMEM_0(
    .clock (clock),
    .reset (reset),
    .except (except),

    .CDB_Data (CDB_Data), // the value of the register that is going to be stored
	.CDB_PRF_idx (CDB_PRF_idx),
  	.CDB_valid(CDB_reg_write),

    // from ALU to lsq // calculating the address
	.ALU_ROB_idx (ALU_ROB_idx),
    .ALU_is_valid (ALU_is_valid),
    .ALU_is_ls (ALU_is_ls),
    .ALU_data (ALU_data),

    // SQ from id_stage
    .st_size (id_ex_ld_st_size),
    .st_data (st_data),
    .st_data_valid (id_ex_opb_valid),
    .st_en (st_en),
    .st_ROB_idx (ROB_idx),
    .commit (commit_st),   // from ROB, whether head of SQ should commit


    // LQ from id_stage
    .ld_size (id_ex_ld_st_size),
    .ld_en (ld_en),
    .ld_ROB_idx (ROB_idx),
	.ld_PRF_idx (ld_ex_prf_idx),
	.ld_is_signed(id_ex_sign),

    // from mem
    .mem2proc_response (mem_to_dcache_response),// 0 = can't accept, other=tag of transaction
	.mem2proc_data (cachemem_to_dcache_data),    // data resulting from a load
	.mem2proc_tag (mem_to_dcache_tag),     // 0 = no value, other=tag of transaction

    // LSQ num free
    .sq_num_free (sq_num_free),
    .lq_num_free (lq_num_free),

    // LQ to CDB, highest priority REQUIRED
    .CDB_Data_out (lq_CDB_Data), // the data loaded from dcache or memory
  	.CDB_PRF_idx_out (lq_CDB_PRF_idx), // 
  	.CDB_valid_out (lq_CDB_valid[`WAYS-1]),
	.CDB_ROB_idx_out (lq_CDB_ROB_idx),
  	.CDB_direction_out (lq_CDB_direction),
  	.CDB_target_out (lq_CDB_target),
    // to mem
	.Dmem_command (Dmem_command), 
	.Dmem_addr (Dmem_addr),
	.Dmem_size (Dmem_size),
	.Dmem_data (Dmem_data)
);

assign lq_CDB_valid[`WAYS-2:0] = 0;


//////////////////////////////////////////////////
//                                              //
//                   ROB-Stage                  //
//                                              //
//////////////////////////////////////////////////
generate
  for(genvar i = 0; i < `WAYS; i = i + 1) begin
		assign dest_ARN[i]          = id_ex_packet[i].inst.r.rd;
		assign dest_PRN[i]          = id_ex_packet[i].dest_PRF_idx;
		assign is_branch[i]         = id_ex_packet[i].cond_branch | id_ex_packet[i].uncond_branch;
		assign valid[i]             = id_ex_packet[i].valid & ~except;
		assign illegal[i]			= id_ex_packet[i].illegal;
		assign halt[i]				= id_ex_packet[i].halt;
		assign PC[i]				= id_ex_packet[i].PC;
    //---------------------
		assign target[i]			= id_ex_predictions[i] ? id_ex_next_PC : id_ex_packet[i].PC+4;
		assign id_ex_reg_write[i]   = id_ex_packet[i].reg_write;
        assign id_ex_is_store[i]    = id_ex_packet[i].wr_mem;
	end
endgenerate


assign rob_num_free 	 = num_free;
assign rob_direction_out = direction_out;
assign rob_PC_out        = PC_out;

  rob Rob(
    .clock,
    .reset,

    // wire declarations for rob inputs/outputs
    .CDB_ROB_idx,
    .CDB_valid (CDB_valid & ~CDB_is_load_from_ex),
    .CDB_direction,
    .CDB_target,

    .dest_ARN,
    .dest_PRN,
    .reg_write(id_ex_reg_write),
    .is_branch,
    .is_store(id_ex_is_store),
    .valid,
		
    .PC,
    .target, 
    .branch_direction (id_ex_predictions),

	.illegal,
	.halt,
// output
    .tail,
	.next_tail,
    .dest_ARN_out,
    .dest_PRN_out,
    .valid_out,

    .num_free,
	.next_num_free,
	.proc_nuke(except),
    .next_pc(except_next_PC),

    .PC_out,
    .direction_out,
    .target_out,
	.is_branch_out(valid_update),

	.illegal_out,
	.halt_out,
	.num_committed,
	.commit (commit_st)
);
//////////////////////////////////////////////////
//                                              //
//                   RS-Stage                   //
//                                              //
//////////////////////////////////////////////////

generate
	for(genvar i = 0; i < `WAYS; i = i + 1) begin
		assign rs_valid_inst_out[i] = rs_packet_out[i].valid;
		assign rs_IR_out[i]			= rs_packet_out[i].inst;
	end
endgenerate

assign rs_num_is_free = num_is_free;

 RS Rs (
        // inputs
        .clock,
        .reset(reset | except),
        .CDB_Data,
        .CDB_PRF_idx,
        .CDB_valid (CDB_reg_write),
		
        .opa_valid_in(id_ex_opa_valid),
        .opb_valid_in(id_ex_opb_valid),
        .id_rs_packet_in(id_ex_packet),                            
        .load_in(~(num_free<`WAYS) & ~(num_is_free<`WAYS) & ~except),
		.ALU_occupied (ALU_occupied | lq_CDB_valid),

        // output
        .rs_packet_out,

        .num_is_free,
		.num_is_free_next,
		.load_in_hub(rs_load_in_hub),
		.is_free_hub(rs_is_free_hub),
		.ready_hub(rs_ready_hub)

    );






//////////////////////////////////////////////////
//                                              //
//                  EX-Stage                    //
//                                              //
//////////////////////////////////////////////////
generate
	for(genvar i = 0; i < `WAYS; i = i + 1) begin
		assign ex_valid_inst_out[i] = ex_packet_out[i].valid;
		assign ex_alu_result_out[i] = ex_packet_out[i].alu_result;
		assign brand_result[i]		= ex_packet_out[i].take_branch;
		assign ex_packet_in[i] 		= (ALU_occupied[i] | lq_CDB_valid[i])? ex_packet_in_tmp[i]:rs_packet_out[i];
	end
endgenerate


always_ff @(posedge clock) begin
 	for(int i = 0; i < `WAYS; i = i + 1) begin
	 	if(~ALU_occupied[i] & ~lq_CDB_valid[i]) begin
	 		ex_packet_in_tmp[i] <= `SD rs_packet_out[i];
		end
	end
end


	ex_stage ex_stage_0 (
		// Inputs
		.clock(clock),
		.reset(reset | except),
		.lq_CDB_valid (lq_CDB_valid),
		.id_ex_packet_in(ex_packet_in),
		// Outputs
		.ex_packet_out(ex_packet_out),
		.occupied_hub(ALU_occupied),
		.ex_is_branch_out(CDB_is_branch)

	);

endmodule  // module verisimple
`endif // __PIPELINE_V__

