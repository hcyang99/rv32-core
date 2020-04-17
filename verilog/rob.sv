// `include "../sys_defs.svh"
// struct definitions
typedef struct packed{
    logic [$clog2(`REGS)-1:0]   dest_ARN;
    logic [$clog2(`PRF)-1:0]    dest_PRN;
    logic                       reg_write;
    logic                       is_branch;
    logic                       is_store;
    logic [`XLEN-1:0]           PC;
    logic [`XLEN-1:0]           target;
    logic                       branch_direction;
    logic                       mispredicted;
    // TODO: include load and store stuff
    logic                       done;
    logic                       illegal;
    logic                       halt;
}rob_entry;



module rob(
    input                                           clock,
    input                                           reset,

    // wire declarations for rob inputs/outputs
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]            CDB_ROB_idx,
    input [`WAYS-1:0]                               CDB_valid,
    input [`WAYS-1:0]                               CDB_direction,
    input [`WAYS-1:0] [`XLEN-1:0]                   CDB_target,

    input [`WAYS-1:0] [4:0]                         dest_ARN,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]            dest_PRN,
    input [`WAYS-1:0]                               reg_write,
    input [`WAYS-1:0]                               is_branch,
    input [`WAYS-1:0]                               is_store,
    input [`WAYS-1:0]                               valid,
    input [`WAYS-1:0] [`XLEN-1:0]                   PC,

    input [`WAYS-1:0] [`XLEN-1:0]                   target,
    input [`WAYS-1:0]                               branch_direction,

    input [`WAYS-1:0]                               illegal,
    input [`WAYS-1:0]                               halt,

    output logic [$clog2(`ROB)-1:0]                 tail,
    output logic [$clog2(`ROB)-1:0]                 next_tail,

    output logic [`WAYS-1:0] [4:0]                  dest_ARN_out,
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0]     dest_PRN_out,
    output logic [`WAYS-1:0]                        valid_out,

    output logic [$clog2(`ROB):0]                   num_free,
    output logic [$clog2(`ROB):0]                   next_num_free,

    output logic                                    proc_nuke,
    output logic [`XLEN-1:0]                        next_pc,

    output logic [`WAYS-1:0] [`XLEN-1:0]            PC_out,
    output logic [`WAYS-1:0]                        direction_out,
    output logic [`WAYS-1:0] [`XLEN-1:0]            target_out,
    output logic [`WAYS-1:0]                        is_branch_out,

    output logic                                    illegal_out,
    output logic                                    halt_out,
    output logic [$clog2(`WAYS):0]                  num_committed,
    output logic                                    commit
);

rob_entry [`ROB-1:0]                                entries;
logic [$clog2(`ROB)-1:0]                            head;
//logic [$clog2(`ROB)-1:0]                          tail;
logic [$clog2(`ROB)-1:0]                            next_head;
//logic [$clog2(`ROB)-1:0]                            next_tail;
logic [$clog2(`WAYS)-1:0]                           num_dispatched;
//logic [$clog2(`WAYS):0]                           num_committed;
rob_entry [`WAYS-1:0]                               new_entries;
//logic [$clog2(`ROB):0]                              next_num_free;
//logic                                               store_commit;

// Combinational (next state) logic
/*
always_ff @(posedge clock) begin

for(int i = 0; i < `WAYS ; i = i + 1) begin
  //if(if_id_packet_in[i].inst == `XLEN'h00128293) begin
  if(valid[i]) begin
    $display("ENTERING ROB: PC=%h TARGET=%h DIRECTION=%b",PC[i],target[i],branch_direction[i]);
   end
   end

for(int i = 0; i < `WAYS ; i = i + 1) begin
  //if(if_id_packet_in[i].inst == `XLEN'h00128293) begin
  if(CDB_valid[i]) begin
    $display("CDB TO ROB: TARGET=%h DIRECTION=%b",CDB_target[i],CDB_direction[i]);
  end
  end
end
*/
assign next_num_free = (reset | proc_nuke) ? `ROB : (num_free - num_dispatched + num_committed);
always_comb begin

    //$display("comb start!");
    // dispatch logic
    num_dispatched = 0;
    for(int i = 0; i < `WAYS; i++) begin

        // Store inputs in ROB if valid
        if(valid[i]) begin
            new_entries[i].dest_ARN = dest_ARN[i];
            new_entries[i].dest_PRN = dest_PRN[i];
            new_entries[i].reg_write = reg_write[i];
            new_entries[i].is_branch = is_branch[i];
            new_entries[i].is_store = is_store[i];
            new_entries[i].PC = PC[i];
            new_entries[i].target = target[i];
            new_entries[i].branch_direction = branch_direction[i];
            new_entries[i].mispredicted = 0;
            new_entries[i].done = 0;
            new_entries[i].illegal = illegal[i];
            new_entries[i].halt = halt[i];


            // Valid inputs should never come after invalid inputs
            // That means the last valid i + 1 is the number of valid inputs
            num_dispatched = i + 1;
        end
    end

    // Move tail based on number of valid inputs received
    next_tail = (tail + num_dispatched) % `ROB;

    // Commit/Output combinational logic
    num_committed = 0;
    proc_nuke = 0;
    next_pc = 0;
    illegal_out = 0;
    halt_out = 0;
    commit = 0;

    // Default outputs
    for(int i = 0; i < `WAYS; i++) begin
        dest_PRN_out[i] = 0;
        dest_ARN_out[i] = 0;
        valid_out[i] = 0;

        PC_out[i] = 0;
        direction_out[i] = 0;
        target_out[i] = 0;
        is_branch_out[i] = 0;
    end

    for(int i = 0; i < `WAYS; i++) begin

        // If committing, set outputs and check for mispredicted branch
        // Everything after the && makes sure we only commit one store per cycle
        if(entries[(head + i) % `ROB].done) begin
