//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  ex_stage.v                                           //
//                                                                      //
//  Description :  instruction execute (EX) stage of the pipeline;      //
//                 given the instruction command code CMD, select the   //
//                 proper input A and B for the ALU, compute the result,// 
//                 and compute the condition for branches, and pass all //
//                 the results down the pipeline. MWB                   // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`ifndef __EX_STAGE_V__
`define __EX_STAGE_V__

`timescale 1ns/100ps
//
// The ALU
//
// given the command code CMD and proper operands A and B, compute the
// result of the instruction
//`timescale 1ns/100ps

// This module is purely combinational
//

typedef enum logic {INITIAL,  MULT_NOT_DONE } alu_state;

module alu(
	input 		clock,
	input		reset,
	input 		valid_in,
	
	input [`XLEN-1:0] opa,
	input [`XLEN-1:0] opb,
	ALU_FUNC     func,

	output logic        		occupied,
	output logic				valid_out,
	output logic [`XLEN-1:0] 	result
);

	alu_state				state,next_state;
	logic					start;
	logic					is_mult;
	logic					range, range_reg; // 1 if [63:32]
	logic [(2*`XLEN)-1:0] 	product;
	logic [`XLEN-1:0]		final_product,alu_result;
	logic [1:0] sign;

	
	wire signed [`XLEN-1:0]   signed_opa, signed_opb;
	wire signed [2*`XLEN-1:0] signed_mul, mixed_mul;
	wire        [2*`XLEN-1:0] unsigned_mul;

	assign is_mult = (func == ALU_MUL) | (func == ALU_MULH) | (func == ALU_MULHSU) | (func == ALU_MULHU);

	mult mult_0 (
		.clock(clock), //check
		.reset(reset), // check
		.start(start), //check
		.sign(sign), // check

		.mcand(opa), 
		.mplier(opb),
		.product(product),
		.done(mult_done)
	);

assign occupied = (state == MULT_NOT_DONE);

	always_comb begin
		valid_out = 0;
		start = 0;
//		occupied = 0;
		case (state)
			INITIAL:	begin
				if(~valid_in) 			next_state = INITIAL; 	else
				if(~is_mult)	begin
					valid_out = 1;
					next_state = INITIAL; 
				end	else begin 
					start = 1;
//					occupied = 1;
					next_state = MULT_NOT_DONE;
				end
			end
			MULT_NOT_DONE:	begin
				if(mult_done)	begin
					valid_out = 1;
//					occupied  = 0;
					next_state = INITIAL; 
				end	else begin 
					//start = 1;
//					occupied = 1;
					next_state = MULT_NOT_DONE;
				end
			end
			default: 			next_state = INITIAL;
		endcase
	end

	always_ff @(posedge clock) begin
//		$display("state: %b next_stage: %b valid_in: %b",state,next_state,valid_in);
		if(reset) begin
					state <= `SD INITIAL; 
		end else begin
										state <= `SD next_state;
			if(is_mult)	range_reg <= `SD range;
		end	
	end

	assign signed_opa = opa;
	assign signed_opb = opb;
	assign result = is_mult ? final_product: alu_result;

	always_comb begin
	//$display("occupied: %b mult_done: %b is_mult: %b",occupied,mult_done,is_mult);
		if(range_reg) 	final_product = product[2*`XLEN-1:`XLEN]; else
						final_product = product[`XLEN-1:0];
		sign = 0;
		range = 0;
		alu_result = 0;
			case (func)
			ALU_ADD:      alu_result = opa + opb;
			ALU_SUB:      alu_result = opa - opb;
			ALU_AND:      alu_result = opa & opb;
			ALU_SLT:      alu_result = signed_opa < signed_opb;
			ALU_SLTU:     alu_result = opa < opb;
			ALU_OR:       alu_result = opa | opb;
			ALU_XOR:      alu_result = opa ^ opb;
			ALU_SRL:      alu_result = opa >> opb[4:0];
			ALU_SLL:      alu_result = opa << opb[4:0];
			ALU_SRA:      alu_result = signed_opa >>> opb[4:0]; // arithmetic from logical shift
			ALU_MUL:      begin
				sign = 2'b11;
				range = 0;
			end
			ALU_MULH:     begin
				sign = 2'b11;
				range = 1;
			end
			ALU_MULHSU:   begin
				sign = 2'b01;
				range = 1;
			end
			ALU_MULHU:    begin
				sign = 2'b00;
				range = 1;
			end
			default:      alu_result = `XLEN'hfacebeec;  // here to prevent latches
			endcase
	end
endmodule // alu

//
// BrCond module
//
// Given the instruction code, compute the proper condition for the
// instruction; for branches this condition will indicate whether the
// target is taken.
//
// This module is purely combinational
//
module brcond(// Inputs
	input [`XLEN-1:0] rs1,    // Value to check against condition
	input [`XLEN-1:0] rs2,
	input  [2:0] func,  // Specifies which condition to check

	output logic cond    // 0/1 condition result (False/True)
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
		cond = 0;
		case (func)
			3'b000: cond = signed_rs1 == signed_rs2;  // BEQ
			3'b001: cond = signed_rs1 != signed_rs2;  // BNE
			3'b100: cond = signed_rs1 < signed_rs2;   // BLT
			3'b101: cond = signed_rs1 >= signed_rs2;  // BGE
			3'b110: cond = rs1 < rs2;                 // BLTU
			3'b111: cond = rs1 >= rs2;                // BGEU
		endcase
	end
	
endmodule // brcond


module ex_stage(
	input clock,               // system clock
	input reset,               // system reset
	input 	ID_EX_PACKET	[`WAYS-1:0]      	id_ex_packet_in,
	output 	EX_MEM_PACKET	[`WAYS-1:0] 		ex_packet_out,
	output [`WAYS-1:0] 							occupied_hub
);

	logic [`WAYS-1: 0][`XLEN-1:0] opa_mux_out, opb_mux_out;
	logic [`WAYS-1: 0]            brcond_result;

	// Pass-throughs
	generate
		for (genvar i = 0; i < `WAYS; i = i + 1) begin
           	assign ex_packet_out[i].NPC 			= id_ex_packet_in[i].NPC;
			assign ex_packet_out[i].rs2_value 		= id_ex_packet_in[i].rs2_value;
			assign ex_packet_out[i].rd_mem 			= id_ex_packet_in[i].rd_mem;
			assign ex_packet_out[i].wr_mem 			= id_ex_packet_in[i].wr_mem;
			assign ex_packet_out[i].dest_PRF_idx 	= id_ex_packet_in[i].dest_PRF_idx;
			assign ex_packet_out[i].rob_idx      	= id_ex_packet_in[i].rob_idx;
			assign ex_packet_out[i].halt 			= id_ex_packet_in[i].halt;
			assign ex_packet_out[i].illegal 		= id_ex_packet_in[i].illegal;
			assign ex_packet_out[i].csr_op 			= id_ex_packet_in[i].csr_op;
			assign ex_packet_out[i].mem_size 		= id_ex_packet_in[i].inst.r.funct3;
			// ultimate "take branch" signal:
	 		//	unconditional, or conditional and the condition is true
			assign ex_packet_out[i].take_branch = id_ex_packet_in[i].uncond_branch
		                          | (id_ex_packet_in[i].cond_branch & brcond_result[i]);
        end
	endgenerate


	
	// ALU opA mux
	//
	always_comb begin
