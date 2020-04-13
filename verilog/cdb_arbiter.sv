`include "../sys_defs.svh"
module cdb_arbiter(
    input clock,
    input reset,

    input [`WAYS:0] [`XLEN-1:0]                         CDB_Data_in,
  	input [`WAYS:0] [$clog2(`PRF)-1:0]                  CDB_PRF_idx_in,
  	input [`WAYS:0]                                     CDB_valid_in,
	input [`WAYS:0] [$clog2(`ROB)-1:0]                  CDB_ROB_idx_in,
  	input [`WAYS:0]                                     CDB_direction_in,
  	input [`WAYS:0] [`XLEN-1:0]                         CDB_target_in,
	input [`WAYS:0]							            CDB_reg_write_in,

    output logic [`WAYS:0]                              gnt,
    output logic [`WAYS-1:0] [`XLEN-1:0]                CDB_Data_out,
  	output logic [`WAYS-1:0] [$clog2(`PRF)-1:0]         CDB_PRF_idx_out,
  	output logic [`WAYS-1:0]                            CDB_valid_out,
	output logic [`WAYS-1:0] [$clog2(`ROB)-1:0]         CDB_ROB_idx_out,
  	output logic [`WAYS-1:0]                            CDB_direction_out,
  	output logic [`WAYS-1:0] [`XLEN-1:0]                CDB_target_out,
	output logic [`WAYS-1:0]						    CDB_reg_write_out
);


endmodule

