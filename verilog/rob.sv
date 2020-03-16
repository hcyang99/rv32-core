
// struct definitions
typedef struct packed{
    uint64_t dest_ARN;
    uint64_t dest_PRN;
    uint64_t reg_write;
    uint64_t is_branch;
    uint64_t PC;
    uint64_t target;
    uint64_t branch_direction;
    uint64_t mispredicted;
    // TODO: include load and store stuff
    uint64_t done;
}rob_entry;



module rob(
    input                                           clock;
    input                                           reset;

    // wire declarations for rob inputs/outputs
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]            CDB_ROB_idx;
    input [`WAYS-1:0]                               CDB_valid;
    input [`WAYS-1:0]                               CDB_direction;
    input [`WAYS-1:0] [`XLEN-1:0]                   CDB_target;

    input [`WAYS-1:0] [$clog2(`REGS)]               dest_ARN;
    input [`WAYS-1:0] [$clog2(`PRF)]                dest_PRN;
    input [`WAYS-1:0]                               reg_write;
    input [`WAYS-1:0]                               is_branch;
    input [`WAYS-1:0]                               valid;
    input [`WAYS-1:0] [`XLEN-1:0]                   PC;
    input [`WAYS-1:0] [`XLEN-1:0]                   inst_target;
    input [`WAYS-1:0]                               prediction;

    output logic [$clog2(`ROB)-1:0]                 tail;
    output logic [`WAYS-1:0] [$clog2(`PRF)-1:0]     dest_PRN_out;
    output logic [`WAYS-1:0] [$clog2(`REGS)-1:0]    dest_ARN_out;
    output logic [`WAYS-1:0]                        valid_out;
    output logic [$clog2(`ROB)-1:0]                 num_free;
)

rob_entry [`ROB-1:0]                              entries;
logic [$clog2(`ROB)-1:0]                          head;
logic [$clog2(`ROB)-1:0]                          tail;
logic [$clog2(`ROB)-1:0]                          next_head;
logic [$clog2(`ROB)-1:0]                          next_tail;
logic [$clog2(`WAYS)-1:0]                         num_dispatched;
logic [$clog2(`WAYS)-1:0]                         num_committed;

// Dispatch logic
always_comb begin
    for(int i = 0; i < `WAYS; i++) begin
    
        // Store inputs in ROB if valid
        if(valid[i]) begin
            entries[tail + i % `ROB].dest_ARN = dest_ARN[i];
            entries[tail + i % `ROB].dest_PRN = dest_PRN[i];
            entries[tail + i % `ROB].reg_write = reg_write[i];
            entries[tail + i % `ROB].is_branch = is_branch[i];
            entries[tail + i % `ROB].PC = PC[i];
            entries[tail + i % `ROB].target = target[i];
            entries[tail + i % `ROB].branch_direction = branch_direction[i];
            entries[tail + i % `ROB].mispredicted = 0;
            entries[tail + i % `ROB].done = 0;
            num_dispatched = i;
        end
    end
    
    // Move tail based on number of valid inouts received
    next_tail = tail + num_dispatched % `ROB;
end

// CDB logic
always_ff @(posedge clock) begin
    for(int i = 0; i < `WAYS; ++i) begin
        if(CDB_valid[i]) begin
            entries[CDB_ROB_idx].done             = 1'b1;
            entries[CDB_ROB_idx].mispredicted     =
                entries[CDB_ROB_idx].branch_direction == CDB_direction[i] ? 1'b0 : 1'b1;

            entries[CDB_ROB_idx].branch_direction = CDB_direction[i];
            entries[CDB_ROB_idx].target           = CDB_target[i];
        end
    end
end

// Commit logic
always_ff @(posedge clock) begin
    for(int i = 0; i < `WAYS; i++) begin
        if(entries[head].is_branch & entries[head].mispredicted) begin
            
        end
        else if(entries[head].reg_write & entries[head].done) begin
            
        end
    end
end



// Sequential Logic
always_ff @(posedge clock) begin
    if(reset) begin
        num_free            <= `SD ($clog2(`ROB))'d`ROB;
        head                <= `SD tail;
        entries[head].done  <= `SD 1'b0;
    end else begin
        head                <= `SD next_head;
        tail                <= `SD next_tail;
        num_free            <=  `SD num_free - num_dispatched + num_committed;
    end
end

endmodule