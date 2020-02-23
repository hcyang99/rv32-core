`include "sys_defs.svh"
`define REG_LEN     64
`define PRF         64
`define ROB         16
`define RS          16

`define OLEN        16
`define PCLEN       32
`define WAYS        3

module testbench;
    logic     clock;
    logic     reset;

    logic [`WAYS-1:0] [`REG_LEN-1:0]            CDB_Data;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx;
    logic [`WAYS-1:0]                           CDB_valid;

    logic [`REG_LEN-1:0]                        opa_in; // data or PRN
    logic [`REG_LEN-1:0]                        opb_in; // data or PRN
    logic                                       opa_valid_in; // indicate whether it is data or PRN, 1: data 0: PRN
    logic                                       opb_valid_in; // assuming opx_valid_in is 0 when en == 0
    logic                                       rd_mem_in;                         
    logic                                       wr_mem_in;
    logic [$clog2(`PRF)-1:0]                    dest_PRF_idx_in;
    logic [$clog2(`ROB):0]                      rob_idx_in;                        

    logic                                       load_in; // high when dispatch
    logic [`OLEN-1:0]                           offset_in;
    logic [`PCLEN-1:0]                          PC_in;
    ALU_FUNC                              Operation_in;


    logic                                ready;
    logic [`REG_LEN-1:0]                 opa_out;
    logic [`REG_LEN-1:0]                 opb_out;
    logic [$clog2(`PRF)-1:0]             dest_PRF_idx_out;
    logic [$clog2(`ROB)-1:0]             rob_idx_out;
    logic                                is_free;

    logic [`PCLEN-1:0]                   PC_out;
    ALU_FUNC                             Operation_out;
    logic [`OLEN-1:0]                    offset_out;
    logic                                rd_mem_out;                        
    logic                                wr_mem_out;


    RS_Line myRS_line (clock,reset,CDB_Data,CDB_PRF_idx,CDB_valid,
                opa_in,opb_in,opa_valid_in,opb_valid_in,rd_mem_in,wr_mem_in,
                dest_PRF_idx_in,rob_idx_in,load_in,offset_in,PC_in,
                Operation_in,ready,opa_out,opb_out,dest_PRF_idx_out,
                rob_idx_out,is_free,PC_out,Operation_out,offset_out,
                rd_mem_out,wr_mem_out);

    always begin
        #5
        clock = ~clock;
    end
    
    initial 
    begin
    clock = 0;
    $display("start");
    $display("Time|reset|load_in|CDB_Data[0]|CDB_PRF_idx[0]|CDB_valid[0]|opa_in|opa_valid_in|opb_in|opb_valid_in|is_free|ready");
    $monitor("%4.0f  %b    %b     %h      %h       %h     %h   %h   %h   %h     %h     %h", $time, reset, load_in, CDB_Data[0],CDB_PRF_idx[0],CDB_valid[0],opa_in,opa_valid_in,opb_in,opb_valid_in,is_free,ready);
        @(negedge clock);
        reset = 1; 
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        CDB_valid = 3'b000;
        @(negedge clock);
        load_in = 1;
        opa_in = 64'h110;
        opa_valid_in = 1;
        opb_in = 64'h11;
        opb_valid_in = 0;
        @(negedge clock);

        load_in = 0;
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