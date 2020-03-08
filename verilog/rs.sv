/**********change has made**********
1. always load in that amount of instruction, but if it reach the end. 
set the insruction as invalid, and insert `NOOP

2. observe that there is one clock period time delay in the output num_is_free,
so one solution is outputting the num_is_free, free_increase and free_decrease at
the same time
**********************/
`include "sys_defs.svh"
//`define REG_LEN     64
`define PRF         64
`define ROB         16
`define RS          16

`define OLEN        16
`define PCLEN       32
`define WAYS        3
//`timescale 1ns/100ps

module RS_Line(
    input                                       clock,
    input                                       reset,

    input [`WAYS-1:0] [`XLEN-1:0]               CDB_Data,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx,
    input [`WAYS-1:0]                           CDB_valid,

    input [`XLEN-1:0]                           opa_in, // data or PRN
    input [`XLEN-1:0]                           opb_in, // data or PRN
    input                                       opa_valid_in, // indicate whether it is data or PRN, 1: data 0: PRN
    input                                       opb_valid_in, // assuming opx_valid_in is 0 when en == 0
    input                                       rd_mem_in,                         
    input                                       wr_mem_in,
    input [$clog2(`PRF)-1:0]                    dest_PRF_idx_in,
    input [$clog2(`ROB)-1:0]                    rob_idx_in,                        

    input                                       load_in, // high when dispatch
    input [`OLEN-1:0]                           offset_in,
    input [`PCLEN-1:0]                          PC_in,
//    input ALU_FUNC                              Operation_in,


    output logic                                ready,
    // RS entry
    output logic [`XLEN-1:0]                    opa_out,
    output logic [`XLEN-1:0]                    opb_out,
    output logic [$clog2(`PRF)-1:0]             dest_PRF_idx_out,
    output logic [$clog2(`ROB)-1:0]             rob_idx_out,
    output logic                                is_free,

    output logic [`PCLEN-1:0]                   PC_out,
//    output ALU_FUNC                             Operation_out,
    output logic [`OLEN-1:0]                    offset_out,
    output logic                                rd_mem_out,                        
    output logic                                wr_mem_out                         
);

    logic [`WAYS-1:0]                           opa_reg_is_from_CDB;
    logic [`WAYS-1:0]                           opb_reg_is_from_CDB;
    reg                                         opa_valid_reg;
    reg                                         opb_valid_reg;
//    logic [`XLEN-1:0]                           opa_reg;
//    logic [`XLEN-1:0]                           opb_reg;
    reg [`XLEN-1:0]                             opa_reg_feed;
    reg [`XLEN-1:0]                             opb_reg_feed;
    logic                                       opa_valid_reg_feed;
    logic                                       opb_valid_reg_feed;

    assign ready = opa_valid_reg & opb_valid_reg;

    // watching CDB
    generate
        for (genvar i = 0; i < `WAYS; i = i + 1) begin
            assign opa_reg_is_from_CDB[i] = ~opa_valid_reg && CDB_valid[i] && CDB_PRF_idx[i] == opa_out;
            assign opb_reg_is_from_CDB[i] = ~opb_valid_reg && CDB_valid[i] && CDB_PRF_idx[i] == opb_out;
        end
    endgenerate

    always_comb begin
//    $display("opb_reg_is_from_CDB:%b opb_valid_reg:%b CDB_valid:%b CDB_PRF_idx:%h opb_out:%h",opb_reg_is_from_CDB,opb_valid_reg,CDB_valid,CDB_PRF_idx,opb_out);
        opa_reg_feed = opa_out;
        opb_reg_feed = opb_out;
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
//    $display("reset: %h load_in: %h",reset,load_in);
        if (reset) begin
            is_free <= 1;
            opa_valid_reg <= 0;
            opb_valid_reg <= 0;
            opa_out <= 0;
            opb_out <= 0;
        end
        else if (load_in) begin
            is_free <= 0;
            opa_valid_reg <= opa_valid_in;
            opb_valid_reg <= opb_valid_in;
            opa_out <= opa_in;
            opb_out <= opb_in;
        end
        else begin
            opa_valid_reg <= opa_valid_reg_feed;
            opb_valid_reg <= opb_valid_reg_feed;
            opa_out <= opa_reg_feed;
            opb_out <= opb_reg_feed;
        end
    end

    always_ff @ (posedge clock) begin
        if (reset) begin
            PC_out <= 0;
//            Operation_out <= ALU_ADD;
            offset_out <= 0;
            rd_mem_out <= 0;                          
            wr_mem_out <= 0; 
            dest_PRF_idx_out <= 0;
            rob_idx_out <= 0;
        end
        else if (load_in) begin
            PC_out <= PC_in;
//            Operation_out <= Operation_in;
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
    input [`WAYS-1:0]                           CDB_valid,   // always start from LSB, like 1, 11, 111, 1111

    input [`WAYS-1:0] [`XLEN-1:0]               opa_in, // data or PRN
    input [`WAYS-1:0] [`XLEN-1:0]               opb_in, // data or PRN
    input [`WAYS-1:0]                           opa_valid_in, // indicate whether it is data or PRN, 1: data 0: PRN
    input [`WAYS-1:0]                           opb_valid_in,
    input [`WAYS-1:0]                           rd_mem_in,                          
    input [`WAYS-1:0]                           wr_mem_in,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        dest_PRF_idx_in,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        rob_idx_in,                             

    input                                       load_in, // ***high when dispatch***
    input [`WAYS-1:0] [`OLEN-1:0]               offset_in,
    input [`WAYS-1:0] [`PCLEN-1:0]              PC_in,
//    input ALU_FUNC                              Operation_in [`WAYS-1:0],


    output logic [`WAYS-1:0]                    inst_out_valid, // tell which inst is valid, **001** when only one inst is valid 
    output logic [`WAYS-1:0] [`XLEN-1:0]        opa_out,
    output logic [`WAYS-1:0] [`XLEN-1:0]        opb_out,
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] dest_PRF_idx_out,
    output logic [`WAYS-1:0] [$clog2(`ROB)-1:0] rob_idx_out,

    output logic [`WAYS-1:0] [`PCLEN-1:0]       PC_out,
//    output ALU_FUNC                             Operation_out [`WAYS-1:0],
    output logic [`WAYS-1:0] [`OLEN-1:0]        offset_out,
    output logic [$clog2(`RS):0]                num_is_free,
    
    output logic [`WAYS-1:0]                    rd_mem_out,                          
    output logic [`WAYS-1:0]                    wr_mem_out,

//debug
    output logic [$clog2(`WAYS):0]              free_decrease,
    output logic [$clog2(`RS):0]                num_is_free_next,
    output logic [`RS-1:0]                      is_free_hub,
    output logic [$clog2(`WAYS):0]              free_increase,
    output wor   [`RS-1:0]                      reset_hub,
    output logic [`RS-1:0]                      ready_hub
);
    // in hubs
//    wor   [`RS-1:0]                             reset_hub;
    logic [`RS-1:0] [`XLEN-1:0]                 opa_in_hub;
    logic [`RS-1:0] [`XLEN-1:0]                 opb_in_hub;
    logic [`RS-1:0]                             opa_valid_in_hub;
    logic [`RS-1:0]                             opb_valid_in_hub;
    logic [`RS-1:0]                             rd_mem_in_hub;
    logic [`RS-1:0]                             wr_mem_in_hub;                                
    logic [`RS-1:0] [$clog2(`PRF)-1:0]          dest_PRF_idx_in_hub;
    logic [`RS-1:0] [$clog2(`ROB)-1:0]          rob_idx_in_hub;
    wor   [`RS-1:0]                             load_in_hub;
    logic [`RS-1:0] [`OLEN-1:0]                 offset_in_hub;
    logic [`RS-1:0] [`PCLEN-1:0]                PC_in_hub;
//    ALU_FUNC                                    Operation_in_hub [`RS-1:0];
    
    // out hubs
//    logic [`RS-1:0]                             ready_hub;
    logic [`RS-1:0] [`XLEN-1:0]                 opa_out_hub;
    logic [`RS-1:0] [`XLEN-1:0]                 opb_out_hub;
    logic [`RS-1:0] [$clog2(`PRF)-1:0]          dest_PRF_idx_out_hub;
    logic [`RS-1:0] [$clog2(`ROB)-1:0]          rob_idx_out_hub;