//		$display("occupied_hub: %b",occupied_hub);
			for( int i = 0; i < `WAYS; ++i) begin
			opa_mux_out[i] = `XLEN'hdeadfbac;
			case (id_ex_packet_in[i].opa_select)
				OPA_IS_RS1:  opa_mux_out[i] = id_ex_packet_in[i].rs1_value;
				OPA_IS_NPC:  opa_mux_out[i] = id_ex_packet_in[i].NPC;
				OPA_IS_PC:   opa_mux_out[i] = id_ex_packet_in[i].PC;
				OPA_IS_ZERO: opa_mux_out[i] = 0;
			endcase
		end
	end

	 //
	 // ALU opB mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		for( int i = 0; i < `WAYS; ++i) begin
			opb_mux_out[i] = `XLEN'hfacefeed;
			case (id_ex_packet_in[i].opb_select)
				OPB_IS_RS2:   opb_mux_out[i] = id_ex_packet_in[i].rs2_value;
				OPB_IS_I_IMM: opb_mux_out[i] = `RV32_signext_Iimm(id_ex_packet_in[i].inst);
				OPB_IS_S_IMM: opb_mux_out[i] = `RV32_signext_Simm(id_ex_packet_in[i].inst);
				OPB_IS_B_IMM: opb_mux_out[i] = `RV32_signext_Bimm(id_ex_packet_in[i].inst);
				OPB_IS_U_IMM: opb_mux_out[i] = `RV32_signext_Uimm(id_ex_packet_in[i].inst);
				OPB_IS_J_IMM: opb_mux_out[i] = `RV32_signext_Jimm(id_ex_packet_in[i].inst);
			endcase
		end
	end

	//
	// instantiate the ALU
	//
	generate
		genvar i;
		for (i=0; i<`WAYS; i++) begin
			alu alu_0(// Inputs
				.clock(clock),
				.reset(reset),
				.valid_in(id_ex_packet_in[i].valid),

				.opa(opa_mux_out[i]),
				.opb(opb_mux_out[i]),
				.func(id_ex_packet_in[i].alu_func),

		// Output
				.occupied(occupied_hub[i]),
				.valid_out(ex_packet_out[i].valid),
				.result(ex_packet_out[i].alu_result)
			);

			brcond brcond_0(// Inputs
				.rs1(id_ex_packet_in[i].rs1_value), 
				.rs2(id_ex_packet_in[i].rs2_value),
				.func(id_ex_packet_in[i].inst.b.funct3), // inst bits to determine check

		// Output
				.cond(brcond_result[i])
			);			
		end
	endgenerate

	always_ff@(posedge clock) begin
			for( int i = 0; i < `WAYS; ++i) begin
		if(id_ex_packet_in[i].inst == `XLEN'hfc0312e3) begin
		$display("-------------------");
		$display("at bne: take_branch: %b cond_branch: %b brcond_result:%b rs1_value: %h rs2_value: %h valid: %b",
		ex_packet_out[i].take_branch,
		id_ex_packet_in[i].cond_branch,
		brcond_result[i],
		id_ex_packet_in[i].rs1_value,id_ex_packet_in[i].rs2_value,
		id_ex_packet_in[i].valid);
		end
	end
end

always_ff @(posedge clock) begin
 $display("occupied_hub:%b",occupied_hub);
 
for(int i = 0; i < `WAYS ; i = i + 1) begin
		  
		if(ex_packet_out[i].valid) begin
		  $display("inst:%h",id_ex_packet_in[i].inst);
		  $display("PRF_idx:%d",id_ex_packet_in[i].dest_PRF_idx);
		  $display("result:%h",ex_packet_out[i].alu_result);

		end
end
end



	 //
	 // instantiate the branch condition tester
	 //
	

	 

endmodule // module ex_stage
`endif // __EX_STAGE_V__
