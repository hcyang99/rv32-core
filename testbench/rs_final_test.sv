`include "sys_defs.svh"
//`define XLEN        64
`define PRF         64
`define LOGPRF      6 //$clog2(`PRF)

`define ROB         16
`define RS          16
`define OLEN        16
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
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        dest_PRF_idx_in;
    logic [`WAYS-1:0] [$clog2(`ROB)-1:0]        rob_idx_in;      
                           
     ID_EX_PACKET [`WAYS-1:0]              id_rs_packet_in;

    logic                                       load_in; // high when dispatch :: SHOULD HAVE BEEN MULTIPLE ENTRIES??
    logic [`WAYS-1:0]                           inst_valid_in;

// output
     ID_EX_PACKET [`WAYS-1:0]             rs_packet_out;

    logic [`WAYS-1:0]                       inst_out_valid; // tell which inst is valid, **001** when only one inst is valid 
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]    dest_PRF_idx_out;
    logic [`WAYS-1:0] [$clog2(`ROB)-1:0]    rob_idx_out;

    logic [$clog2(`RS):0]                   num_is_free;
    
    logic [$clog2(`WAYS):0]                 free_decrease;
    logic [$clog2(`RS):0]                   num_is_free_next; 
    logic [`RS-1:0]                         is_free_hub;
    logic [$clog2(`WAYS):0]              free_increase;
    logic   [`RS-1:0]                     reset_hub;
    logic [`RS-1:0]                      ready_hub;

        logic                            maunal_test;
        logic                            night_ship;
        logic                            output_selector;
        logic                            load_prior_to_reset;
/* 
 *                          END OF WIRE DECLARATION
 *
 * ============================================================================
 */
generate
        for (genvar i = 0; i < `WAYS; i = i + 1) begin
                assign id_rs_packet_in[i].rs1_value = opa_in[i];
                assign id_rs_packet_in[i].rs2_value = opb_in[i];
                assign id_rs_packet_in[i].valid     = inst_valid_in[i];
        end
    endgenerate


    RS rs_dummy (
        // inputs
        .clock,
        .reset,
        .CDB_Data,
        .CDB_PRF_idx,
        .CDB_valid,
        .opa_valid_in,
        .opb_valid_in,
        .dest_PRF_idx_in,
        .rob_idx_in, 
        .id_rs_packet_in,                            
        .load_in,

        // output
        .rs_packet_out,
        .inst_out_valid, // tell which inst is valid, **001** when only one inst is valid 
        .dest_PRF_idx_out,
        .rob_idx_out,

        .num_is_free,
    

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
    reset |=> (num_is_free ==`RS);
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

property p6;
        @(posedge clock)
        load_prior_to_reset |=> (num_is_free == 1);
endproperty
assert property(p6) else $finish;



initial 
    begin
    clock = 0;
    $display("start");
    $display("Time|reset|load_in|CDB_PRF_idx|CDB_valid|opa_in|opa_valid_in|opb_in|opb_valid_in|inst_out_valid|opa_out|opb_out|num_is_free|is_free_hub|ready_hub|reset_hub");
    $monitor("%4.0f  %b ", $time, reset,
            "   %b", load_in,
            "      %h        %b",CDB_PRF_idx[1],CDB_valid,
            "   %h     %h",opa_in[1],opa_valid_in[1],
            "     %h     %h",opb_in[1],opb_valid_in[1],
            "     %b    %h   %h",inst_out_valid,rs_packet_out[0].rs1_value,rs_packet_out[0].rs2_value,
            "     %d    %b    %b     %b",num_is_free,is_free_hub,ready_hub,reset_hub);

//    $monitor("Time:%4.0f opa_in[0]: %h opb_in[0]: %h",$time, opa_in,opb_in);
// single input
        @(negedge clock);// 10
        reset = 1; 
        inst_valid_in = 3'b111;
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
        load_in = 1;
        inst_valid_in = 0;
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
        inst_valid_in = 3'b111;

        dest_PRF_idx_in = {`WAYS*$clog2(`PRF){1'b1}} & $random;
        rob_idx_in = {`WAYS*$clog2(`PRF){1'b1}} & $random;
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
// check for output selector when more than 3 RS entries are ready
// should +3 afrer 1.5*clock period, +1 after 1 clock period

       @(negedge clock)
        $display("start testing output selector");
        repeat(100) begin
        dest_PRF_idx_in = {`WAYS*$clog2(`PRF){1'b1}} & $random;
        rob_idx_in = {`WAYS*$clog2(`PRF){1'b1}} & $random;
        
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
        // num_is_free = 1;
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
        @(negedge clock);
        output_selector = 1;
        @(negedge clock);//120
        output_selector = 0;
        @(negedge clock);//180
        load_in = 1;
        opa_in[0] = `XLEN'h1;
        opa_in[1] = `XLEN'b11;
        opa_in[2] = `XLEN'b101;
        opa_valid_in = `WAYS'b111;
        opb_in[0] = `XLEN'b0;
        opb_in[1] = `XLEN'b10;
        opb_in[2] = `XLEN'b100;
        opb_valid_in = `WAYS'b0;
        CDB_valid = `WAYS'b0;
        //185: 13
        @(negedge clock);//190
        //195: 10
        @(negedge clock);//200
        //205: 7
        @(negedge clock);//210
        //215: 4
        @(negedge clock);//220
        //225: 1
        load_prior_to_reset = 1;

        CDB_valid = `WAYS'b111;
        CDB_PRF_idx[0] = `LOGPRF'b0;
        CDB_PRF_idx[1] = `LOGPRF'b10;
        CDB_PRF_idx[2] = `LOGPRF'b100;
        CDB_Data = {`WAYS*`XLEN{1'b1}} & $random;
        @(negedge clock);//230
        //235: 1?
// test the functionality of reset
        load_prior_to_reset = 0;

        load_in = 1;
        opa_in[0] = `XLEN'h1;
        opa_in[1] = `XLEN'b11;
        opa_in[2] = `XLEN'b101;
        opa_valid_in = `WAYS'b111;
        opb_in[0] = `XLEN'b0;
        opb_in[1] = `XLEN'b10;
        opb_in[2] = `XLEN'b100;
        opb_valid_in = `WAYS'b111;
        CDB_valid = `WAYS'b0;

        @(negedge clock);//240
        load_in = 0;
        // 245: 4
        @(negedge clock);//250
        // 255: 7
        @(negedge clock);//250
        @(negedge clock);//250

     $finish;
     end // initial

endmodule                