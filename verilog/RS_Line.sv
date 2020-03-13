`include "../sys_defs.svh"
//`define REG_LEN     64
`define PRF         64
`define ROB         16
`define RS          16

`define OLEN        16
`define PCLEN       32
`define WAYS        3

module RS_Line(
    input                                       clock,
    input                                       reset,

    input [`WAYS-1:0] [`XLEN-1:0]               CDB_Data,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx,
    input [`WAYS-1:0]                           CDB_valid,

    input [`XLEN-1:0]                           opa_in, // data or PRN
    input [`XLEN-1:0]                           opb_in, // data or PRN
    input                                       opa_valid_in, // indicate whether it is data or PRN, 1: data 0: PRN
    input                                       opb_valid_in, // assuming opx_valid_in is 0 when en == 0
    input                                       rd_mem_in,                         
    input                                       wr_mem_in,
    input [$clog2(`PRF)-1:0]                    dest_PRF_idx_in,
    input [$clog2(`ROB)-1:0]                    rob_idx_in,                        

    input                                       load_in, // high when dispatch
    input                                       instruction_valid,
    input [`OLEN-1:0]                           offset_in,
    input [`PCLEN-1:0]                          PC_in,
    input ALU_FUNC                              Operation_in,


    output logic                                ready,    // RS entry
    output logic [`XLEN-1:0]                    opa_out,
    output logic [`XLEN-1:0]                    opb_out,
    output logic [$clog2(`PRF)-1:0]             dest_PRF_idx_out,
    output logic [$clog2(`ROB)-1:0]             rob_idx_out,
    output logic                                is_free,

    output logic [`PCLEN-1:0]                   PC_out,
    output ALU_FUNC                             Operation_out,
    output logic [`OLEN-1:0]                    offset_out,
    output logic                                rd_mem_out,                        
    output logic                                wr_mem_out                         
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

    // watching CDB
    generate
        for (genvar i = 0; i < `WAYS; i = i + 1) begin
            assign opa_reg_is_from_CDB[i] = ~opa_valid_reg && CDB_valid[i] && CDB_PRF_idx[i] == opa_out;
            assign opb_reg_is_from_CDB[i] = ~opb_valid_reg && CDB_valid[i] && CDB_PRF_idx[i] == opb_out;
        end
    endgenerate

    always_comb begin
//    $display("opb_reg_is_from_CDB:%b opb_valid_reg:%b CDB_valid:%b CDB_PRF_idx:%h opb_out:%h",opb_reg_is_from_CDB,opb_valid_reg,CDB_valid,CDB_PRF_idx,opb_out);
        opa_reg_feed = opa_out;
        opb_reg_feed = opb_out;
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
//    $display("opa_valid_reg: %b opb_valid_reg: %b",opa_valid_reg,opb_valid_reg);
        if (reset | ~instruction_valid) begin
            is_free <= 1;
            opa_valid_reg <= 0;
            opb_valid_reg <= 0;
            opa_out <= 0;
            opb_out <= 0;
        end
        else if (load_in) begin
            is_free <= 0;
            opa_valid_reg <= opa_valid_in;
            opb_valid_reg <= opb_valid_in;
            opa_out <= opa_in;
            opb_out <= opb_in;
        end
        else begin
            opa_valid_reg <= opa_valid_reg_feed;
            opb_valid_reg <= opb_valid_reg_feed;
            opa_out <= opa_reg_feed;
            opb_out <= opb_reg_feed;
        end
    end

    always_ff @ (posedge clock) begin
        if (reset | ~instruction_valid) begin
            PC_out <= 0;
            Operation_out <= ALU_ADD;
            offset_out <= 0;
            rd_mem_out <= 0;                          
            wr_mem_out <= 0; 
            dest_PRF_idx_out <= 0;
            rob_idx_out <= 0;
        end
        else if (load_in) begin
            PC_out <= PC_in;
            Operation_out <= Operation_in;
            offset_out <= offset_in;
            rd_mem_out <= rd_mem_in;                          
            wr_mem_out <= wr_mem_in; 
            dest_PRF_idx_out <= dest_PRF_idx_in;
            rob_idx_out <= rob_idx_in;
        end
    end
    
endmodule
