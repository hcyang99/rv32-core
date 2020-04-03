

`timescale 1ns/100ps

extern void print_header(string str);
extern void print_cycles(int cycle_count);
extern void print_stage(string div, int inst, int valid_inst);
extern void print_rs(string div, int inst, int valid_inst, int num_free);
extern void print_rob(string div, int direction, int PC, int num_free);
extern void print_ex_out(string div, int alu_result, int valid);
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
`ifndef CACHE_MODE
	MEM_SIZE     proc2mem_size;
`endif
	logic  [3:0] pipeline_completed_insts;
	EXCEPTION_CODE   pipeline_error_status;
	logic  [4:0] pipeline_commit_wr_idx;
	logic [`XLEN-1:0] pipeline_commit_wr_data;
	logic        pipeline_commit_wr_en;
	logic [`XLEN-1:0] pipeline_commit_NPC;

	logic [`WAYS-1:0]	if_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] if_IR_out;

	logic [`WAYS-1:0]	id_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] id_IR_out;

	logic [`WAYS-1:0]	id_ex_valid_inst;
	logic [`WAYS-1:0] [`XLEN-1:0] id_ex_IR;

	logic [`WAYS-1:0]	rob_direction_out;
    logic [`WAYS-1:0] [`XLEN-1:0] rob_PC_out;
	logic [$clog2(`ROB):0]  rob_next_num_free;
	
	logic [`WAYS-1:0]    rs_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] rs_IR_out;
    logic [$clog2(`RS):0]    rs_num_is_free;

	logic [`WAYS-1:0]    ex_valid_inst_out;
	logic [`WAYS-1:0] [`XLEN-1:0] ex_alu_result_out;

    logic [63:0] debug_counter;
	logic [`WAYS-1:0] 	OPA_VALID;
	logic [`WAYS-1:0] 	OPB_VALID;

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
`ifndef CACHE_MODE
        .proc2mem_size              (proc2mem_size),
`endif

	    .pipeline_completed_insts  	(pipeline_completed_insts),
	    .pipeline_error_status   	(pipeline_error_status),
	    .pipeline_commit_wr_idx 	(pipeline_commit_wr_idx),
	    .pipeline_commit_wr_data 	(pipeline_commit_wr_data),
	    .pipeline_commit_wr_en      (pipeline_commit_wr_en),
	    .pipeline_commit_NPC 	    (pipeline_commit_NPC),
// newly-added for debugging
	.if_valid_inst_out,
	.if_IR_out,

	.id_valid_inst_out,
	.id_IR_out,

	.id_ex_valid_inst,
	.id_ex_IR,

	.rob_direction_out,
    .rob_PC_out,
	.rob_next_num_free,
	
	.rs_valid_inst_out,
	.rs_IR_out,
    .rs_num_is_free,

	.ex_valid_inst_out,
	.ex_alu_result_out,

	.OPA_VALID,
	.OPB_VALID
    );


	// Instantiate the Data Memory
	mem memory (
        // Inputs
        .clk               (clock),
        .proc2mem_command  (proc2mem_command),
        .proc2mem_addr     (proc2mem_addr),
        .proc2mem_data     (proc2mem_data),
`ifndef CACHE_MODE
        .proc2mem_size     (proc2mem_size),
`endif

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
	$display("time: %4.0f",$time);
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
				print_cycles(clock_count);
				print_stage(" ", if_IR_out[i], {31'b0,if_valid_inst_out[i]});
				print_stage("|", id_IR_out[i], {31'b0,id_valid_inst_out[i]});
				print_stage("|", id_ex_IR[i], {31'b0,id_ex_valid_inst[i]});
				print_rob("|", {31'b0, rob_direction_out[i]}, rob_PC_out[i], {28'b0, rob_next_num_free});
				print_rs("|", rs_IR_out[i], {31'b0,rs_valid_inst_out[i]}, {28'b0, rs_num_is_free});
				print_ex_out("|", ex_alu_result_out[i], {31'b0,ex_valid_inst_out[i]});

				print_reg(32'b0, pipeline_commit_wr_data[31:0],
					{27'b0,pipeline_commit_wr_idx}, {31'b0,pipeline_commit_wr_en});
				print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
					32'b0, proc2mem_addr[31:0],
					proc2mem_data[63:32], proc2mem_data[31:0]);
			end



			// cross module referencing error fixed
			// print the writeback information to writeback.out
			if(pipeline_completed_insts>0) begin
                for(int i = 0; i < `WAYS; i++) begin
                    if(core.valid_out[i])
                        $fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
                            core.PC_out[i],
                            core.dest_ARN_out[i],
                            core.id_stage_0.prf.registers[core.dest_PRN_out[i]]);
                    else
					    $fdisplay(wb_fileno, "PC=%x, ---", core.PC_out[i]);
                end
			end

			// deal with any halting conditions
			if((pipeline_error_status != NO_ERROR && pipeline_error_status != LOAD_ACCESS_FAULT) || debug_counter > 50000) begin
				$display("@@@ Unified Memory contents hex on left, decimal on right: ");
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
				#100 $finish;
			end

            debug_counter <= debug_counter + 1;
		end  // if(reset)   
	end 



    /* ------------------------- driver ------------------------- */
    initial begin

        clock = 1'b0;
        reset = 1'b1;
	$monitor("time: %4.0f if_valid_inst_out: %b id_valid_inst_out: %b id_IR_out[0]: %h id_opa_valid: %b id_opb_valid: %b ex_valid_inst_out: %b",
	$time,if_valid_inst_out,id_valid_inst_out,id_IR_out[0],OPA_VALID, OPB_VALID,ex_valid_inst_out);
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
        print_header("            IF            ID            EX              ROB              RS           EX_OUT     D-MEM Bus &\n");
        print_header("Cycle:  VLD    IR   | VLD    IR   | VLD    IR   | DIR    PC     NF |   IR     NF | VLD      ALU  Reg Result");
    end




    // Generate System Clock
    always begin
        #(`VERILOG_CLOCK_PERIOD/2.0);
        clock = ~clock;
    end



endmodule