//        $display("COMMIT PC=%h MIS=%b IDX=%d",entries[(head + i) % `ROB].PC,entries[(head + i) % `ROB].mispredicted,(head + i) % `ROB);
            dest_PRN_out[i] = entries[(head + i) % `ROB].dest_PRN;
            dest_ARN_out[i] = entries[(head + i) % `ROB].dest_ARN;
            valid_out[i] = entries[(head + i) % `ROB].reg_write;

            PC_out[i] = entries[(head + i) % `ROB].PC;
            direction_out[i] = entries[(head + i) % `ROB].branch_direction;
            target_out[i] = entries[(head + i) % `ROB].target;
            is_branch_out[i] = entries[(head + i) % `ROB].is_branch;

            illegal_out = illegal_out | entries[(head + i) % `ROB].illegal;
            halt_out = halt_out | entries[(head + i) % `ROB].halt;
            commit = commit | entries[(head + i) % `ROB].is_store;
            
            num_committed = i + 1;
           if(halt_out | commit) begin
         //  proc_nuke=1;
           break;
           end
        //   next_num_free = next_num_free + 1;

            // if(entries[(head + i) % `ROB].reg_write) 
                // valid_out[i] = 1;
            

            if(entries[(head + i) % `ROB].is_branch && entries[(head + i) % `ROB].mispredicted) begin
 //           $display("MISPREDICT");
                proc_nuke = 1;
                if(entries[(head + i) % `ROB].branch_direction)
                    next_pc = entries[(head + i) % `ROB].target;
                else
                    next_pc = entries[(head + i) % `ROB].PC + 4;
                next_tail = 0;
            //    next_num_free = `ROB;
                break;
            end
        end else break;
    end

    // Move head based on number of valid inputs received
    next_head = (head + num_committed) % `ROB;
    //$display("comb end!");
end





// Sequential Logic
// synopsys sync_set_reset "reset" 
always_ff @(posedge clock) begin
    //$display("sequential start!");
    if(reset || proc_nuke) begin
        num_free            <= `SD `ROB;
        tail                <= `SD 0;
        head                <= `SD 0;
        //entries[0].done     <= `SD 1'b0;
        entries <= `SD 0;
    end else begin
        for(int i = 0; i < `WAYS; i++) begin

            // Dispatch logic
            if(valid[i]) begin
                entries[(tail + i) % `ROB] <= `SD new_entries[i];
            end

            // CDB logic
            if(CDB_valid[i] && entries[CDB_ROB_idx[i]]!=0) begin
                //$display("ROB idx%d now done!", CDB_ROB_idx[i]);
                entries[CDB_ROB_idx[i]].done             <= `SD 1'b1;
                entries[CDB_ROB_idx[i]].mispredicted     <= `SD entries[CDB_ROB_idx[i]].is_branch && (CDB_target[i]!=entries[CDB_ROB_idx[i]].target);            //   entries[CDB_ROB_idx[i]].is_branch && 
         //           (entries[CDB_ROB_idx[i]].branch_direction != CDB_direction[i]) ||
        //            (CDB_direction[i] == 1 && entries[CDB_ROB_idx[i]].target != CDB_target[i]);
                entries[CDB_ROB_idx[i]].branch_direction <= `SD CDB_direction[i];
                entries[CDB_ROB_idx[i]].target           <= `SD CDB_target[i];

//                $display("DONE ROB : PC=%h CDB TARGET=%h IDX=%d",  entries[CDB_ROB_idx[i]].PC ,CDB_target[i],CDB_ROB_idx[i]);
            end
        end

        // Commit logic
        for(int i = 0; i < num_committed; i++) begin
            entries[(head + i) % `ROB].done <= 0;
        end

        // Other state updates
        tail                <= `SD next_tail;
        head                <= `SD next_head;
        num_free            <= `SD next_num_free;
//        $display("HEAD:%d TAIL:%d NUM_FREE:%d",head,tail,num_free);
    end
    //$display("sequential end!");
end

endmodule

