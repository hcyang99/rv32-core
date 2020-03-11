`define WAYS 3
`define PRF         64
`define ROB         16
`define RS          16

`define OLEN        16
`define PCLEN       32
`define WAYS        3



extern void generate_test(int, int, int, int, int);

module testbench;



    initial begin
        $display("generating test file...");
        generate_test(`WAYS, `ROB, `PRF, `PRF - `ROB, `XLEN);
        $display("finished generating test file");
        $finish;
    end

endmodule
