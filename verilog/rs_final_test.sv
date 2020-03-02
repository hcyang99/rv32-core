`include "sys_defs.svh"
//`define XLEN     64
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
 // input
    logic                                       clock;
    logic                                       reset;
    logic [`WAYS-1:0] [`XLEN-1:0]               CDB_Data;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx;
    logic [`WAYS-1:0]                           CDB_valid;

    logic [`WAYS-1:0] [`XLEN-1:0]               opa_in; // data or PRN
    logic [`WAYS-1:0] [`XLEN-1:0]               opb_in; // data or PRN
    logic [`WAYS-1:0]                           opa_valid_in; // indicate whether it is data or PRN, 1: data 0: PRN
    logic [`WAYS-1:0]                           opb_valid_in;
    logic [`WAYS-1:0]                           rd_mem_in;                          
    logic [`WAYS-1:0]                           wr_mem_in;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        dest_PRF_idx_in;
    logic [`WAYS-1:0] [$clog2(`ROB)-1:0]        rob_idx_in; ;      
                           

    logic [`WAYS-1:0]                           load_in; // high when dispatch :: SHOULD HAVE BEEN MULTIPLE ENTRIES??
    logic [`WAYS-1:0] [`OLEN-1:0]               offset_in;
    logic [`WAYS-1:0] [`PCLEN-1:0]              PC_in;
    ALU_FUNC                                    Operation_in [`WAYS-1:0];

// output
    logic [`WAYS-1:0]                       inst_out_valid; // tell which inst is valid, **001** when only one inst is valid 
    logic [`WAYS-1:0] [`XLEN-1:0]           opa_out;
    logic [`WAYS-1:0] [`XLEN-1:0]           opb_out;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]    dest_PRF_idx_out;
    logic [`WAYS-1:0] [$clog2(`ROB)-1:0]    rob_idx_out;

    logic [`WAYS-1:0] [`PCLEN-1:0]          PC_out;
    ALU_FUNC                                Operation_out [`WAYS-1:0];
    logic [`WAYS-1:0] [`OLEN-1:0]           offset_out;
    logic [$clog2(`RS)-1:0]                 num_is_free;
    
    logic [`WAYS-1:0]                       rd_mem_out;                         
    logic [`WAYS-1:0]                       wr_mem_out;        


/* 
 *                          END OF WIRE DECLARATION
 *
 * ============================================================================
 */



    RS rs_dummy (
        // inputs
        .clock(clock),
        .reset(reset),
        .CDB_Data(),
        .CDB_PRF_idx(),
        .CDB_valid(),
        .opa_in(),
        .opb_in(),
        .opa_valid_in(),
        .opb_valid_in(),
        .rd_mem_in(),                          
        .wr_mem_in(),
        .dest_PRF_idx_in(),
        .rob_idx_in(),                             
        .load_in(),
        .offset_in(),
        .PC_in(),
        .Operation_in(),

        // output
        .inst_out_valid(), // tell which inst is valid, **001** when only one inst is valid 
        .opa_out(),
        .opb_out(),
        .dest_PRF_idx_out(),
        .rob_idx_out(),

        .PC_out(),
        .Operation_out(),
        .offset_out(),
        .num_is_free(),
    
        .rd_mem_out(),                          
        .wr_mem_out()    
    );

// Generate System Clock
    // YANKED from the p3 testbench
	always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end

initial 
    begin
    clock = 0;
    $display("start");
    $display("Time|reset|load_in|CDB_Data|CDB_PRF_idx|CDB_valid|opa_in|opa_valid_in|opb_in|opb_valid_in|inst_out_valid|opa_out[0]|opb_out[0]");
    $monitor("%4.0f  %b ", $time, reset,
            "    %b      %h", load_in[0], CDB_Data[0],
            "        %h         %h",CDB_PRF_idx[0],CDB_valid[0],
            "   %h     %h",opa_in[0],opa_valid_in[0],
            "     %h     %h",opb_in[0],opb_valid_in[0],
            "           %b    %h   %h",inst_out_valid,opa_out[0],opb_out[0]);
        @(negedge clock);
        reset = 1; 
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        CDB_valid = 3'b000;
        @(negedge clock);
        load_in = 3'b001;
        opa_in[0] = 32'h110;
        opa_valid_in = 3'b001;
        opb_in[0] = 32'h11;
        opb_valid_in[0] = 3'b000;
        @(negedge clock);
        load_in = 3'b0;
        @(negedge clock);
        CDB_valid = 3'b001;
        CDB_Data[0] = 64'habc;
        CDB_PRF_idx[0] = 64'h11;
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        $finish;
     end // initial

endmodule                