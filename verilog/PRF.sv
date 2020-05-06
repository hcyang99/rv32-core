
//`define WAYS    4
//`define XLEN    32
//`define PRF     64
module PRF(
        input                                   clock,
        input                                   reset,
        input   [`WAYS-1:0] [$clog2(`PRF)-1:0]  rda_idx,
        input   [`WAYS-1:0] [$clog2(`PRF)-1:0]  rdb_idx,
        input   [`WAYS-1:0] [$clog2(`PRF)-1:0]  wr_idx,
        input   [`WAYS-1:0] [`XLEN-1:0]         wr_dat,
        input   [`WAYS-1:0]                     wr_en,

        output logic [`WAYS-1:0] [`XLEN-1:0]    rda_dat,
        output logic [`WAYS-1:0] [`XLEN-1:0]    rdb_dat,
        output logic [`PRF-1:0] [`XLEN-1:0]     prf_regs
    );
  
    reg [`PRF-1:0] [`XLEN-1:0]      registers;
    logic [`PRF-1:0] [`XLEN-1:0]    reg_next;
    assign prf_regs = registers;

    logic [`WAYS-1:0][`WAYS-1:0]    opa_is_from_wr;
    logic [`WAYS-1:0][`WAYS-1:0]    opb_is_from_wr;

    generate
        for(genvar i = 0; i < `WAYS; i = i + 1) begin
            for(genvar j = 0; j <`WAYS; j = j + 1) begin
                assign opa_is_from_wr[i][j] = wr_en[j] && (wr_idx[j] == rda_idx[i]);
                assign opb_is_from_wr[i][j] = wr_en[j] && (wr_idx[j] == rdb_idx[i]);
            end
        end
    endgenerate


    always_comb begin
        for (int i = 0; i < `WAYS; i = i + 1) begin
            rda_dat[i] = registers[rda_idx[i]];
            rdb_dat[i] = registers[rdb_idx[i]];
            for (int j = 0 ; j < `WAYS ; j = j + 1) begin
               if(opa_is_from_wr[i][j]) rda_dat[i] = wr_dat[j];  
               if(opb_is_from_wr[i][j]) rdb_dat[i] = wr_dat[j];
            end
        end
    end

always_comb begin // MAY BE OPTIMIZED
    reg_next = registers;
    for (int i = 0; i < `WAYS; i = i + 1) begin
        if (wr_en[i]) reg_next[wr_idx[i]] = wr_dat[i];
    end
end

always_ff @ (posedge clock) begin
    if (reset) registers <= 0;
    else registers <= reg_next;
end

endmodule // PRF