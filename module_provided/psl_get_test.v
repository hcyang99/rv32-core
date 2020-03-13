module testbench;
    parameter REQS  = 3;
    parameter WIDTH = 16;
        
      // Inputs
    logic  [WIDTH-1:0]       req;
    logic en;
    logic reset;
  // Outputs
    logic  [WIDTH-1:0]       gnt;
    wand [WIDTH*REQS-1:0]  gnt_bus;

    logic quit;

    psel_gen #(REQS,WIDTH) mypsel_gen(en,reset,req,gnt_bus);

    initial 
    begin
        $monitor("Time:%4.0f en:%b reset:%b req:%b gnt_bus:%h", $time, en, reset, req, gnt_bus);
        en = 1;
        reset = 0;
        #5    
        req = 16'hffff;
        quit = 0;
		quit <= #1300 1;
    reset <= #100 1;
    reset <= #200 0;
    en <= #300 0;
    en <= #400 1;
		while(~quit) begin
			#5
            req = req + 1;
		end
        $finish;
     end // initial
endmodule