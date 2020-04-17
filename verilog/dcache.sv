// cachemem32x64
// write-back no-write-allocate dcache


module dcache(
    input                       clock,
    input                       reset, 

    input                       proc_wr_en,
    input [2:0]                 proc_wr_offset,
    input [4:0]                 proc_wr_idx,
    input [7:0]                 proc_wr_tag,
    input [63:0]                proc_wr_data, 
    input [1:0]                 proc_wr_size,

    input                       mem_wr_en,
    input [4:0]                 mem_wr_idx,
    input [7:0]                 mem_wr_tag,
    input [63:0]                mem_wr_data, 

    input                       rd_en,
    input [2:0]                 rd_offset,
    input [4:0]                 rd_idx,
    input [7:0]                 rd_tag,
    input [1:0]                 rd_size,
    input [`LSQSZ-1:0]          rd_gnt,

    output logic [63:0]         rd_data,
    output logic [`LSQSZ-1:0]   rd_feedback,

    // write dirty entries back
    output logic                wb_en_out,
    output logic [15:0]         wb_addr_out,
    output logic [63:0]         wb_data_out,
    output logic [1:0]          wb_size_out,

    // write directly to mem on wr miss
    output logic                wr_en_out,
    output logic [15:0]         wr_addr_out,
    output logic [63:0]         wr_data_out,
    output logic [1:0]          wr_size_out,

    // read from mem on rd miss
    output logic                rd_en_out,
    output logic [15:0]         rd_addr_out,
    output logic [1:0]          rd_size_out,
    output logic [`LSQSZ-1:0]   rd_gnt_out
);

reg [31:0] [63:0] data;
reg [31:0] [7:0] tags; 
reg [31:0] valid;
reg [31:0] dirty;
reg [1:0] [12:0] victim_tags;
reg [1:0] [63:0] victim_data;
reg [1:0] victim_valid;
reg [1:0] victim_dirty;
reg victim_lru;

wire [63:0] rd_data_cache_raw;
wire [63:0] rd_data_cache;
wire [63:0] rd_data_victim;

logic [63:0] proc_wr_mask;
logic [63:0] proc_rd_mask;

logic [1:0] [12:0] victim_tags_after_wr;
logic [1:0] [63:0] victim_data_after_wr;
logic [1:0] victim_valid_after_wr;
logic [1:0] victim_dirty_after_wr;
logic victim_lru_after_wr;
logic [31:0] [63:0] data_after_wr;
logic [31:0] [7:0] tags_after_wr; 
logic [31:0] valid_after_wr;
logic [31:0] dirty_after_wr;

logic [1:0] [12:0] victim_tags_after_rd;
logic [1:0] [63:0] victim_data_after_rd;
logic [1:0] victim_valid_after_rd;
logic [1:0] victim_dirty_after_rd;
logic victim_lru_after_rd;
logic [31:0] [63:0] data_after_rd;
logic [31:0] [7:0] tags_after_rd; 
logic [31:0] valid_after_rd;
logic [31:0] dirty_after_rd;

logic [1:0] [12:0] victim_tags_after_mem;
logic [1:0] [63:0] victim_data_after_mem;
logic [1:0] victim_valid_after_mem;
logic [1:0] victim_dirty_after_mem;
logic victim_lru_after_mem;
logic [31:0] [63:0] data_after_mem;
logic [31:0] [7:0] tags_after_mem; 
logic [31:0] valid_after_mem;
logic [31:0] dirty_after_mem;

logic swap_dirty_tmp_wr;
logic [63:0] swap_data_tmp_wr;
logic [7:0] swap_tag_tmp_wr;
logic swap_dirty_tmp_rd;
logic [63:0] swap_data_tmp_rd;
logic [7:0] swap_tag_tmp_rd;

wire rd_cache_hit;
wire [1:0] rd_victim_match;
wire rd_victim_hit;
wire wr_cache_hit;
wire [1:0] wr_victim_match;
wire wr_victim_hit;
wor mem_cache_conflict;

always_comb begin
    case (proc_wr_size)
        BYTE:      proc_wr_mask = {56'b0, {8{1'b1}}};
        HALF:      proc_wr_mask = {48'b0, {16{1'b1}}};
        WORD:      proc_wr_mask = {32'b0, {32{1'b1}}};
        default:    proc_wr_mask = {64{1'b1}};
    endcase
    proc_wr_mask = proc_wr_mask << {proc_wr_offset, 3'b0};

    case (rd_size)
        BYTE:      proc_rd_mask = {56'b0, {8{1'b1}}};
        HALF:      proc_rd_mask = {48'b0, {16{1'b1}}};
        WORD:      proc_rd_mask = {32'b0, {32{1'b1}}};
        default:    proc_rd_mask = {64{1'b1}};
    endcase
end

// check if incoming mem already exists in cache/victim
assign mem_cache_conflict = valid_after_rd[mem_wr_idx] && mem_wr_tag == tags_after_rd[mem_wr_idx];
assign mem_cache_conflict = victim_valid_after_rd[0] && {mem_wr_tag, mem_wr_idx} == victim_tags_after_rd[0];
assign mem_cache_conflict = victim_valid_after_rd[1] && {mem_wr_tag, mem_wr_idx} == victim_tags_after_rd[1];

// check if read hit
assign rd_data_cache_raw = data_after_wr[rd_idx];
assign rd_data_cache = (rd_data_cache_raw >> {rd_offset, 3'b0}) & proc_rd_mask;
assign rd_cache_hit = tags_after_wr[rd_idx] == rd_tag && valid_after_wr[rd_idx];
assign rd_victim_hit = rd_victim_match != 0;
genvar gi;
for (gi = 0; gi < 2; ++gi) begin
    assign rd_victim_match[gi] = victim_tags_after_wr[gi] == {rd_tag, rd_idx} && victim_valid_after_wr[gi];
end

// check if write hit
assign wr_cache_hit = (tags[proc_wr_idx] == proc_wr_tag) && valid[proc_wr_idx];
assign wr_victim_hit = wr_victim_match != 0;
for (gi = 0; gi < 2; ++gi) begin
    assign wr_victim_match[gi] = (victim_tags[gi] == {proc_wr_tag, proc_wr_idx}) && victim_valid[gi];
end

// handle write
always_comb begin
    // internal states
    victim_tags_after_wr = victim_tags;
    victim_data_after_wr = victim_data;
    victim_valid_after_wr = victim_valid;
    victim_dirty_after_wr = victim_dirty;
    victim_lru_after_wr = victim_lru;
    data_after_wr = data;
    tags_after_wr = tags; 
    valid_after_wr = valid;
    dirty_after_wr = dirty;
    // outputs
    wr_en_out = 0;
    wr_addr_out = 0;
    wr_data_out = 0;
    wr_size_out = 0;
    swap_data_tmp_wr = 0;
    swap_dirty_tmp_wr = 0;
    if (proc_wr_en) begin
        if (wr_cache_hit) begin
            // cache match: write directly to cache entry
            data_after_wr[proc_wr_idx] = (data[proc_wr_idx] & ~proc_wr_mask) |
                                    (proc_wr_mask & (proc_wr_data << {proc_wr_offset, 3'b0}));
            dirty_after_wr[proc_wr_idx] = 1'b1;
        end
        else if (wr_victim_hit) begin
            // cache miss victim match: overwrite matching victim with old cache, overwrite old cache
            victim_lru_after_wr = ~wr_victim_match[0];
            for (int i = 0; i < 2; ++i) begin
                if (wr_victim_match[i]) begin
                    victim_data_after_wr[i] = data[proc_wr_idx];
                    victim_dirty_after_wr[i] = dirty[proc_wr_idx];
                    victim_tags_after_wr[i] = {tags[proc_wr_idx], proc_wr_idx};
                    swap_data_tmp_wr = (victim_data_after_wr[i] & ~proc_wr_mask) | 
                                        (proc_wr_mask & (proc_wr_data << {proc_wr_offset, 3'b0}));
                    swap_dirty_tmp_wr = 1'b1;
                    swap_tag_tmp_wr = victim_tags[i][12:5];
                end
            end
            data_after_wr[proc_wr_idx] = swap_data_tmp_wr;
            dirty_after_wr[proc_wr_idx] = swap_dirty_tmp_wr;
            tags_after_wr[proc_wr_idx] = swap_tag_tmp_wr;
        end
        else begin
            // cache miss victim miss: goto mem
            wr_en_out = 1'b1;
            wr_addr_out = {proc_wr_tag, proc_wr_idx, proc_wr_offset};
            wr_data_out = proc_wr_data;
            wr_size_out = proc_wr_size;
        end
    end
end


// handle read
always_comb begin
    // internal states
    victim_tags_after_rd = victim_tags_after_wr;
    victim_data_after_rd = victim_data_after_wr;
    victim_valid_after_rd = victim_valid_after_wr;
    victim_dirty_after_rd = victim_dirty_after_wr;
    victim_lru_after_rd = victim_lru_after_wr;
    data_after_rd = data_after_wr;
    tags_after_rd = tags_after_wr;
    valid_after_rd = valid_after_wr;
    dirty_after_rd = dirty_after_wr;
    // outputs
    rd_data = 0;
    rd_feedback = 0;
    rd_en_out = 0;
    rd_addr_out = 0;
    rd_gnt_out = 0;
    if (rd_en) begin
        if (rd_cache_hit) begin
            // cache match: read directly from cache
            rd_data = rd_data_cache;
            rd_feedback = rd_gnt;
        end
        else if (rd_victim_hit) begin
            // cache miss victim match: swap
            victim_lru_after_rd = ~rd_victim_match[0];
            for (int i = 0; i < 2; ++i) begin
                if (rd_victim_match[i]) begin
                    victim_data_after_rd[i] = data_after_wr[rd_idx];
                    victim_dirty_after_rd[i] = dirty_after_wr[rd_idx];
                    victim_tags_after_rd[i] = {tags_after_wr[rd_idx], rd_idx};
                    swap_data_tmp_rd = victim_data_after_wr[i];
                    swap_dirty_tmp_rd = victim_dirty_after_wr[i];
                    swap_tag_tmp_rd = victim_tags_after_wr[i][12:5];
                    rd_data = (victim_data_after_wr[i] >> {rd_offset, 3'b0}) & proc_rd_mask;
                    rd_feedback = rd_gnt;
                end
            end
            data_after_rd[rd_idx] = swap_data_tmp_rd;
            dirty_after_rd[rd_idx] = swap_dirty_tmp_rd;
            tags_after_rd[rd_idx] = swap_tag_tmp_rd;
        end
        else begin
            // cache miss victim miss: goto mem
            rd_en_out = 1'b1;
            rd_addr_out = {rd_tag, rd_idx, 3'b0};
            rd_gnt_out = rd_gnt;
            rd_size_out = rd_size;
        end
    end
end


// handle incoming memory
always_comb begin
    // internal states
    victim_tags_after_mem = victim_tags_after_rd;
    victim_data_after_mem = victim_data_after_rd;
    victim_valid_after_mem = victim_valid_after_rd;
    victim_dirty_after_mem = victim_dirty_after_rd;
    victim_lru_after_mem = victim_lru_after_rd;
    data_after_mem = data_after_rd;
    tags_after_mem = tags_after_rd;
    valid_after_mem = valid_after_rd;
    dirty_after_mem = dirty_after_rd;
    // outputs
    wb_en_out = 0;
    wb_addr_out = 0;
    wb_data_out = 0;
    wb_size_out = 0;
    if (mem_wr_en) begin
        if (mem_cache_conflict) begin
            // entry already exists in cache/victim, do nothing
        end
        else if (~valid_after_rd[mem_wr_idx]) begin
            // overwrite directly
            data_after_mem[mem_wr_idx] = mem_wr_data;
            tags_after_mem[mem_wr_idx] = mem_wr_tag;
            valid_after_mem[mem_wr_idx] = 1'b1;
            dirty_after_mem[mem_wr_idx] = 1'b0;
        end
        else if (victim_valid_after_rd != 2'b11) begin
            // evict cache entry, overwrite victim cache lru
            // overwrite cache
            data_after_mem[mem_wr_idx] = mem_wr_data;
            tags_after_mem[mem_wr_idx] = mem_wr_tag;
            valid_after_mem[mem_wr_idx] = 1'b1;
            dirty_after_mem[mem_wr_idx] = 1'b0;
            // overwrite victim lru
            victim_tags_after_mem = {tags_after_rd[mem_wr_idx], mem_wr_idx};
            victim_data_after_mem = data_after_rd[mem_wr_idx];
            victim_valid_after_mem[victim_lru_after_rd] = valid_after_rd[mem_wr_idx];
            victim_dirty_after_mem = dirty_after_rd[mem_wr_idx];
            victim_lru_after_mem = ~victim_lru_after_rd;
        end
        else begin
            // evict cache entry, evict victim cache lru, write back to mem
            // overwrite cache
            data_after_mem[mem_wr_idx] = mem_wr_data;
            tags_after_mem[mem_wr_idx] = mem_wr_tag;
            valid_after_mem[mem_wr_idx] = 1'b1;
            dirty_after_mem[mem_wr_idx] = 1'b0;
            // overwrite victim lru
            victim_tags_after_mem[victim_lru_after_rd] = {tags_after_rd[mem_wr_idx], mem_wr_idx};
            victim_data_after_mem[victim_lru_after_rd] = data_after_rd[mem_wr_idx];
            victim_valid_after_mem[victim_lru_after_rd] = valid_after_rd[mem_wr_idx];
            victim_dirty_after_mem[victim_lru_after_rd] = dirty_after_rd[mem_wr_idx];
            victim_lru_after_mem = ~victim_lru_after_rd;
            // write back
            if (victim_dirty_after_rd[victim_lru_after_rd]) begin
                wb_en_out = 1'b1;
                wb_addr_out = {victim_tags_after_rd[victim_lru_after_rd], 3'b0};
                wb_data_out = victim_data_after_rd[victim_lru_after_rd];
                wb_size_out = DOUBLE;
            end
        end
    end
end

always_ff @(posedge clock) begin
    if (reset) begin
        data <= 0;
        tags <= 0; 
        valid <= 0;
        dirty <= 0;
        victim_tags <= 0;
        victim_data <= 0;
        victim_valid <= 0;
        victim_dirty <= 0;
        victim_lru <= 0;
    end
    else begin
        data <= data_after_mem;
        tags <= tags_after_mem; 
        valid <= valid_after_mem;
        dirty <= dirty_after_mem;
        victim_tags <= victim_tags_after_mem;
        victim_data <= victim_data_after_mem;
        victim_valid <= victim_valid_after_mem;
        victim_dirty <= victim_dirty_after_mem;
        victim_lru <= victim_lru_after_mem;
    end
end

endmodule
