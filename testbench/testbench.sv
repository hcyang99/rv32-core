

`timescale 1ns/100ps

`define WRITEBACK

extern void print_header(string str);
extern void print_cycles(int time_in, int cycle_count);
extern void print_stage(string div, int inst, int valid_inst);
extern void print_rs(string div, int inst, int valid_inst, int num_free, int load_in_hub, int is_free_hub, int ready_hub);
extern void print_rob(string div, int except, int direction, int PC, int num_free, int dest_ARN_out, int valid_out);
extern void print_ex_out(string div, int alu_result, int valid, int alu_occupied, int brand_results,int NPC);
extern void print_valids(int opa_valid, int opb_valid);
extern void print_opaopb(int opa_valid, int opb_valid, int rs1_value, int rs2_value);
extern void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                      int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
extern void print_membus(int proc2mem_command, int mem2proc_response,
                         int proc2mem_addr_hi, int proc2mem_addr_lo,
                         int proc2mem_data_hi, int proc2mem_data_lo);
extern void print_close();


module testbench;



    // ------------------------- wire & variable declarations -------------------------
    logic   clock;
    logic   reset;
    logic [31:0] clock_count;
    logic [31:0] instr_count;
	int          wb_fileno;
	
	logic [1:0]  proc2mem_command;
	logic [`XLEN-1:0] proc2mem_addr;
	logic [63:0] proc2mem_data;
	logic  [3:0] mem2proc_response;
	logic [63:0] mem2proc_data;
	logic  [3:0] mem2proc_tag;

	logic  [3:0] pipeline_completed_insts;
	EXCEPTION_CODE   pipeline_error_status;
	logic  [4:0] pipeline_commit_wr_idx;
	logic [`XLEN-1:0] pipeline_commit_wr_data;
	logic        pipeline_commit_wr_en;
	logic [`XLEN-1:0] pipeline_commit_NPC;

	logic [1:0]     proc2mem_size;


// if
	logic [`WAYS-1:0]	if_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] if_IR_out;
// id
	logic [`WAYS-1:0]	id_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] id_IR_out;
	logic [`WAYS-1:0]	id_opa_valid;
	logic [`WAYS-1:0]	id_opb_valid;

// id_ex
	logic [`WAYS-1:0]	id_ex_valid_inst;
	logic [`WAYS-1:0] [`XLEN-1:0] id_ex_IR;
	logic [`WAYS-1:0]	id_ex_opa_valid;
	logic [`WAYS-1:0]	id_ex_opb_valid;
	logic [`WAYS-1:0][`XLEN-1:0] id_ex_rs1_value;
	logic [`WAYS-1:0][`XLEN-1:0] id_ex_rs2_value;

// rob
	logic except;
	logic [`WAYS-1:0]	rob_direction_out;
    logic [`WAYS-1:0] [`XLEN-1:0] rob_PC_out;
	logic [$clog2(`ROB):0]  rob_num_free;
	logic [`WAYS-1:0] [4:0]    dest_ARN_out;
	logic [`WAYS-1:0]          valid_out;
	logic [`WAYS-1:0] [`XLEN-1:0] PC_out;

