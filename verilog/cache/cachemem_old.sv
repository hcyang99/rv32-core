// cachemem32x64

`timescale 1ns/100ps

module cache(
    input                       clock,
    input                       reset, 

    input                       wr_en,
    input [4:0]                 wr_idx,
    input [7:0]                 wr_tag,
    input [63:0]                wr_data, 

    input [`WAYS:0] [4:0]       rd_idx,
    input [`WAYS:0] [7:0]       rd_tag,

    output [`WAYS:0] [63:0]     rd_data,
    output [`WAYS:0]            rd_valid
);



reg [31:0] [63:0] data;
reg [31:0] [7:0] tags; 
reg [31:0] valid;

genvar gi;
generate;
    for (gi = 0; gi < `WAYS + 1; ++gi) begin
        assign rd_data[gi] = data[rd_idx[gi]];
        assign rd_valid[gi] = valid[rd_idx[gi]] & (tags[rd_idx[gi]] == rd_tag[gi]);
    end
endgenerate

always_ff @(posedge clock) begin
//$display("rd_valid: %b",rd_valid);
    if (reset)
        valid <= 31'b0;
    else if (wr_en)
        valid[wr_idx] <= 1'b1;
end

always_ff @(posedge clock) begin
    if (reset) begin
        data[wr_idx] <= 0;
        tags[wr_idx] <= 0;
    end
    else if (wr_en) begin
        data[wr_idx] <= wr_data;
        tags[wr_idx] <= wr_tag;
    end
end

endmodule
