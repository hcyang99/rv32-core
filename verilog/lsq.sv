
typedef struct packed {
    logic [1:0]                                 size;
    logic [31:0]                                data;
    logic                                       data_valid;
    logic [$clog2(`ROB)-1:0]                    ROB_idx;
    logic [15:0]                                addr;
    logic                                       addr_valid;
    logic                                       valid;
} sq_entry;

module LSQ(
    input                                       clock,
    input                                       reset,
    input                                       except,

    // CDB
    input [`WAYS-1:0] [31:0]                    CDB_Data,
  	input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx,
  	input [`WAYS-1:0]                           CDB_valid,

    // ALU
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        ALU_ROB_idx,
    input [`WAYS-1:0]                           ALU_is_valid,
    input [`WAYS-1:0]                           ALU_is_ls,      // 1 = load, 0 = store (do we need this since we have ROB idx?)
    input [`WAYS-1:0] [15:0]                    ALU_data,

    // SQ
    input [`WAYS-1:0] [1:0]                 st_size,
    input [`WAYS-1:0] [31:0]                    st_data,
    input [`WAYS-1:0]                           st_data_valid,
    input [`WAYS-1:0]                           st_en,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        st_ROB_idx,
    input                                       commit,   // from ROB, whether head of SQ should commit

    // LQ
    input [`WAYS-1:0] [1:0]                 ld_size,
    input [`WAYS-1:0]                           ld_en,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        ld_ROB_idx,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        ld_PRF_idx,

    // feedback from DCache
    input [`LSQSZ-1:0]                          dc_feedback,
    input [31:0]                                dc_data,        // from dcache, on the same cycle
    input [`LSQSZ-1:0]                          mem_feedback,
    input [31:0]                                mem_data,       // from mem, only overwrites "waiting" entries

    // LSQ head/tail
    output logic [$clog2(`LSQSZ):0]           sq_num_free,
    output logic [$clog2(`LSQSZ):0]           lq_num_free,

    // write to DCache
    output logic                                wr_en,
    output logic [2:0]                          wr_offset,
    output logic [4:0]                          wr_idx,
    output logic [7:0]                          wr_tag,
    output logic [31:0]                         wr_data,
    output logic [1:0]                      wr_size,

    // read from DCache
    output logic [2:0]                          rd_offset,
    output logic [4:0]                          rd_idx,
    output logic [7:0]                          rd_tag,
    output logic [1:0]                      rd_size,
    output logic                                rd_en,
    output logic [`LSQSZ-1:0]                   rd_gnt,

    // LQ to CDB, highest priority REQUIRED
    output logic [31:0]                         CDB_Data_out,
  	output logic [$clog2(`PRF)-1:0]             CDB_PRF_idx_out,
  	output logic                                CDB_valid_out,
    output logic [$clog2(`ROB)-1:0]             CDB_ROB_idx_out,
  	output logic                                CDB_direction_out,
  	output logic [31:0]                         CDB_target_out
);

    wire [`LSQSZ-1:0] [1:0]                    store_sz;
    wire [`LSQSZ-1:0] [15:0]                       store_addr;
    wire [`LSQSZ-1:0] [31:0]                       store_data;
    wire [`LSQSZ-1:0]                              store_data_valid;
    wire [`LSQSZ-1:0]                              store_addr_valid;
    wire [`WAYS-1:0] [$clog2(`LSQSZ)-1:0]          ld_sq_tail;

    // For store queue
    logic [$clog2(`LSQSZ)-1:0]                      sq_head;
    logic [$clog2(`LSQSZ)-1:0]                      sq_tail;
    sq_entry [`LSQSZ-1:0]                           sq_entries;

    genvar gi, gj;
    generate;
        for (gi = 0; gi < `LSQSZ; ++gi) begin
            assign store_sz[gi] = sq_entries[gi].size;
            assign store_addr[gi] = sq_entries[gi].addr;
            assign store_addr_valid[gi] = sq_entries[gi].addr_valid;
            assign store_data[gi] = sq_entries[gi].data;
            assign store_data_valid[gi] = sq_entries[gi].data_valid;
        end

        assign ld_sq_tail[0] = sq_tail;
        for (gi = 1; gi < `WAYS; ++gi) begin
            assign ld_sq_tail[gi] = (ld_sq_tail[gi - 1] == `LSQSZ - 1) ? 0 : ld_sq_tail[gi - 1] + 1;
        end
    endgenerate

    wire [`WAYS-1:0] [1:0]                 ld_size_in;
    wire [`WAYS-1:0] [$clog2(`ROB)-1:0]        ld_ROB_idx_in;
    wire [`WAYS-1:0] [$clog2(`PRF)-1:0]        ld_PRF_idx_in;
    generate;
        for (gi = 0; gi < `WAYS; ++gi) begin
            assign ld_size_in[gi] = ld_en[gi] ? ld_size[gi] : 0;
            assign ld_ROB_idx_in[gi] = ld_en[gi] ? ld_ROB_idx[gi] : 0;
            assign ld_PRF_idx_in[gi] = ld_en[gi] ? ld_PRF_idx[gi] : 0;
        end
    endgenerate

    LQ lq(
        .clock(clock),
        .reset(reset),
        .except(except),

        // SQ
        .store_sz(store_sz),
        .store_addr(store_addr),
        .store_data(store_data),
        .store_addr_valid(store_addr_valid),
        .store_data_valid(store_data_valid),
        .sq_head(sq_head),

        // issue
        .ld_size(ld_size_in),
        .ld_en(ld_en),
        .ld_ROB_idx(ld_ROB_idx_in),
        .ld_PRF_idx(ld_PRF_idx_in),
        .sq_tail_in(ld_sq_tail),

        // ALU
        .ALU_ROB_idx(ALU_ROB_idx),
        .ALU_is_valid(ALU_is_valid),
        .ALU_is_ls(ALU_is_ls),
        .ALU_data(ALU_data),

        // feedback from DCache
        .dc_feedback(dc_feedback),
        .dc_data(dc_data),        // from dcache, on the same cycle
        .mem_feedback(mem_feedback),
        .mem_data(mem_data),       // from mem, only overwrites "waiting" entries

        // outputs
        .lq_num_free_out(lq_num_free),

        // read from DCache
        .rd_offset(rd_offset),
        .rd_idx(rd_idx),
        .rd_tag(rd_tag),
        .rd_size(rd_size),
        .rd_en(rd_en),
        .rd_gnt(rd_gnt),

        // LQ to CDB, highest priority REQUIRED
        .CDB_Data(CDB_Data_out),
        .CDB_PRF_idx(CDB_PRF_idx_out),
        .CDB_valid(CDB_valid_out),
        .CDB_ROB_idx(CDB_ROB_idx_out),
        .CDB_direction(CDB_direction_out),
        .CDB_target(CDB_target_out)
);

    store_queue sq(
        .clock,
        .reset,
        .except,
        .commit,

        .size(st_size),
        .data(st_data),
        .data_valid(st_data_valid),
        .ROB_idx(st_ROB_idx),
        .enable(st_en),

        .CDB_Data,
        .CDB_PRF_idx,
        .CDB_valid,

        .ALU_ROB_idx,
        .ALU_is_valid(ALU_is_valid & ALU_is_ls),
        .ALU_data(ALU_data),

        .sq_head,
        .sq_tail,

        .write_en(wr_en),
        .write_addr({wr_tag, wr_idx, wr_offset}),
        .write_data(wr_data),
        .write_size(wr_size),
        
        .sq_out(sq_entries),
        .num_free(sq_num_free)
    );

endmodule
