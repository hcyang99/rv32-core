module testbench;
    parameter REQS  = 4;
    parameter WIDTH = 8;
        
      // Inputs
    logic  [WIDTH-1:0]       req;

  // Outputs
    wor  [WIDTH-1:0]       gnt;
    wand [WIDTH*REQS-1:0]  gnt_bus;
    wire                   empty;

    logic quit;

    psel_gen #(REQS,WIDTH) mypsel_gen(req,gnt,gnt_bus,empty);

    initial 
    begin
        $monitor("Time:%4.0f req:%b gnt:%b gnt_bus:%h empty:%h", $time, req, gnt, gnt_bus, empty);
        #5    
        req = 0;

        quit = 0;
		quit <= #1300 1;
		while(~quit) begin
			#5
            req = req + 1;
		end
        $finish;
     end // initial
endmodule