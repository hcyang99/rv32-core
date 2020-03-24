
// struct definitions
typedef struct packed{
    logic [$clog2(`REGS)-1:0]   dest_ARN;
    logic [$clog2(`PRF)-1:0]    dest_PRN;
    logic                       reg_write;
    logic                       is_branch;
    logic [`XLEN-1:0]           PC;
    logic [`XLEN-1:0]           target;
    logic                       branch_direction;
    logic                       mispredicted;
    // TODO: include load and store stuff
    logic                       done;
}rob_entry;



module rob(
    input                                           clock,
    input                                           reset,

    // wire declarations for rob inputs/outputs
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]            CDB_ROB_idx,
    input [`WAYS-1:0]                               CDB_valid,
    input [`WAYS-1:0]                               CDB_direction,
    input [`WAYS-1:0] [`XLEN-1:0]                   CDB_target,

    input [`WAYS-1:0] [$clog2(`REGS)-1:0]           dest_ARN,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]            dest_PRN,
    input [`WAYS-1:0]                               reg_write,
    input [`WAYS-1:0]                               is_branch,
    input [`WAYS-1:0]                               valid,
    input [`WAYS-1:0] [`XLEN-1:0]                   PC,
    input [`WAYS-1:0] [`XLEN-1:0]                   target,
    input [`WAYS-1:0]                               branch_direction,

    output logic [$clog2(`ROB)-1:0]                 next_tail,
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0]     dest_ARN_out,
    output logic [`WAYS-1:0] [$clog2(`REGS)-1:0]    dest_PRN_out,
    output logic [`WAYS-1:0]                        valid_out,
    output logic [$clog2(`ROB):0]                   next_num_free
);

rob_entry [`ROB-1:0]                                entries;
logic [$clog2(`ROB)-1:0]                            head;
logic [$clog2(`ROB)-1:0]                            tail;
logic [$clog2(`ROB)-1:0]                            next_head;
//logic [$clog2(`ROB)-1:0]                          next_tail;
logic [$clog2(`WAYS)-1:0]                           num_dispatched;
logic [$clog2(`WAYS)-1:0]                           num_committed;
rob_entry [`WAYS-1:0]                               new_entries;
logic                                               proc_nuke;
logic [$clog2(`ROB):0]                              num_free;

// Dispatch combinational logic
always_comb begin
    num_dispatched = 0;
    for(int i = 0; i < `WAYS; i++) begin
    
        // Store inputs in ROB if valid
        if(valid[i]) begin
            new_entries[i].dest_ARN = dest_ARN[i];
            new_entries[i].dest_PRN = dest_PRN[i];
            new_entries[i].reg_write = reg_write[i];
            new_entries[i].is_branch = is_branch[i];
            new_entries[i].PC = PC[i];
            new_entries[i].target = target[i];
            new_entries[i].branch_direction = branch_direction[i];
            new_entries[i].mispredicted = 0;
            new_entries[i].done = 0;

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
    for(int i = 0; i < `WAYS; i++) begin
        valid_out[i] = 0;
        dest_PRN_out[i] = 0;
        dest_ARN_out[i] = 0;
    end
    for(int i = 0; i < `WAYS; i++) begin
        next_num_free = num_free - num_dispatched + num_committed;
        if(entries[(head + i) % `ROB].done) begin
            dest_PRN_out[i] = entries[(head + i) % `ROB].dest_PRN;
            dest_ARN_out[i] = entries[(head + i) % `ROB].dest_ARN;
            num_committed = i + 1;
            if(entries[(head + i) % `ROB].reg_write) 
                valid_out[i] = 1;
            if(entries[(head + i) % `ROB].is_branch && entries[(head + i) % `ROB].mispredicted) begin
                proc_nuke = 1;
                next_tail = 0;
                next_num_free = `ROB;
                break;
            end
        end else break;
    end

    // Move head based on number of valid inputs received
    next_head = (head + num_committed) % `ROB;
end

// Sequential Logic
always_ff @(posedge clock) begin
    if(reset || proc_nuke) begin
        num_free            <= `SD `ROB;
        tail                <= `SD 0;
        head                <= `SD 0;
        entries[0].done  <= `SD 1'b0;
    end else begin
        for(int i = 0; i < `WAYS; i++) begin
            
            // Dispatch logic
            if(valid[i]) begin
                entries[(tail + i) % `ROB] <= `SD new_entries[i];
            end

            // CDB logic
            if(CDB_valid[i]) begin
                entries[CDB_ROB_idx[i]].done             <= `SD 1'b1;
                entries[CDB_ROB_idx[i]].mispredicted     <= `SD
                    entries[CDB_ROB_idx[i]].branch_direction == CDB_direction[i] ?
                    (CDB_direction[i] == 0 || entries[CDB_ROB_idx[i]].target == CDB_target[i] ? 1'b0 : 1'b1) : 1'b1;
                entries[CDB_ROB_idx[i]].branch_direction <= `SD CDB_direction[i];
                entries[CDB_ROB_idx[i]].target           <= `SD CDB_target[i];
            end
        end
        tail                <= `SD next_tail;
        head                <= `SD next_head;
        num_free            <= `SD next_num_free;
    end
end

endmodule
