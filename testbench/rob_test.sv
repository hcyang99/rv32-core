

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

/*
    rob rob_instance{

    };
*/

    task check_one_test;


    endtask



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

        $finish;
    end

endmodule
