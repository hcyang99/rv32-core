`include "sys_defs.svh"
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
    logic [$clog2(`PRF)-1:0]                    dest_PRF_idx_in;
    logic [$clog2(`ROB)-1:0]                    rob_idx_in;

    //logic                                       load_in;
    logic [`OLEN-1:0]                           offset_in;
    logic [`PCLEN-1:0]                          PC_in;
    ALU_FUNC                                    Operation_in;


    // outputs from one rs entry
    logic                                       ready;
    logic [`XLEN-1:0]                           opa_out;
    logic [`XLEN-1:0]                           opb_out;
    logic [$clog2(`PRF)-1:0]                    dest_PRF_idx_out;
    logic [$clog2(`ROB)-1:0]                    rob_idx_out;
    logic                                       is_free;

    logic [`PCLEN-1:0]                          PC_out;
    ALU_FUNC                                    Operation_out;
    logic [`OLEN-1:0]                           offset_out;
    logic                                       rd_mem_out;                          
    logic                                       wr_mem_out;                           


    // variables to track program state
    // these are the wires to modify throughout the testbench
    // ones that are commented out were declared elsewhere
    //logic                                       clock;
    //logic                                       reset;
    logic [`XLEN-1:0]                           PC;
    logic                                       inst;
    logic [`XLEN-1:0]                           rs1_value;
    logic [`XLEN-1:0]                           rs2_value;
    logic [$clog2(`PRF)-1:0]                    rs1_prn;
    logic [$clog2(`PRF)-1:0]                    rs2_prn;
    //logic  [$clog2(`ROB)-1:0]                   rob_idx;
    //logic                                       load_in;
    //logic                                       CDB_valid;
    //logic                                       opa_valid;
    //logic                                       opb_valid;
    logic                                       test_start;
    logic [3:0]                                 j;
    logic [3:0]                                 k;
    logic [`XLEN-1:0]                           opa_out_correct;
    logic [`XLEN-1:0]                           opb_out_correct;
    logic                                       teststart;
    logic                                       correct;



/* 
 *                          END OF WIRE DECLARATION
 *
 * ============================================================================
 */








/* ============================================================================
 *
 *                             COMBINATIONAL LOGIC
 * 
 */

    always_comb begin           // Logic to determine if output is correct. If correct == 0, module is wrong!
        correct = 1'b1;
        if(ready) begin
            if(is_free) correct = 1'b0;
            else if(dest_PRF_idx_out == dest_PRF_idx_in && rob_idx_out == rob_idx_in &&
                    PC_out == PC_in && Operation_out == Operation_in &&
                    offset_out == offset_in && rd_mem_out == rd_mem_in && wr_mem_out == wr_mem_in) begin
                if(opa_valid && opa_out != opa_in || !opa_valid && opa_out != CDB_Data[j]) correct = 1'b0;
                if(opb_valid && opb_out != opb_in || !opb_valid && opb_out != CDB_Data[k]) correct = 1'b0;
            end else correct = 1'b0;    // If here, then one of the pass-throughs was changed
        end else correct = 1'b0;
    end

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

    RS_Line rs_entry(
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
 *                            END OF MODULE INSTANCES
 *
 * ============================================================================
 */




/* ============================================================================
 *
 *                               TESTBENCH TASKS
 * 
 */

logic [3:0] wait_1;
logic [3:0] wait_2;
    task new_test;
        @(negedge clock);
        assign reset = 1'b1;
        @(negedge clock);
        assign reset = 1'b0;
        @(negedge clock);
        assign teststart = 1'b1;
        @(negedge clock);
        assign teststart = 1'b0;
            assign wait_1 = $random % 10;
            assign wait_2 = $random % 10;
            repeat (wait_1) @(negedge clock);
            CDB_valid[j] = 1'b1;
            $display("CDB_valid[%d] %h", j, CDB_valid[j]);
            $display("CDB_PRF_idx[%d] %h", j, CDB_PRF_idx[j]);
            @(negedge clock);
            CDB_valid[j] = 1'b0;
            repeat (wait_2) @(negedge clock);
            CDB_valid[k] = 1'b1;
            $display("CDB_valid[%d] %h", k, CDB_valid[k]);
            $display("CDB_PRF_idx[%d] %h", k, CDB_PRF_idx[k]);
            @(negedge clock);
            CDB_valid[k] = 1'b0;
            @(negedge clock);
            check_correct;
    endtask

    task check_correct;
        #2
        if(!correct) begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Failed");
            $finish;
        end
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


    always_ff @(negedge clock) begin
        PC <= `SD  PC + `WAYS * 4;
    end

    always_ff @(posedge teststart) begin

        inst = $random;
        rs1_value = $random;
        rs2_value = $random;
        rs1_prn = $random;
        rs2_prn = $random;

        if(opa_valid) begin
            opa_in = {$random, $random};
        end else begin
            opa_in = {$clog2(`PRF){1'b1}} & $random;
        end
        $display("opa_in: %h", opa_in);

        if(opb_valid) begin
            opb_in = {$random, $random};
        end else begin
            opb_in = {$clog2(`PRF){1'b1}} & $random;
        end
        $display("opb_in: %h", opb_in);


        assign j = (($random & 4'hf) % `WAYS);
        $display("j: %h", j);
        assign k = ((j + 1) % `WAYS);
        $display("k: %h", k);

        
        for(int i = 0; i < `WAYS; i = i + 1)
        begin: foo
            CDB_Data[i] = {$random, $random};
            CDB_PRF_idx[i] = ~opa_valid && (i == j) ? opa_in :
                             ~opb_valid && (i == k) ? opb_in : $random;
            $display("CDB_Data[%d]: %h", i, CDB_Data[i]);
            $display("CDB_PRF_idx[%d]: %h", i, CDB_PRF_idx[i]);
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
            opa_out_correct = CDB_Data[j];
        end

        if(opb_valid) begin
            opb_out_correct = opb_in;
        end else begin
            opb_out_correct = CDB_Data[k];
        end


    end

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
        //$random(10);

/* ========================= TESTS FOR ONE RS ENTRY ========================= */

        $display("start");
        $display("Time|reset|load_in|opa_in|opa_valid|opb_in|opb_valid|is_free|ready");
        $monitor("%4.0f  %b    %b     %h   %h   %h %h     %h     %h", $time, reset, teststart, opa_in,opa_valid,opb_in,opb_valid,is_free,ready);

/* ------------------------- both operands are ready ------------------------- */
        opa_valid = 1'b1;
        opb_valid = 1'b1;

        clock = 1'b1;
        test_start = 1'b0;
        @(negedge clock);

        repeat (99) new_test();

/* ------------------------- only one operand is ready ------------------------- */
        opa_valid = 1'b0;

        @(negedge clock);

        repeat (45) new_test();

        opa_valid = 1'b1;
        opb_valid = 1'b0;

        @(negedge clock);

        repeat (45) new_test();

/* ------------------------- neither operand is ready ------------------------- */
        opa_valid = 1'b0;

        repeat (99) new_test();



        $display("@@@ Passed");
        $finish;

    end




/* 
 *                             END OF TESTBENCH DRIVER
 *
 * ============================================================================
 */


endmodule

