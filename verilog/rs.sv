`define XLEN        64
`define PRF_LOG2    6
`define ROB_LOG2    5
`define RS          16
`define RS_LOG2     4

`define OLEN        16
`define PCLEN       32
`define WAYS        3

module RS_Line(
    input                                       clock;
    input                                       reset;
    input                                       en;

    input [`WAYS-1:0] [`XLEN-1:0]               CDB_Data;
    input [`WAYS-1:0] [`PRF_LOG2-1:0]           CDB_PRF_idx;
    input [`WAYS-1:0]                           CDB_valid;

    input [`XLEN-1:0]                           opa_in; // data or PRN
    input [`XLEN-1:0]                           opb_in; // data or PRN
    input                                       opa_valid; // indicate whether it is data or PRN, 1: data 0: PRN
    input                                       opb_valid;
    input                                       rd_mem_in;                          
    input                                       wr_mem_in;                           

    input                                       load_in; // high when dispatch
    input [`OLEN-1:0]                           offset_in;
    input [`PCLEN-1:0]                          PC_in;
    ALU_FUNC                                    Operation_in; //

//    input INST_STRUCT               inst;

    output logic                                ready;
    output logic [`XLEN-1:0]                    opa_out;
    output logic [`XLEN-1:0]                    opb_out;
    output logic [`PRF_LOG2-1:0]                dest_PRF_idx;
    output logic [`ROB_LOG2-1:0]                rob_idx;
    output logic                                is_free;    

    output logic [`PCLEN-1:0]                   PC_out;
    ALU_FUNC                                    Operation_out; // need to be updated
    output logic [`OLEN-1:0]                    offset_out;
    output logic                                rd_mem_out;                          
    output logic                                wr_mem_out;                           


);
    
endmodule

module RS(
    input                                       clock;
    input                                       reset;

    input [`WAYS-1:0] [`XLEN-1:0]               CDB_Data;
    input [`WAYS-1:0] [`PRF_LOG2-1:0]           CDB_PRF_idx;
    input [`WAYS-1:0]                           CDB_valid;

    input [`WAYS-1:0] [`XLEN-1:0]               opa_in; // data or PRN
    input [`WAYS-1:0] [`XLEN-1:0]               opb_in; // data or PRN
    input [`WAYS-1:0]                           opa_valid; // indicate whether it is data or PRN, 1: data 0: PRN
    input [`WAYS-1:0]                           opb_valid;
    input [`WAYS-1:0]                           rd_mem_in;                          
    input [`WAYS-1:0]                           wr_mem_in;                           


    input                                       load_in; // high when dispatch
    input [`WAYS-1:0] [`OLEN-1:0]               offset_in;
    input [`WAYS-1:0] [`PCLEN-1:0]              PC_in;
    input [`WAYS-1:0] [4:0]                     Operation_in; // need to be updated

//    input INST_STRUCT               inst;
    output logic [`WAYS-1:0]                    inst_out_valid; // tell which inst is valid, 100 when only one inst is valid 
    output logic [`WAYS-1:0] [`XLEN-1:0]        opa_out;
    output logic [`WAYS-1:0] [`XLEN-1:0]        opb_out;
    output logic [`WAYS-1:0] [`PRF_LOG2-1:0]    dest_PRF_idx;
    output logic [`WAYS-1:0] [`ROB_LOG2-1:0]    rob_idx;

    output logic [`WAYS-1:0] [`PCLEN-1:0]       PC_out;
    output logic [`WAYS-1:0] [4:0]              Operation_out; // need to be updated
    output logic [`WAYS-1:0] [`OLEN-1:0]        offset_out;
    output logic [`RS_LOG2-1:0]                 num_is_free;
    
    output logic [`WAYS-1:0]                    rd_mem_out;                          
    output logic [`WAYS-1:0]                    wr_mem_out;                           

);

endmodule