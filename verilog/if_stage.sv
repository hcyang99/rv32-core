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
// `include "../sys_defs.svh"

module if_stage(
	input         clock,                  // system clock
	input         reset,                  // system reset
	input 		  stall,

	input [`XLEN-1:0]	pc_predicted, // the predicted PC

// the following logic should be handled outside the module
	input         	    rob_take_branch,      // taken-branch signal
	input  [`XLEN-1:0] 	rob_target_pc,        // target pc: use if take_branch is TRUE
	
	input  [`WAYS-1:0] [63:0] 	Icache2proc_data,          // Data coming back from instruction-memory
	input  [`WAYS-1:0]			Icache2proc_valid,

	output logic [`WAYS-1:0][`XLEN-1:0] proc2Icache_addr,    // Address sent to Instruction cache


	output IF_ID_PACKET [`WAYS-1:0] if_packet_out         // Output data packet from IF going to ID, see sys_defs for signal information 
);

	logic   [`XLEN-1:0] PC_reg;
	logic   [`WAYS-1:0] [`XLEN-1:0] PC_reg_hub;             // PC we are currently fetching	

	logic    PC_enable;
	
	


	// this mux is because the Imem gives us 64 bits not 32 bits
	
	always_comb begin
		for(int i = 0; i < `WAYS; i = i + 1) begin
			if(i == 0) 	PC_reg_hub[i] = PC_reg; else
			  			PC_reg_hub[i] = PC_reg_hub[i-1] + 4;
		end
	end

	generate
		for (genvar i = 0 ; i <`WAYS; i = i + 1) begin
			assign proc2Icache_addr[i] 	 = {PC_reg_hub[i][`XLEN-1:3], 3'b0};
			assign if_packet_out[i].inst = PC_reg_hub[i][2] ? Icache2proc_data[i][63:32] : Icache2proc_data[i][31:0];
			assign if_packet_out[i].NPC  = PC_reg_hub[i] + 4;
			assign if_packet_out[i].PC   = PC_reg_hub[i];
			assign if_packet_out[i].valid = (Icache2proc_valid == {`WAYS{1'b1}}) & (if_packet_out[i].inst != 0) & ~stall;	
		end
	endgenerate


	// default next PC value
	
	// next PC is target_pc if there is a taken branch or
	// the next sequential PC (PC+4) if no branch
	// (halting is handled with the enable PC_enable;
	
	// The take-branch signal must override stalling (otherwise it may be lost)
	assign PC_enable =  ~stall && (Icache2proc_valid == {`WAYS{1'b1}});
	
	// Pass PC+4 down pipeline w/instruction


	// This register holds the PC value
	// synopsys sync_set_reset "reset"
	

	always_ff @(posedge clock) begin
//	$display("PC_reg_hub[0]: %h PC_reg_hub[1]: %h PC_reg_hub[2]: %h",PC_reg_hub[0],PC_reg_hub[1],PC_reg_hub[2]);
//	$display("proc2Icache_addr[0]: %h proc2Icache_addr[1]: %h proc2Icache_addr[2]: %h",proc2Icache_addr[0],proc2Icache_addr[1],proc2Icache_addr[2]);
//	$display("Icache2proc_data[0]: %h",Icache2proc_data[0]);
//	$display("pc_predicted: %h Icache2proc_valid: %b",pc_predicted,Icache2proc_valid);
		if(reset) 				PC_reg <= `SD 0; else      // initial PC value is 0
		if(rob_take_branch) 	PC_reg <= `SD rob_target_pc; else
		if(PC_enable)			PC_reg <= `SD pc_predicted;
	end  // always


endmodule  // module if_stage
