`timescale 1ns/100ps

`define XLEN        64
`define PRF         64
`define ROB         16
`define RS          16

`define OLEN        16
`define PCLEN       32
`define WAYS        3



module testbench;


/* ============================================================================
 *
 *                               WIRE DECLARATIONS
 * 
 */

/*
    // inputs to the rs module
    logic                                       clock;
    logic                                       reset;

    logic [`WAYS-1:0] [`XLEN-1:0]               CDB_Data;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx;
    logic [`WAYS-1:0]                           CDB_valid;

    logic [`WAYS-1:0] [`XLEN-1:0]               opa_in; // data or PRN
    logic [`WAYS-1:0] [`XLEN-1:0]               opb_in; // data or PRN
    logic [`WAYS-1:0]                           opa_valid; // indicate whether it is data or PRN, 1: data 0: PRN
    logic [`WAYS-1:0]                           opb_valid;
    logic [`WAYS-1:0]                           rd_mem_in;                          
    logic [`WAYS-1:0]                           wr_mem_in;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        dest_PRF_idx;
    logic [`WAYS-1:0] [$clog2(`ROB):0]          rob_idx;                             

    logic [`WAYS-1:0]                           load_in;
    logic [`WAYS-1:0] [`OLEN-1:0]               offset_in;
    logic [`WAYS-1:0] [`PCLEN-1:0]              PC_in;
    ALU_FUNC [`WAYS-1:0]                        Operation_in;


    // outputs from the rs module
    logic [`WAYS-1:0]                           inst_out_valid; // tell which inst is valid, 100 when only one inst is valid 
    logic [`WAYS-1:0] [`XLEN-1:0]               opa_out;
    logic [`WAYS-1:0] [`XLEN-1:0]               opb_out;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        dest_PRF_idx;
    logic [`WAYS-1:0] [$clog2(`ROB)-1:0]        rob_idx;

    logic [`WAYS-1:0] [`PCLEN-1:0]              PC_out;
    logic [`WAYS-1:0] ALU_FUNC                  Operation_out;
    logic [`WAYS-1:0] [`OLEN-1:0]               offset_out;
    logic [`RS_LOG2-1:0]                        num_is_free;
   
    logic [`WAYS-1:0]                           rd_mem_out;                          
    logic [`WAYS-1:0]                           wr_mem_out;                           
*/

    // inputs for one rs entry
    logic                                       clock;
    logic                                       reset;

    logic [`WAYS-1:0] [`XLEN-1:0]               CDB_Data;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx;
    logic [`WAYS-1:0]                           CDB_valid;

    logic [`XLEN-1:0]                           opa_in; // data or PRN
    logic [`XLEN-1:0]                           opb_in; // data or PRN
    logic                                       opa_valid; // indicate whether it is data or PRN, 1: data 0: PRN
    logic                                       opb_valid;
    logic                                       rd_mem_in;                          
    logic                                       wr_mem_in;
    logic [$clog2(`PRF)-1:0]                    dest_PRF_idx;
    logic [$clog2(`ROB):0]                      rob_idx;                             

    logic                                       load_in;
    logic [`OLEN-1:0]                           offset_in;
    logic [`PCLEN-1:0]                          PC_in;
    ALU_FUNC                                    Operation_in;


    // outputs from one rs entry
    logic                                       ready;
    logic [`REG_LEN-1:0]                        opa_out;
    logic [`REG_LEN-1:0]                        opb_out;
    logic [$clog2(`PRF)-1:0]                    dest_PRF_idx;
    logic [$clog2(`ROB)-1:0]                    rob_idx;
    logic                                       is_free;

    logic [`PCLEN-1:0]                          PC_out;
    logic ALU_FUNC                              Operation_out;
    logic [`OLEN-1:0]                           offset_out;
    logic                                       rd_mem_out;                          
    logic                                       wr_mem_out;                           

/*
    // inputs for the decode
    IF_ID_PACKET [`WAYS-1:0]                    if_packet;

    // outputs from the decode
    ALU_OPA_SELECT [`WAYS-1:0]                  opa_select;
    ALU_OPB_SELECT [`WAYS-1:0]                  opb_select;
    //ALU_FUNC [`WAYS-1:0]                        alu_func;
    //logic [`WAYS-1:0]                           dest_reg;
    //logic [`WAYS-1:0]                           rd_mem;
    //logic [`WAYS-1:0]                           wr_mem;
    logic [`WAYS-1:0]                           cond_branch; // TODO: maybe (maybe ?? ) pipe this into rs
    logic [`WAYS-1:0]                           uncond_branch;
    logic [`WAYS-1:0]                           csr_op;
    logic [`WAYS-1:0]                           halt;
    logic [`WAYS-1:0]                           illegal;
    logic [`WAYS-1:0]                           valid_inst;
 */   


    // variables to track program state
    // these are the wires to modify throughout the testbench
    // ones that are commented out were declared elsewhere
    //logic                                       clock;
    //logic                                       reset;
    logic [`XLEN-1:0]                           PC;
    logic                                       inst;
    logic [`XLEN-1:0]                           rs1_value;
    logic [`XLEN-1:0]                           rs2_value
    logic [$clog2(`PRF)-1:0]                    rs1_prn;
    logic [$clog2(`PRF)-1:0]                    rs2_prn;
    //logic  [$clog2(`ROB)-1:0]                   rob_idx;
    //logic                                       load_in;
    //logic                                       CDB_valid;
    //logic                                       opa_valid;
    //logic                                       opb_valid;
    logic                                       test_start;
    logic                                       j_out;
    logic                                       k_out;
    


