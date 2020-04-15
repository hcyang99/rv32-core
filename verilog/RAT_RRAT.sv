//`define WAYS    4
//`define XLEN    32
//`define PRF     64

module RAT_RRAT(
    input                                       clock,
    input                                       reset,
    input                                       except,

    input [`WAYS-1:0] [4:0]                     rda_idx,            // rename query 1
    input [`WAYS-1:0] [4:0]                     rdb_idx,            // rename query 2
    input [`WAYS-1:0] [4:0]                     RAT_dest_idx,       // ARF # to be renamed
    input [`WAYS-1:0]                           RAT_idx_valid,      // how many ARF # to rename?

    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_CDB,     // From CDB, these are now valid
    input [`WAYS-1:0]                           wr_en_CDB,

    input [`WAYS-1:0] [4:0]                     RRAT_ARF_idx,       // ARF # to be renamed, from ROB
    input [`WAYS-1:0]                           RRAT_idx_valid, 
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        RRAT_PRF_idx,       // PRF # 

    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] rename_result,      // New PRF # renamed to
    output logic [`WAYS-1:0]                    rename_result_valid,

    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] rda_idx_out,        // PRF # 
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] rdb_idx_out,        // PRF #
    output logic [`WAYS-1:0]                    rda_valid,
    output logic [`WAYS-1:0]                    rdb_valid
);

    logic [`PRF-1:0]                     valid_RAT_reg_out;  // from valid list
    logic [`PRF-1:0]                     valid_RRAT_reg_out;

    logic [`PRF-1:0]                     free_RAT_reg_out;   // from free list
    logic [`PRF-1:0]                     free_RRAT_reg_out;

    logic [31:0] [$clog2(`PRF)-1:0]      RAT_reg_out;        // from RAT/RRAT internals
    logic [31:0] [$clog2(`PRF)-1:0]      RRAT_reg_out;

    // internal buses
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        RRAT_PRF_old_from_rat;     // rat bcasts
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]        PRF_idx_from_free;         
    logic [`WAYS-1:0]                           PRF_idx_valid_from_free;   
    logic [`WAYS-1:0]                           is_renamed;

    assign rename_result = PRF_idx_from_free;
    assign rename_result_valid = PRF_idx_valid_from_free;
    assign is_renamed = PRF_idx_valid_from_free & RAT_idx_valid;

    RAT_RRAT_internal rat(
        /* inputs */
        .clock(clock),
        .reset(reset),
        .except(except),

        .rda_idx(rda_idx),                      // rename query 1
        .rdb_idx(rdb_idx),                      // rename query 2
        .RAT_dest_idx(RAT_dest_idx),            // ARF # to be renamed
        .RAT_idx_valid(RAT_idx_valid),

        .RRAT_ARF_idx(RRAT_ARF_idx),            // ARF # to be renamed
        .RRAT_idx_valid(RRAT_idx_valid),
        .RRAT_PRF_idx(RRAT_PRF_idx),            // PRF # 

        .PRF_idx_in(PRF_idx_from_free),         // from freelist
        .PRF_idx_in_valid(PRF_idx_valid_from_free),

        /* outputs */
        .RRAT_PRF_old(RRAT_PRF_old_from_rat),   // to free/valid list
        .rda_idx_out(rda_idx_out),              // PRF #
        .rdb_idx_out(rdb_idx_out)               // PRF #

        /* Debug Outputs */
        `ifdef DEBUG
        ,
        .RAT_reg_out(RAT_reg_out),
        .RRAT_reg_out(RRAT_reg_out)
        `endif
    );

    FreeList free(
        /* inputs */
        .clock(clock),
        .reset(reset),
        .except(except),

        .needed(RAT_idx_valid),                         // # of free entries consumed by RAT

        .reg_idx_wr_RRAT_new(RRAT_PRF_idx),             // From RRAT, these are entering RRAT
        .wr_en_RRAT(RRAT_idx_valid),                    // REQUIRES: en bits after mis-branch are low
        .reg_idx_wr_RRAT_old(RRAT_PRF_old_from_rat),    // From RRAT, these are leaving RRAT

        /* outputs */
        .reg_idx_out(PRF_idx_from_free),
        .reg_idx_out_valid(PRF_idx_valid_from_free)     // if partially valid, upper bits are high, lower bits are not

        /* Debug Outputs */
        `ifdef DEBUG
        ,
        .free_RAT_reg_out(free_RAT_reg_out),
        .free_RRAT_reg_out(free_RRAT_reg_out)
        `endif
    );

    ValidList vlist(
        /* inputs */
        .clock(clock),
        .reset(reset),
        .except(except),

        .rda_idx(rda_idx_out),                              // For Renaming
        .rdb_idx(rdb_idx_out),                              // For Renaming
        .reg_idx_wr_RAT(PRF_idx_from_free),             // From RAT, freshly renamed entries are invalid
        .wr_en_RAT(is_renamed),

        .reg_idx_wr_CDB(reg_idx_wr_CDB),                // From CDB, these are now valid
        .wr_en_CDB(wr_en_CDB),


        .reg_idx_wr_RRAT_new(RRAT_PRF_idx),             // From RRAT, these are entering RRAT
        .wr_en_RRAT(RRAT_idx_valid),  // need to change!  // REQUIRES: en bits after mis-branch are low
        .reg_idx_wr_RRAT_old(RRAT_PRF_old_from_rat),    // From RRAT, these are leaving RRAT

        /* outputs */
        .rda_valid(rda_valid),
        .rdb_valid(rdb_valid)

        /* Debug Outputs */
        `ifdef DEBUG
        ,
        .valid_RAT_reg_out(valid_RAT_reg_out),
        .valid_RRAT_reg_out(valid_RRAT_reg_out)
        `endif
    );

