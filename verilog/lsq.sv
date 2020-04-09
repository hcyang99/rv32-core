`define WAYS 4
`define PRF 64
`define LSQSZ 16
`define ROB 32

`define BYTE 2'b0
`define HALF 2'h1
`define WORD 2'h2
`define DOUBLE 2'h3
`define MEM_SIZE [1:0]

module LSQ(
    input                                       clock,
    input                                       reset,
    input                                       except,

    // CDB
    input [`WAYS-1:0] [63:0]                    CDB_Data;
  	input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx;
  	input [`WAYS-1:0]                           CDB_valid;

    // ALU
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        ALU_ROB_idx,
    input [`WAYS-1:0]                           ALU_is_valid,
    input [`WAYS-1:0]                           ALU_is_ls,
    input [`WAYS-1:0]                           ALU_data,

    // SQ
    input [`WAYS-1:0] `MEM_SIZE                 st_size,
    input [`WAYS-1:0] [63:0]                    st_data,
    input [`WAYS-1:0]                           st_data_valid,
    input [`WAYS-1:0]                           st_en,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        st_ROB_idx,
    input                                       commit,   // from ROB, whether head of SQ should commit

    // LQ
    input [`WAYS-1:0] `MEM_SIZE                 ld_size,
    input [`WAYS-1:0]                           ld_en,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        ld_ROB_idx,

    // feedback from DCache
    input [`LSQSZ-1:0]                          rd_feedback,
    input [63:0]                                rd_data,

    // LSQ head/tail
    output logic [$clog2(`LSQSZ)-1:0]           sq_head,
    output logic [$clog2(`LSQSZ)-1:0]           sq_tail,
    output logic [$clog2(`LSQSZ)-1:0]           lq_head,
    output logic [$clog2(`LSQSZ)-1:0]           lq_tail,

    // write to DCache
    output logic                                wr_en,
    output logic [2:0]                          wr_offset,
    output logic [4:0]                          wr_idx,
    output logic [7:0]                          wr_tag,
    output logic [63:0]                         wr_data,
    output logic `MEM_SIZE                      wr_size,

    // read from DCache
    output logic [2:0]                          rd_offset,
    output logic [4:0]                          rd_idx,
    output logic [7:0]                          rd_tag,
    output logic `MEM_SIZE                      rd_size,
    output logic [`LSQSZ-1:0]                   rd_en,

    // LQ to CDB, highest priority REQUIRED
    output logic [`XLEN-1:0]                    CDB_Data,
  	output logic [$clog2(`PRF)-1:0]             CDB_PRF_idx,
  	output logic                                CDB_valid,
	output logic [$clog2(`ROB)-1:0]             CDB_ROB_idx,
  	output logic                                CDB_direction,
  	output logic [63:0]                         CDB_target
);

logic [`LSQSZ-1:0] `MEM_SIZE                    store_sz;
logic [`LSQSZ-1:0] [63:0]                       store_addr;
logic [`LSQSZ-1:0] [63:0]                       store_data;
logic [`LSQSZ-1:0]                              store_valid;

logic [`WAYS-1:0] [$clog2(`LSQSZ)-1:0]          ld_SQ_tail;


endmodule