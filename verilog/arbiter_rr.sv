module arbiter_rr #(parameter WIDTH = 16) (
    input clock,
    input reset,
    input [WIDTH-1:0] req;
    output wire [WIDTH-1:0] gnt;
);
reg [WIDTH-1:0] mask_reg;
wand [WIDTH-1:0] mask_next;

wire [WIDTH-1:0] masked_req;
wire [WIDTH-1:0] gnt_masked;
wire [WIDTH-1:0] gnt_unmasked;

assign masked_req = mask_reg & req;

ar_wand_sel #(.WIDTH(WIDTH)) sel_masked (
    .req(masked_req),
    .gnt(gnt_masked)
);

ar_wand_sel #(.WIDTH(WIDTH)) sel_unmasked (
    .req(req),
    .gnt(gnt_unmasked)
);

genvar gi;
generate;
    assign mask_next = {WIDTH{1'b1}};
    for (gi = 0; gi < WIDTH; ++gi) begin
        assign mask_next[gi:0] = {(gi+1){gnt[gi]}};
    end
endgenerate

assign gnt = gnt_masked ? gnt_masked : gnt_unmasked;


always_ff @ (posedge clock) begin
    if (reset) begin
        mask_reg <= {WIDTH{1'b1}};
    end
    else begin
        mask_reg <= mask_next;
    end
end

endmodule

module ar_wand_sel #(parameter WIDTH = 64) (req,gnt);
  //synopsys template
  input wire  [WIDTH-1:0] req;
  output wand [WIDTH-1:0] gnt;

  wire  [WIDTH-1:0] req_r;
  wand  [WIDTH-1:0] gnt_r;

  //priority selector
  genvar i;
  // reverse inputs and outputs
  for (i = 0; i < WIDTH; i = i + 1)
  begin : reverse
    assign req_r[WIDTH-1-i] = req[i];
    assign gnt[WIDTH-1-i]   = gnt_r[i];
  end

  for (i = 0; i < WIDTH-1 ; i = i + 1)
  begin : foo
    assign gnt_r [WIDTH-1:i] = {{(WIDTH-1-i){~req_r[i]}},req_r[i]};
  end
  assign gnt_r[WIDTH-1] = req_r[WIDTH-1];

endmodule