endmodule

// todo: optimize this
module RAT_RRAT_internal(
    input                                       clock,
    input                                       reset,
    input                                       except,

    input [`WAYS-1:0] [4:0]                     rda_idx,            // rename query 1
    input [`WAYS-1:0] [4:0]                     rdb_idx,            // rename query 2
    input [`WAYS-1:0] [4:0]                     RAT_dest_idx,       // ARF # to be renamed
    input [`WAYS-1:0]                           RAT_idx_valid,

    input [`WAYS-1:0] [4:0]                     RRAT_ARF_idx,       // ARF # to be renamed
    input [`WAYS-1:0]                           RRAT_idx_valid, 
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        RRAT_PRF_idx,       // PRF # 

    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        PRF_idx_in,         // from freelist
    input [`WAYS-1:0]                           PRF_idx_in_valid,   // from freelist

    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] RRAT_PRF_old,       // to free/valid list
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] rda_idx_out,        // PRF # 
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] rdb_idx_out         // PRF #

    /* Debug Outputs */
    `ifdef DEBUG
    ,
    output logic [31:0] [$clog2(`PRF)-1:0]      RAT_reg_out,
    output logic [31:0] [$clog2(`PRF)-1:0]      RRAT_reg_out
    `endif
);

reg [31:0] [$clog2(`PRF)-1:0] RAT_reg;
wire [31:0] [$clog2(`PRF)-1:0] RAT_next;
reg [31:0] [$clog2(`PRF)-1:0] RRAT_reg;
logic [31:0] [$clog2(`PRF)-1:0] RRAT_next;
wire [31:0] [$clog2(`PRF)-1:0] RAT_RRAT_rst;
wire [`WAYS-1:0] is_renamed;

wire [`WAYS:0] [31:0] [$clog2(`PRF)-1:0] RAT_tmp;
wire [`WAYS-1:0] [31:0] RAT_tmp_overwrite;


`ifdef DEBUG
assign RAT_reg_out = RAT_reg;
assign RRAT_reg_out = RRAT_reg;
`endif

assign is_renamed = RAT_idx_valid & PRF_idx_in_valid;





generate;
    genvar gi, gj;
    // overwrite mask
    for (gi = 0; gi < `WAYS; ++gi) begin
        assign RAT_tmp_overwrite[gi] = is_renamed[gi] ? {32'h1 << RAT_dest_idx[gi]} : 32'h0;
    end

    // RAT temp
    // tmp[0]
    assign RAT_tmp[0] = RAT_reg;
    // others
    for (gi = 0; gi < `WAYS; ++gi) begin
        for (gj = 0; gj < 32; ++gj) begin
            assign RAT_tmp[gi + 1][gj] = RAT_tmp_overwrite[gi][gj] ? PRF_idx_in[gi] : RAT_tmp[gi][gj];
        end
    end

    // read
    for (gi = 0; gi < `WAYS; ++gi) begin
        assign rda_idx_out[gi] = RAT_tmp[gi][rda_idx[gi]];
        assign rdb_idx_out[gi] = RAT_tmp[gi][rdb_idx[gi]];
    end

    // RAT_next
    assign RAT_next = RAT_tmp[`WAYS];

    // reset values
    for (gi = 0; gi < 32; ++gi) begin
        assign RAT_RRAT_rst[gi] = gi;
    end


endgenerate


// // RAT_next
// always_comb begin
//     RAT_next = RAT_reg;
//     for (int i = 0; i < `WAYS; ++i) begin
//         if (is_renamed[i]) begin
//             RAT_next[RAT_dest_idx[i]] = PRF_idx_in[i];
//         end
//     end
// end

// Forwarding performed here
generate
    for (gi = 0; gi < `WAYS; ++gi) begin
        always_comb begin
            RRAT_PRF_old[gi] = RRAT_reg[RRAT_ARF_idx[gi]];
            for (int j = 0; j < gi; ++j) begin
                if (PRF_idx_in_valid[j] && (RRAT_ARF_idx[gi] == RRAT_ARF_idx[j])) begin
                    RRAT_PRF_old[gi] = RRAT_PRF_idx[j];
                end
            end
        end
    end
endgenerate


// RRAT_next
always_comb begin
    RRAT_next = RRAT_reg;
    for (int i = 0; i < `WAYS; ++i) begin
        if (RRAT_idx_valid[i]) begin
            RRAT_next[RRAT_ARF_idx[i]] = RRAT_PRF_idx[i];
        end
    end
end



always_ff @ (posedge clock) begin
    if (reset) begin
        RAT_reg <= RAT_RRAT_rst;
        RRAT_reg <= RAT_RRAT_rst;
    end
    else if (except) begin
        RAT_reg <= RRAT_next;
        RRAT_reg <= RRAT_next;
    end
    else begin
        RAT_reg <= RAT_next;
        RRAT_reg <= RRAT_next;
    end
end 
    
endmodule