// rs	
	logic [`WAYS-1:0]    rs_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] rs_IR_out;
    logic [$clog2(`RS):0]    rs_num_is_free;
	logic [`RS-1:0]		rs_load_in_hub;
	logic [`RS-1:0]		rs_is_free_hub;
	logic [`RS-1:0]		rs_ready_hub;

// ex_stage
	logic [`WAYS-1:0]    ex_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] ex_alu_result_out;
	logic [`WAYS-1:0] 	ALU_occupied;
	logic [`WAYS-1:0] 	brand_result;

    logic [63:0] debug_counter;

    // ------------------------- module instances ------------------------- 

    processor core(
        // Inputs
        .clock                      (clock),
        .reset                      (reset),
        .mem2proc_response          (mem2proc_response),
        .mem2proc_data              (mem2proc_data),
        .mem2proc_tag               (mem2proc_tag),


        // Outputs
        .proc2mem_command           (proc2mem_command),
        .proc2mem_addr              (proc2mem_addr),
        .proc2mem_data              (proc2mem_data),
        .proc2mem_size              (proc2mem_size),

	    .pipeline_completed_insts  	(pipeline_completed_insts),
	    .pipeline_error_status   	(pipeline_error_status),
	    .pipeline_commit_wr_idx 	(pipeline_commit_wr_idx),
	    .pipeline_commit_wr_data 	(pipeline_commit_wr_data),
	    .pipeline_commit_wr_en      (pipeline_commit_wr_en),
	    .pipeline_commit_NPC 	    (pipeline_commit_NPC),
		.PC_out						(PC_out),
// newly-added for debugging
	.if_valid_inst_out,
	.if_IR_out,

	.id_valid_inst_out,
	.id_IR_out,
	.id_opa_valid,
	.id_opb_valid,

	.id_ex_valid_inst,
	.id_ex_IR,
	.id_ex_opa_valid,
	.id_ex_opb_valid,
	.id_ex_rs1_value,
	.id_ex_rs2_value,

	.except,
	.rob_direction_out,
    .rob_PC_out,
	.rob_num_free,
	.dest_ARN_out,
	.valid_out,
	
	.rs_valid_inst_out,
	.rs_IR_out,
    .rs_num_is_free,
	.rs_load_in_hub(rs_load_in_hub),
	.rs_is_free_hub(rs_is_free_hub),
	.rs_ready_hub(rs_ready_hub),

	.ex_valid_inst_out,
	.ex_alu_result_out,
	.ALU_occupied,
	.brand_result
    );


	// Instantiate the Data Memory
	mem memory (
        // Inputs
        .clk               (clock),
        .proc2mem_command  (proc2mem_command),
        .proc2mem_addr     (proc2mem_addr),
        .proc2mem_data     (proc2mem_data),
        .proc2mem_size     (proc2mem_size),

        // Outputs

        .mem2proc_response (mem2proc_response),
        .mem2proc_data     (mem2proc_data),
        .mem2proc_tag      (mem2proc_tag)
    );


    // ------------------------- testbench logic & tasks ------------------------- 

	// Task to display # of elapsed clock edges
	task show_clk_count (input[3:0] last_inst_count);
		real cpi;
		begin
			cpi = (clock_count + 1.0) / (instr_count + last_inst_count -1);
			$display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
			          clock_count+1, instr_count + last_inst_count -1, cpi);
			$display("@@  %4.2f ns total time to execute\n@@\n",
			          clock_count*`VERILOG_CLOCK_PERIOD);
		end
	endtask  // task show_clk_count 


	task clean_cache_and_write_mem;
		for(int i = 0; i < 32; i++) begin
			if(core.DMEM_0.dcache_0.valid[i] & core.DMEM_0.dcache_0.dirty[i]) begin
				mem.unified_memory[32 * core.DMEM_0.dcache_0.tags[i] + i] = core.DMEM_0.dcache_0.data[i];
			end
		end

		for(int i = 0; i < 2; i++) begin
			if(core.DMEM_0.dcache_0.victim_valid[i] & core.DMEM_0.dcache_0.victim_dirty[i]) begin
				mem.unified_memory[core.DMEM_0.dcache_0.victim_tags[i]] = core.DMEM_0.dcache_0.victim_data[i];
			end
		end
	endtask

	// Show contents of a range of Unified Memory, in both hex and decimal
	task show_mem_with_decimal;
		input [31:0] start_addr;
		input [31:0] end_addr;
		int showing_data;
		begin
			$display("@@@");
			showing_data=0;
			for(int k=start_addr;k<=end_addr; k=k+1)
				if (memory.unified_memory[k] != 0) begin
					$display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k], 
				                                            memory.unified_memory[k]);
					showing_data=1;
				end else if(showing_data!=0) begin
					$display("@@@");
					showing_data=0;
				end
			$display("@@@");
		end
	endtask  // task show_mem_with_decimal





    // ------------------------- always @ clock logic ------------------------- 

	// Count the number of posedges and number of instructions completed
	// till simulation ends
	always @(posedge clock) begin
//	$display("time: %4.0f",$time);
		if(reset) begin
	//		$display("@@ %t : System at reset", $realtime); // FOR DEBUG
			clock_count <= `SD 0;
			instr_count <= `SD 0;
		end else begin
			clock_count <= `SD (clock_count + 1);
			instr_count <= `SD (instr_count + pipeline_completed_insts);
		end
	end


	always @(negedge clock) begin
        if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@", $realtime);
            debug_counter <= `SD 0;
        end else begin
			`SD;
			`SD;

			// print the processor stuff via c code to the processor.out
			for(int i = 0; i < `WAYS; i++) begin
				print_cycles($realtime, clock_count);
				print_stage(" ", if_IR_out[i], {31'b0,if_valid_inst_out[i]});
				print_stage("|", id_IR_out[i], {31'b0,id_valid_inst_out[i]});
				print_valids({31'b0, id_opa_valid[i]}, {31'b0, id_opb_valid[i]});
				print_stage("|", id_ex_IR[i], {31'b0,id_ex_valid_inst[i]});
				print_opaopb({31'b0, id_ex_opa_valid[i]}, {31'b0, id_ex_opb_valid[i]}, id_ex_rs1_value[i], id_ex_rs2_value[i]);
				print_rob("|", {31'b0, except}, {31'b0, rob_direction_out[i]}, rob_PC_out[i], {27'b0, rob_num_free}, {27'b0, dest_ARN_out[i]}, {31'b0, valid_out[i]});
				print_rs("|", rs_IR_out[i], {31'b0,rs_valid_inst_out[i]}, {27'b0, rs_num_is_free}, {16'b0, rs_load_in_hub}, {16'b0, rs_is_free_hub}, {16'b0, rs_is_free_hub});
				print_ex_out("|", ex_alu_result_out[i], {31'b0,ex_valid_inst_out[i]}, {31'b0, ALU_occupied[i]}, {31'b0, brand_result[i]},core.ex_packet_out[i].NPC);

				print_reg(32'b0, pipeline_commit_wr_data[31:0],
					{27'b0,pipeline_commit_wr_idx}, {31'b0,pipeline_commit_wr_en});
				print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
					32'b0, proc2mem_addr[31:0],
					proc2mem_data[63:32], proc2mem_data[31:0]);
			end


`ifdef WRITEBACK
			// cross module referencing error fixed
			// print the writeback information to writeback.out
			if(pipeline_completed_insts>0) begin
                for(int i = 0; i < `WAYS; i++) begin
                    if(core.valid_out[i])
                        $fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
                            core.PC_out[i],
                            core.dest_ARN_out[i],
                            core.id_stage_0.prf.registers[core.dest_PRN_out[i]]);
                end
			end
`endif
			// deal with any halting conditions
			if((pipeline_error_status != NO_ERROR && pipeline_error_status != LOAD_ACCESS_FAULT) || debug_counter > 10000000) begin
				$display("@@@ Unified Memory contents hex on left, decimal on right: ");
				clean_cache_and_write_mem;
				show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
				// 8Bytes per line, 16kB total
				
				$display("@@  %t : System halted\n@@", $realtime);
				
				case(pipeline_error_status)
					LOAD_ACCESS_FAULT:  
						$display("@@@ System halted on memory error");
					HALTED_ON_WFI:          
						$display("@@@ System halted on WFI instruction");
					ILLEGAL_INST:
						$display("@@@ System halted on illegal instruction");
					default: 
						$display("@@@ System halted on unknown error code %x", 
							pipeline_error_status);
				endcase
				$display("@@@\n@@");
				show_clk_count(pipeline_completed_insts);
//				print_close(); // close the pipe_print output file
				$fclose(wb_fileno);
				#500 $finish;
			end

            debug_counter <= debug_counter + 1;
		end  // if(reset)
	end



    /* ------------------------- driver ------------------------- */
    initial begin

        clock = 1'b0;
        reset = 1'b1;
//	$monitor("time: %4.0f if_valid_inst_out: %b id_valid_inst_out: %b id_IR_out[0]: %h rs_valid_inst_out:%b ex_valid_inst_out: %b",
//	$time,if_valid_inst_out,id_valid_inst_out,id_IR_out[0],rs_valid_inst_out,ex_valid_inst_out);
        $display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
        reset = 1'b1;
		@(posedge clock);
        @(posedge clock);

        $readmemh("program.mem", memory.unified_memory);

        @(posedge clock);
        @(posedge clock);
        `SD;
        // This reset is at an odd time to avoid the pos & neg clock edges

        reset = 1'b0;
        $display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);

        wb_fileno = $fopen("writeback.out");
        print_header("                       IF               ID                           ID_EX                                   ROB                             RS                    EX_OUT          D-MEM Bus &\n");
        print_header("   Time:   Cycle:  VLD    IR   | VLD    IR   V1 V2| VLD    IR  VLD         OP_A  VLD       OP_B| DIR    PC     NF EXC   ARN VLD|    IR     NF  LD   FR   RD | VLD     ALU OC BR    Reg Result");
    end




    // Generate System Clock
    always begin
        #(`VERILOG_CLOCK_PERIOD/2.0);
        clock = ~clock;
    end



endmodule
