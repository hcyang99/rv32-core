module testbench;
    parameter OUT_WIDTH = 4;

    parameter IN_WIDTH = 1<<OUT_WIDTH;

    logic [IN_WIDTH-1:0] gnt;

	logic [OUT_WIDTH-1:0] enc;

    pe #(OUT_WIDTH,IN_WIDTH) mype(gnt,enc);

    initial 
    begin
        $monitor("Time:%4.0f gnt:%b enc:%d", $time, gnt, enc);
        gnt=16'h0f00;
        #5    
        gnt=16'h1000;
        #5
        gnt=16'h0101;
        #5
        gnt=16'h0008;
        #5
        gnt=16'h0080;
        #5
        gnt=16'h0400;
        #5
        $finish;
     end // initial
endmodule