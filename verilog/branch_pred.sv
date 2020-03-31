module branch_pred #(parameter SIZE=128) (
    input clock, reset,

    // Input to make prediction(s)
    input [`XLEN-1:0]                   PC,

    // Input to update state based on committed branch(es)
    input [`WAYS-1:0] [`XLEN-1:0]       PC_update,
    input [`WAYS-1:0]                   direction_update,
    input [`WAYS-1:0] [`XLEN-1:0]       target_update,
    input [`WAYS-1:0]                   valid_update,

    // Output
    output logic [`XLEN-1:0]            next_PC,
    output logic [`WAYS-1:0]            predictions
);

    // Internal register declarations (BTB and PHT)
    logic [SIZE-1:0] [`XLEN-1:0]        BTB;
    logic [SIZE-1:0]                    BTB_valid;
    logic [SIZE-1:0] [1:0]              PHT;

    // index = PC[$clog2(SIZE)+1:2]

    // Combinational/Output logic
    always_comb begin
        // Default output is all not taken
        next_PC = PC + (`WAYS * 4);
        predictions = 0;

        // See if something should be predicted taken
        for(int i = 0; i < `WAYS; i++) begin
            if(PHT[PC[$clog2(SIZE)+1:2] + i][1] && BTB_valid[PC[$clog2(SIZE)+1:2] + i]) begin
                next_PC = BTB[PC[$clog2(SIZE)+1:2] + i];
                predictions[i] = 1;
                break;
            end
        end
    end

    // Sequential Logic
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
    $display("PC: %h next_PC: %h", PC,next_PC);
        if(reset) begin
            BTB_valid = 0;
            for(int i = 0; i < SIZE; i++) begin
                PHT[i] = 2'b01;
            end
        end else begin
            for(int i = 0; i < `WAYS; i++) begin
                if(valid_update[i]) begin
                    if(direction_update[i]) begin
                        BTB_valid[PC_update[i][$clog2(SIZE)+1:2]] = 1;
                        BTB[PC_update[i][$clog2(SIZE)+1:2]] = target_update;
                        if(PHT[PC_update[i][$clog2(SIZE)+1:2]] < 2'b11)
                            PHT[PC_update[i][$clog2(SIZE)+1:2]] = PHT[PC_update[i][$clog2(SIZE)+1:2]] + 1;
                    end else begin
                        if(PHT[PC_update[i][$clog2(SIZE)+1:2]] > 2'b00)
                            PHT[PC_update[i][$clog2(SIZE)+1:2]] = PHT[PC_update[i][$clog2(SIZE)+1:2]] - 1;
                    end
                end // if valid_update
            end // loop
        end // if(!reset)
    end // always_ff
endmodule