/* 
 *                          END OF WIRE DECLARATION
 *
 * ============================================================================
 */








/* ============================================================================
 *
 *                             COMBINATION LOGIC
 * 
 */

/*
    // if_packet assignment
    generate
        for(genvar i = 0; i < WAYS; i = i + 1)
        begin: foo
            assign if_packet[i].inst = inst[i];
            assign if_packet[i].PC = PC + i * 4;
            assign if_packet[i].NPC = PC + i * 4 + 4;
            assign if_packet[i].valid = 1'b1; // TODO: have the driver drive this instead (maybe?)
        end
    endgenerate

    generate
        for(genvar i = 0; i < WAYS; i = i + 1)
        begin: foo
            assign PC_in[i] = PC + i * 4;
        end
    endgenerate



	//
	// opA mux
	//
    generate
        for(genvar i = 0; i < WAYS; i = i + 1)
        begin : foo
            always_comb begin
                if(opa_valid[i]) begin
                    case (opa_select[i])
                        OPA_IS_RS1:  opa_in[i] = rs1_value[i];
                        OPA_IS_NPC:  opa_in[i] = PC + i * 4 + 4;
                        OPA_IS_PC:   opa_in[i] = PC + i * 4;
                        OPA_IS_ZERO: opa_in[i] = 0;
                    endcase
                end else begin
                    opa_in[i] = rs1_prn[i];
                end
            end
        end
    endgenerate

	//
	// opB mux
	//
    generate
        for(genvar i = 0; i < WAYS; i = i + 1)
        begin : foo
            always_comb begin
                offset_in[i] = `OLEN'h0;
                if(opb_valid[i]) begin
                    case (opb_select[i])
                        OPB_IS_RS2:   opb_in[i] = rs2_value;
                        OPB_IS_I_IMM: offset_in[i] = `RV32_signext_Iimm(inst);
                        OPB_IS_S_IMM: offset_in[i] = `RV32_signext_Simm(inst);
                        OPB_IS_B_IMM: offset_in[i] = `RV32_signext_Bimm(inst);
                        OPB_IS_U_IMM: offset_in[i] = `RV32_signext_Uimm(inst);
                        OPB_IS_J_IMM: offset_in[i] = `RV32_signext_Jimm(inst);
                    endcase 
                end else begin
                    opb_in[i] = rs2_prn[i];
                end
            end
        end
    endgenerate
*/

