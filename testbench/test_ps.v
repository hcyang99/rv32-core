module testbench;
    parameter NUM_BITS = 16;
    logic [NUM_BITS-1:0] req;
    logic                 en;

    logic [NUM_BITS-1:0] gnt;
    logic               req_up;
        

    ps #(NUM_BITS) myps(req, en, gnt, req_up);

    initial 
    begin
        $monitor("Time:%4.0f en:%b req:%b gnt:%b req_up:%d", $time, en,req, gnt, req_up);
        en = 1;
        #5    
        req=16'h0123;
        #5
        req=16'h0001;
        #5
        req=16'h0008;
        #5
        req=16'hf080;
        #5
        req=16'h0400;
        #5
        $finish;
     end // initial
endmodule