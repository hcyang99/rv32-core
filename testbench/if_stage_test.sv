module testbench;
    logic         clock;                  // system clock
	logic         reset;                  // system reset
	logic 		  stall;

	logic [`XLEN-1:0]	pc_predicted; // the predicted PC

// the following logic should be handled outside the module
	logic         	    rob_take_branch;      // taken-branch signal
	logic  [`XLEN-1:0] 	rob_target_pc;        // target pc: use if take_branch is TRUE
	
	logic  [`WAYS-1:0] [63:0] 	Icache2proc_data;          // Data coming back from instruction-memory
	logic  [`WAYS-1:0]			Icache2proc_valid;

	logic [`WAYS-1:0][`XLEN-1:0] proc2Icache_addr;    // Address sent to Instruction cache


	IF_ID_PACKET [`WAYS-1:0] if_packet_out;        

if_stage if_stage_0(.*);

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
    $display("Time|reset");
    $monitor("%4.0f  %01b  ", $time, reset);

// single input
        @(negedge clock);// 10
        reset = 1;
        stall = 0;
        rob_take_branch = 0;
        Icache2proc_valid = {`WAYS{1'b1}};
        pc_predicted = 0;
        @(negedge clock);// 20
        reset = 0;
        // 25: first insts go to if_id
        repeat(10) begin
             pc_predicted = pc_predicted + 4*`WAYS;
        @(negedge clock);// 30
        end

        @(negedge clock);// 40

     $finish;
end



endmodule