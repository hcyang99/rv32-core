
// typedef struct packed {
//     logic `MEM_SIZE                                 size;
//     logic [63:0]                                    data;
//     logic                                           data_valid;
//     logic [$clog2(`ROB)-1:0]                        ROB_idx;
//     logic [15:0]                                    addr;
//     logic                                           addr_valid;
//     logic                                           valid;
// } sq_entry;

module store_queue(
    input                                           clock,
    input                                           reset,
    input                                           except,
    input                                           commit,

    // From dispatch
    input [`WAYS-1:0] [1:0]                         size,
    input [`WAYS-1:0] [31:0]                        data,
    input [`WAYS-1:0]                               data_valid,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]            ROB_idx,
    input [`WAYS-1:0]                               enable,

    // From CDB
    input [`WAYS-1:0] [31:0]                        CDB_Data,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]            CDB_PRF_idx,
    input [`WAYS-1:0]                               CDB_valid,

    // From ALU
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]            ALU_ROB_idx,
    input [`WAYS-1:0]                               ALU_is_valid,
    input [`WAYS-1:0] [15:0]                        ALU_data,

    // To debug
    output reg [$clog2(`LSQSZ)-1:0]                 sq_head,
    output reg [$clog2(`LSQSZ)-1:0]                 sq_tail,

    // To D$
    output logic                                    write_en,
    output logic [15:0]                             write_addr,
    output logic [31:0]                             write_data,
    output logic [1:0]                              write_size,
    
    // To LB
    output sq_entry [`LSQSZ-1:0]                    sq_out,

    // To flow control logic (stall)
    output reg [$clog2(`LSQSZ):0]                   num_free
);

    reg [`LSQSZ-1:0] [1:0]                            size_reg;
    reg [`LSQSZ-1:0] [31:0]                           data_reg;
    reg [`LSQSZ-1:0]                                  data_valid_reg;
    reg [`LSQSZ-1:0] [$clog2(`ROB)-1:0]               ROB_idx_reg;
    reg [`LSQSZ-1:0] [15:0]                           addr_reg;
    reg [`LSQSZ-1:0]                                  addr_valid_reg;
    reg [`LSQSZ-1:0]                                  valid_reg;

    genvar gi, gj;

    // output to LB
    generate;
        for (gi = 0; gi < `LSQSZ; ++gi) begin
            assign sq_out[gi].size = size_reg[gi];
            assign sq_out[gi].data = data_reg[gi];
            assign sq_out[gi].data_valid = data_valid_reg[gi];
            assign sq_out[gi].ROB_idx = ROB_idx_reg[gi];
            assign sq_out[gi].addr = addr_reg[gi];
            assign sq_out[gi].addr_valid = addr_valid_reg[gi];
            assign sq_out[gi].valid = valid_reg[gi];
        end
    endgenerate


    // head and tail
    reg [`LSQSZ-1:0] sq_head_internal;  // one-hot encoding
    reg [`LSQSZ-1:0] sq_tail_internal;
    wire [`LSQSZ-1:0] sq_head_internal_next;
    wire [`LSQSZ-1:0] sq_tail_internal_next;
    wire [`WAYS:0] [`LSQSZ-1:0] sq_tail_internal_tmp;
    wor [$clog2(`LSQSZ)-1:0] sq_head_next;
    wor [$clog2(`LSQSZ)-1:0] sq_tail_next;

    assign sq_head_internal_next = commit ? 
        {sq_head_internal[`LSQSZ-2:0], sq_head_internal[`LSQSZ-1]} : sq_head_internal;
    
    assign sq_tail_internal_tmp[0] = sq_tail_internal;
    generate;
        for (gi = 1; gi <= `WAYS; ++gi) begin
            assign sq_tail_internal_tmp[gi] = enable[gi-1] ? 
                {sq_tail_internal_tmp[gi-1][`LSQSZ-2:0], sq_tail_internal_tmp[gi-1][`LSQSZ-1]} :
                sq_tail_internal_tmp[gi-1];
        end
    endgenerate
    assign sq_tail_internal_next = sq_tail_internal_tmp[`WAYS];

    generate;
        for (gi = 0; gi < `LSQSZ; ++gi) begin
            assign sq_head_next = sq_head_internal_next[gi] ? gi : 0;
            assign sq_tail_next = sq_tail_internal_next[gi] ? gi : 0;
        end
    endgenerate

    always_ff @(posedge clock) begin
        if (reset | except) begin
            sq_head <= 0;
            sq_tail <= 0;
            sq_head_internal <= `LSQSZ'b1;
            sq_tail_internal <= `LSQSZ'b1;
        end
        else begin
            sq_head <= sq_head_next;
            sq_tail <= sq_tail_next;
            sq_head_internal <= sq_head_internal_next;
            sq_tail_internal <= sq_tail_internal_next;
        end
    end

    // check for CDB/ALU hit
    wire [`WAYS-1:0] [`LSQSZ-1:0] CDB_hit;
    wire [`WAYS-1:0] [`LSQSZ-1:0] ALU_hit;
    generate;
        for (gi = 0; gi < `WAYS; ++gi) begin
            for (gj = 0; gj < `LSQSZ; ++gj) begin
                assign CDB_hit[gi][gj] = valid_reg[gi] & CDB_valid[gi] & CDB_PRF_idx[gi] == data_reg[gj] & (~data_valid_reg[gj]);
                assign ALU_hit[gi][gj] = valid_reg[gi] & ALU_is_valid[gi] & ALU_ROB_idx[gi] == ROB_idx_reg[gj] & (~addr_valid_reg[gj]);
            end
        end
    endgenerate

    // write to regs
    wand [`LSQSZ-1:0] general_hold;
    wand [`LSQSZ-1:0] cdb_hold;
    wand [`LSQSZ-1:0] alu_hold;
    assign general_hold = ~(commit ? sq_head_internal : `LSQSZ'b0); // going out
    assign cdb_hold = general_hold;
    assign alu_hold = general_hold;
    generate;
        for (gi = 0; gi < `WAYS; ++gi) begin
            assign general_hold = ~(enable[gi] ? sq_tail_internal_tmp[gi] : `LSQSZ'b0); // coming in
            assign cdb_hold = ~CDB_hit[gi];
            assign alu_hold = ~ALU_hit[gi];
        end
    endgenerate

    wor [`LSQSZ-1:0] [1:0]                        size_next;
    wor [`LSQSZ-1:0] [31:0]                           data_next;
    wor [`LSQSZ-1:0]                                  data_valid_next;
    wor [`LSQSZ-1:0] [$clog2(`ROB)-1:0]               ROB_idx_next;
    wor [`LSQSZ-1:0] [15:0]                           addr_next;
    wor [`LSQSZ-1:0]                                  addr_valid_next;
    wor [`LSQSZ-1:0]                                  valid_next;

    // clear invalid inputs
    wire [`WAYS-1:0] [1:0]                     size_tmp;
    wire [`WAYS-1:0] [31:0]                        data_tmp;
    wire [`WAYS-1:0]                               data_valid_tmp;
    wire [`WAYS-1:0] [$clog2(`ROB)-1:0]            ROB_idx_tmp;
    generate;
        for (gi = 0; gi < `WAYS; ++gi) begin
            assign size_tmp[gi] = enable[gi] ? size[gi] : 0;
            assign data_tmp[gi] = enable[gi] ? data[gi] : 0;
            assign data_valid_tmp[gi] = enable[gi] ? data_valid[gi] : 0;
            assign ROB_idx_tmp[gi] = enable[gi] ? ROB_idx[gi] : 0;
        end
    endgenerate

    // Non CDB/ALU
    generate;
        // hold original values, clear going head and coming tail
        for (gi = 0; gi < `LSQSZ; ++gi) begin
            assign size_next[gi] = general_hold[gi] ? size_reg[gi] : 0;
            assign ROB_idx_next[gi] = general_hold[gi] ? ROB_idx_reg[gi] : 0;
            assign valid_next[gi] = general_hold[gi] ? valid_reg[gi] : 0;
        end
        // going head; do nothing
        // coming tails
        for (gi = 0; gi < `LSQSZ; ++gi) begin
            for (gj = 0; gj < `WAYS; ++gj) begin
                assign size_next[gi] = sq_tail_internal_tmp[gj][gi] ? size_tmp[gj] : 0;
                assign ROB_idx_next[gi] = sq_tail_internal_tmp[gj][gi] ? ROB_idx_tmp[gj] : 0;
                assign valid_next[gi] = sq_tail_internal_tmp[gj][gi] ? enable[gj] : 0;
            end
        end
    endgenerate

    // ALU
    generate;
        // hold original values, clear going head and coming tail
        for (gi = 0; gi < `LSQSZ; ++gi) begin
            assign addr_next[gi] = alu_hold[gi] ? addr_reg[gi] : 0;
            assign addr_valid_next[gi] = alu_hold[gi] ? addr_valid_reg[gi] : 0;
        end
        // going head; do nothing
        // coming tails; do nothing
        // ALU hits
        for (gi = 0; gi < `WAYS; ++gi) begin
            for (gj = 0; gj < `LSQSZ; ++gj) begin
                assign addr_next[gj] = ALU_hit[gi][gj] ? ALU_data[gi] : 0;
                assign addr_valid_next[gj] = ALU_hit[gi][gj];
            end
        end
    endgenerate

    // CDB
    generate;
        // hold original values, clear going head and coming tail
        for (gi = 0; gi < `LSQSZ; ++gi) begin
            assign data_next[gi] = cdb_hold[gi] ? data_reg[gi] : 0;
            assign data_valid_next[gi] = cdb_hold[gi] ? data_valid_reg[gi] : 0;
        end
        // going head; do nothing
        // coming tails
        for (gi = 0; gi < `LSQSZ; ++gi) begin
            for (gj = 0; gj < `WAYS; ++gj) begin
                assign data_next[gi] = sq_tail_internal_tmp[gj][gi] ? data_tmp[gj] : 0;
                assign data_valid_next[gi] = sq_tail_internal_tmp[gj][gi] ? data_valid_tmp[gj] : 0;
            end
        end
        // CDB hits
        for (gi = 0; gi < `WAYS; ++gi) begin
            for (gj = 0; gj < `LSQSZ; ++gj) begin
                assign data_next[gj] = CDB_hit[gi][gj] ? CDB_Data[gi] : 0;
                assign data_valid_next[gj] = CDB_hit[gi][gj];
            end
        end
    endgenerate

    always_ff @(posedge clock) begin
        if (reset | except) begin
            size_reg <= 0;
            data_reg <= 0;
            data_valid_reg <= 0;
            ROB_idx_reg <= 0;
            addr_reg <= 0;
            addr_valid_reg <= 0;
            valid_reg <= 0;
        end
        else begin
            size_reg <= size_next;
            data_reg <= data_next;
            data_valid_reg <= data_valid_next;
            ROB_idx_reg <= ROB_idx_next;
            addr_reg <= addr_next;
            addr_valid_reg <= addr_valid_next;
            valid_reg <= valid_next;
        end
    end

    // head reg
    reg [1:0]                               sq_head_size_reg;
    reg [31:0]                              sq_head_data_reg;
    reg                                     sq_head_data_valid_reg;
    reg [$clog2(`ROB)-1:0]                  sq_head_ROB_idx_reg;
    reg [15:0]                              sq_head_addr_reg;
    reg                                     sq_head_addr_valid_reg;
    reg                                     sq_head_valid_reg;

    wor [1:0]                               sq_head_size_next;
    wor [31:0]                              sq_head_data_next;
    wor                                     sq_head_data_valid_next;
    wor [$clog2(`ROB)-1:0]                  sq_head_ROB_idx_next;
    wor [15:0]                              sq_head_addr_next;
    wor                                     sq_head_addr_valid_next;
    wor                                     sq_head_valid_next;

    generate;
        for (gi = 0; gi < `LSQSZ; ++gi) begin
            assign sq_head_size_next = sq_head_internal_next[gi] ? size_next[gi] : 0;
            assign sq_head_data_next = sq_head_internal_next[gi] ? data_next[gi] : 0;
            assign sq_head_data_valid_next = sq_head_internal_next[gi] ? data_valid_next[gi] : 0;
            assign sq_head_ROB_idx_next = sq_head_internal_next[gi] ? ROB_idx_next[gi] : 0;
            assign sq_head_addr_next = sq_head_internal_next[gi] ? addr_next[gi] : 0;
            assign sq_head_addr_valid_next = sq_head_internal_next[gi] ? addr_valid_next[gi] : 0;
            assign sq_head_valid_next = sq_head_internal_next[gi] ? valid_next[gi] : 0;
        end
    endgenerate

    always_ff @(posedge clock) begin
        if (reset | except) begin
            sq_head_size_reg <= 0;
            sq_head_data_reg <= 0;
            sq_head_data_valid_reg <= 0;
            sq_head_ROB_idx_reg <= 0;
            sq_head_addr_reg <= 0;
            sq_head_addr_valid_reg <= 0;
            sq_head_valid_reg <= 0;
        end
        else begin
            sq_head_size_reg <= sq_head_size_next;
            sq_head_data_reg <= sq_head_data_next;
            sq_head_data_valid_reg <= sq_head_data_valid_next;
            sq_head_ROB_idx_reg <= sq_head_ROB_idx_next;
            sq_head_addr_reg <= sq_head_addr_next;
            sq_head_addr_valid_reg <= sq_head_addr_valid_next;
            sq_head_valid_reg <= sq_head_valid_next;
        end
    end

    // output to dcache
    assign write_en = commit ? sq_head_valid_reg : 0;
    assign write_addr = commit ? sq_head_addr_reg : 0;
    assign write_data = commit ? sq_head_data_reg : 0;
    assign write_size = commit ? sq_head_size_reg : 0;


    // num free
    logic [$clog2(`WAYS):0] num_dispatched;
    wire [$clog2(`LSQSZ):0] num_free_next;
    assign num_free_next = (num_free - num_dispatched) + commit;

    always_comb begin
        num_dispatched = 0;
        foreach(enable[i]) begin
            num_dispatched += enable[i];
        end
    end

    always_ff @(posedge clock) begin
        if (reset | except) begin
            num_free <= `LSQSZ;
        end
        else begin
            num_free <= num_free_next;
        end
    end

endmodule
