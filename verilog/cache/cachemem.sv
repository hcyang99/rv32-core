// cachemem32x64

`timescale 1ns/100ps

module cache(
        input clock, reset, wr_en,
        
        input [4:0] wr_idx,
        input  [7:0] wr_tag,
        input [63:0] wr_data, 

        input [`WAYS-1:0] [4:0] rd_idx,
        input [`WAYS-1:0] [7:0] rd_tag,

        output [`WAYS-1:0] [63:0] rd_data,
        output [`WAYS-1:0] rd_valid
        
      );



  logic [31:0] [63:0] data ;
  logic [31:0]  [7:0] tags; 
  logic [31:0]        valids;

  assign rd_data = data[rd_idx];
  assign rd_valid = valids[rd_idx] && (tags[rd_idx] == rd_tag);

  always_ff @(posedge clock) begin
    if(reset)
      valids <= `SD 31'b0;
    else if(wr_en) 
      valids[wr_idx] <= `SD 1;
  end
  
  always_ff @(posedge clock) begin
    if(wr_en) begin
      data[wr_idx] <= `SD wr_data;
      tags[wr_idx] <= `SD wr_tag;
    end
  end

endmodule
