`define WAYS    4
`define XLEN    32
`define PRF     64
module PRF(
        input                                   clock,
        input                                   reset,
        input   [`WAYS-1:0] [$clog2(`PRF)-1:0]  rda_idx,
        input   [`WAYS-1:0] [$clog2(`PRF)-1:0]  rdb_idx,
        input   [`WAYS-1:0] [$clog2(`PRF)-1:0]  wr_idx,
        input   [`WAYS-1:0] [`XLEN-1:0]         wr_dat,
        input   [`WAYS-1:0]                     wr_en,

        output logic [`WAYS-1:0] [`XLEN-1:0]    rda_dat,
        output logic [`WAYS-1:0] [`XLEN-1:0]    rdb_dat
    );
  
reg [`PRF-1:0] [`XLEN-1:0]      registers;
logic [`PRF-1:0] [`XLEN-1:0]    reg_next;

generate;
    genvar i;
    for (i = 0; i < `WAYS; i = i + 1) begin
        assign rda_dat[i] = registers[rda_idx[i]];
        assign rdb_dat[i] = registers[rdb_idx[i]];
    end
endgenerate


always_comb begin // MAY BE OPTIMIZED
    reg_next = registers;
    for (int i = 0; i < `WAYS; i = i + 1) begin
        if (wr_en[i] && wr_idx[i]) reg_next[wr_idx[i]] = wr_dat[i];
    end
end

always_ff @ (posedge clock) begin
    if (reset) registers <= 0;
    else registers <= reg_next;
end

endmodule // PRF