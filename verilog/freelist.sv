`define WAYS    4
`define XLEN    32
`define PRF     64

module FreeList(
    input                                       clock,
    input                                       reset,
    input                                       except,
    input [`WAYS-1:0]                           needed,                 // # of free entries consumed by RAT

    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_RRAT_new,     // From RRAT, these are entering RRAT
    input [`WAYS-1:0]                           wr_en_RRAT_new,         // REQUIRES: en bits after mis-branch are low
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        reg_idx_wr_RRAT_old,     // From RRAT, these are leaving RRAT
    input [`WAYS-1:0]                           wr_en_RRAT_old,

    output logic [$clog2(`WAYS)-1:0]            available,
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] reg_idx_out,
    output logic [`WAYS-1:0]                    reg_idx_out_valid
);

reg [`PRF-1:0] free_RAT_reg;
logic [`PRF-1:0] free_RAT_next;
reg [`PRF-1:0] free_RRAT_reg;
logic [`PRF-1:0] free_RRAT_next;
reg     [$clog2(`PRF)-1:0] available_reg;
logic [$clog2(`PRF)-1:0] available_next;
logic [$clog2(`PRF)-1:0] available_reduced;
logic [$clog2(`PRF)-1:0] available_increased;
logic [$clog2(`PRF)-1:0] needed_cnt;

assign available = available_reg >= `WAYS ? `WAYS : available_reg;

always_comb begin
    needed_cnt = 0;
    for (int i = 0; i < `WAYS; ++i) begin
        if (needed[i])
            ++needed_cnt;
    end
end

assign available_reduced = (needed_cnt > available ? available : needed_cnt);

// generating output idx, out valid, available_reduced and free_RAT_next
always_comb begin
    free_RAT_next = free_RAT_reg;
    reg_idx_out_valid = 0;
    reg_idx_out = 0;
    for (int i = 0, int j = 0; i < `PRF; ++i) begin
        if (free_RAT_reg[i] && j < `WAYS) begin
            reg_idx_out[j] = i;
            if (j < available && needed[j]) begin
                reg_idx_out_valid[j] = 1'b1;
                free_RAT_next[i] = 1'b0;
            end 
            ++j;
        end
    end
    for (int i = 0; i < `WAYS; ++i) begin
        if (wr_en_RRAT_old[i])
            free_RAT_next[reg_idx_wr_RRAT_old[i]] = 1'b1;
    end
end

// free_RRAT_next and available_increased
always_comb begin
    available_increased = 0;
    free_RRAT_next = free_RRAT_reg;
    for (int i = 0; i < `WAYS; ++i) begin
        if (wr_en_RRAT_new[i])
            free_RRAT_next[reg_idx_wr_RRAT_new[i]] = 1'b0;
        if (wr_en_RRAT_old[i]) begin
            free_RRAT_next[reg_idx_wr_RRAT_old[i]] = 1'b1;
            ++available_increased;
        end
    end
end

assign available_next = available - available_reduced + available_increased;


always_ff @ (posedge clock) begin
    if (reset) begin    // on start-up
        available_reg <= `PRF - 32;
        for (int i = 0; i < `PRF; ++i) begin
            if (i < 32) begin
                free_RAT_reg[i] <= 1'b0;
                free_RRAT_reg[i] <= 1'b0;
            end
            else begin
                free_RAT_reg[i] <= 1'b1;
                free_RRAT_reg[i] <= 1'b1;
            end
        end
    end
    else if (except) begin  // on mis-branch
        available_reg <= `PRF - 32;
        free_RRAT_reg <= free_RRAT_next;
        free_RAT_reg <= free_RRAT_next;
    end
    else begin  // normal
        available_reg <= available_next;
        free_RAT_reg <= free_RAT_next;
        free_RRAT_reg <= free_RRAT_next;
    end
end

endmodule

