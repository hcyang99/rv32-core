// optimized non-blocking icache with prefetch disabled
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

reg [31:0] pending;
reg [15:0] [12:0] wait_buffer;  // [mem tag] [idx], dummy 0
reg [15:0] wait_valid;
logic [15:0] [12:0] wait_buffer_next;
logic [15:0] wait_valid_next;
logic [15:0] fetch_addr;
logic [2:0] miss_outstanding;
logic [31:0] pending_next;

assign Icache_data_out = cachemem_data;
assign Icache_valid_out = cachemem_valid; 
assign current_index = wait_buffer[Imem2proc_tag][4:0];
assign current_tag = wait_buffer[Imem2proc_tag][12:5];
assign data_write_enable = wait_valid[Imem2proc_tag];
assign miss_outstanding = ~cachemem_valid;
assign proc2Imem_addr = miss_outstanding ? fetch_addr : 0;
assign proc2Imem_command = miss_outstanding ? BUS_LOAD : BUS_NONE;

genvar gi;
generate;
    for (gi = 0; gi < `WAYS; ++gi) begin
        assign rd_idx[gi] = proc2Icache_addr[gi][7:3]; // the set index
        assign rd_tag[gi] = proc2Icache_addr[gi][15:8]; // the tag
    end
endgenerate


always_comb begin
    fetch_addr = 0;
    for (int i = `WAYS - 1; i >= 0; --i) begin
        if (miss_outstanding[i]) begin   
            // goto mem iff miss && no pending hit
            fetch_addr = {proc2Icache_addr[i][15:3], 3'b0};
        end
    end
end


always_comb begin
    wait_buffer_next = wait_buffer;
    wait_valid_next = wait_valid;
    pending_next = pending;

    // clear 
    wait_buffer_next[Imem2proc_tag] = 0;
    wait_valid_next[Imem2proc_tag] = 0;
    pending_next[current_index] = 0;

    // add
    if (Imem2proc_response && proc2Imem_command) begin
        wait_buffer_next[Imem2proc_response] = proc2Imem_addr[15:3];
        wait_valid_next[Imem2proc_response] = 1'b1;
        pending_next[proc2Imem_addr[7:4]] = 1'b1;
    end
end

always_ff @(posedge clock) begin
    if (reset) begin
        wait_buffer <= 0;
        wait_valid <= 0;
    end
    else begin
        wait_buffer <= wait_buffer_next;
        wait_valid <= wait_valid_next;
    end
end

endmodule

