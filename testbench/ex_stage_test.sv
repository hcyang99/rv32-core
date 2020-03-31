//`timescale 1ns/100ps

module testbench;
    logic clock, reset;
	ID_EX_PACKET [`WAYS-1:0] id_ex_packet_in;
	EX_MEM_PACKET [`WAYS-1:0] ex_packet_out;
	logic [`WAYS-1:0] occupied_hub;


	ALU_FUNC [`WAYS-1:0] op;
	logic [`WAYS-1:0][`XLEN-1:0]	res;
    logic [`WAYS-1:0][`XLEN-1:0]	opa;
	logic [`WAYS-1:0][`XLEN-1:0]	opb;


generate
	for(genvar i = 0; i < `WAYS; i = i + 1) begin
        assign id_ex_packet_in[i].opa_select = OPA_IS_RS1;
        assign id_ex_packet_in[i].opb_select = OPB_IS_RS2;
		assign id_ex_packet_in[i].alu_func = op[i];
		assign id_ex_packet_in[i].rs1_value = opa[i];
		assign id_ex_packet_in[i].rs2_value = opb[i];
		assign	res[i] = ex_packet_out[i].alu_result;
	end
endgenerate


 ex_stage ex_stage_dummy(
	.clock,               // system clock
	.reset,               // system reset
	.id_ex_packet_in,
    .ex_packet_out,
	.occupied_hub
);

// Generate System Clock
    // YANKED from the p3 testbench
	always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end

initial 
    begin
    clock = 0;
    $display("start");
    $display("Time|reset|op[0]|opa[0]|opb[0]|res[0]|occupied");
    $monitor("%4.0f  %b  ", $time, reset,
           "%b   %h    %h     ", op[0],opa[0],opb[0],
           "%h   %b",res[0],occupied_hub);

// single input
        @(negedge clock);// 10
        reset = 1;
        @(negedge clock);// 20
        reset = 0;
        id_ex_packet_in[0].valid = 1;
        op[0] = ALU_ADD;
        opa[0] = `XLEN'b1;
        opb[0] = `XLEN'b10;
        @(negedge clock);// 30
        @(negedge clock);// 40
        opa[0] = `XLEN'hffffff;
        opb[0] = `XLEN'heeeeee;
        op[0] = ALU_MUL;
        @(negedge clock);// 50
        id_ex_packet_in[0].valid = 0;

        @(negedge clock);// 40
        @(negedge clock);// 40
        
        @(negedge clock);// 40

     $finish;
end


endmodule