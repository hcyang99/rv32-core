// optimized non-blocking icache with prefetch enabled
module icache(
    input clock,
    input reset,

    // from Imemory to icache
    input [3:0] Imem2proc_response,
    input [3:0] Imem2proc_tag,
    
    // from processor to icache
    input [`WAYS-1:0][31:0] proc2Icache_addr,
    input [`WAYS-1:0] proc2Icache_en,

    // from cachemem to icache
    input [`WAYS-1:0][63:0] cachemem_data, // read an instruction when it's not in a cache put it inside a cache
    input [`WAYS-1:0] cachemem_valid, // for prefectching

    // from icache to imemory
    output logic    [1:0] proc2Imem_command, 
    output logic    [31:0] proc2Imem_addr,

    // from icache to processor
    output logic    [`WAYS-1:0][63:0] Icache_data_out, // value is memory[proc2Icache_addr]
    output logic    [`WAYS-1:0] Icache_valid_out,      // when this is high

    // from icache to cache mem
    output logic [`WAYS-1:0] [4:0] rd_idx,
    output logic [`WAYS-1:0] [7:0] rd_tag,
    output logic  [4:0] current_index,
    output logic  [7:0] current_tag,
    output logic  data_write_enable
);

reg [2:0] prefetch_cnt;
reg [15:0] [12:0] wait_buffer;  // [mem tag] [idx], dummy 0
reg [15:0] wait_valid;
reg [31:0] [7:0] pending_tags;  // prevent multiple fetches
reg [31:0] pending_valid;
reg [15:0] prefetch_addr;
logic [15:0] [12:0] wait_buffer_next;
logic [15:0] wait_valid_next;
logic [31:0] [7:0] pending_tags_next;
logic [31:0] pending_valid_next;
logic [15:0] prefetch_addr_next;
logic [15:0] fetch_addr;
wire [`WAYS-1:0] pending_hit;
logic [2:0] prefetch_cnt_next;
logic [2:0] miss_outstanding;

assign Icache_data_out = cachemem_data;
assign Icache_valid_out = cachemem_valid; 
assign current_index = wait_buffer[Imem2proc_tag][4:0];
assign current_tag = wait_buffer[Imem2proc_tag][12:5];
assign data_write_enable = wait_valid[Imem2proc_tag];
assign miss_outstanding = proc2Icache_en & ~cachemem_valid;
assign proc2Imem_addr = (miss_outstanding & ~pending_hit) ? fetch_addr : prefetch_addr;
assign proc2Imem_command = (miss_outstanding || prefetch_cnt) ? BUS_LOAD : BUS_NONE;
assign prefetch_addr_next = (Imem2proc_response != 0) ? (proc2Imem_addr + 8) : proc2Imem_addr;

always_comb begin
    prefetch_cnt_next = prefetch_cnt;
    if (prefetch_cnt && !miss_outstanding && Imem2proc_response) begin
        prefetch_cnt_next = prefetch_cnt - 1;
    end
    if (miss_outstanding)
        prefetch_cnt_next = 4;
end

genvar gi;
generate;
    for (gi = 0; gi < `WAYS; ++gi) begin
        assign rd_idx[gi] = proc2Icache_addr[gi][7:3]; // the set index
        assign rd_tag[gi] = proc2Icache_addr[gi][15:8]; // the tag
        assign pending_hit[gi] = proc2Icache_en[gi] && pending_valid[rd_idx[gi]]
                                && (rd_tag[gi] == pending_tags[rd_idx[gi]]);
    end
endgenerate


always_comb begin
    fetch_addr = 0;
    for (int i = `WAYS - 1; i >= 0; --i) begin
        if (miss_outstanding[i] & ~pending_hit[i]) begin   
            // goto mem iff miss && no pending hit
            fetch_addr = {proc2Icache_addr[i][15:3], 3'b0};
        end
    end
end


always_comb begin
    wait_buffer_next = wait_buffer;
    wait_valid_next = wait_valid;
    pending_tags_next = pending_tags;
    pending_valid_next = pending_valid;

    // clear 
    wait_buffer_next[Imem2proc_tag] = 0;
    wait_valid_next[Imem2proc_tag] = 0;
    pending_tags_next[current_index] = 0;
    pending_valid_next[current_index] = 0;

    // add
    if (Imem2proc_response && proc2Imem_command) begin
        wait_buffer_next[Imem2proc_response] = proc2Imem_addr[15:3];
        wait_valid_next[Imem2proc_response] = 1'b1;
        pending_tags_next[proc2Imem_addr[7:3]] = proc2Imem_addr[15:8];
        pending_valid_next[proc2Imem_addr[7:3]] = 1'b1;
    end
end

always_ff @(posedge clock) begin
    if (reset) begin
        wait_buffer <= 0;
        wait_valid <= 0;
        pending_tags <= 0;
        pending_valid <= 0;
        prefetch_addr <= 0;
        prefetch_cnt <= 0;
    end
    else begin
        wait_buffer <= wait_buffer_next;
        wait_valid <= wait_valid_next;
        pending_tags <= pending_tags_next;
        pending_valid <= pending_valid_next;
        prefetch_addr <= prefetch_addr_next;
        prefetch_cnt <= prefetch_cnt_next;
    end
end

endmodule

