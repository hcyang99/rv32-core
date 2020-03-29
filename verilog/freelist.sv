//`define WAYS    4
//`define XLEN    32
//`define PRF     64
`define DEBUG

// optimized
module FreeList(
    input                                       clock,
    input                                       reset,
    input                                       except,
    input [`WAYS-1:0]                           needed,                 // # of free entries consumed by RAT

    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_RRAT_new,    // From RRAT, these are entering RRAT
    input [`WAYS-1:0]                           wr_en_RRAT,             // REQUIRES: en bits after mis-branch are low
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_RRAT_old,    // From RRAT, these are leaving RRAT

    output reg [`WAYS-1:0] [$clog2(`PRF)-1:0]   reg_idx_out,
    output reg [`WAYS-1:0]                      reg_idx_out_valid       // if partially valid, upper bits are high, lower bits are not

    /* Debug Outputs */
    `ifdef DEBUG
    ,
    output logic [`PRF-1:0]                     free_RAT_reg_out,
    output logic [`PRF-1:0]                     free_RRAT_reg_out
    `endif
);

logic [`WAYS-1:0] [$clog2(`PRF)-1:0] reg_idx_out_raw;
logic [`WAYS-1:0] reg_idx_out_valid_raw;
logic [`PRF-1:0] free_list_rst;
reg [`PRF-1:0] free_RAT_reg;
logic [`PRF-1:0] free_RAT_next_decreased;
logic [`PRF-1:0] free_RAT_next_increased;
logic [`PRF-1:0] free_RAT_next;
reg [`PRF-1:0] free_RRAT_reg;
logic [`PRF-1:0] free_RRAT_next;
logic [`PRF-1:0] free_RRAT_next_decreased;
logic [`PRF-1:0] free_RRAT_next_increased;
logic [$clog2(`PRF)-1:0] needed_cnt;

`ifdef DEBUG
assign free_RAT_reg_out = free_RAT_reg;
assign free_RRAT_reg_out = free_RRAT_reg;
`endif


assign free_RRAT_next = (free_RRAT_reg & free_RRAT_next_decreased) | free_RRAT_next_increased;

// free_RRAT_next; optimized
always_comb begin
    free_RRAT_next_decreased = free_RRAT_reg;
    free_RRAT_next_increased = free_RRAT_reg;
    free_RAT_next_increased = free_RAT_reg;
    for (int i = 0; i < `WAYS; ++i) begin
        if (wr_en_RRAT[i]) begin
            free_RRAT_next_decreased[reg_idx_wr_RRAT_new[i]] = 1'b0;
            free_RRAT_next_increased[reg_idx_wr_RRAT_old[i]] = 1'b1;
            free_RAT_next_increased[reg_idx_wr_RRAT_old[i]] = 1'b1;
        end
    end
end

genvar gi;

// always_comb begin
//     reg_idx_out_valid_raw = 0;
//     reg_idx_out_raw = 0;
//     for (int i = 0, int j = 0; i < `PRF; ++i) begin
//         if (free_RAT_reg[i] && j < `WAYS) begin
//             reg_idx_out_valid_raw[j] = 1'b1;
//             reg_idx_out_raw[j] = i;
//             ++j;
//         end
//     end
// end

freelist_psel_gen ps(
    .req(free_RAT_reg),
    .result(reg_idx_out_raw),
    .result_valid(reg_idx_out_valid_raw),
    .gnt_bus(),
    .empty()
);

generate;
    for (gi = 0; gi < `WAYS; ++gi) begin
        always_ff @ (posedge clock) begin
            if (reset | except) begin
                reg_idx_out[gi] <= 0;
                reg_idx_out_valid[gi] <= 0;
            end
            else begin
                reg_idx_out[gi] <= reg_idx_out_raw[gi];
                reg_idx_out_valid[gi] <= reg_idx_out_valid_raw[gi];
            end
        end
    end
endgenerate

assign free_RAT_next = (free_RAT_reg & free_RAT_next_decreased) | free_RAT_next_increased;

// free_RAT_next
always_comb begin
    free_RAT_next_decreased = free_RAT_reg;
    for (int i = 0; i < `WAYS; ++i) begin
        if (reg_idx_out_valid[i] & needed[i]) begin
             free_RAT_next_decreased[reg_idx_out[i]] = 1'b0;
        end
    end
end

// reset values
generate;
    for (gi = 0; gi < `PRF; ++gi) begin
        assign free_list_rst[gi] = gi >= 32;
    end
endgenerate


always_ff @ (posedge clock) begin
    if (reset) begin    // on start-up
        free_RAT_reg <= free_list_rst;
        free_RRAT_reg <= free_list_rst;
    end
    else if (except) begin  // on mis-branch
        free_RRAT_reg <= free_RRAT_next;
        free_RAT_reg <= free_RRAT_next;
    end
    else begin  // normal
        free_RAT_reg <= free_RAT_next;
        free_RRAT_reg <= free_RRAT_next;
    end
end

endmodule

