`include "sys_defs.svh"
//`define REG_LEN     64

//`timescale 1ns/100ps

module RS_Line(
    input                                       clock,
    input                                       reset,

    input [`WAYS-1:0] [`XLEN-1:0]               CDB_Data,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx,
    input [`WAYS-1:0]                           CDB_valid,

    input                                       opa_valid_in, // indicate whether it is data or PRN, 1: data 0: PRN
    input                                       opb_valid_in, // assuming opx_valid_in is 0 when en == 0

    input                                       load_in, // high when dispatch
    input ID_EX_PACKET                          id_rs_packet_in,

    output ID_EX_PACKET                         rs_packet_out,
    output logic                                ready,
    // RS entry
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
//    $display("opb_reg_is_from_CDB:%b opb_valid_reg:%b CDB_valid:%b CDB_PRF_idx:%h opb_out:%h",opb_reg_is_from_CDB,opb_valid_reg,CDB_valid,CDB_PRF_idx,opb_out);
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
//    $display("in small module, load_in: %b inst_valid_in: %b",load_in,inst_valid_in);
        if(load_in & id_rs_packet_in.valid)begin
            is_free <= 0;
            opa_valid_reg <= opa_valid_in;
            opb_valid_reg <= opb_valid_in;
        end
        else if (reset | (~id_rs_packet_in.valid & load_in)) begin
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
        if (load_in & id_rs_packet_in.valid) begin
            rs_packet_out <= id_rs_packet_in;
        end 
        else if (reset | (~id_rs_packet_in.valid & load_in)) begin
            rs_packet_out <= 0;
        end 
        else begin
            rs_packet_out.rs1_value <=  opa_reg_feed;
            rs_packet_out.rs2_value <=  opb_reg_feed;
        end
    end
    
endmodule

