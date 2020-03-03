module testbench;
    logic clock, reset;
    RS rs_dummy (
        // inputs
        .clock(clock),
        .reset(reset),
        .CDB_Data(),
        .CDB_PRF_idx(),
        .CDB_valid(),
        .opa_in(),
        .opb_in(),
        .opa_valid_in(),
        .opb_valid_in(),
        .rd_mem_in(),                          
        .wr_mem_in(),
        .dest_PRF_idx_in(),
        .rob_idx_in(),                             
        .load_in(),
        .offset_in(),
        .PC_in(),
        .Operation_in(),

        // output
        .inst_out_valid(), // tell which inst is valid, **001** when only one inst is valid 
        .opa_out(),
        .opb_out(),
        .dest_PRF_idx_out(),
        .rob_idx_out(),

        .PC_out(),
        .Operation_out(),
        .offset_out(),
        .num_is_free(),
    
        .rd_mem_out(),                          
        .wr_mem_out()    
    );
    
    initial begin
        @ (negedge clock);
        $finish;
    end
endmodule