/**********change has made**********
1. always load in that amount of instruction, but if it reach the end. 
set the insruction as invalid

2. observe that there is one clock period time delay in the output num_is_free,
// output num_is_free_next
**********************/

//`timescale 1ns/100ps

module RS_Line(
    input                                       clock,
    input                                       reset,

    input [`WAYS-1:0] [`XLEN-1:0]               CDB_Data,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx,
    input [`WAYS-1:0]                           CDB_valid,

    input                                       opa_valid_in, // indicate whether it is data or PRN, 1: data 0: PRN
    input                                       opb_valid_in, // assuming opx_valid_in is 0 when en == 0

    input                                       load_in, // high when dispatch
    input ID_EX_PACKET                          id_rs_packet_in,

    output ID_EX_PACKET                         rs_packet_out,
    output logic                                ready,
    // RS entry
    output logic                                is_free

`ifdef VISUAL_DEBUGGER
    ,
    output reg                                  opa_valid_reg,
    output reg                                  opb_valid_reg
`endif
);

    logic [`WAYS-1:0]                           opa_reg_is_from_CDB;
    logic [`WAYS-1:0]                           opb_reg_is_from_CDB;
`ifndef VISUAL_DEBUGGER
    reg                                         opa_valid_reg;
    reg                                         opb_valid_reg;
`endif

    reg [`XLEN-1:0]                             opa_reg_feed;
    reg [`XLEN-1:0]                             opb_reg_feed;
    logic                                       opa_valid_reg_feed;
    logic                                       opb_valid_reg_feed;

    assign ready = opa_valid_reg & opb_valid_reg;

    // watching CDB for broadcasting!!!
    generate
        for (genvar i = 0; i < `WAYS; i = i + 1) begin
            assign opa_reg_is_from_CDB[i] = ~opa_valid_reg && CDB_valid[i] && CDB_PRF_idx[i] == rs_packet_out.rs1_value;
            assign opb_reg_is_from_CDB[i] = ~opb_valid_reg && CDB_valid[i] && CDB_PRF_idx[i] == rs_packet_out.rs2_value;
        end
    endgenerate

    always_comb begin
        opa_reg_feed = rs_packet_out.rs1_value;
        opb_reg_feed = rs_packet_out.rs2_value;
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
        if(load_in & id_rs_packet_in.valid)begin
            is_free <= `SD 0;
            opa_valid_reg <= `SD opa_valid_in;
            opb_valid_reg <= `SD opb_valid_in;
        end
        else if (reset | (~id_rs_packet_in.valid & load_in)) begin
            is_free <= `SD 1;
            opa_valid_reg <= `SD 0;
            opb_valid_reg <= `SD 0;
        end
        else begin
            opa_valid_reg <= `SD  opa_valid_reg_feed;
            opb_valid_reg <= `SD  opb_valid_reg_feed;
        end
    end

    always_ff @ (posedge clock) begin
        if (load_in & id_rs_packet_in.valid) begin
            rs_packet_out <= `SD id_rs_packet_in;
        end 
        else if (reset | (~id_rs_packet_in.valid & load_in)) begin
            rs_packet_out <= `SD 0;
        end 
        else begin
            rs_packet_out.rs1_value <= `SD  opa_reg_feed;
            rs_packet_out.rs2_value <= `SD  opb_reg_feed;
        end
    end
    
endmodule





module RS(
    input                                       clock,
    input                                       reset,

    input [`WAYS-1:0] [`XLEN-1:0]               CDB_Data,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx,
    input [`WAYS-1:0]                           CDB_valid,   // always start from LSB, like 1, 11, 111, 1111

    input [`WAYS-1:0]                           opa_valid_in, // indicate whether it is data or PRN, 1: data 0: PRN
    input [`WAYS-1:0]                           opb_valid_in,

    input ID_EX_PACKET [`WAYS-1:0]              id_rs_packet_in,
    input                                       load_in, // ***high when dispatch***

    input [`WAYS-1:0]                           ALU_occupied,
    output ID_EX_PACKET [`WAYS-1:0]             rs_packet_out,

    output logic [$clog2(`RS):0]                num_is_free,
    output logic [$clog2(`RS):0]                num_is_free_next,
// for debugging
    output wor   [`RS-1:0]                      load_in_hub,
    output logic [`RS-1:0]                      is_free_hub,
    output logic [`RS-1:0]                      ready_hub


);

//debug
    logic [$clog2(`WAYS):0]              free_decrease;
    logic [$clog2(`WAYS):0]              free_increase;
    logic   [`RS-1:0]                      reset_hub;
    wor [`RS-1:0]                             reset_hub_tmp;

    // in hubs
    logic [$clog2(`WAYS):0]                     ALU_idx;
    logic [`RS-1:0]                             opa_valid_in_hub;
    logic [`RS-1:0]                             opb_valid_in_hub;
    ID_EX_PACKET [`RS-1:0]                      id_rs_packet_in_hub;
    ID_EX_PACKET [`RS-1:0]                      rs_packet_out_hub;

    
    // out hubs
    logic [`WAYS-1:0] [`XLEN-1:0]               opa_in_processed;
    logic [`WAYS-1:0] [`XLEN-1:0]               opb_in_processed;
    logic [`WAYS-1:0] [`WAYS-1:0]               opa_is_from_CDB;
    logic [`WAYS-1:0] [`WAYS-1:0]               opb_is_from_CDB; 
    logic [`WAYS-1:0]                           opa_valid_in_processed;
    logic [`WAYS-1:0]                           opb_valid_in_processed;


// for input selector
    logic [`RS*`WAYS-1:0]   in_gnt_bus;
    logic [`RS*`WAYS-1:0]   out_gnt_bus;
    logic                   has_match;

`ifdef VISUAL_DEBUGGER
    reg [`RS-1:0] opa_valid_reg;
    reg [`RS-1:0] opb_valid_reg;
`endif



    assign num_is_free_next = (num_is_free - free_decrease + free_increase);

    // watching CDB for night ship!!!
    generate
        for (genvar i = 0; i < `WAYS; i = i + 1) begin
            assign load_in_hub = in_gnt_bus[(i+1)*`RS-1 -: `RS];
            assign reset_hub_tmp = out_gnt_bus[(i+1)*`RS-1 -: `RS];
            for (genvar j = 0; j < `WAYS; j = j + 1) begin
                assign opa_is_from_CDB[i][j] = ~opa_valid_in[i] && CDB_valid[j] && CDB_PRF_idx[j] == id_rs_packet_in[i].rs1_value;
                assign opb_is_from_CDB[i][j] = ~opb_valid_in[i] && CDB_valid[j] && CDB_PRF_idx[j] == id_rs_packet_in[i].rs2_value;
            end
        end
    endgenerate


    always_comb begin
        for (int i = 0; i < `WAYS; i = i + 1) begin
            opa_in_processed[i] = id_rs_packet_in[i].rs1_value;
            opb_in_processed[i] = id_rs_packet_in[i].rs2_value;
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

    rs_psel_gen #(`WAYS,`RS) input_selector(.en(load_in),.reset(1'b0),.req(is_free_hub | reset_hub), .gnt_bus(in_gnt_bus));

    
    // input selector
    // selecting `WAYS RS Entries to load_in
    always_comb begin
        id_rs_packet_in_hub = 0;
        opa_valid_in_hub = 0;
        opb_valid_in_hub = 0;
        free_decrease = 0;
        for (int i = 0; i < `RS; i = i + 1) begin
            if(load_in_hub[i]) begin
                if(free_decrease < `WAYS) begin
                    id_rs_packet_in_hub[i]           = id_rs_packet_in[free_decrease];
                    id_rs_packet_in_hub[i].rs1_value = opa_in_processed[free_decrease];
                    id_rs_packet_in_hub[i].rs2_value = opb_in_processed[free_decrease];
                    opa_valid_in_hub[i]              = opa_valid_in_processed[free_decrease];
                    opb_valid_in_hub[i]              = opb_valid_in_processed[free_decrease];
                    // pipeline related
                    if(id_rs_packet_in[free_decrease].valid) free_decrease = free_decrease + 1;
                end else break;
            end
        end
    end

    always_ff @ (posedge clock) begin
    // watch CDB

        if (reset) begin
            num_is_free <= `SD `RS;
        end
        else begin
            num_is_free <= `SD num_is_free_next;
        end

    end

RS_Line lines [`RS-1:0] (
        // inputs
        .clock(clock),
        .reset(reset_hub),
        .CDB_Data(CDB_Data),
        .CDB_PRF_idx(CDB_PRF_idx),
        .CDB_valid(CDB_valid),
        
        .opa_valid_in(opa_valid_in_hub),
        .opb_valid_in(opb_valid_in_hub),
        .load_in(load_in_hub),
        .id_rs_packet_in(id_rs_packet_in_hub),

        // outputs
        .rs_packet_out(rs_packet_out_hub),
        .ready(ready_hub),
        .is_free(is_free_hub)
`ifdef VISUAL_DEBUGGER
        ,
        .opa_valid_reg,
        .opb_valid_reg
`endif
    );

    rs_psel_gen #(`WAYS,`RS) output_selector(.en(1'b1),.reset(reset),.req(ready_hub),.gnt_bus(out_gnt_bus));


// output selector
    always_comb begin
        free_increase = 0;
        rs_packet_out = 0;
        reset_hub = reset_hub_tmp;
        ALU_idx = 0;
        has_match = 0;
//        $display("reset_hub_tmp: %b ALU_occupied: %b",reset_hub_tmp,ALU_occupied);
        if(~reset) begin            
            for (int i = 0; i < `RS; i = i + 1) begin
//            $display("i: %d free_increase: %d ALU_idx: %d",i,free_increase,ALU_idx);
                if (reset_hub_tmp[i]) begin
                    has_match = 0;
                    if((ALU_idx < `WAYS)) begin
                        for(int j = 0; j < `WAYS; j = j + 1) begin
//                            $display("j: %d ALU_occupied[j]: %b",j,ALU_occupied[j]);
                            // to be changed (delete j <`WAYS)
                            if((j>= ALU_idx) && ~ALU_occupied[j]) begin
                                rs_packet_out[free_increase] = rs_packet_out_hub[i];
                                free_increase = free_increase + 1;
                                ALU_idx = j + 1;
                                has_match = 1;
                                break;
                            end 
                        end
                        if(~has_match) begin
                            reset_hub[i] = 0;                    
//                            $display("reset_hub: %b",reset_hub);                            
                        end
                    end else begin
                        reset_hub[i] = 0;                    
//                        $display("reset_hub: %b",reset_hub);
                    end
                end
            end
        end
    end




endmodule