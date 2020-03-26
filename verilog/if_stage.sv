/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.v                                          //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       // 
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module if_stage(
	input         clock,                  // system clock
	input         reset,                  // system reset
	input         mem_wb_valid_inst,      // only go to next instruction when true
	                                      // makes pipeline behave as single-cycle

	input  [`WAYS-1:0] [`XLEN-1:0]	pc_predicted, // the predicted PC
// the following logic should be handled outside the module
	input         	            	ex_mem_take_branch,      // taken-branch signal
	input  [`WAYS-1:0] [`XLEN-1:0] 	ex_mem_target_pc_with_predicted,        // target pc: use if take_branch is TRUE
	
	input  [`WAYS-1] [63:0] Imem2proc_data,          // Data coming back from instruction-memory

	output logic [`WAYS-1][`XLEN-1:0] proc2Icache_addr,    // Address sent to Instruction cache


	output IF_ID_PACKET [`WAYS-1] if_packet_out         // Output data packet from IF going to ID, see sys_defs for signal information 
);


	logic   [`WAYS-1] [`XLEN-1:0] PC_reg;             // PC we are currently fetching	
	logic   [`WAYS-1] [`XLEN-1:0] next_PC;

	logic           PC_enable;
	
	
	assign next_PC = pc_predicted;


	// this mux is because the Imem gives us 64 bits not 32 bits
	generate
		for (genvar i = 0 ; i <`WAYS; i = i + 1) begin
			assign proc2Icache_addr[i] 	 = {PC_reg[i][`XLEN-1:3], 3'b0};
			assign if_packet_out[i].inst = PC_reg[i][2] ? Imem2proc_data[i][63:32] : Imem2proc_data[i][31:0];
			assign if_packet_out[i].NPC  = next_PC[i];
			assign if_packet_out[i].PC  = PC_reg[i];
		end
	endgenerate
	
	// default next PC value
	
	// next PC is target_pc if there is a taken branch or
	// the next sequential PC (PC+4) if no branch
	// (halting is handled with the enable PC_enable;
	
	// The take-branch signal must override stalling (otherwise it may be lost)
	assign PC_enable =  ~stall;
	
	// Pass PC+4 down pipeline w/instruction


	// This register holds the PC value
	// synopsys sync_set_reset "reset"
	
	always_ff @(posedge clock) begin
		if(reset)
			PC_reg <= `SD 0;       // initial PC value is 0
		else if(PC_enable) begin
			if(ex_mem_take_branch)  PC_reg <= `SD next_PC; else
									PC_reg <= `SD ex_mem_target_pc_with_predicted;
		
		end
	end  // always
	
	// This FF controls the stall signal that artificially forces
	// fetch to stall until the previous instruction has completed
	// This must be removed for Project 3
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		for( int i = 0; i < `WAYS; i = i + 1) begin
			if (reset) begin
				if_packet_out[i].valid <= `SD 1;  // must start with something				
			end
			else if_packet_out[i].valid <= `SD mem_wb_valid_inst;		
		end
	end
endmodule  // module if_stage
