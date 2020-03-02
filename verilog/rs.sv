`include "sys_defs.svh"
//`define REG_LEN     64
`define PRF         64
`define ROB         16
`define RS          16

`define OLEN        16
`define PCLEN       32
`define WAYS        3

module RS_Line(
    input                                       clock,
    input                                       reset,

    input [`WAYS-1:0] [`XLEN-1:0]            CDB_Data,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx,
    input [`WAYS-1:0]                           CDB_valid,

    input [`XLEN-1:0]                        opa_in, // data or PRN
    input [`XLEN-1:0]                        opb_in, // data or PRN
    input                                       opa_valid_in, // indicate whether it is data or PRN, 1: data 0: PRN
    input                                       opb_valid_in, // assuming opx_valid_in is 0 when en == 0
    input                                       rd_mem_in,                         
    input                                       wr_mem_in,
    input [$clog2(`PRF)-1:0]                    dest_PRF_idx_in,
    input [$clog2(`ROB):0]                      rob_idx_in,                        

    input                                       load_in, // high when dispatch
    input [`OLEN-1:0]                           offset_in,
    input [`PCLEN-1:0]                          PC_in,
    input ALU_FUNC                              Operation_in,


    output logic                                ready,
    output logic [`XLEN-1:0]                 opa_out,
    output logic [`XLEN-1:0]                 opb_out,
    output logic [$clog2(`PRF)-1:0]             dest_PRF_idx_out,
    output logic [$clog2(`ROB)-1:0]             rob_idx_out,
    output logic                                is_free,

    output logic [`PCLEN-1:0]                   PC_out,
    output ALU_FUNC                             Operation_out,
    output logic [`OLEN-1:0]                    offset_out,
    output logic                                rd_mem_out,                        
    output logic                                wr_mem_out                         
);

    logic [`WAYS-1:0]                           opa_reg_is_from_CDB;
    logic [`WAYS-1:0]                           opb_reg_is_from_CDB;
    reg                                         opa_valid_reg;
    reg                                         opb_valid_reg;
    reg [`XLEN-1:0]                          opa_reg;
    reg [`XLEN-1:0]                          opb_reg;
    logic [`XLEN-1:0]                        opa_reg_feed;
    logic [`XLEN-1:0]                        opb_reg_feed;
    logic                                       opa_valid_reg_feed;
    logic                                       opb_valid_reg_feed;

    assign ready = opa_valid_reg & opb_valid_reg;

    // watching CDB
    generate
        for (genvar i = 0; i < `WAYS; i = i + 1) begin
            assign opa_reg_is_from_CDB[i] = ~opa_valid_reg && CDB_valid[i] && CDB_PRF_idx[i] == opa_reg;
            assign opb_reg_is_from_CDB[i] = ~opb_valid_reg && CDB_valid[i] && CDB_PRF_idx[i] == opb_reg;
        end
    endgenerate

    always_comb begin
        opa_reg_feed = opa_reg;
        opb_reg_feed = opb_reg;
        opa_valid_reg_feed = opa_valid_reg;
        opb_valid_reg_feed = opb_valid_reg;
        if (~is_free) begin
            for (int i = 0; i < `WAYS; i = i + 1) begin
                if (opa_reg_is_from_CDB[i]) begin
                    opa_reg_feed = CDB_Data[i];
                    opa_valid_reg_feed = 1'b1;
                end
                if (opb_reg_is_from_CDB[i]) begin
                    opb_reg_feed = CDB_Data[i];
                    opb_valid_reg_feed = 1'b1;
                end
            end
        end
    end

    always_ff @ (posedge clock) begin
        if (reset) begin
            is_free <= 1;
            opa_valid_reg <= 0;
            opb_valid_reg <= 0;
            opa_reg <= 0;
            opb_reg <= 0;
        end
        else if (load_in) begin
            is_free <= 0;
            opa_valid_reg <= opa_valid_in;
            opb_valid_reg <= opb_valid_in;
            opa_reg <= opa_in;
            opb_reg <= opb_in;
        end
        else begin
            opa_valid_reg <= opa_valid_reg_feed;
            opb_valid_reg <= opb_valid_reg_feed;
            opa_reg <= opa_reg_feed;
            opb_reg <= opb_reg_feed;
        end
    end

    always_ff @ (posedge clock) begin
        if (reset) begin
            PC_out <= 0;
            Operation_out <= ALU_ADD;
            offset_out <= 0;
            rd_mem_out <= 0;                          
            wr_mem_out <= 0; 
            dest_PRF_idx_out <= 0;
            rob_idx_out <= 0;
        end
        else if (load_in) begin
            PC_out <= PC_in;
            Operation_out <= Operation_in;
            offset_out <= offset_in;
            rd_mem_out <= rd_mem_in;                          
            wr_mem_out <= wr_mem_in; 
            dest_PRF_idx_out <= dest_PRF_idx_in;
            rob_idx_out <= rob_idx_in;
        end
    end
    
endmodule

module RS(
    input                                       clock,
    input                                       reset,

    input [`WAYS-1:0] [`XLEN-1:0]               CDB_Data,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx,
    input [`WAYS-1:0]                           CDB_valid,

    input [`WAYS-1:0] [`XLEN-1:0]               opa_in, // data or PRN
    input [`WAYS-1:0] [`XLEN-1:0]               opb_in, // data or PRN
    input [`WAYS-1:0]                           opa_valid_in, // indicate whether it is data or PRN, 1: data 0: PRN
    input [`WAYS-1:0]                           opb_valid_in,
    input [`WAYS-1:0]                           rd_mem_in,                          
    input [`WAYS-1:0]                           wr_mem_in,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        dest_PRF_idx_in,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        rob_idx_in,                             

    input [`WAYS-1:0]                           load_in, // high when dispatch :: SHOULD HAVE BEEN MULTIPLE ENTRIES??
    input [`WAYS-1:0] [`OLEN-1:0]               offset_in,
    input [`WAYS-1:0] [`PCLEN-1:0]              PC_in,
    input ALU_FUNC                              Operation_in [`WAYS-1:0],


    output logic [`WAYS-1:0]                    inst_out_valid, // tell which inst is valid, **001** when only one inst is valid 
    output logic [`WAYS-1:0] [`XLEN-1:0]        opa_out,
    output logic [`WAYS-1:0] [`XLEN-1:0]        opb_out,
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] dest_PRF_idx_out,
    output logic [`WAYS-1:0] [$clog2(`ROB)-1:0] rob_idx_out,

    output logic [`WAYS-1:0] [`PCLEN-1:0]       PC_out,
    output ALU_FUNC                             Operation_out [`WAYS-1:0],
    output logic [`WAYS-1:0] [`OLEN-1:0]        offset_out,
    output logic [$clog2(`RS)-1:0]              num_is_free,
    
    output logic [`WAYS-1:0]                    rd_mem_out,                          
    output logic [`WAYS-1:0]                    wr_mem_out                        

);
    // in hubs
    logic [`RS-1:0]                             reset_hub;
    logic [`RS-1:0] [`XLEN-1:0]                 opa_in_hub;
    logic [`RS-1:0] [`XLEN-1:0]                 opb_in_hub;
    logic [`RS-1:0]                             opa_valid_in_hub;
    logic [`RS-1:0]                             opb_valid_in_hub;
    logic [`RS-1:0]                             rd_mem_in_hub;
    logic [`RS-1:0]                             wr_mem_in_hub;
    logic [`RS-1:0] [$clog2(`PRF)-1:0]          dest_PRF_idx_in_hub;
    logic [`RS-1:0] [$clog2(`ROB):0]            rob_idx_in_hub;
    logic [`RS-1:0]                             load_in_hub;
    logic [`RS-1:0] [`OLEN-1:0]                 offset_in_hub;
    logic [`RS-1:0] [`PCLEN-1:0]                PC_in_hub;
    ALU_FUNC Operation_in_hub [`RS-1:0];
    
    // out hubs
    logic [`RS-1:0]                             ready_hub;
    logic [`RS-1:0] [`XLEN-1:0]              opa_out_hub;
    logic [`RS-1:0] [`XLEN-1:0]              opb_out_hub;
    logic [`RS-1:0] [$clog2(`PRF)-1:0]          dest_PRF_idx_out_hub;
    logic [`RS-1:0] [$clog2(`ROB)-1:0]          rob_idx_out_hub;
    logic [`RS-1:0]                             is_free_hub;   
    logic [`RS-1:0] [`PCLEN-1:0]                PC_out_hub;
    ALU_FUNC Operation_out_hub [`RS-1:0];
    logic [`RS-1:0] [`OLEN-1:0]                 offset_out_hub;
    logic [`RS-1:0]                             rd_mem_out_hub;                         
    logic [`RS-1:0]                             wr_mem_out_hub;

    // other internals
    reg [$clog2(`RS)-1:0]                       free_count;
    logic [$clog2(`RS)-1:0]                     free_count_next;
    logic [$clog2(`RS)-1:0]                     free_decrease;
    logic [$clog2(`RS)-1:0]                     free_increase;
    logic [`WAYS-1:0] [`XLEN-1:0]            opa_in_processed;
    logic [`WAYS-1:0] [`XLEN-1:0]            opb_in_processed;
    logic [`WAYS-1:0] [`WAYS-1:0]               opa_is_from_CDB;
    logic [`WAYS-1:0] [`WAYS-1:0]               opb_is_from_CDB; 
    logic [`WAYS-1:0]                           opa_valid_in_processed;
    logic [`WAYS-1:0]                           opb_valid_in_processed;

    assign free_count_next = free_count - free_decrease + free_increase;

    // watching CDB
    generate
        for (genvar i = 0; i < `WAYS; i = i + 1) begin
            for (genvar j = 0; j < `WAYS; j = j + 1) begin
                assign opa_is_from_CDB[i][j] = ~opa_valid_in[i] && CDB_valid[j] && CDB_PRF_idx[j] == opa_in[i];
                assign opb_is_from_CDB[i][j] = ~opb_valid_in[i] && CDB_valid[j] && CDB_PRF_idx[j] == opb_in[i];
            end
        end
    endgenerate
    


    generate
        for (genvar i = 0; i < `WAYS; i = i + 1) begin
            always_comb begin
                opa_in_processed[i] = opa_in[i];
                opb_in_processed[i] = opb_in[i];
                opa_valid_in_processed[i] = opa_valid_in[i];
                opb_valid_in_processed[i] = opb_valid_in[i];
                for (int j = 0; j < `WAYS; j = j + 1) begin
                    if (opa_is_from_CDB[i][j]) begin
                        opa_in_processed[i] = CDB_Data[j];
                        opa_valid_in_processed[i] = 1'b1;
                    end
                    if (opb_is_from_CDB[i][j]) begin
                        opb_in_processed[i] = CDB_Data[j];
                        opb_valid_in_processed[i] = 1'b1;
                    end
                end
            end
        end
    endgenerate

    RS_Line lines [`RS-1:0] (
        // inputs
        .clock(clock),
        .reset(reset_hub),
        .CDB_Data(CDB_Data),
        .CDB_PRF_idx(CDB_PRF_idx),
        .CDB_valid(CDB_valid),
        
        .opa_in(opa_in_hub),
        .opb_in(opb_in_hub),
        .opa_valid_in(opa_valid_in_hub),
        .opb_valid_in(opb_valid_in_hub),
        .rd_mem_in(rd_mem_in_hub),
        .wr_mem_in(wr_mem_in_hub),
        .dest_PRF_idx_in(dest_PRF_idx_in_hub),
        .rob_idx_in(rob_idx_in_hub),
        .load_in(load_in_hub),
        .offset_in(offset_in_hub),
        .PC_in(PC_in_hub),
        .Operation_in(Operation_in_hub),

        // outputs
        .ready(ready_hub),
        .opa_out(opa_out_hub),
        .opb_out(opb_out_hub),
        .dest_PRF_idx_out(dest_PRF_idx_out_hub),
        .rob_idx_out(rob_idx_out_hub),
        .is_free(is_free_hub),
        .PC_out(PC_out_hub),
        .Operation_out(Operation_out_hub),
        .offset_out(offset_out_hub),
        .rd_mem_out(rd_mem_out_hub),
        .wr_mem_out(wr_mem_out_hub)           
    );

    // selecting `WAYS RS Entries to load_in
    always_comb begin
    $display("opa_is_from_CDB = %h",opa_is_from_CDB);
    $display("opb_is_from_CDB = %h",opb_is_from_CDB);
        opa_in_hub = 0;
        opb_in_hub = 0;
        opa_valid_in_hub = 0;
        opb_valid_in_hub = 0;
        rd_mem_in_hub = 0;
        wr_mem_in_hub = 0;
        dest_PRF_idx_in_hub = 0;
        rob_idx_in_hub = 0;
        load_in_hub = 0;
        offset_in_hub = 0;
        PC_in_hub = 0;
        Operation_in_hub = '{`RS{ALU_ADD}};
        int j = 0;
        for (int i = 0; i < `RS; i = i + 1) begin
            if (j < `WAYS && is_free_hub[i]) begin
                opa_in_hub[i] = opa_in_processed[j];
                opb_in_hub[i] = opb_in_processed[j];
                opa_valid_in_hub[i] = opa_valid_in_processed[j];
                opb_valid_in_hub[i] = opb_valid_in_processed[j];
                rd_mem_in_hub[i] = rd_mem_in[j];
                wr_mem_in_hub[i] = wr_mem_in[j];
                dest_PRF_idx_in_hub[i] = dest_PRF_idx_in[j];
                rob_idx_in_hub[i] = rob_idx_in[j];
                load_in_hub[i] = load_in[j];
                offset_in_hub[i] = offset_in[j];
                PC_in_hub[i] = PC_in[j];
                Operation_in_hub[i] = Operation_in[j];
                j = j + 1;
            end
        end
        free_decrease = j;
    end

    always_ff @ (posedge clock) begin
        $display("ready_hub: %b",ready_hub);
        if (reset) begin
            free_count <= `RS;
        end
        else begin
            free_count <= free_count_next;
        end
    end
    assign num_is_free = free_count;

    always_comb begin
        int j = 0;
        reset_hub = 0;
        inst_out_valid = 0; // tell which inst is valid, **001** when only one inst is valid 
        opa_out = 0;
        opb_out = 0;
        dest_PRF_idx_out = 0;
        rob_idx_out = 0;
        PC_out = 0;
        Operation_out = '{`WAYS{ALU_ADD}};
        offset_out = 0;
        rd_mem_out = 0;                          
        wr_mem_out = 0;
        if (reset) begin
            reset_hub = {`RS{1'b1}};
        end
        else begin
            for (int i = 0; i < `RS; i = i + 1) begin
                if (j < `WAYS && ready_hub[i]) begin
                    reset_hub[i] = 1'b1;
                    inst_out_valid[j] = 1'b1;
                    opa_out[j] = opa_out_hub[i];
                    opb_out[j] = opb_out_hub[i];
                    dest_PRF_idx_out[j] = dest_PRF_idx_out_hub[i];
                    rob_idx_out[j] = rob_idx_out_hub[i];
                    PC_out[j] = PC_out_hub[i];
                    Operation_out[j] = Operation_out_hub[i];
                    offset_out[j] = offset_out_hub[i];
                    rd_mem_out[j] = rd_mem_out_hub[i];        
                    wr_mem_out[j] = wr_mem_out_hub[i];
                    j = j + 1;
                end
            end
            free_increase = j;
        end
    end



endmodule