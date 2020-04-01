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
module alu(
	input 		clock,
	input		reset,

	input 		en,
	
	input [`XLEN-1:0] opa,
	input [`XLEN-1:0] opb,
	ALU_FUNC     func,

	output logic        		occupied,
	output logic [`XLEN-1:0] 	result
);

	logic					is_mult_next;
	logic					start;
	logic       			mult_done;
	logic					is_mult;
	logic					range; // 1 if [63:32]
	logic					range_next;
	logic [(2*`XLEN)-1:0] 	product;

	logic [1:0] sign;

	
	wire signed [`XLEN-1:0]   signed_opa, signed_opb;
	wire signed [2*`XLEN-1:0] signed_mul, mixed_mul;
	wire        [2*`XLEN-1:0] unsigned_mul;
	assign signed_opa = opa;
	assign signed_opb = opb;
//	assign signed_mul = signed_opa * signed_opb;
//	assign unsigned_mul = opa * opb;
//	assign mixed_mul = signed_opa * opb;

	always_ff @(posedge clock) begin
		is_mult <= is_mult_next;
		range 	<= range_next;
	end

//	assign occupied = en? is_mult & ~mult_done : occupied_before;
	assign occupied = is_mult & ~mult_done;

	mult mult0(
		.clock(clock),
		.reset(reset),
		.start(start),
		.sign(sign),

		.mcand(opa),
		.mplier(opb),
		.product(product),
		.done(mult_done)
	);

	always_comb begin
	$display("occupied: %b",occupied);
		start = 0;
		is_mult_next = is_mult;
		range_next	 = range;
		sign = 0;
		if(en) begin
			is_mult_next = 0;
			case (func)
			ALU_ADD:      result = opa + opb;
			ALU_SUB:      result = opa - opb;
			ALU_AND:      result = opa & opb;
			ALU_SLT:      result = signed_opa < signed_opb;
			ALU_SLTU:     result = opa < opb;
			ALU_OR:       result = opa | opb;
			ALU_XOR:      result = opa ^ opb;
			ALU_SRL:      result = opa >> opb[4:0];
			ALU_SLL:      result = opa << opb[4:0];
			ALU_SRA:      result = signed_opa >>> opb[4:0]; // arithmetic from logical shift
			ALU_MUL:      begin
				start = 1'b1;
				sign = 2'b11;
				result = product[`XLEN-1:0];
				range_next = 0;
				is_mult_next = 1;
			end
			ALU_MULH:     begin
				start = 1;
				sign = 2'b11;
				result = product[2*`XLEN-1:`XLEN];
				range_next = 1;
				is_mult_next = 1;
			end
			ALU_MULHSU:   begin
				start = 1'b1;
				sign = 2'b01;
				result = product[2*`XLEN-1:`XLEN];
				range_next = 1;
				is_mult_next = 1;
			end
			ALU_MULHU:    begin
				start = 1'b1;
				sign = 2'b00;
				result = product[2*`XLEN-1:`XLEN];
				range_next = 1;
				is_mult_next = 1;
			end
			default:      result = `XLEN'hfacebeec;  // here to prevent latches
			endcase
//			$display("opa: %h opb: %h res: %h",opa, opb ,result);
		end  else if (is_mult) begin
			if(range) 	result = product[2*`XLEN-1:`XLEN]; else
						result = product[`XLEN-1:0];
		end
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
	//

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
			assign ex_packet_out[i].valid 			= id_ex_packet_in[i].valid;
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
		$display("occupied_hub: %b",occupied_hub);
		for( int i = 0; i < `WAYS; ++i) begin
		if(id_ex_packet_in[i].inst == `XLEN'hfc0312e3) begin
		$display("-------------------");
//		$display("at bne: take_branch: %b cond_branch: %b brcond_result:%b rs1_value: %h rs2_value: %h",ex_packet_out[i].take_branch,id_ex_packet_in[i].cond_branch,brcond_result[i],id_ex_packet_in[i].rs1_value,id_ex_packet_in[i].rs2_value);
	end
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
				.en(id_ex_packet_in[i].valid),

				.opa(opa_mux_out[i]),
				.opb(opb_mux_out[i]),
				.func(id_ex_packet_in[i].alu_func),

		// Output
				.occupied(occupied_hub[i]),
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






	 //
	 // instantiate the branch condition tester
	 //
	

	 

endmodule // module ex_stage
`endif // __EX_STAGE_V__
