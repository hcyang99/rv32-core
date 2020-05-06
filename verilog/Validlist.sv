//`define WAYS    4
//`define XLEN    32
//`define PRF     64
//`define DEBUG

// todo: optimize this
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
    input [`WAYS-1:0]                           wr_en_RRAT,         // REQUIRES: en bits after mis-branch are low
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_RRAT_old,     // From RRAT, these are leaving RRAT

    output logic [`WAYS-1:0]                    rda_valid,
    output logic [`WAYS-1:0]                    rdb_valid

    /* Debug Outputs */
    `ifdef DEBUG
    ,
    output logic [`PRF-1:0]                     valid_RAT_reg_out,
    output logic [`PRF-1:0]                     valid_RRAT_reg_out
    `endif
);

reg [`PRF-1:0]      valid_RAT_reg;
wire [`PRF-1:0]     valid_RAT_next;
reg [`PRF-1:0]      valid_RRAT_reg;
wire [`PRF-1:0]    valid_RRAT_next;
wire [`PRF-1:0]    valid_list_rst;
wand [`WAYS:0] [`PRF-1:0] valid_RAT_tmp;
wor [`PRF-1:0] CDB_incoming;
wor [`PRF-1:0] RRAT_incoming;
wor [`PRF-1:0] RRAT_leaving;

`ifdef DEBUG
    assign valid_RAT_reg_out = valid_RAT_reg;
    assign valid_RRAT_reg_out = valid_RRAT_reg;
`endif

genvar gi, gj;
generate;
    for (gi = 0; gi < `WAYS; ++gi) begin
        // new valids from CDB
        assign CDB_incoming = wr_en_CDB[gi] ? {`PRF'h1 << reg_idx_wr_CDB[gi]} : `PRF'h0;

        // entering RRAT
        assign RRAT_incoming = wr_en_RRAT[gi] ? {`PRF'h1 << reg_idx_wr_RRAT_new[gi]} : `PRF'h0;

        // leaving RRAT
        assign RRAT_leaving = wr_en_RRAT[gi] ? {`PRF'h1 << reg_idx_wr_RRAT_old[gi]} : `PRF'h0;
    end 

    // temps
    assign valid_RAT_tmp[0] = valid_RAT_reg | CDB_incoming;
    for (gi = 0; gi < `WAYS; ++gi) begin
        assign valid_RAT_tmp[gi + 1] = valid_RAT_tmp[gi];
        assign valid_RAT_tmp[gi + 1] = ~(wr_en_RAT[gi] ? {`PRF'h1 << reg_idx_wr_RAT[gi]} : `PRF'h0);
    end
    // idx [`WAYS] is after all insts, to be written to reg next posedge
    assign valid_RAT_next = valid_RAT_tmp[`WAYS];

    assign valid_RRAT_next = valid_RRAT_reg & (~RRAT_leaving) | RRAT_incoming;

    // read; conflicts between read and write handled in RS? handled here anyway
    for (gi = 0; gi < `WAYS; ++gi) begin
        assign rda_valid[gi] = valid_RAT_tmp[gi][rda_idx[gi]];
        assign rdb_valid[gi] = valid_RAT_tmp[gi][rdb_idx[gi]];
    end

    // reset values
    for (gi = 0; gi < `PRF; ++gi) begin
        assign valid_list_rst[gi] = gi < 32;
    end

endgenerate

// // write, from RAT and CDB
// always_comb begin
//     valid_RAT_next = valid_RAT_reg;
//     for (int i = 0; i < `WAYS; i = i + 1) begin
//         if (wr_en_RAT[i])
//             valid_RAT_next[reg_idx_wr_RAT[i]] = 1'b0;
//         if (wr_en_CDB[i])
//             valid_RAT_next[reg_idx_wr_CDB[i]] = 1'b1;
//     end
// end

// // write, from RRAT
// always_comb begin
//     valid_RRAT_next = valid_RRAT_reg;
//     for (int i = 0; i < `WAYS; i = i + 1) begin
//         if (wr_en_RRAT[i])
//             valid_RRAT_next[reg_idx_wr_RRAT_old[i]] = 1'b0;
//         if (wr_en_RRAT[i])
//             valid_RRAT_next[reg_idx_wr_RRAT_new[i]] = 1'b1;
//     end
// end

always_ff @ (posedge clock) begin
    if (reset) begin    // this runs only on start-up
        valid_RAT_reg <= valid_list_rst;
        valid_RRAT_reg <= valid_list_rst;
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