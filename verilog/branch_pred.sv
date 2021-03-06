module branch_pred_v2 #(parameter SIZE=128,//Size of BHT
    parameter PSZ=128,//Size of PHT
    parameter PL=7,//PL=$clog2(PSZ)
    parameter NS=32,//Num of set of BTB
    parameter NW=4)(//Num of way of BTB
    
    input clock, reset,

    // Input to make prediction(s)
    input [`XLEN-1:0] PC,
    input [`WAYS-1:0] is_branch,
    input [`WAYS-1:0] is_valid,
    // Input to update state based on committed branch(es)
    input [`WAYS-1:0] [`XLEN-1:0]       PC_update,
    input [`WAYS-1:0]                   direction_update,
    input [`WAYS-1:0] [`XLEN-1:0]       target_update,
    input [`WAYS-1:0]                   valid_update,

    // Output
    output logic [`XLEN-1:0]            next_PC,
    output logic [`WAYS-1:0]            predictions
);

    // Internal register declarations (BHT and PHT and BTB)
    logic [SIZE-1:0] [PL-1:0]          BHT;
    logic [PSZ-1:0] [1:0]              PHT;

    logic [NS-1:0] [NW-1:0] [`XLEN-1:0]     BTB_PC;
    logic [NS-1:0] [NW-1:0] [`XLEN-1:0]     BTB_target;
    logic [NS-1:0] [NW-1:0]                 BTB_valid;
    //logic [NS-1:0] [NW-1:0] [$clog2(NW)-1:0]  BTB_LRU;
    logic branch;
    //logic hit;
    logic [$clog2(NW)-1:0] LRU;
    // index = PC[$clog2(SIZE)+1:2]

    // Combinational/Output logic
    always_comb begin
        // Default output is all not taken
        next_PC = PC + (`WAYS * 4);
        predictions = 0;
        branch = 0;

        // See if something should be predicted taken
        for(int i = 0; i < `WAYS; i++) begin
            if(PHT[BHT[PC[$clog2(SIZE)+1:2] + i]][1] && is_branch[i] && is_valid[i] ) begin
                //next_PC = BTB[PC[$clog2(SIZE)+1:2] + i]; && BTB_valid[PC[$clog2(SIZE)+1:2] + i]
               for(int j=0; j < NW; j++)begin
                   if(BTB_valid[PC[$clog2(NS)+1:2]+i][j]==1 && BTB_PC[PC[$clog2(NS)+1:2]+i][j]==PC+(i*4) )begin
                      next_PC = BTB_target[PC[$clog2(NS)+1:2]+i][j];
                      predictions[i] = 1;
                      branch =1;
                      break;
                   end
                end
            end
            if(branch)break;
        end
        
    end

    // Sequential Logic
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
//    $display("PC: %h next_PC: %h", PC,next_PC);
        if(reset) begin
            BTB_valid  <= `SD 0;
            BHT        <= `SD 0;
            BTB_PC     <= `SD 0;
            BTB_target <= `SD 0;
            for(int i = 0; i < PSZ; i++) begin
                PHT[i] <= `SD 2'b01;
            end
        end else begin
            for(int i = 0; i < `WAYS; i++) begin
                if(valid_update[i]) begin
                    if(direction_update[i]) begin
                        //hit = 0;
                        //BTB_valid[PC_update[i][$clog2(SIZE)+1:2]] <= `SD 1;
                        // BTB[PC_update[i][$clog2(SIZE)+1:2]] <= `SD target_update[i];
                        BHT[PC_update[i][$clog2(SIZE)+1:2]] <= `SD {BHT[PC_update[i][$clog2(SIZE)+1:2]][PL-2:0],1'b1};

                        if(PHT[BHT[PC_update[i][$clog2(SIZE)+1:2]]] < 2'b11)begin
                            PHT[BHT[PC_update[i][$clog2(SIZE)+1:2]]] <= `SD PHT[BHT[PC_update[i][$clog2(SIZE)+1:2]]] + 1;
                        end

                        LRU = NW;

                        for(int j=0; j < NW; j++)begin
                         if(BTB_valid[PC_update[i][$clog2(NS)+1:2]][j]==1 && BTB_PC[PC_update[i][$clog2(NS)+1:2]][j]==PC_update[i])begin
                            //BTB_target[PC_update[i][$clog2(NS)+1:2]][j] <= `SD target_update[i];
                          //  hit = 1;
                            LRU = j;
                            break;
                          end
                        end
                        
                        BTB_PC[PC_update[i][$clog2(NS)+1:2]][0] <= `SD PC_update[i];
                        BTB_target[PC_update[i][$clog2(NS)+1:2]][0] <= `SD target_update[i];
                        BTB_valid[PC_update[i][$clog2(NS)+1:2]][0] <= `SD 1'b1;
                        for (int j = 1; j < NW; j++)begin
                          if(j < LRU +1 )begin
                             BTB_PC[PC_update[i][$clog2(NS)+1:2]][j]     <= `SD BTB_PC[PC_update[i][$clog2(NS)+1:2]][j-1];
                             BTB_target[PC_update[i][$clog2(NS)+1:2]][j] <= `SD BTB_target[PC_update[i][$clog2(NS)+1:2]][j-1];
                             BTB_valid[PC_update[i][$clog2(NS)+1:2]][j]  <= `SD BTB_valid[PC_update[i][$clog2(NS)+1:2]][j-1];
                          end
                        end

                    end else begin
                         BHT[PC_update[i][$clog2(SIZE)+1:2]] <= `SD {BHT[PC_update[i][$clog2(SIZE)+1:2]][PL-2:0],1'b0};
                        if(PHT[BHT[PC_update[i][$clog2(SIZE)+1:2]]] > 2'b00)begin
                            PHT[BHT[PC_update[i][$clog2(SIZE)+1:2]]] <= `SD PHT[BHT[PC_update[i][$clog2(SIZE)+1:2]]] - 1;
                        end    
                    end
                end // if valid_update
            end // loop
        end // if(!reset)
    end // always_ff
endmodule






module branch_pred #(parameter SIZE=128) (
    input clock, reset,

    // Input to make prediction(s)
    input [`XLEN-1:0]                   PC,
    input [`WAYS-1:0] is_branch,
    input [`WAYS-1:0] is_valid,
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
            if(PHT[PC[$clog2(SIZE)+1:2] + i][1] && BTB_valid[PC[$clog2(SIZE)+1:2] + i] && is_branch[i] && is_valid[i] ) begin
                next_PC = BTB[PC[$clog2(SIZE)+1:2] + i];
                predictions[i] = 1;
                break;
            end
        end
    end

    // Sequential Logic
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
//    $display("PC: %h next_PC: %h", PC,next_PC);
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
                        BTB[PC_update[i][$clog2(SIZE)+1:2]] = target_update[i];
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


