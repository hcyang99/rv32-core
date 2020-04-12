`define BYTE 2'b0
`define HALF 2'h1
`define WORD 2'h2
`define DOUBLE 2'h3
`define MEM_SIZE [1:0]

// typedef struct packed {
//     logic `MEM_SIZE                                 size;
//     logic [63:0]                                    data;
//     logic                                           data_valid;
//     logic [$clog2(`ROB)-1:0]                        ROB_idx;
//     logic [15:0]                                    addr;
//     logic                                           addr_valid;
//     logic                                           valid;
// } sq_entry;

module store_queue(
    input                                           clock,
    input                                           reset,
    input                                           except,
    input                                           commit,

    // From dispatch
    input [`WAYS-1:0] `MEM_SIZE                     size,
    input [`WAYS-1:0] [63:0]                        data,
    input [`WAYS-1:0]                               data_valid,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]            ROB_idx,
    input [`WAYS-1:0]                               enable,

    // From CDB
    input [`WAYS-1:0] [63:0]                        CDB_Data,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]            CDB_PRF_idx,
    input [`WAYS-1:0]                               CDB_valid,

    // From ALU
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]            ALU_ROB_idx,
    input [`WAYS-1:0]                               ALU_is_valid,
    input [`WAYS-1:0] [15:0]                        ALU_data,

    // To debug
    output logic [$clog2(`LSQSZ)-1:0]               sq_head,
    output logic [$clog2(`LSQSZ)-1:0]               sq_tail,

    // To D$
    output logic                                    write_en,
    output logic [15:0]                             write_addr,
    output logic [63:0]                             write_data,
    output logic `MEM_SIZE                          write_size,
    
    // To LB
    output sq_entry [`LSQSZ-1:0]                    sq_out,

    // To flow control logic (stall)
    output logic [$clog2(`LSQSZ):0]                 num_free
);

    sq_entry [`LSQSZ-1:0]                           entries;
    logic [$clog2(`WAYS):0]                         num_dispatched;
    sq_entry [`WAYS-1:0]                            new_entries;
    logic [`WAYS-1:0] [$clog2(`LSQSZ)-1:0]          ALU_write_idx;
    logic [`WAYS-1:0]                               ALU_write_valid;
    logic [`LSQSZ-1:0] [`WAYS-1:0]                  CDB_write_idx;
    logic [`LSQSZ-1:0]                              CDB_write_valid;

    // Combinational/output logic
    always_comb begin
        // SQ state for LB
        sq_out = entries;

        // Output to D$ (Commit)
        write_en = commit;
        write_addr = entries[sq_head].addr;
        write_data = entries[sq_head].data;
        write_size = entries[sq_head].size;

        // Input from decode (Dispatch)
        num_dispatched = 0;
        for(int i = 0; i < `WAYS; i++) begin
            new_entries[i].size = 0;
            new_entries[i].data = 0;
            new_entries[i].data_valid = 0;
            new_entries[i].ROB_idx = 0;
            new_entries[i].addr = 0;
            new_entries[i].addr_valid = 0;
            new_entries[i].valid = 0;
            if(enable[i]) begin
                new_entries[num_dispatched].size = size[i];
                new_entries[num_dispatched].data = data[i];
                new_entries[num_dispatched].data_valid = data_valid[i];
                new_entries[num_dispatched].ROB_idx = ROB_idx[i];
                new_entries[num_dispatched].valid = 1;
                num_dispatched = num_dispatched + 1;
            end
        end

        // Input from CDB and ALU (Update)
        // ALU
        for(int i = 0; i < `WAYS; i++) begin
            ALU_write_idx[i] = sq_head;
            ALU_write_valid[i] = 0;
            if(ALU_is_valid[i]) begin
                for(int j = 0; j < `LSQSZ - num_free; j++) begin
                    if(ALU_ROB_idx[i] == entries[(sq_head + j) % `LSQSZ].ROB_idx) begin
                        ALU_write_idx[i] = (sq_head + j) % `LSQSZ;
                        ALU_write_valid[i] = 1;
                        break;
                    end // if ALU_ROB[i] matches entries[j].ROB
                end // for all SQ entries
            end // if ALU_is_valid
        end // for all ALU inputs

        // CDB
        for(int i = 0; i < `LSQSZ - num_free; i++) begin
            CDB_write_idx[i] = 0;
            CDB_write_valid[i] = 0;
            if(!entries[(sq_head + i) % `LSQSZ].data_valid) begin
                for(int j = 0; j < `WAYS; j++) begin
                    if(CDB_valid[j] && (entries[(sq_head + i) % `LSQSZ].data == CDB_PRF_idx[j])) begin
                        CDB_write_idx[i] = j;
                        CDB_write_valid[i] = 1;
                        break;
                    end // CDB_PRF[j] matches entries[i]
                end // for all CDBs
            end // if !entries[i].data
        end // for all SQ entries
    end

    // Sequential logic
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset || except) begin
            for(int i = 0; i < `LSQSZ; i++) begin
                entries[i].valid <= 0;
            end
            sq_head <= 0;
            sq_tail <= 0;
            num_free <= `LSQSZ;
        end else begin

            // Commit (head)
            if(commit) begin
                entries[sq_head].valid <= 0;
                sq_head <= (sq_head + 1) % `LSQSZ;
            end

            // Dispatch (tail)
            for(int i = 0; i < num_dispatched; i++) begin
                entries[(sq_tail + i) % `LSQSZ] <= new_entries[i];
            end
            sq_tail <= (sq_tail + num_dispatched) % `LSQSZ;
            
            // Other (num_free and updating entries)
            num_free <= num_free - num_dispatched + commit;
            for(int i = 0; i < `WAYS; i++) begin
                if(ALU_write_valid[i]) begin
                    entries[ALU_write_idx[i]].addr <= ALU_data[i];
                    entries[ALU_write_idx[i]].addr_valid <= 1;
                end
            end
            for(int i = 0; i < `LSQSZ - num_free; i++) begin
                if(CDB_write_valid[i]) begin
                    entries[(sq_head + i) % `LSQSZ].data <= CDB_Data[CDB_write_idx[i]];
                    entries[(sq_head + i) % `LSQSZ].data_valid <= 1;
                end
            end
        end
    end

endmodule