/* 
 *                            END OF COMBINATIONAL LOGIC
 *
 * ============================================================================
 */





/* ============================================================================
 *
 *                               MODULE INSTANCES
 * 
 */

    RS_line rs_entry(
        clock,
        reset,

        CDB_Data,
        CDB_PRF_idx,
        CDB_valid,

        opa_in,
        opb_in,
        opa_valid_in,
        opb_valid_in,
        rd_mem_in,
        wr_mem_in,
        dest_PRF_idx_in,
        rob_idx_in,

        teststart, // high when dispatch
        offset_in,
        PC_in,
        Operation_in,


        ready,
        opa_out,
        opb_out,
        dest_PRF_idx_out,
        rob_idx_out,
        is_free,

        PC_out,
        Operation_out,
        offset_out,
        rd_mem_out,                        
        wr_mem_out                         
    );

/*
    // TODO: fully implement superscalar decode
    decoder [`WAYS-1:0] d_stage(
        if_packet,
        opa_select,
        opb_select,
        dest_PRF_idx, // TODO: pipe this into a PRN designator
        Operation_in,
        rd_mem_in,
        wr_mem_in,
        cond_branch,
        uncond_branch,
        csr_op,
        halt,
        illegal,
        valid_inst
    );
*/

/*
    rs main(
        // inputs
        clock,
        reset,

        CDB_Data,
        CDB_PRF_idx,
        CDB_valid,

        opa_in,
        opb_in,
        opa_valid,
        opb_valid,
        rd_mem_in,
        wr_mem_in,
        dest_PRF_idx,
        rob_idx,

        load_in,
        offset_in,
        PC_in,
        Operation_in,

        // outputs
        inst_out_valid,
        opa_out,
        opb_out,
        dest_PRF_idx,
        rob_idx,

        PC_out,
        Operation_out,
        offset_out,
        num_is_free,

        rd_mem_out,
        wr_mem_out
    );
*/


/* 
 *                            END OF MODULE INSTANCES
 *
 * ============================================================================
 */




/* ============================================================================
 *
 *                               TESTBENCH TASKS
 * 
 */

    task new_test;
        @negedge(clock);
        teststart = 1'b1;
        @negedge(clock);
        teststart = 1'b0;
        generate
            genvar wait_1 = $random % 10;
            genvar wait_2 = $random % 10;
            repeat (wait_1) @negedge(clock);
            CDB_valid[j_out] = 1'b1;
            @negedge(clock);
            CDB_valid[j_out] = 1'b0;
            repeat (wait_2) @negedge(clock);
            CDB_valid[k_out] = 1'b1;
            @negedge(clock);
            CDB_valid[k_out] = 1'b0;
   
        endgenerate
    endtask


/* 
 *                            END OF TESTBENCH TASKS
 *
 * ============================================================================
 */






