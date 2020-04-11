module mem_arbiter(
    // Icache inputs
    input [63:0]                Icache_addr,
    input [63:0]                Icache_data,
    input [1:0]                 Icache_command,

    // Dcache inputs
    input [63:0]                Dcache_addr,
    input [63:0]                Dcache_data,
    input [1:0]                 Dcache_command,

    // Mem inputs
    input [3:0]                 mem_tag,
    input [63:0]                mem_data,
    input [3:0]                 mem_response,

    // Icache outputs
    output logic [3:0]          Icache_tag,
    output logic [63:0]         Icache_data,
    output logic [3:0]          Icache_response,

    // Dcache outputs
    output logic [3:0]          Dcache_tag,
    output logic [63:0]         Dcache_data,
    output logic [3:0]          Dcache_response,

    // Mem outputs
    output logic [63:0]         mem_addr,
    output logic [63:0]         mem_data,
    output logic [1:0]          mem_command
);

    always_comb begin
        Icache_tag = mem_tag;
        Icache_data = mem_data;
        Dcache_tag = mem_tag;
        Dcache_data = mem_data;

        // Default to picking Dcache 
        Icache_response = 0;
        Dcache_response = mem_response;
        mem_addr = Dcache_addr;
        mem_data = Dcache_data;
        mem_command = Dcache_command;

        // Pick Icache if Dcache command is BUS_NONE
        if(Dcache_command = `BUS_NONE) begin
            Icache_response = mem_response;
            Dcache_response = 0;
            mem_addr = Icache_addr;
            mem_data = Icache_data;
            mem_command = Icache_command;
        end
    end

endmodule
