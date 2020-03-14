/**********change has made**********
1. always load in that amount of instruction, but if it reach the end. 
set the insruction as invalid

2. observe that there is one clock period time delay in the output num_is_free,
// output num_is_free_next
**********************/
`include "sys_defs.svh"
//`define REG_LEN     64
`define PRF         64
`define ROB         16
`define RS          16

`define OLEN        16
`define WAYS        3
//`timescale 1ns/100ps

module RS_Line(
    input                                       clock,
    input                                       reset,

    input [`WAYS-1:0] [`XLEN-1:0]               CDB_Data,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx,
    input [`WAYS-1:0]                           CDB_valid,

    input                                       opa_valid_in, // indicate whether it is data or PRN, 1: data 0: PRN
    input                                       opb_valid_in, // assuming opx_valid_in is 0 when en == 0
    input [$clog2(`PRF)-1:0]                    dest_PRF_idx_in,
    input [$clog2(`ROB)-1:0]                    rob_idx_in,                        

    input                                       load_in, // high when dispatch
    input                                       inst_valid_in,
    input ID_EX_PACKET                          id_rs_packet_in,

    output ID_EX_PACKET                         rs_packet_out,
    output logic                                ready,
    // RS entry
    output logic [$clog2(`PRF)-1:0]             dest_PRF_idx_out,
    output logic [$clog2(`ROB)-1:0]             rob_idx_out,
    output logic                                is_free

);

    logic [`WAYS-1:0]                           opa_reg_is_from_CDB;
    logic [`WAYS-1:0]                           opb_reg_is_from_CDB;
    reg                                         opa_valid_reg;
    reg                                         opb_valid_reg;
//    logic [`XLEN-1:0]                           opa_reg;
//    logic [`XLEN-1:0]                           opb_reg;
    reg [`XLEN-1:0]                             opa_reg_feed;
    reg [`XLEN-1:0]                             opb_reg_feed;
    logic                                       opa_valid_reg_feed;
    logic                                       opb_valid_reg_feed;

    assign ready = opa_valid_reg & opb_valid_reg;

    // watching CDB for broadcasting!!!
    generate
        for (genvar i = 0; i < `WAYS; i = i + 1) begin
            assign opa_reg_is_from_CDB[i] = ~opa_valid_reg && CDB_valid[i] && CDB_PRF_idx[i] == rs_packet_out.rs1_value;
            assign opb_reg_is_from_CDB[i] = ~opb_valid_reg && CDB_valid[i] && CDB_PRF_idx[i] == rs_packet_out.rs2_value;
        end
    endgenerate

    always_comb begin
    $display("opb_reg_is_from_CDB:%b opb_valid_reg:%b CDB_valid:%b CDB_PRF_idx[0]:%h opb_out:%h",opb_reg_is_from_CDB,opb_valid_reg,CDB_valid,CDB_PRF_idx[0],rs_packet_out.rs2_value);
        opa_reg_feed = rs_packet_out.rs1_value;
        opb_reg_feed = rs_packet_out.rs2_value;
        opa_valid_reg_feed = opa_valid_reg;
        opb_valid_reg_feed = opb_valid_reg;
        if (~is_free) begin
            for (int i = 0; i < `WAYS; i = i + 1) begin
                if (opa_reg_is_from_CDB[i]) begin
                    opa_reg_feed = CDB_Data[i];
                    opa_valid_reg_feed = 1'b1;
                end
                if (opb_reg_is_from_CDB[i]) begin
                    opb_reg_feed = CDB_Data[i];
                    opb_valid_reg_feed = 1'b1;
                end
            end
        end
    end
    
    always_ff @ (posedge clock) begin
        if(load_in & inst_valid_in)begin
            is_free <= 0;
            opa_valid_reg <= opa_valid_in;
            opb_valid_reg <= opb_valid_in;
        end
        else if (reset | (~inst_valid_in & load_in)) begin
            is_free <= 1;
            opa_valid_reg <= 0;
            opb_valid_reg <= 0;
        end
        else begin
            opa_valid_reg <=  opa_valid_reg_feed;
            opb_valid_reg <=  opb_valid_reg_feed;
        end
    end

    always_ff @ (posedge clock) begin
//     if(load_in)   $display("in small module, id_rs_packet_in.rs1_value: %h id_rs_packet_in.rs2_value: %h",id_rs_packet_in.rs1_value,id_rs_packet_in.rs2_value);
//     $display("opa_reg_is_from_CDB: %b opb_reg_is_from_CDB: %b",opa_reg_is_from_CDB,opb_reg_is_from_CDB);

        if (load_in & inst_valid_in) begin
            rs_packet_out <= id_rs_packet_in;
            dest_PRF_idx_out <=  dest_PRF_idx_in;
            rob_idx_out <=  rob_idx_in;
        end 
        else if (reset | (~inst_valid_in & load_in)) begin
            rs_packet_out <= 0;
            dest_PRF_idx_out <=  0;
            rob_idx_out <=  0;
        end 
        else begin
            rs_packet_out.rs1_value <=  opa_reg_feed;
            rs_packet_out.rs2_value <=  opb_reg_feed;
        end
    end
    
endmodule



