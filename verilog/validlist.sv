//`define WAYS    4
//`define XLEN    32
//`define PRF     64

module ValidList(
    input                                       clock,
    input                                       reset,
    input                                       except,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        rda_idx,            // For Renaming
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        rdb_idx,            // For Renaming
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_RAT,     // From RAT, freshly renamed entries are invalid
    input [`WAYS-1:0]                           wr_en_RAT,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_CDB,     // From CDB, these are now valid
    input [`WAYS-1:0]                           wr_en_CDB,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_RRAT_new,     // From RRAT, these are entering RRAT
    input [`WAYS-1:0]                           wr_en_RRAT_new,         // REQUIRES: en bits after mis-branch are low
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_RRAT_old,     // From RRAT, these are leaving RRAT
    input [`WAYS-1:0]                           wr_en_RRAT_old,

    output logic [`WAYS-1:0]                    rda_valid,
    output logic [`WAYS-1:0]                    rdb_valid
);

reg [`PRF-1:0]      valid_RAT_reg;
logic [`PRF-1:0]    valid_RAT_next;
reg [`PRF-1:0]      valid_RRAT_reg;
logic [`PRF-1:0]    valid_RRAT_next;

// read
generate;  // conflicts between read and write handled in RS
    genvar i;
    for (i = 0; i < `WAYS; i = i + 1) begin
        assign rda_valid[i] = valid_RAT_reg[rda_idx[i]];
        assign rdb_valid[i] = valid_RAT_reg[rdb_idx[i]];
    end
endgenerate

// write, from RAT and CDB
always_comb begin
    valid_RAT_next = valid_RAT_reg;
    for (int i = 0; i < `WAYS; i = i + 1) begin
        if (wr_en_RAT[i])
            valid_RAT_next[reg_idx_wr_RAT[i]] = 1'b0;
        if (wr_en_CDB[i])
            valid_RAT_next[reg_idx_wr_CDB[i]] = 1'b1;
    end
end

// write, from RRAT
always_comb begin
    valid_RRAT_next = valid_RRAT_reg;
    for (int i = 0; i < `WAYS; i = i + 1) begin
        if (wr_en_RRAT_old[i])
            valid_RRAT_next[reg_idx_wr_RRAT_old[i]] = 1'b0;
        if (wr_en_RRAT_new[i])
            valid_RRAT_next[reg_idx_wr_RRAT_new[i]] = 1'b1;
    end
end

always_ff @ (posedge clock) begin
    if (reset) begin    // this runs only on start-up
        for (int i = 0; i < 32; ++i) begin
            valid_RAT_reg[i] <= 1'b1;
            valid_RRAT_reg[i] <= 1'b1;
        end
        for (int i = 32; i < `PRF; ++i) begin
            valid_RAT_reg[i] <= 1'b0;
            valid_RRAT_reg[i] <= 1'b0;
        end
    end
    else if (except) begin  // REQUIRES: en bits after mis-branch are low
        valid_RAT_reg <= valid_RRAT_next;
        valid_RRAT_reg <= valid_RRAT_next;
    end
    else begin
        valid_RAT_reg <= valid_RAT_next;
        valid_RRAT_reg <= valid_RRAT_next;
    end
end

endmodule