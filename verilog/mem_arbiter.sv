module mem_arbiter(
    // Icache inputs
    input [`XLEN-1:0]                Icache_addr_in,
    input [1:0]                 Icache_command_in,

    // Dcache inputs
    input [`XLEN-1:0]                Dcache_addr_in,
    input [63:0]                Dcache_data_in,
    input [1:0]                 Dcache_command_in,
    input [1:0]             Dmem_size_in,

    // Mem inputs
    input [3:0]                 mem_tag_in,
    input [63:0]                mem_data_in,
    input [3:0]                 mem_response_in,

    // Icache outputs
    output logic [3:0]          Icache_tag_out,
    output logic [63:0]         Icache_data_out,
    output logic [3:0]          Icache_response_out,

    // Dcache outputs
    output logic [3:0]          Dcache_tag_out,
    output logic [63:0]         Dcache_data_out,
    output logic [3:0]          Dcache_response_out,

    // Mem outputs
    output logic [`XLEN-1:0]         mem_addr_out,
    output logic [63:0]         mem_data_out,
    output logic [1:0]          mem_command_out,
    output logic [1:0]      mem_size_out
);

    always_comb begin
        Icache_tag_out = mem_tag_in;
        Icache_data_out = mem_data_in;
        Dcache_tag_out = mem_tag_in;
        Dcache_data_out = mem_data_in;

        // Default to picking Dcache 
        Icache_response_out = 0;
        Dcache_response_out = mem_response_in;
        mem_addr_out = Dcache_addr_in;
        mem_data_out = Dcache_data_in;
        mem_command_out = Dcache_command_in;
        mem_size_out = Dmem_size_in;

        // Pick Icache if Dcache command is BUS_NONE
        if(Dcache_command_in == BUS_NONE) begin
            Icache_response_out = mem_response_in;
            Dcache_response_out = 0;
            mem_addr_out = Icache_addr_in;
            mem_data_out = 0;
            mem_command_out = Icache_command_in;
            mem_size_out = DOUBLE;
        end
    end

endmodule
