

// i think 1000 is enough...
// if not then change this
`define ROB_NUM_TESTS   1000
`define SIZE_OF_TEST    (`WAYS * 12)
`define SIZE_OF_OUTPUT  (`WAYS * 3 + 2)


extern void generate_test(int, int, int, int, int, int);

module testbench;

    logic                                   clock;
    logic                                   reset;

    // loading files into memory
    logic [63:0]                            test_input      [(`ROB_NUM_TESTS * `WAYS * 12) - 1:0];
    logic [63:0]                            correct_out     [(`ROB_NUM_TESTS * (`WAYS * 3 + 2)) - 1:0];

    // wire declarations for rob inputs/outputs
    logic [`WAYS-1:0] [$clog2(`ROB)-1:0]    CDB_ROB_idx;
    logic [`WAYS-1:0]                       CDB_valid;
    logic [`WAYS-1:0]                       CDB_direction;
    logic [`WAYS-1:0] [`XLEN-1:0]           CDB_target;

    logic [`WAYS-1:0] [$clog2(`REGS)]        dest_ARN;
    logic [`WAYS-1:0] [$clog2(`PRF)]        dest_PRN;
    logic [`WAYS-1:0]                       reg_write;
    logic [`WAYS-1:0]                       is_branch;
    logic [`WAYS-1:0]                       valid;
    logic [`WAYS-1:0] [`XLEN-1:0]           PC;
    logic [`WAYS-1:0] [`XLEN-1:0]           inst_target;
    logic [`WAYS-1:0]                       prediction;

    // outputs
    logic [`XLEN-1:0]                       tail_ptr;
    logic [`WAYS-1:0] [$clog2(`PRF)-1:0]    dest_PRN_out;
    logic [`WAYS-1:0] [$clog2(`REGS)-1:0]   dest_ARN_out;
    logic [`WAYS-1:0]                       valid_out;
    logic [$clog2(`ROB)-1:0]                num_free;


    rob rob_instance(
        clock,
        reset,


        CDB_ROB_idx,
        CDB_valid,
        CDB_direction,
        CDB_target,

        dest_ARN,
        dest_PRN,
        reg_write,
        is_branch,
        valid,
        PC,
        inst_target,
        prediction,

        tail,
        dest_PRN_out,
        dest_ARN_out,
        valid_out,
        num_free
    );

    logic [$clog2(`ROB_NUM_TESTS)-1:0]  curr_test;
    logic                               correct;

    always_comb begin
        int start = curr_test * (`WAYS * 12);
        for(int i = 0; i < `WAYS; i++)
        begin : foo
            CDB_ROB_idx[i] = test_input[start + i * 12];
            CDB_valid[i] = test_input[start + i * 12 + 1];
            CDB_direction[i] = test_input[start + i * 12 + 2];
            CDB_target[i] = test_input[start + i * 12 + 3];

            dest_ARN[i] = test_input[start + i * 12 + 4];
            dest_PRN[i] = test_input[start + i * 12 + 5];
            reg_write[i] = test_input[start + i * 12 + 6];
            is_branch[i] = test_input[start + i * 12 + 7];
            valid[i] = test_input[start + i * 12 + 8];
            PC[i] = test_input[start + i * 12 + 9];
            inst_target[i] = test_input[start + i * 12 + 10];
            prediction[i] = test_input[start + i * 12 + 11];
        end
    end

    always_comb begin
        correct = 1'b1;

        if(tail != correct_out[(curr_test * (`WAYS * 3 + 2))])
            correct = 1'b0;

        for(int j = 0; j < `WAYS; j++)
        begin: foo
            if(valid_out != correct_out[(curr_test * (`WAYS * 3 + 2)) + 3 + (j * 3)])
                correct = 1'b0;
            if(valid_out) begin
                if(dest_PRN_out != correct_out[(curr_test * (`WAYS * 3 + 2)) + 1 + (j * 3)])
                    correct = 1'b0;
                if(dest_ARN_out != correct_out[(curr_test * (`WAYS * 3 + 2)) + 2 + (j * 3)])
                    correct = 1'b0;
            end
        end
        if(num_free != correct_out[(curr_test * (`WAYS * 3 + 2)) + 1 + (`WAYS * 3)])
            correct = 1'b0;
    end

    task check_correct;
        #3
        if(!correct) begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("tail: %h", tail_ptr);
            for(int i = 0; i < `WAYS; i++)
            begin : foo
                $display("dest_ARN: %h", dest_ARN[i]);
                $display("dest_PRN: %h", dest_PRN[i]);
                $display("valid_out: %h", valid_out[i]);
            end
            $display("num_free: %h", num_free);
            $display("@@@ Failed");
            $finish;
        end
    endtask

    always_ff @(posedge clock) begin
        if(reset)
            curr_test <= `SD 0;
        else begin
            curr_test <= `SD curr_test + 1;
            check_correct;
        end
    end

    always begin
        #(`VERILOG_CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    initial begin
        clock = 1'b0;
        reset = 1'b0;

        // this testbench re-generates the test file and output key every time
        // we may seed the RNG using system time to generate different test cases
        // currently this just generates the same thing every time we run it...
        $display("generating test file...");
        generate_test(`WAYS, `ROB, `PRF, `PRF - `ROB, `XLEN, `ROB_NUM_TESTS);
        $display("finished generating test file");

        $display("@@\n@@\n@@    %t  Asserting System reset......", $realtime);
        reset = 1'b1;
        @(posedge clock);
        @(posedge clock);

        $readmemh("rob_test.mem", test_input);
        $readmemh("rob_test.correct", correct_out);

        @(posedge clock);
        @(posedge clock);
        `SD;

        reset = 1'b0;

        $display("@@    %t  Deasserting System reset......\n@@\n@@", $realtime);

        repeat(`ROB_NUM_TESTS) @(posedge clock);


        $finish;
    end

endmodule
