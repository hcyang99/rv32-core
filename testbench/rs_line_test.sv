`include "sys_defs.svh"
//`define REG_LEN     64
`define PRF         64
`define ROB         16
`define RS          16

`define OLEN        16
`define PCLEN       32
`define WAYS        3

module testbench;
    logic                                       clock;
    logic                                       reset;

    logic [`WAYS-1:0] [`XLEN-1:0]               CDB_Data;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx;
    logic [`WAYS-1:0]                           CDB_valid;

    logic                                       opa_valid_in; // indicate whether it is data or PRN, 1: data 0: PRN
    logic                                       opb_valid_in; // assuming opx_valid_in is 0 when en == 0
    logic [$clog2(`PRF)-1:0]                    dest_PRF_idx_in;
    logic [$clog2(`ROB)-1:0]                    rob_idx_in;                   

    logic                                       load_in; // high when dispatch
    logic                                       inst_valid_in;
    ID_EX_PACKET                          id_rs_packet_in;

    ID_EX_PACKET                         rs_packet_out;
    logic                                ready;
    // RS entry
    logic [$clog2(`PRF)-1:0]             dest_PRF_idx_out;
    logic [$clog2(`ROB)-1:0]             rob_idx_out;
    logic                                is_free;

    RS_Line lines(
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
        .load_in,
        .inst_valid_in, // when load_in = 1, it does represent whether the inst is valid or not, when load_in = 0, it should make no difference
        .id_rs_packet_in,

        // outputs
        .rs_packet_out,
        .ready,
        .dest_PRF_idx_out,
        .rob_idx_out,
        .is_free
    );

    always begin
        #5
        clock = ~clock;
    end
    
    initial 
    begin
    clock = 0;
    $display("start");
    $display("Time|reset|load_in|CDB_Data[0]|CDB_PRF_idx[0]|CDB_valid|opa_out|opa_valid_in|opb_out|opb_valid_in|is_free|ready");
    $monitor("%4.0f  %b    %b     %h      %h       %b     %h   %h   %h   %h     %h     %h", $time, reset, load_in, CDB_Data[0],CDB_PRF_idx[0],CDB_valid,rs_packet_out.rs1_value,opa_valid_in,rs_packet_out.rs2_value,opb_valid_in,is_free,ready);
        @(negedge clock);
        reset = 1; 
        @(negedge clock);
        reset = 0;
        inst_valid_in = 1;
        @(negedge clock);
        CDB_valid = 3'b000;
        @(negedge clock);
        load_in = 1;
        id_rs_packet_in.rs1_value = 32'b110;
        opa_valid_in = 1;
        id_rs_packet_in.rs2_value = 32'b11;
        opb_valid_in = 0;
        @(negedge clock);

        load_in = 0;
        @(negedge clock);
        CDB_valid = 3'b001;
        CDB_Data[0] = 64'habc;
        CDB_PRF_idx[0] = 32'b11;
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        $finish;
     end // initial
endmodule