//    logic [`RS-1:0]                             is_free_hub;
    logic [`RS-1:0] [`PCLEN-1:0]                PC_out_hub;
//    ALU_FUNC                                    Operation_out_hub [`RS-1:0];
    logic [`RS-1:0] [`OLEN-1:0]                 offset_out_hub;
    logic [`RS-1:0]                             rd_mem_out_hub;                         
    logic [`RS-1:0]                             wr_mem_out_hub;

    // other internals
//    reg   [$clog2(`RS):0]                       num_is_free;
//    logic [$clog2(`RS):0]                       num_is_free_next;
//    logic [$clog2(`WAYS):0]                     free_decrease;
//    logic [$clog2(`WAYS):0]                     free_increase;
    logic [`WAYS-1:0] [`XLEN-1:0]               opa_in_processed;
    logic [`WAYS-1:0] [`XLEN-1:0]               opb_in_processed;
    logic [`WAYS-1:0] [`WAYS-1:0]               opa_is_from_CDB;
    logic [`WAYS-1:0] [`WAYS-1:0]               opb_is_from_CDB; 
    logic [`WAYS-1:0]                           opa_valid_in_processed;
    logic [`WAYS-1:0]                           opb_valid_in_processed;

// for input selector
    logic [`RS*`WAYS-1:0]  in_gnt_bus;
    logic [`RS*`WAYS-1:0]  out_gnt_bus;


    assign num_is_free_next = (num_is_free - free_decrease + free_increase);

    // watching CDB
    generate
        for (genvar i = 0; i < `WAYS; i = i + 1) begin
            assign load_in_hub = in_gnt_bus[(i+1)*`RS-1 -: `RS];
            assign reset_hub = out_gnt_bus[(i+1)*`RS-1 -: `RS];
            for (genvar j = 0; j < `WAYS; j = j + 1) begin
                assign opa_is_from_CDB[i][j] = ~opa_valid_in[i] && CDB_valid[j] && CDB_PRF_idx[j] == opa_in[i];
                assign opb_is_from_CDB[i][j] = ~opb_valid_in[i] && CDB_valid[j] && CDB_PRF_idx[j] == opb_in[i];
            end
        end
    endgenerate
    


    always_comb begin
        for (int i = 0; i < `WAYS; i = i + 1) begin
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

    psel_gen #(`WAYS,`RS) input_selector(.en(load_in),.reset(1'b0),.req(is_free_hub), .gnt_bus(in_gnt_bus));

    
    // input selector
    // selecting `WAYS RS Entries to load_in
    always_comb begin
        opa_in_hub = 0;
        opb_in_hub = 0;
        opa_valid_in_hub = 0;
        opb_valid_in_hub = 0;
        rd_mem_in_hub = 0;
        wr_mem_in_hub = 0;
        dest_PRF_idx_in_hub = 0;
        rob_idx_in_hub = 0;
        offset_in_hub = 0;
        PC_in_hub = 0;
//        Operation_in_hub = '{`RS{ALU_ADD}};
        free_decrease = 0;
        for (int i = 0; i < `RS; i = i + 1) begin
            if(load_in_hub[i]) begin
                if(free_decrease < `WAYS) begin
                    opa_in_hub[i] = opa_in_processed[free_decrease];
                    opb_in_hub[i] = opb_in_processed[free_decrease];
                    opa_valid_in_hub[i] = opa_valid_in_processed[free_decrease];
                    opb_valid_in_hub[i] = opb_valid_in_processed[free_decrease];
                    // pipeline related
                    rd_mem_in_hub[i] = rd_mem_in[free_decrease];
                    wr_mem_in_hub[i] = wr_mem_in[free_decrease];
                    dest_PRF_idx_in_hub[i] = dest_PRF_idx_in[free_decrease];
                    rob_idx_in_hub[i] = rob_idx_in[free_decrease];
                    offset_in_hub[i] = offset_in[free_decrease];
                    PC_in_hub[i] = PC_in[free_decrease];
//                    Operation_in_hub[i] = Operation_in[free_decrease];
                    free_decrease = free_decrease + 1;
                end else break;
            end
        end
    end

/*
        for (int i = 0; i < `RS; i = i + 1) begin
            if (j < `WAYS && is_free_hub[i]) begin
                if(load_in[j]) begin
                    load_in_hub[i] = 1;
                    opa_in_hub[i] = opa_in_processed[j];
                    opb_in_hub[i] = opb_in_processed[j];
                    opa_valid_in_hub[i] = opa_valid_in_processed[j];
                    opb_valid_in_hub[i] = opb_valid_in_processed[j];
                    rd_mem_in_hub[i] = rd_mem_in[j];
                    wr_mem_in_hub[i] = wr_mem_in[j];
                    dest_PRF_idx_in_hub[i] = dest_PRF_idx_in[j];
                    rob_idx_in_hub[i] = rob_idx_in[j];
                    offset_in_hub[i] = offset_in[j];
                    PC_in_hub[i] = PC_in[j];
                    Operation_in_hub[i] = Operation_in[j];
                end
                j = j + 1;
            end
        end
        free_decrease = j;
    end
*/


    always_ff @ (posedge clock) begin
    // watch CDB
//        $display("opa_is_from_CDB = %b",opa_is_from_CDB);
//        $display("opb_is_from_CDB = %b",opb_is_from_CDB);
    // processing
//        $display("in rs.sv, opa_in[0]: %h opb_in[0]: %h",opa_in,opb_in);
//        $display("opa_in_processed[1]: %h opb_in_processed[1]: %h",opa_in_processed[1],opb_in_processed[1]);
//        $display("opa_valid_in_processed: %b opb_valid_in_processed: %b",opa_valid_in_processed, opb_valid_in_processed);
//        $display("opa_in_hub[0]: %h opb_in_hub[0]: %h",opa_in_hub[0],opb_in_hub[0]);
//        $display("opa_valid_in_hub[0]: %b opb_valid_in_hub[0]: %b",opa_valid_in_hub[0],opb_valid_in_hub[0]);
//        $display("load_in_hub: %h",load_in_hub);
//        $display("free_decrease: %d free_increase: %d",free_decrease,free_increase); 
//        $display("opa_out_hub[0]: %h opb_out_hub[0]: %h",opa_out_hub[0],opb_out_hub[0]);
//        $display("load_in: %b is_free_hub: %b load_in_hub: %b ready_hub:%b inst_out_valid:%b",load_in,is_free_hub, load_in_hub,ready_hub,inst_out_valid); 
//            $display("reset_hub: %b",reset_hub);
        if (reset) begin
            num_is_free <= `RS;
        end
        else begin
            num_is_free <= num_is_free_next;
        end

    end

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
//        .Operation_in(Operation_in_hub),

        // outputs
        .ready(ready_hub),
        .opa_out(opa_out_hub),
        .opb_out(opb_out_hub),
        .dest_PRF_idx_out(dest_PRF_idx_out_hub),
        .rob_idx_out(rob_idx_out_hub),
        .is_free(is_free_hub),
        .PC_out(PC_out_hub),
//        .Operation_out(Operation_out_hub),
        .offset_out(offset_out_hub),
        .rd_mem_out(rd_mem_out_hub),
        .wr_mem_out(wr_mem_out_hub)           
    );

    psel_gen #(`WAYS,`RS) output_selector(.en(1'b1),.reset(reset),.req(ready_hub),.gnt_bus(out_gnt_bus));


// output selector
    always_comb begin
        free_increase = 0;
        opa_out = 0;
        opb_out = 0;
        dest_PRF_idx_out = 0;
        rob_idx_out = 0;
        PC_out = 0;
//        Operation_out = '{`WAYS{ALU_ADD}};
        offset_out = 0;
        rd_mem_out = 0;
        wr_mem_out = 0;
        inst_out_valid = 0;
        if(~reset) begin            
            for (int i = 0; i < `RS; i = i + 1) begin
//            $display("i:%d free_increase: %d num_is_free_next: %d",i, free_increase,num_is_free_next);
                if (reset_hub[i]) begin
                    inst_out_valid[free_increase] = 1;
                    opa_out[free_increase] = opa_out_hub[i];
                    opb_out[free_increase] = opb_out_hub[i];
                    dest_PRF_idx_out[free_increase] = dest_PRF_idx_out_hub[i];
                    rob_idx_out[free_increase] = rob_idx_out_hub[i];
                    PC_out[free_increase] = PC_out_hub[i];
//                  Operation_out[free_increase] = Operation_out_hub[i];
                    offset_out[free_increase] = offset_out_hub[i];
                    rd_mem_out[free_increase] = rd_mem_out_hub[i];        
                    wr_mem_out[free_increase] = wr_mem_out_hub[i];
                    free_increase = free_increase + 1;
                end
            end
        end
    end



endmodule