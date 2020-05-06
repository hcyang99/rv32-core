// `include "../sys_defs.svh"
module DMEM(
    input                                       clock,
    input                                       reset,
    input                                       except,

    // CDB
    input [`WAYS-1:0] [31:0]                    CDB_Data,
  	input [`WAYS-1:0] [$clog2(`PRF)-1:0]        CDB_PRF_idx,
  	input [`WAYS-1:0]                           CDB_valid,

    // ALU
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        ALU_ROB_idx,
    input [`WAYS-1:0]                           ALU_is_valid,
    input [`WAYS-1:0]                           ALU_is_ls,      // 1 = load, 0 = store (do we need this since we have ROB idx?)
    input [`WAYS-1:0] [31:0]                    ALU_data,

    // SQ
    input [`WAYS-1:0] [1:0]                     st_size,
    input [`WAYS-1:0] [31:0]                    st_data,
    input [`WAYS-1:0]                           st_data_valid,
    input [`WAYS-1:0]                           st_en,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        st_ROB_idx,
    input                                       commit,   // from ROB, whether head of SQ should commit

    // LQ
    input [`WAYS-1:0] [1:0]                     ld_size,
    input [`WAYS-1:0]                           ld_en,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        ld_ROB_idx,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        ld_PRF_idx,
    input [`WAYS-1:0]                           ld_is_signed,

    // from mem
    input [3:0]                                 mem2proc_response,// 0 = can't accept, other=tag of transaction
	  input [63:0]                                mem2proc_data,    // data resulting from a load
	  input [3:0]                                 mem2proc_tag,     // 0 = no value, other=tag of transaction

    // LSQ num free
    output logic [$clog2(`LSQSZ):0]             sq_num_free,
    output logic [$clog2(`LSQSZ):0]             lq_num_free,

    // LQ to CDB, highest priority REQUIRED
    output logic [31:0]                         CDB_Data_out,
  	output logic [$clog2(`PRF)-1:0]             CDB_PRF_idx_out,
  	output logic                                CDB_valid_out,
    output logic [$clog2(`ROB)-1:0]             CDB_ROB_idx_out,
  	output logic                                CDB_direction_out,
  	output logic [31:0]                         CDB_target_out,

    // to mem
    output logic [1:0]                          Dmem_command, 
    output logic [15:0]                         Dmem_addr,
    output logic [1:0]                          Dmem_size,
    output logic [63:0]                         Dmem_data,

    output logic [31:0]                         lsq_to_dc_wr_data,
    output logic                                lsq_to_dc_wr_en,
    output logic [1:0]                             lsq_to_dc_wr_size,
    output logic [15:0]                         lsq_to_dc_wr_addr,
    output logic [31:0] [63:0]  dcache_data,
    output logic [31:0] [7:0]   dcache_tags,
    output logic [31:0]         dcache_dirty,
    output logic [31:0]         dcache_valid,
    output logic [1:0] [12:0]     victim_tags,
    output logic [1:0] [63:0]     victim_data,
    output logic [1:0]            victim_valid,
    output logic [1:0]            victim_dirty,

    output logic [2:0]          dctrl_valid_new,
    output logic [2:0]          dctrl_is_wr_new,
    output logic [2:0] [63:0]   dctrl_data_new,
    output logic [2:0] [15:0]   dctrl_addr_new,
    output logic [15:0] [15:0]  dctrl_addr_q1,
    output logic [15:0]         dctrl_is_wr_q1,
    output logic [15:0]         dctrl_is_rd_q1,
    output logic [15:0] [1:0]   dctrl_sz_q1,
    output logic [2:0] [1:0]    dctrl_sz_new,
    output logic [15:0] [63:0]  dctrl_data_q1
);

logic [`WAYS-1:0] [15:0]                        ALU_data_tmp;
genvar gi;
generate;
    for (gi = 0; gi < `WAYS; ++gi) begin
        assign ALU_data_tmp[gi] = ALU_data[gi][15:0];
    end
endgenerate

// write to DCache

logic [2:0]                                 lsq_to_dc_wr_offset;
logic [4:0]                                 lsq_to_dc_wr_idx;
logic [7:0]                                 lsq_to_dc_wr_tag;

assign lsq_to_dc_wr_addr = {lsq_to_dc_wr_tag, lsq_to_dc_wr_idx, lsq_to_dc_wr_offset};

// read from DCache
logic [2:0]                                 lsq_to_dc_rd_offset;
logic [4:0]                                 lsq_to_dc_rd_idx;
logic [7:0]                                 lsq_to_dc_rd_tag;
logic [1:0]                             lsq_to_dc_rd_size;
logic                                       lsq_to_dc_rd_en;
logic [`LSQSZ-1:0]                          lsq_to_dc_rd_gnt;

// feedback from DCache
logic [`LSQSZ-1:0]                          dc_feedback;
logic [`LSQSZ-1:0]                          mem_feedback;
logic [31:0]                                mem_data;       // from mem, only overwrites "waiting" entries

logic                                       mem_wr_en;
logic [4:0]                                 mem_wr_idx;
logic [7:0]                                 mem_wr_tag;
logic [63:0]                                mem_wr_data;

logic [63:0]                                dc_to_lsq_rd_data;

// write dirty entries back
logic                                       dc_to_mem_wb_en_out;
logic [15:0]                                dc_to_mem_wb_addr_out;
logic [63:0]                                dc_to_mem_wb_data_out;
logic [1:0]                             dc_to_mem_wb_size_out;

// write directly to mem on wr miss
logic                                       dc_to_mem_wr_en_out;
logic [15:0]                                dc_to_mem_wr_addr_out;
logic [63:0]                                dc_to_mem_wr_data_out;
logic [1:0]                             dc_to_mem_wr_size_out;

// read from mem on rd miss
logic                                       dc_to_mem_rd_en_out;
logic [15:0]                                dc_to_mem_rd_addr_out;
logic [1:0]                             dc_to_mem_rd_size_out;
logic [`LSQSZ-1:0]                          dc_to_mem_rd_gnt_out;

LSQ LSQ_0(
    .clock(clock),
    .reset(reset),
    .except(except),

    .CDB_Data(CDB_Data),
    .CDB_PRF_idx(CDB_PRF_idx),
    .CDB_valid(CDB_valid),

    .ALU_ROB_idx(ALU_ROB_idx),
    .ALU_is_valid(ALU_is_valid),
    .ALU_is_ls(ALU_is_ls),
    .ALU_data(ALU_data_tmp),

    .st_size(st_size),
    .st_data(st_data),
    .st_data_valid(st_data_valid),
    .st_en(st_en),
    .st_ROB_idx(st_ROB_idx),
    .commit(commit),

    .ld_size(ld_size),
    .ld_en(ld_en),
    .ld_ROB_idx(ld_ROB_idx),
    .ld_PRF_idx(ld_PRF_idx),
    .ld_is_signed(ld_is_signed),

    .dc_feedback(dc_feedback),
    .dc_data(dc_to_lsq_rd_data[31:0]),
    .mem_feedback(mem_feedback),
    .mem_data(mem_data),

    .sq_num_free(sq_num_free),
    .lq_num_free(lq_num_free),

    .wr_en(lsq_to_dc_wr_en),
    .wr_offset(lsq_to_dc_wr_offset),
    .wr_idx(lsq_to_dc_wr_idx),
    .wr_tag(lsq_to_dc_wr_tag),
    .wr_data(lsq_to_dc_wr_data),
    .wr_size(lsq_to_dc_wr_size),

    .rd_offset(lsq_to_dc_rd_offset),
    .rd_idx(lsq_to_dc_rd_idx),
    .rd_tag(lsq_to_dc_rd_tag),
    .rd_size(lsq_to_dc_rd_size),
    .rd_en(lsq_to_dc_rd_en),
    .rd_gnt(lsq_to_dc_rd_gnt),

    .CDB_Data_out(CDB_Data_out),
    .CDB_PRF_idx_out(CDB_PRF_idx_out),
    .CDB_valid_out(CDB_valid_out),
    .CDB_ROB_idx_out(CDB_ROB_idx_out),
    .CDB_direction_out(CDB_direction_out),
    .CDB_target_out(CDB_target_out)
);

dcache dcache_0(
    .clock,
    .reset,

    .proc_wr_en(lsq_to_dc_wr_en),
    .proc_wr_offset(lsq_to_dc_wr_offset),
    .proc_wr_idx(lsq_to_dc_wr_idx),
    .proc_wr_tag(lsq_to_dc_wr_tag),
    .proc_wr_data({32'b0, lsq_to_dc_wr_data}),
    .proc_wr_size(lsq_to_dc_wr_size),

    .mem_wr_en,
    .mem_wr_idx,
    .mem_wr_tag,
    .mem_wr_data,

    .rd_en(lsq_to_dc_rd_en),
    .rd_offset(lsq_to_dc_rd_offset),
    .rd_idx(lsq_to_dc_rd_idx),
    .rd_tag(lsq_to_dc_rd_tag),
    .rd_size(lsq_to_dc_rd_size),
    .rd_gnt(lsq_to_dc_rd_gnt),

    .rd_data(dc_to_lsq_rd_data),
    .rd_feedback(dc_feedback),

    .wb_en_out(dc_to_mem_wb_en_out),
    .wb_addr_out(dc_to_mem_wb_addr_out),
    .wb_data_out(dc_to_mem_wb_data_out),
    .wb_size_out(dc_to_mem_wb_size_out),

    .wr_en_out(dc_to_mem_wr_en_out),
    .wr_addr_out(dc_to_mem_wr_addr_out),
    .wr_data_out(dc_to_mem_wr_data_out),
    .wr_size_out(dc_to_mem_wr_size_out),

    .rd_en_out(dc_to_mem_rd_en_out),
    .rd_addr_out(dc_to_mem_rd_addr_out),
    .rd_size_out(dc_to_mem_rd_size_out),
    .rd_gnt_out(dc_to_mem_rd_gnt_out),

    .dcache_data,
    .dcache_tags,
    .dcache_dirty,
    .dcache_valid,
    .victim_tags,
    .victim_data,
    .victim_valid,
    .victim_dirty
);

dcache_ctrl dcache_ctrl_0(
    .clock,
    .reset,
    .except,

    .wb_en_in(dc_to_mem_wb_en_out),
    .wb_addr_in(dc_to_mem_wb_addr_out),
    .wb_data_in(dc_to_mem_wb_data_out),
    .wb_size_in(dc_to_mem_wb_size_out),

    .wr_en_in(dc_to_mem_wr_en_out),
    .wr_addr_in(dc_to_mem_wr_addr_out),
    .wr_data_in(dc_to_mem_wr_data_out),
    .wr_size_in(dc_to_mem_wr_size_out),

    .rd_en_in(dc_to_mem_rd_en_out),
    .rd_addr_in(dc_to_mem_rd_addr_out),
    .rd_gnt_in(dc_to_mem_rd_gnt_out),
    .rd_size_in(dc_to_mem_rd_size_out),

    .mem2proc_response,
    .mem2proc_data,
    .mem2proc_tag,

    .Dmem_command,
    .Dmem_addr,
    .Dmem_size,
    .Dmem_data,

    .mem_feedback,
    .mem_data,

    .mem_wr_en,
    .mem_wr_idx,
    .mem_wr_tag,
    .mem_wr_data,

    .dctrl_valid_new,
    .dctrl_is_wr_new,
    .dctrl_data_new,
    .dctrl_addr_new,
    .dctrl_addr_q1,
    .dctrl_is_wr_q1,
    .dctrl_is_rd_q1,
    .dctrl_sz_q1,
    .dctrl_sz_new,
    .dctrl_data_q1
);
    
endmodule