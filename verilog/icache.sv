module icache(
    input clock,
    input reset,

    input [3:0] Imem2proc_response,
    input [63:0] Imem2proc_data,
    input [3:0] Imem2proc_tag,

    input [`WAYS-1:0][31:0] proc2Icache_addr,
    input [`WAYS-1:0] proc2Icache_en,
    input [`WAYS-1:0][63:0] cachemem_data, // read an instruction when it's not in a cache put it inside a cache
    input [`WAYS-1:0] cachemem_valid,

    output logic  [1:0] proc2Imem_command, 
    output logic [31:0] proc2Imem_addr,

    output logic [`WAYS-1:0][63:0] Icache_data_out, // value is memory[proc2Icache_addr]
    output logic  [`WAYS-1:0] Icache_valid_out,      // when this is high

    output reg  [4:0] current_index,
    output reg  [7:0] current_tag,
    // output logic  [4:0] last_index,
    // output logic  [7:0] last_tag,
    output logic  data_write_enable
);
 
reg [3:0] current_mem_tag;
logic [`WAYS-1:0] miss_outstanding;
reg wait_for_mem_reg;
logic wait_for_mem_next;
logic send_request = (miss_outstanding != 0) & (~wait_for_mem_reg);
logic update_mem_tag;
logic [4:0] current_index_wire;
logic [7:0] current_tag_wire;

assign miss_outstanding = ~(proc2Icache_en & ~cachemem_valid);
assign Icache_data_out = cachemem_data;
assign Icache_valid_out = cachemem_valid; 

always_comb begin
    proc2Imem_command = BUS_NONE;
    proc2Imem_addr = 0;
    current_index_wire = current_index;
    current_tag_wire = current_tag;
    if (~wait_for_mem_reg) begin    // avoid sending repeated requests
        for (int i = `WAYS - 1; i >= 0; --i) begin
            if (miss_outstanding[i]) begin
                proc2Imem_command = BUS_LOAD;
                proc2Imem_addr = {proc2Icache_addr[i][31:3], 3'b0};
                {current_tag_wire, current_index_wire} = {proc2Icache_addr[i][15:3], 3'b0};
            end
        end
    end
end

always_comb begin
    update_mem_tag = 0;
    wait_for_mem_next = wait_for_mem_reg;
    if (wait_for_mem_reg && (current_mem_tag == Imem2proc_tag)) begin
        wait_for_mem_next = 0;
    end
    else if (send_request) begin
        if (Imem2proc_response == 0) begin  // rejected, send again
            wait_for_mem_next = 0;
        end
        else begin  // successfully sent
            wait_for_mem_next = 1'b1;
            update_mem_tag = 1'b1;
        end
    end
end

always_ff @ (posedge clock) begin
    if (reset) begin
        wait_for_mem_reg <= 0;
    end
    else begin
        wait_for_mem_reg <= wait_for_mem_next;
    end
end

assign data_write_enable = (current_mem_tag == Imem2proc_tag) && (current_mem_tag != 0);

// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if (reset) begin
        current_index <= 0;
        current_tag <= 0;
        current_mem_tag <= 0;
    end 
    else begin        
        if (update_mem_tag) begin
            current_mem_tag <= Imem2proc_response;
            current_index <= current_index_wire;
            current_tag <= current_tag_wire;
        end
        else if (data_write_enable)
            current_mem_tag <= 0;
    end
end

endmodule