/* ============================================================================
 *
 *                               SEQUENTIAL LOGIC
 * 
 */

    always @(negedge clock) begin
        PC <= `SD  PC + WAYS * 4;
    end

    always @(posedge test_start) begin
        // inputs
/*        input opa_valid;
        input opb_valid;
        input clock;

        // outputs
        output [`WAYS-1:0] [`REG_LEN-1:0] CDB_DATA;
        output [`WAYS-1:0] [$clog2(`PRF)-1:0] CDB_PRF_idx;

        output [`REG_LEN-1:0] opa_in;
        output [`REG_LEN-1:0] opb_in;
        output rd_mem_in;
        output wr_mem_in;
        output [$clog2(`PRF)-1:0] dest_PRF_idx_in;
        output [$clog2(`ROB)-1:0] rob_idx_in;

        output [`OLEN-1:0] offset_in;
        output [`PCLEN-1:0] PC_in;
        output ALU_FUNC Operation_in;

        output j_out;
        output k_out;
*/
        inst = $random;
        rs1_value = $random;
        rs2_value = $random;
        rs1_prn = $random;
        rs2_prn = $random;
        generate
            genvar j = $random % `WAYS;
            genvar k = j + 1 % `WAYS; // we guarantee that `WAYS will be > 1
            j_out = j;
            k_out = k;

            if(`WAYS == 1) begin
            end else begin
                for(genvar i = 0; i < `WAYS; i = i + 1)
                begin: foo
                    CDB_Data[i] = {$random, $random};
                    CDB_PRF_idx[i] = ~opa_valid && i == j ? opa_in :
                                     ~opb_valid && i == k ? opb_in : $random;
                end
            end
        endgenerate

        if(opa_valid) begin
            opa_in = {$random, $random};
        end else begin
            opa_in = {$clog2(`PRF){1'b1}} & $random;
        end

        if(opb_valid) begin
            opb_in = {$random, $random};
        end else begin
            opb_in = {$clog2(`PRF){1'b1}} & $random;
        end

        rd_mem_in = $random;
        wr_mem_in = $random;
        dest_PRF_idx_in = $random;
        rob_idx_in = $random;
        
        offset_in = $random;
        PC_in = $random;
        Operation_in = $random;

        if(opa_valid) begin
            opa_out_correct = opa_in;
        end else begin
            opa_out_correct = CDB_Data[j_out];
        end

        if(opb_valid) begin
            opb_out_correct = opb_in;
        end else begin
            opb_out_correct = CDB_Data[k_out];
        end


    end
/*
    always @(negedge clock) begin
        generate
            begin : foo
                genvar j = $random;
                if(j % 2) begin
                    genvar k = $random % `WAYS;
                    CDB_PRF_idx[k] = rs1_prn;
                end else begin
                    genvar k = $random % `WAYS;
                    CDB_PRF_idx[i] = rs2_prn;
                end
        endgenerate
    end
*/


/* 
 *                            END OF SEQUENTIAL LOGIC
 *
 * ============================================================================
 */





/* ============================================================================
 *
 *                               TESTBENCH DRIVER
 * 
 */


	
	// Generate System Clock
    // YANKED from the p3 testbench
	always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
	

    initial begin
        $random(10)

/* ========================= TESTS FOR ONE RS ENTRY ========================= */


/* ------------------------- both operands are ready ------------------------- */
        opa_valid = 1'b1;
        opb_valid = 1'b1;

        clock = 1'b1;
        reset = 1'b1;
        test_start = 1'b0;
        @negedge(clock);
        @negedge(clock);
        reset = 1'b0;
        @negedge(clock);

        repeat (99) new_test();

/* ------------------------- only one operand is ready ------------------------- */
        opa_valid = 1'b0;

        @negedge(clock);

        repeat (45) new_test();

        opa_valid = 1'b1;
        opb_valid = 1'b0;

        @negedge(clock);

        repeat (45) new_test();

/* ------------------------- neither operand is ready ------------------------- */
        opb_valid = 1'b1;

        repeat (99) new_test();



/* ========================= TEST FOR THE WHOLE RS ========================= */
/*
        reset = 1'b1;
        clock = 1'b0;

        @negedge(clock);
        @negedge(clock);

        reset = 1'b0;
        PC = `XLEN'h0;


/* ------------------------- both operands are ready ------------------------- */
/*
        opa_valid = 1'b1;
        opb_valid = 1'b1;

        


        // test case where CDB broadcast on the same cycle as dispatch
        CDB_valid[0] = 1'b1;
        CDB_Data[0] = `XLEN'h0;
        CDB_PRF_idx[0] = $clog2(`PRF)'h0;

/* ------------------------- only one operand is ready ------------------------- */
/*
        opa_valid = 1'b0;



        @negedge(clock);
        opa_valid = 1'b1;
        opb_valid = 1'b0;

        @negedge(clock);

/* ------------------------- neither operand is ready ------------------------- */
//        opa_valid = 1'b0;




    end




/* 
 *                             END OF TESTBENCH DRIVER
 *
 * ============================================================================
 */


endmodule

