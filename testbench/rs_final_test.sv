`include "sys_defs.svh"
//`define XLEN        64
`define PRF         64
`define LOGPRF      6 //$clog2(`PRF)

`define ROB         16
`define RS          16
`define OLEN        16
`define PCLEN       32
`define WAYS        3
//`timescale 1ns/100ps


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
                           

    logic                                       load_in; // high when dispatch :: SHOULD HAVE BEEN MULTIPLE ENTRIES??
    logic [`WAYS-1:0] [`OLEN-1:0]               offset_in;
    logic [`WAYS-1:0] [`PCLEN-1:0]              PC_in;
//    ALU_FUNC                                  Operation_in  [`WAYS-1:0] ;

// output
    logic [`WAYS-1:0]                       inst_out_valid; // tell which inst is valid, **001** when only one inst is valid 
    logic [`WAYS-1:0] [`XLEN-1:0]           opa_out;
    logic [`WAYS-1:0] [`XLEN-1:0]           opb_out;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]    dest_PRF_idx_out;
    logic [`WAYS-1:0] [$clog2(`ROB)-1:0]    rob_idx_out;

    logic [`WAYS-1:0] [`PCLEN-1:0]          PC_out;
//    ALU_FUNC                                Operation_out [`WAYS-1:0];
    logic [`WAYS-1:0] [`OLEN-1:0]           offset_out;
    logic [$clog2(`RS):0]                   num_is_free;
    
    logic [`WAYS-1:0]                       rd_mem_out;                         
    logic [`WAYS-1:0]                       wr_mem_out;        

    logic [$clog2(`WAYS):0]                 free_decrease;
    logic [$clog2(`RS):0]                   num_is_free_next; 
    logic [`RS-1:0]                         is_free_hub;
    logic [$clog2(`WAYS):0]              free_increase;
    logic   [`RS-1:0]                     reset_hub;
        logic [`RS-1:0]                      ready_hub;

        logic                            maunal_test;
        logic                            night_ship;
        logic                           output_selector;
/* 
 *                          END OF WIRE DECLARATION
 *
 * ============================================================================
 */



    RS rs_dummy (
        // inputs
        .clock,
        .reset,
        .CDB_Data,
        .CDB_PRF_idx,
        .CDB_valid,
        .opa_in,
        .opb_in,
        .opa_valid_in,
        .opb_valid_in,
        .rd_mem_in,                          
        .wr_mem_in,
        .dest_PRF_idx_in,
        .rob_idx_in,                             
        .load_in,
        .offset_in,
        .PC_in,
//        .Operation_in,

        // output
        .inst_out_valid, // tell which inst is valid, **001** when only one inst is valid 
        .opa_out,
        .opb_out,
        .dest_PRF_idx_out,
        .rob_idx_out,

        .PC_out,
//        .Operation_out,
        .offset_out,
        .num_is_free,
    
        .rd_mem_out,       
        .wr_mem_out,

        .free_decrease,
        .num_is_free_next,
        .is_free_hub,
        .free_increase,
        .reset_hub,

        .ready_hub
    );

// Generate System Clock
    // YANKED from the p3 testbench
	always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end

property p1;
// check reset
    @(posedge clock)
    reset |=> (opa_out == 0 && opb_out == 0 && num_is_free ==`RS);
endproperty
assert property(p1) else $finish;

property p2;
        @(posedge clock)
        maunal_test |-> (num_is_free == `RS);
endproperty
assert property(p2) else $finish;

property p3;
        @(posedge clock)
        maunal_test |=> (num_is_free == `RS-`WAYS);
endproperty
assert property(p3) else $finish;

property p4;
        @(negedge clock)
        night_ship |-> (num_is_free == `RS-`WAYS);
endproperty
assert property(p4) else $finish;
/*
sequence check_output
        (num_is_free == 3'b100)[->4] ##4 (num_is_free == `RS);
endsequence
*/
property p5;
        @(posedge clock)
        output_selector |=> (num_is_free == `RS);
endproperty
assert property(p5) else $finish;


initial 
    begin
    clock = 0;
    $display("start");
    $display("Time|reset|load_in|CDB_PRF_idx[1]|CDB_valid|opa_in|opa_valid_in|opb_in|opb_valid_in|inst_out_valid|opa_out[0]|opb_out[0]|num_is_free|is_free_hub|ready_hub");
    $monitor("%4.0f  %b ", $time, reset,
            "    %b     ", load_in,
            "        %h         %b",CDB_PRF_idx[1],CDB_valid,
            "   %h     %h",opa_in[1],opa_valid_in[1],
            "     %h     %h",opb_in[1],opb_valid_in[1],
            "           %b    %h   %h",inst_out_valid,opa_out[0],opb_out[0],
            "     %d    %b    %b",num_is_free,is_free_hub,ready_hub);

//    $monitor("Time:%4.0f opa_in[0]: %h opb_in[0]: %h",$time, opa_in,opb_in);
// single input
        @(negedge clock);// 10
        reset = 1; 
        @(negedge clock);// 20
        reset = 0;
        @(negedge clock); // 30
        @(negedge clock); // 40
        // manual testcase
        maunal_test = 1;
        load_in = 1;
        CDB_valid = `WAYS'b0;
        opa_in[0] = `XLEN'h1;
        opa_in[1] = `XLEN'b11;
        opa_in[2] = `XLEN'b101;
        opa_valid_in = `WAYS'b111;
        opb_in[0] = `XLEN'b0;
        opb_in[1] = `XLEN'b10;
        opb_in[2] = `XLEN'b100;
        opb_valid_in = `WAYS'b0;
        CDB_valid = `WAYS'b1;
        CDB_Data[0] = `XLEN'habc;
        CDB_PRF_idx[0] = `LOGPRF'b0; 
        @(negedge clock);//50
        maunal_test = 0;
        load_in = 0;
        CDB_valid = `WAYS'b11;
        CDB_Data[0] = `XLEN'habc;
        CDB_PRF_idx[0] = `LOGPRF'b10; 
        CDB_Data[1] = `XLEN'habc;
        CDB_PRF_idx[1] = `LOGPRF'b100;
// check for ships in the night
// should recover after 1.5*clock period
        @(negedge clock);  //60 
        $display("start testing night ship"); 
        repeat(100) begin 
        night_ship = 1;  
        load_in = 1;

        rd_mem_in = {`WAYS{1'b1}} & $random;
        wr_mem_in = {`WAYS{1'b1}} & $random;
        dest_PRF_idx_in = {`WAYS*$clog2(`PRF){1'b1}} & $random;
        rob_idx_in = {`WAYS*$clog2(`PRF){1'b1}} & $random;
        offset_in = {`OLEN*`WAYS{1'b1}} & $random;
        PC_in = {`PCLEN*`WAYS{1'b1}} & $random;

        opa_in[0] = {`XLEN{1'b1}} & $random;
        opa_in[1] = {`XLEN{1'b1}} & $random;
        opa_in[2] = {`XLEN{1'b1}} & $random;
        opa_valid_in = `WAYS'b111;
        opb_in[0] = {`XLEN{1'b1}} & $random;
        opb_in[1] = {`XLEN{1'b1}} & $random;
        opb_in[2] = {`LOGPRF{1'b1}} & $random;
        opb_valid_in = `WAYS'b011;
        CDB_valid = `WAYS'b10;
        CDB_PRF_idx[0] = {`LOGPRF{1'b1}} & $random;
        CDB_PRF_idx[1] = opb_in[2];
        CDB_PRF_idx[2] = {`LOGPRF{1'b1}} & $random;
        CDB_Data = {`WAYS*`XLEN{1'b1}} & $random;
        @(negedge clock);
        end
// check for output selector when more than 3 RS entries are ready (4 are ready)
// should +3 afrer 1.5*clock period, +1 after 1 clock period
       @(negedge clock)
        $display("start testing output selector");
        repeat(100) begin
        rd_mem_in = {`WAYS{1'b1}} & $random;
        wr_mem_in = {`WAYS{1'b1}} & $random;
        dest_PRF_idx_in = {`WAYS*$clog2(`PRF){1'b1}} & $random;
        rob_idx_in = {`WAYS*$clog2(`PRF){1'b1}} & $random;
        offset_in = {`OLEN*`WAYS{1'b1}} & $random;
        PC_in = {`PCLEN*`WAYS{1'b1}} & $random;
        
        night_ship = 0;
        opa_in[0] = {`LOGPRF{1'b1}} & $random;
        opa_in[1] = {`LOGPRF{1'b1}} & $random;
        opa_in[2] = {`LOGPRF{1'b1}} & $random;
        opa_valid_in = `WAYS'b0;
        opb_in[0] = {`LOGPRF{1'b1}} & $random;
        opb_in[1] = {`LOGPRF{1'b1}} & $random;
        opb_in[2] = {`LOGPRF{1'b1}} & $random;
        opb_valid_in = `WAYS'b0;
        CDB_valid = `WAYS'b0;
        CDB_Data = {`WAYS*`XLEN{1'b1}} & $random;
        // num_is_free = 13;
        @(negedge clock);
        output_selector = 0;
        CDB_PRF_idx[0] =  opa_in[2];
        CDB_PRF_idx[1] =  opa_in[1];
        CDB_PRF_idx[2] =  opa_in[0];
        opa_in[0] = {`XLEN{1'b1}} & $random;
        opa_in[1] = {`XLEN{1'b1}} & $random;
        opa_in[2] = {`XLEN{1'b1}} & $random;
        opa_valid_in = `WAYS'b111;
        CDB_Data = {`WAYS*`XLEN{1'b1}} & $random;
        CDB_valid = `WAYS'b111;
        // num_is_free = 10;
        @(negedge clock);
        CDB_Data = {`WAYS*`XLEN{1'b1}} & $random;
        CDB_valid = `WAYS'b0;
        // num_is_free = 7;
        @(negedge clock);
        CDB_PRF_idx[0] = opb_in[2];
        CDB_PRF_idx[1] = opb_in[1];
        CDB_PRF_idx[2] = opb_in[0];
        opa_in[0] = {`XLEN{1'b1}} & $random;
        opa_in[1] = {`XLEN{1'b1}} & $random;
        opa_in[2] = {`XLEN{1'b1}} & $random;
        opa_valid_in = `WAYS'b111;
        opb_in[0] = {`XLEN{1'b1}} & $random;
        opb_in[1] = {`XLEN{1'b1}} & $random;
        opb_in[2] = {`XLEN{1'b1}} & $random;
        opb_valid_in = `WAYS'b111;
        CDB_valid = `WAYS'b111;
        // num_is_free = 4;
        @(negedge clock);
        end
        @(negedge clock);
        load_in = 0;
        CDB_valid = 0;
        maunal_test = 0;
        night_ship = 0;
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        output_selector = 1;
// check for one CDB entry validate two RS entry
// should 
/*
        @(negedge clock);//70
//        load_in = 1'b1;
        opa_in[0] = `XLEN'b10;
        opa_in[1] = `XLEN'b101;
        opa_in[2] = `XLEN'b1010;
        opa_valid_in = `WAYS'b0;
        opb_in[0] = `XLEN'b11;
        opb_in[1] = `XLEN'b1010;
        opb_in[2] = `XLEN'b101;
        opb_valid_in = `WAYS'b0;
// CDB
        CDB_valid = `WAYS'b111;
        CDB_Data[1] = `XLEN'habcdef;
        CDB_PRF_idx[1] = `LOGPRF'b1010;
        CDB_Data[0] = `XLEN'hbcdef;
        CDB_PRF_idx[0] = `LOGPRF'b101;
        CDB_Data[2] = `XLEN'hcdef;
        CDB_PRF_idx[2] = `LOGPRF'b1010;
        */

        @(negedge clock);//120

        @(negedge clock);//130
        @(negedge clock);//130
        @(negedge clock);//130

// test the functionality of reset
     $finish;
     end // initial

endmodule                