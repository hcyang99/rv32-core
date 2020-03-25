
module model_PRF(
        input                                   clock,
        input                                   reset,
        input   [`WAYS-1:0] [$clog2(`PRF)-1:0]  rda_idx,
        input   [`WAYS-1:0] [$clog2(`PRF)-1:0]  rdb_idx,
        input   [`WAYS-1:0] [$clog2(`PRF)-1:0]  wr_idx,
        input   [`WAYS-1:0] [`XLEN-1:0]         wr_dat,
        input   [`WAYS-1:0]                     wr_en,

        output logic [`WAYS-1:0] [`XLEN-1:0]    rda_dat,
        output logic [`WAYS-1:0] [`XLEN-1:0]    rdb_dat
    );

// used to generate random write accesses
int data [`PRF-1:0]; 

// read
generate;
    genvar i;
    for (i = 0; i < `WAYS; i = i + 1) begin
        assign rda_dat[i] = data[rda_idx[i]];
        assign rdb_dat[i] = data[rdb_idx[i]];
    end
endgenerate

always @ (posedge clock) begin
    if (reset) begin
        for (int i = 0; i < `PRF; i = i + 1) begin
            data[i] = 0;
        end
    end
    else begin
        // write
        for (int i = 0; i < `WAYS; i = i + 1) begin
            if (wr_en[i]) begin
                data[wr_idx[i]] = wr_dat[i];
            end
        end
    end
end

endmodule

module rand_gen(
    input                                       clock,
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] wr_addr,
    output logic [`WAYS-1:0]                    wr_en,
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] rda_addr,
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0] rdb_addr
);

logic [`PRF-1:0] [$clog2(`PRF)-1:0] wr_rand;
int                                 idx;

// generate random wr_addr, not allowing duplicates
always @ (posedge clock) begin
    for (int i = 0; i < `PRF; i = i + 1) begin
        wr_rand[i] = i;
    end
    for (int i = 0; i < `PRF; i = i + 1) begin
        idx = $random % (`PRF - i);
        wr_addr[i] = wr_rand[idx];
        wr_rand[idx] = wr_addr[`PRF - 1 - i];
    end
end

// generate random rdx_addr, allowing duplicates
always @ (posedge clock) begin
    for (int i = 0; i < `WAYS; i = i + 1) begin
        rda_addr[i] = $random % `PRF;
        rdb_addr[i] = $random % `PRF;
    end
end

// generate random wr_en
always @ (posedge clock) begin
    for (int i = 0; i < `WAYS; i = i + 1) begin
        wr_en[i] = $random % 2;
    end
end

endmodule



module testbench;

logic                                   clock;
logic                                   reset;
logic [`WAYS-1:0] [$clog2(`PRF)-1:0]    wr_addr;
logic [`WAYS-1:0] [$clog2(`PRF)-1:0]    rda_addr;
logic [`WAYS-1:0] [$clog2(`PRF)-1:0]    rdb_addr;
logic [`WAYS-1:0]                       wr_en;

logic [`WAYS-1:0] [`XLEN-1:0]           rda_out_prf;
logic [`WAYS-1:0] [`XLEN-1:0]           rdb_out_prf;
logic [`WAYS-1:0] [`XLEN-1:0]           rda_out_model;
logic [`WAYS-1:0] [`XLEN-1:0]           rdb_out_model;

wire correct = rda_out_model == rda_out_prf
            && rdb_out_model == rdb_out_prf;

task check;
    if (!correct) begin
        $display("Incorrect at time %4.0f",$time);
		$display("@@@failed");
		$finish;
    end
endtask

rand_gen gen(
    .clock(clock),
    .wr_addr(wr_addr),
    .wr_en(wr_en),
    .rda_addr(rda_addr),
    .rdb_addr(rdb_addr)
);

PRF prf(
    .clock(clock),
    .reset(reset),
    .rda_idx(rda_addr),
    .rdb_idx(rdb_addr),
    .wr_idx(wr_addr),
    .wr_en(wr_en),
    .rda_dat(rda_out_prf),
    .rdb_dat(rdb_out_prf)
);

model_PRF model(
    .clock(clock),
    .reset(reset),
    .rda_idx(rda_addr),
    .rdb_idx(rdb_addr),
    .wr_idx(wr_addr),
    .wr_en(wr_en),
    .rda_dat(rda_out_model),
    .rdb_dat(rdb_out_model)
);

int counter;

always begin
	#5;
	clock=~clock;
end

initial begin
    $display("start sim");
    clock = 0;
    reset = 1;
    counter = 0;
    @(posedge clock);
    @(negedge clock);
    reset = 0;
    while (counter < 10000) begin
        @(negedge clock);
        // $display("Time: %4.0f", $time);
        check;
        counter = counter + 1;
    end
    $display("@@@passed");
    $finish;
end

endmodule