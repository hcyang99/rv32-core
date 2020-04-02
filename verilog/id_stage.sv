/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  id_stage.v                                          //
//                                                                     //
//  Description :  instruction decode (ID) stage of the pipeline;      // 
//                 decode the instruction fetch register operands, and // 
//                 compute immediate operand (if applicable)           // 
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`timescale 1ns/100ps


  // Decode an instruction: given instruction bits IR produce the
  // appropriate datapath control signals.
  //
  // This is a *combinational* module (basically a PLA).
  //
module decoder(

	//input [31:0] inst,
	//input valid_inst_in,  // ignore inst when low, outputs will
	                      // reflect noop (except valid_inst)
	//see sys_defs.svh for definition
	input IF_ID_PACKET if_packet,
	
	output ALU_OPA_SELECT opa_select,
	output ALU_OPB_SELECT opb_select,
	output DEST_REG_SEL   dest_reg, // mux selects
	output ALU_FUNC       alu_func,
	output logic rd_mem, wr_mem, cond_branch, uncond_branch,
	output logic csr_op,    // used for CSR operations, we only used this as 
	                        //a cheap way to get the return code out
	output logic halt,      // non-zero on a halt
	output logic illegal,    // non-zero on an illegal instruction
	output logic valid_inst  // for counting valid instructions executed
	                        // and for making the fetch stage die on halts/
	                        // keeping track of when to allow the next
	                        // instruction out of fetch
	                        // 0 for HALT and illegal instructions (die on halt)

);

	INST inst;
	logic valid_inst_in;
	
	assign inst          = if_packet.inst;
	assign valid_inst_in = if_packet.valid;
	assign valid_inst    = valid_inst_in & ~illegal;
	
	always_comb begin
		// default control values:
		// - valid instructions must override these defaults as necessary.
		//	 opa_select, opb_select, and alu_func should be set explicitly.
		// - invalid instructions should clear valid_inst.
		// - These defaults are equivalent to a noop
		// * see sys_defs.vh for the constants used here
//		$display("inst: %h valid_inst_in: %b",inst,valid_inst_in);
		opa_select = OPA_IS_RS1;
		opb_select = OPB_IS_RS2;
		alu_func = ALU_ADD;
		dest_reg = DEST_NONE;
		csr_op = `FALSE;
		rd_mem = `FALSE;
		wr_mem = `FALSE;
		cond_branch = `FALSE;
		uncond_branch = `FALSE;
		halt = `FALSE;
		illegal = `FALSE;
		if(valid_inst_in) begin
			casez (inst) 
				`RV32_LUI: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_ZERO;
					opb_select = OPB_IS_U_IMM;
				end
				`RV32_AUIPC: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_PC;
					opb_select = OPB_IS_U_IMM;
				end
				`RV32_JAL: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_PC;
					opb_select    = OPB_IS_J_IMM;
					uncond_branch = `TRUE;
				end
				`RV32_JALR: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_RS1;
					opb_select    = OPB_IS_I_IMM;
					uncond_branch = `TRUE;
				end
				`RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
				`RV32_BLTU, `RV32_BGEU: begin
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
					cond_branch = `TRUE;
				end
				`RV32_LB, `RV32_LH, `RV32_LW,
				`RV32_LBU, `RV32_LHU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					rd_mem     = `TRUE;
				end
				`RV32_SB, `RV32_SH, `RV32_SW: begin
					opb_select = OPB_IS_S_IMM;
					wr_mem     = `TRUE;
				end
				`RV32_ADDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_SLTI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLT;
				end
				`RV32_SLTIU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLTU;
				end
				`RV32_ANDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_AND;
				end
				`RV32_ORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_OR;
				end
				`RV32_XORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_XOR;
				end
				`RV32_SLLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLL;
				end
				`RV32_SRLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRL;
				end
				`RV32_SRAI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRA;
				end
				`RV32_ADD: begin
					dest_reg   = DEST_RD;
				end
				`RV32_SUB: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SUB;
				end
				`RV32_SLT: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLT;
				end
				`RV32_SLTU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLTU;
				end
				`RV32_AND: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_AND;
				end
				`RV32_OR: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_OR;
				end
				`RV32_XOR: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_XOR;
				end
				`RV32_SLL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLL;
				end
				`RV32_SRL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SRL;
				end
				`RV32_SRA: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SRA;
				end
				`RV32_MUL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MUL;
				end
				`RV32_MULH: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULH;
				end
				`RV32_MULHSU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULHSU;
				end
				`RV32_MULHU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULHU;
				end
				`RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
					csr_op = `TRUE;
				end
				`WFI: begin
					halt = `TRUE;
				end
				default: illegal = `TRUE;

		endcase // casez (inst)
		end // if(valid_inst_in)
	end // always
endmodule // decoder


module id_stage(         
	input         clock,              // system clock
	input         reset,              // system reset

  input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_CDB,     // From CDB, these are now valid
  input [`WAYS-1:0]                           wr_en_CDB,
	input [`WAYS-1:0] [`XLEN-1:0]               wr_dat_CDB,

	input [`WAYS-1:0] [4:0]                     RRAT_ARF_idx,   // ARF # to be renamed, from ROB
	input [`WAYS-1:0]							RRAT_idx_valid,
	input [`WAYS-1:0] [$clog2(`PRF)-1:0]		RRAT_PRF_idx,
	input										except,

	input  IF_ID_PACKET [`WAYS-1:0] 			if_id_packet_in,
	input [`WAYS-1:0] 							predictions,


	output ID_EX_PACKET [`WAYS-1:0] 			id_packet_out,
	output logic [`WAYS-1:0]					opa_valid,
	output logic [`WAYS-1:0]					opb_valid,
	output logic [`WAYS-1:0]  					dest_arn_valid

);

		logic [`WAYS-1:0] [$clog2(`PRF)-1:0] 	dest_PRF;
		logic [`WAYS-1:0]						dest_PRF_valid;

		logic [`WAYS-1:0][4:0]					opa_arn;
		logic [`WAYS-1:0][4:0]					opb_arn;
		logic [`WAYS-1:0][4:0]  				dest_arn;

		logic [`WAYS-1:0][$clog2(`PRF)-1:0] 	opa_prn;
		logic [`WAYS-1:0][$clog2(`PRF)-1:0] 	opb_prn;
		logic [`WAYS-1:0][`XLEN-1:0]			opa_value;
		logic [`WAYS-1:0][`XLEN-1:0]			opb_value;
		logic [`WAYS-1:0]     					opa_valid_tmp;
		logic [`WAYS-1:0]								opb_valid_tmp;
		logic [`WAYS-1:0]				inst_valid_tmp;
		logic 									find_taken;



		DEST_REG_SEL [`WAYS-1:0] dest_reg_select; 
	
		assign find_taken = (predictions != {`WAYS{1'b0}});

    generate
        for(genvar i = 0; i < `WAYS; i = i + 1) begin
    			assign id_packet_out[i].inst = if_id_packet_in[i].inst;
   	 			assign id_packet_out[i].NPC  = if_id_packet_in[i].NPC;
    			assign id_packet_out[i].PC   = if_id_packet_in[i].PC;
					assign dest_arn[i] 			 = if_id_packet_in[i].inst.r.rd;
					assign opa_arn[i]			 = if_id_packet_in[i].inst.r.rs1;
					assign opb_arn[i]			 = if_id_packet_in[i].inst.r.rs2;
					assign dest_arn_valid[i]	 = (dest_reg_select[i] == DEST_RD);
		end
	endgenerate

	
		

	// instantiate the instruction decoder
	    generate
        for(genvar i = 0; i < `WAYS; i = i + 1) begin
					decoder decoder_0 (
						.if_packet(if_id_packet_in[i]),	 
							// Outputs
						.opa_select(id_packet_out[i].opa_select),
						.opb_select(id_packet_out[i].opb_select),
						.alu_func(id_packet_out[i].alu_func),
						.dest_reg(dest_reg_select[i]),
						.rd_mem(id_packet_out[i].rd_mem),
						.wr_mem(id_packet_out[i].wr_mem),
						.cond_branch(id_packet_out[i].cond_branch),
						.uncond_branch(id_packet_out[i].uncond_branch),
						.csr_op(id_packet_out[i].csr_op),
						.halt(id_packet_out[i].halt),
						.illegal(id_packet_out[i].illegal),
						.valid_inst(inst_valid_tmp[i])
					);
				end
			endgenerate

	PRF prf(
	.clock(clock),
	.reset(reset),
	.rda_idx(opa_prn),
	.rdb_idx(opb_prn),
    
	.wr_idx(reg_idx_wr_CDB),
	.wr_dat(wr_dat_CDB),
	.wr_en(wr_en_CDB),
	.rda_dat(opa_value),
	.rdb_dat(opb_value)
	);

	RAT_RRAT rat(
    .clock(clock),
    .reset(reset),
    .except(except),

    .rda_idx(opa_arn),            // rename query 1
    .rdb_idx(opb_arn),            // rename query 2
    .RAT_dest_idx(dest_arn),       // ARF # to be renamed
    .RAT_idx_valid(dest_arn_valid),      // how many ARF # to rename?

    .reg_idx_wr_CDB(reg_idx_wr_CDB),     // From CDB, these are now valid
    .wr_en_CDB(wr_en_CDB),

    .RRAT_ARF_idx(RRAT_ARF_idx),       // ARF # to be renamed, from ROB
    .RRAT_idx_valid(RRAT_idx_valid), 
    .RRAT_PRF_idx(RRAT_PRF_idx),       // PRF # 

    .rename_result(dest_PRF),      // New PRF # renamed to
    .rename_result_valid(dest_PRF_valid), //***** SHOULD BE ALL 1s for M2

    .rda_idx_out(opa_prn),        // PRF # 
    .rdb_idx_out(opb_prn),        // PRF #
    .rda_valid(opa_valid_tmp),
    .rdb_valid(opb_valid_tmp)
);

	always_comb begin
//	$display("if_id_packet_in[0].inst: %h",if_id_packet_in[0].inst);
//	$display("find_taken: %b inst_valid_tmp: %b",find_taken,inst_valid_tmp);
		if(!find_taken) begin
			for(int i = 0; i < `WAYS ; i = i + 1) id_packet_out[i].valid =  inst_valid_tmp[i];
		end else begin
			for(int i = 0; i < `WAYS ; i = i + 1) id_packet_out[i].valid = 0;
			for(int i = 0; i < `WAYS ; i = i + 1) begin
				if(predictions[i] == 0) begin
					id_packet_out[i].valid = inst_valid_tmp[i];
				end else break;
			end
		end
	end

	// mux to generate dest_reg_idx based on
	// the dest_reg_select output from decoder
	always_comb begin
		for(int i = 0; i < `WAYS ; i = i + 1) begin
			case (dest_reg_select[i])
				DEST_RD:    id_packet_out[i].dest_PRF_idx = dest_PRF[i];
				DEST_NONE:  id_packet_out[i].dest_PRF_idx = `ZERO_REG;
				default:    id_packet_out[i].dest_PRF_idx = `ZERO_REG; 
			endcase		
		end
	end

	always_comb begin
		for(int i = 0; i < `WAYS; i = i + 1) begin
		// to be update later with LSQ
			if(id_packet_out[i].opa_select == OPA_IS_RS1 | id_packet_out[i].cond_branch) begin
				opa_valid[i] = opa_valid_tmp[i];
				if(opa_valid[i]) begin
					id_packet_out[i].rs1_value = opa_value[i];
				end else begin
					id_packet_out[i].rs1_value = opa_prn[i];
				end
				for(int j = 0; j < `WAYS; 	j = j +1) begin
					if( j < i && dest_arn_valid[j] && dest_arn[j] == opa_arn[i]) begin
						opa_valid[i] = 0;
						id_packet_out[i].rs1_value = dest_PRF[j];
					end
				end
			end else opa_valid[i] = 1;
			if(id_packet_out[i].opb_select == OPB_IS_RS2 | id_packet_out[i].wr_mem | id_packet_out[i].cond_branch) begin
				opb_valid[i] = opb_valid_tmp[i];
				id_packet_out[i].rs2_value = opb_valid[i]? opb_value[i]:opb_prn[i];
				for(int j = 0; j < `WAYS; j = j +1) begin
					if( j < i && dest_arn_valid[j] && dest_arn[j] == opb_arn[i]) begin
						opb_valid[i] = 0;
						id_packet_out[i].rs2_value = dest_PRF[j];
					end
				end
			end else opb_valid[i] = 1;
		end
	end


always_ff @(posedge clock) begin
$display("except in id_stage: %b",except);
for(int i = 0; i < `WAYS ; i = i + 1) begin
		if(if_id_packet_in[i].inst == `XLEN'h00128293) begin
			$display("opa_value[i]: %h opb_value[i]: %h rs1_value: %h rs2_value: %h",opa_value[i],opb_value[i],id_packet_out[i].rs1_value,id_packet_out[i].rs2_value);
			$display("opa_valid: %b opa_valid_tmp: %b opa_arn: %h opb_arn: %h",opa_valid[i],opa_valid_tmp,opa_arn[i],opb_arn[i]);
			$display("opa_prn: %h opb_prn: %h dest_arn_valid: %b",opa_prn[i],opb_prn[i],dest_arn_valid);		
		end
		if(opa_prn == $log2(`PRF)'h2c)
end
end
   
endmodule // module id_stage
