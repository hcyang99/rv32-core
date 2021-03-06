

module LQ(
    input                                       clock,
    input                                       reset,
    input                                       except,

    // SQ
    input [`LSQSZ-1:0] [1:0]                    store_sz,
    input [`LSQSZ-1:0] [15:0]                   store_addr,
    input [`LSQSZ-1:0] [31:0]                   store_data,
    input [`LSQSZ-1:0]                          store_addr_valid,
    input [`LSQSZ-1:0]                          store_data_valid,
    input [`LSQSZ-1:0]                          store_valid,
    input [$clog2(`LSQSZ)-1:0]                  sq_head,

    // issue
    input [`WAYS-1:0] [1:0]                     ld_size,
    input [`WAYS-1:0]                           ld_en,
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        ld_ROB_idx,
    input [`WAYS-1:0] [$clog2(`PRF)-1:0]        ld_PRF_idx,
    input [`WAYS-1:0]                           ld_is_signed,
    input [`WAYS-1:0] [$clog2(`LSQSZ)-1:0]      sq_tail_in,

    // ALU
    input [`WAYS-1:0] [$clog2(`ROB)-1:0]        ALU_ROB_idx,
    input [`WAYS-1:0]                           ALU_is_valid,
    input [`WAYS-1:0]                           ALU_is_ls,
    input [`WAYS-1:0] [15:0]                    ALU_data,

    // feedback from DCache
    input [`LSQSZ-1:0]                          dc_feedback,
    input [31:0]                                dc_data,        // from dcache, on the same cycle
    input [`LSQSZ-1:0]                          mem_feedback,
    input [31:0]                                mem_data,       // from mem, only overwrites "waiting" entries

    output logic [$clog2(`LSQSZ):0]             lq_num_free_out,

    // read from DCache
    output wor [2:0]                            rd_offset,
    output wor [4:0]                            rd_idx,
    output wor [7:0]                            rd_tag,
    output wor [1:0]                            rd_size,
    output wor                                  rd_en,
    output wor [`LSQSZ-1:0]                     rd_gnt,

    // LQ to CDB, highest priority REQUIRED
    output logic [31:0]                         CDB_Data,
  	output wor [$clog2(`PRF)-1:0]               CDB_PRF_idx,
  	output wire                                 CDB_valid,
	output wor [$clog2(`ROB)-1:0]               CDB_ROB_idx,
  	output wire                                 CDB_direction,
  	output wire [31:0]                          CDB_target
);

reg [`LSQSZ-1:0] [1:0] ld_sz_reg;
reg [`LSQSZ-1:0] [$clog2(`ROB)-1:0] ld_ROB_idx_reg;
reg [`LSQSZ-1:0] [$clog2(`PRF)-1:0] ld_PRF_idx_reg;
reg [`LSQSZ-1:0] ld_free;
reg [`LSQSZ-1:0] ld_addr_ready_reg;
reg [`LSQSZ-1:0] [15:0] ld_addr_reg;
reg [`LSQSZ-1:0] ld_is_signed_reg;
reg [`LSQSZ-1:0] [$clog2(`LSQSZ)-1:0] sq_tail_old;
reg [`LSQSZ-1:0] [31:0] ld_data_reg;
reg [$clog2(`LSQSZ):0] lq_num_free;

wire [`LSQSZ-1:0] [1:0] ld_sz_in_bus;
wire [`LSQSZ-1:0] [$clog2(`ROB)-1:0] ld_ROB_idx_in_bus;
wire [`LSQSZ-1:0] [$clog2(`PRF)-1:0] ld_PRF_idx_in_bus;
wire [`LSQSZ-1:0] ld_en_in_bus; // these are coming into LQ
wire [`LSQSZ-1:0] ld_is_signed_in_bus;
wire [`LSQSZ-1:0] [$clog2(`LSQSZ)-1:0] sq_tail_in_bus;
wire [`LSQSZ-1:0] ld_waiting;    // cache miss, waiting for mem
// wire [`LSQSZ-1:0] lq_in_gnt;      // these are coming into LQ

wor [`LSQSZ-1:0] [15:0] ld_addr_wire;
wor [`LSQSZ-1:0] ld_addr_ready_wire;
wire [`LSQSZ-1:0] ld_done;       // data loaded/forwarded, ready for CDB bcast

wire [`WAYS-1:0] [`LSQSZ-1:0] ALU_hit;

logic [$clog2(`WAYS):0] incoming_cnt;

always_comb begin
    incoming_cnt = 0;
    foreach(ld_en[i]) begin
        incoming_cnt += ld_en[i];
    end
end


// select lq entries for incoming loads
lq_ps_in ps_in(
    .req(ld_free),
    .ld_en(ld_en),
    .ld_size(ld_size),
    .ld_ROB_idx(ld_ROB_idx),
    .ld_PRF_idx(ld_PRF_idx),
    .ld_is_signed(ld_is_signed),
    .sq_tail_in(sq_tail_in),

    .gnt(),
    .ld_sz_in_bus(ld_sz_in_bus),
    .ld_ROB_idx_in_bus(ld_ROB_idx_in_bus),
    .ld_PRF_idx_in_bus(ld_PRF_idx_in_bus),
    .ld_en_in_bus(ld_en_in_bus),
    .ld_is_signed_in_bus(ld_is_signed_in_bus),
    .sq_tail_in_bus(sq_tail_in_bus)
);


genvar gi, gj, gk;
generate;
    // listen to ALU for hit
    for (gi = 0; gi < `WAYS; ++gi) begin
        for (gj = 0; gj < `LSQSZ; ++gj) begin
            // hit iff (ld is valid) && (ld addr is not ready) && (ALU is valid) && (ROB idx match)
            assign ALU_hit[gi][gj] = (~ld_free[gj]) & ALU_is_valid[gi] & ALU_is_ls[gi] & 
                (~ld_addr_ready_reg[gj]) & (ALU_ROB_idx[gi] == ld_ROB_idx_reg[gj]);
        end
    end

    // write to hit entries
    assign ld_addr_wire = ld_addr_reg;
    assign ld_addr_ready_wire = ld_addr_ready_reg;
    for (gi = 0; gi < `WAYS; ++gi) begin
        for (gj = 0; gj < `LSQSZ; ++gj) begin
            assign ld_addr_wire[gj] = ALU_hit[gi][gj] ? ALU_data[gi] : 0;
            assign ld_addr_ready_wire[gj] = ALU_hit[gi][gj] ? 1'b1 : 0;
        end
    end

    

endgenerate

// check for conflicts in SQ
wand [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_block_hit; // [lq_idx] [sq_idx]
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_offset_hit;
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_size_hit;
wand [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_all_hit;

// 1 for valid sq entries older than each load; [lq_idx] [sq_idx]
wire [`LSQSZ-1:0] [`LSQSZ-1:0] age_mask; 
wire [`LSQSZ-1:0]              ge_head; // sq_idx only
wire [`LSQSZ-1:0] [`LSQSZ-1:0] lt_tail;
wire [`LSQSZ-1:0] wrap_around;

// wire [`LSQSZ-1:0] [`LSQSZ-1:0] st_addr_valid_msk_all;
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_block_hit_msk_all; // [lq_idx] [sq_idx]
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_block_hit_msk_ge_head;
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_block_hit_msk_lt_tail;
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_all_hit_msk_all;
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_all_hit_msk_ge_head;
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_all_hit_msk_lt_tail;
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_block_hit_final; // goes to wand sel
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_block_hit_selected; // from wand sel

logic [`LSQSZ-1:0] [1:0] ls_state_next;
wire [`LSQSZ-1:0] [`LSQSZ-1:0] ls_addr_forward_wire;
reg [`LSQSZ-1:0] [1:0] ls_state;     
wire [`LSQSZ-1:0] ls_addr_ready_to_load;

assign ls_addr_all_hit = ls_addr_block_hit & ls_addr_offset_hit & ls_addr_size_hit;
generate;
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        for (gj = 0; gj < `LSQSZ; ++gj) begin
            assign ls_addr_block_hit[gi][gj] = (ld_addr_reg[gi][15:3] == store_addr[gj][15:3]) |
                ~ld_addr_ready_reg[gi] | ~store_addr_valid[gj];
            
            assign ls_addr_block_hit[gi][gj] = ~ld_free[gi];
            assign ls_addr_block_hit[gi][gj] = store_valid[gj];
            assign ls_addr_offset_hit[gi][gj] = ld_addr_reg[gi][2:0] == store_addr[gj][2:0];
            assign ls_addr_size_hit[gi][gj] = ld_sz_reg[gi] == store_sz[gj];
            assign ls_addr_all_hit[gi][gj] = ld_addr_ready_reg[gi];
            assign ls_addr_all_hit[gi][gj] = store_data_valid[gj];
            assign ls_addr_all_hit[gi][gj] = store_addr_valid[gj];
        end
    end
endgenerate

// age logic
generate;
    // wrap_around
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        assign wrap_around[gi] = sq_head > sq_tail_old[gi];
    end

    // age_mask; 1 for sq entries older than each load
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        assign ge_head[gi] = gi >= sq_head;
        for (gj = 0; gj < `LSQSZ; ++gj) begin
            assign lt_tail[gi][gj] = gj < sq_tail_old[gi];
            assign age_mask[gi][gj] = wrap_around[gi] ? (lt_tail[gi][gj] | ge_head[gj])
                                    : (lt_tail[gi][gj] & ge_head[gj]);            
        end
    end

endgenerate

// generate;
//     for (gi = 0; gi < `LSQSZ; ++gi) begin
//         for (gj = 0; gj < `LSQSZ; ++gj) begin
//             assign st_addr_valid_msk_all[gi][gj] = store_addr_valid[gj] | (~age_mask[gi][gj]) | (~store_valid[gj]);
//         end
//     end
// endgenerate

generate;
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        assign ls_addr_block_hit_msk_ge_head[gi] = ls_addr_block_hit[gi] & ge_head;
        assign ls_addr_all_hit_msk_ge_head[gi] = ls_addr_all_hit[gi] & ge_head;
    end
endgenerate
assign ls_addr_block_hit_msk_all = ls_addr_block_hit & age_mask;
assign ls_addr_block_hit_msk_lt_tail = ls_addr_block_hit & lt_tail;
assign ls_addr_all_hit_msk_all = ls_addr_all_hit & age_mask;
assign ls_addr_all_hit_msk_lt_tail = ls_addr_all_hit & lt_tail;



// select the youngest store
generate;
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        assign ls_addr_block_hit_final[gi] = wrap_around[gi] ?
                (ls_addr_block_hit_msk_lt_tail[gi] ? 
                    ls_addr_block_hit_msk_lt_tail[gi] : 
                    ls_addr_block_hit_msk_ge_head[gi]) :
                ls_addr_block_hit_msk_all[gi];
    end
endgenerate

lq_wand_sel sel [`LSQSZ-1:0] (
    .req(ls_addr_block_hit_final),
    .gnt(ls_addr_block_hit_selected)
);

wire [`LSQSZ-1:0] [$clog2(`LSQSZ)-1:0] sq_tail_old_next;
wor [`LSQSZ-1:0] [31:0] ld_data_next;
wire [`LSQSZ-1:0] mem_load_in;
wire dc_miss;

// output done entries to CDB, free one entry
wire [`LSQSZ-1:0] cdb_gnt;
arbiter_rr #(.WIDTH(`LSQSZ)) arb_rr_cdb (
    .clock(clock),
    .reset(reset),
    .req(ld_done),
    .gnt(cdb_gnt)
);

// check if can forward, can goto mem, should wait
assign ls_addr_forward_wire = ls_addr_block_hit_selected & ls_addr_all_hit_msk_all;
wire [`LSQSZ-1:0] ls_addr_can_forward;

generate;
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        always_comb begin
            case(ls_state[gi])
                2'h0:   // wait for addr and conflicting store
                    if ((ls_addr_block_hit_selected[gi] == 0) & (~ld_free[gi]) & ld_addr_ready_reg[gi])
                        ls_state_next[gi] = 2'h1;
                    else if (ls_addr_can_forward[gi])
                        ls_state_next[gi] = 2'h3;
                    else
                        ls_state_next[gi] = 2'h0;
                2'h1:   // wait to goto cache
                    if (rd_gnt[gi]) begin
                        if (dc_miss)
                            ls_state_next[gi] = 2'h2;
                        else
                            ls_state_next[gi] = 2'h3;
                    end
                    else begin
                        ls_state_next[gi] = 2'h1;
                    end
                2'h2:   // wait for mem response
                    if (mem_feedback[gi])
                        ls_state_next[gi] = 2'h3;
                    else
                        ls_state_next[gi] = 2'h2;
                default:    // wait for cdb gnt
                    if (cdb_gnt[gi])
                        ls_state_next[gi] = 2'h0;
                    else    
                        ls_state_next[gi] = 2'h3;
            endcase
        end
        assign ld_waiting[gi] = ls_state[gi] == 2'h2;
        assign ls_addr_can_forward[gi] = ls_addr_forward_wire[gi] != 0;
        assign ls_addr_ready_to_load[gi] = ls_state[gi] == 2'h1; 
        assign ld_done[gi] = ls_state[gi] == 2'h3;
    end
endgenerate

// pick one load to cache
wire [`LSQSZ-1:0] cache_gnt;
arbiter_rr #(.WIDTH(`LSQSZ)) arb_rr_cache (
    .clock(clock),
    .reset(reset),
    .req(ls_addr_ready_to_load),
    .gnt(cache_gnt)
);
generate;
    assign rd_en = cache_gnt != 0;
    assign rd_gnt = cache_gnt;
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        assign {rd_tag, rd_idx, rd_offset} = cache_gnt[gi] ? ld_addr_reg[gi][15:0] : 0;
        assign rd_size = cache_gnt[gi] ? ld_sz_reg[gi] : 0;
    end
endgenerate

wor [31:0] CDB_Data_tmp;
wor [1:0] CDB_sz_tmp;
wor CDB_is_ext;
generate;
    assign CDB_valid = cdb_gnt != 0;
    assign CDB_direction = 0;
    assign CDB_target = 0;
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        assign CDB_Data_tmp = cdb_gnt[gi] ? ld_data_reg[gi] : 0;
  	    assign CDB_PRF_idx = cdb_gnt[gi] ? ld_PRF_idx_reg[gi] : 0;
	    assign CDB_ROB_idx = cdb_gnt[gi] ? ld_ROB_idx_reg[gi] : 0;
        assign CDB_sz_tmp = cdb_gnt[gi] ? ld_sz_reg[gi] : 0;
        assign CDB_is_ext = cdb_gnt[gi] ? ld_is_signed_reg[gi] : 0;
    end
endgenerate

logic [31:0] CDB_Data_ext;
always_comb begin
    case(CDB_sz_tmp)
        BYTE:       CDB_Data_ext = {{24{CDB_Data_tmp[7]}}, CDB_Data_tmp[7:0]};
        HALF:       CDB_Data_ext = {{16{CDB_Data_tmp[15]}}, CDB_Data_tmp[15:0]};
        default:    CDB_Data_ext = CDB_Data_tmp;
    endcase 
end
assign CDB_Data = CDB_is_ext ? CDB_Data_ext: CDB_Data_tmp;


// free count
wire [$clog2(`LSQSZ):0]  lq_num_free_next;
assign lq_num_free_next = lq_num_free - incoming_cnt + CDB_valid;
assign lq_num_free_out = lq_num_free_next;

// always_ff
wire [`LSQSZ-1:0] ld_free_hold;
wire [`LSQSZ-1:0] ld_free_next;
assign ld_free_hold = ld_free | cdb_gnt;
assign ld_free_next = ld_free_hold & (~ld_en_in_bus);

wire [`LSQSZ-1:0] [1:0] ld_sz_next;
wire [`LSQSZ-1:0] [15:0] ld_addr_next;
wire [`LSQSZ-1:0] ld_addr_ready_next;

wire [`LSQSZ-1:0] [$clog2(`ROB)-1:0] ld_ROB_idx_next;
wire [`LSQSZ-1:0] [$clog2(`PRF)-1:0] ld_PRF_idx_next;
wire [`LSQSZ-1:0] ld_is_signed_next;



assign dc_miss = dc_feedback == 0;

assign ld_addr_ready_next = ld_addr_ready_wire & (~ld_free_next);
generate;
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        assign ld_sz_next[gi] = ld_free_hold[gi] ? 
            (ld_en_in_bus[gi] ? ld_sz_in_bus[gi] : 0) : ld_sz_reg[gi];
        
        assign ld_ROB_idx_next[gi] = ld_free_hold[gi] ? 
            (ld_en_in_bus[gi] ? ld_ROB_idx_in_bus[gi] : 0) : ld_ROB_idx_reg[gi];

        assign ld_PRF_idx_next[gi] = ld_free_hold[gi] ? 
            (ld_en_in_bus[gi] ? ld_PRF_idx_in_bus[gi] : 0) : ld_PRF_idx_reg[gi];
        
        assign ld_is_signed_next[gi] = ld_free_hold[gi] ? 
            (ld_en_in_bus[gi] ? ld_is_signed_in_bus[gi] : 0) : ld_is_signed_reg[gi];

        assign ld_addr_next[gi] = ld_free_next[gi] ? 0 : ld_addr_wire[gi];

        assign sq_tail_old_next[gi] = ld_free_hold[gi] ? 
            (ld_en_in_bus[gi] ? sq_tail_in_bus[gi] : 0) : sq_tail_old[gi];
        
        assign ld_data_next[gi] = (cdb_gnt[gi] | ls_addr_can_forward[gi] | dc_feedback[gi] | mem_feedback[gi]) 
                                ? 0 : ld_data_reg[gi];    // zero bcasted
        assign ld_data_next[gi] = dc_feedback[gi] ? dc_data : 0;    // read from DCache
        assign ld_data_next[gi] = (mem_feedback[gi] & ld_waiting[gi]) ? mem_data : 0;   // from mem
        // forwarding
        for (gj = 0; gj < `LSQSZ; ++gj) begin
            assign ld_data_next[gi] = ls_addr_forward_wire[gi][gj] ? store_data[gj] : 0;
        end
    end
endgenerate



always_ff @ (posedge clock) begin
    if (reset | except) begin
        ld_sz_reg <= 0;
        ld_ROB_idx_reg <= 0;
        ld_PRF_idx_reg <= 0;
        ld_is_signed_reg <= 0;
        ld_free <= {`LSQSZ{1'b1}};
        ld_addr_ready_reg <= 0;
        ld_addr_reg <= 0;
        sq_tail_old <= 0;
        ld_data_reg <= 0;
        lq_num_free <= `LSQSZ;
        ls_state <= 0;
    end
    else begin
        ld_sz_reg <= ld_sz_next;
        ld_ROB_idx_reg <= ld_ROB_idx_next;
        ld_PRF_idx_reg <= ld_PRF_idx_next;
        ld_is_signed_reg <= ld_is_signed_next;
        ld_free <= ld_free_next;
        ld_addr_ready_reg <= ld_addr_ready_next;
        ld_addr_reg <= ld_addr_next;
        sq_tail_old <= sq_tail_old_next;
        ld_data_reg <= ld_data_next;
        lq_num_free <= lq_num_free_next;
        ls_state <= ls_state_next;
    end
end
    
endmodule


module lq_ps_in( 
    // Inputs
    req,
    ld_en,
    ld_size,
    ld_ROB_idx,
    ld_PRF_idx,
    ld_is_signed,
    sq_tail_in,
                 
    // Outputs
    gnt,
    ld_sz_in_bus,
    ld_ROB_idx_in_bus,
    ld_PRF_idx_in_bus,
    ld_en_in_bus,
    ld_is_signed_in_bus,
    sq_tail_in_bus
);

// synopsys template
parameter REQS  = `WAYS;
parameter WIDTH = `LSQSZ;

// Inputs
input wire [WIDTH-1:0]                          req;
input wire [REQS-1:0]                           ld_en;
input wire [REQS-1:0] [1:0]                     ld_size;
input wire [REQS-1:0] [$clog2(`ROB)-1:0]        ld_ROB_idx;
input wire [REQS-1:0] [$clog2(`PRF)-1:0]        ld_PRF_idx;
input wire [REQS-1:0]                           ld_is_signed;
input wire [`WAYS-1:0] [$clog2(`LSQSZ)-1:0]     sq_tail_in;

// Outputs
output wor  [WIDTH-1:0]                         gnt;
output wor [`LSQSZ-1:0] [1:0]                   ld_sz_in_bus;
output wor [`LSQSZ-1:0] [$clog2(`ROB)-1:0]      ld_ROB_idx_in_bus;
output wor [`LSQSZ-1:0]                         ld_en_in_bus;
output wor [`LSQSZ-1:0] [$clog2(`PRF)-1:0]      ld_PRF_idx_in_bus;
output wor [`LSQSZ-1:0]                         ld_is_signed_in_bus;
output wor [`LSQSZ-1:0] [$clog2(`LSQSZ)-1:0]    sq_tail_in_bus;

wand [WIDTH*REQS-1:0]                           gnt_bus;

// Internal stuff
wire  [WIDTH*REQS-1:0]                          tmp_reqs;
wire  [WIDTH*REQS-1:0]                          tmp_reqs_rev;
wire  [WIDTH*REQS-1:0]                          tmp_gnts;
wire  [WIDTH*REQS-1:0]                          tmp_gnts_rev;

genvar j, k, x;
for (j = 0; j < REQS; j = j + 1) begin
    // Zero'th request/grant trivial, just normal priority selector
    if (j == 0) begin
        assign tmp_reqs[WIDTH-1:0]  = req[WIDTH-1:0];
        assign gnt_bus[WIDTH-1:0]   = tmp_gnts[WIDTH-1:0];

    // First request/grant, uses input request vector but reversed, mask out
    //  granted bit from first request.
    end 
    else if (j == 1) begin
        for (k=0; k<WIDTH; k=k+1) begin
            assign tmp_reqs[2*WIDTH-1-k] = req[k];
        end

        assign gnt_bus[2*WIDTH-1 -: WIDTH] = tmp_gnts_rev[2*WIDTH-1 -: WIDTH] & ~tmp_gnts[WIDTH-1:0];

    // Request/grants 2-N.  Request vector for j'th request will be same as
    //  j-2 with grant from j-2 masked out.  Will alternate between normal and
    //  reversed priority order.  For the odd lines, need to use reversed grant
    //  output so that it's consistent with order of input.
    end 
    else begin    // mask out gnt from req[j-2]
        assign tmp_reqs[(j+1)*WIDTH-1 -: WIDTH] = tmp_reqs[(j-1)*WIDTH-1 -: WIDTH] &
                                                ~tmp_gnts[(j-1)*WIDTH-1 -: WIDTH];
        
        if (j % 2 == 0)
            assign gnt_bus[(j+1)*WIDTH-1 -: WIDTH] = tmp_gnts[(j+1)*WIDTH-1 -: WIDTH];
        else
            assign gnt_bus[(j+1)*WIDTH-1 -: WIDTH] = tmp_gnts_rev[(j+1)*WIDTH-1 -: WIDTH];

    end

    // instantiate priority selectors
    wand_sel #(WIDTH) psel (.req(tmp_reqs[(j+1)*WIDTH-1 -: WIDTH]), .gnt(tmp_gnts[(j+1)*WIDTH-1 -: WIDTH]));

    // reverse gnts (really only for odd request lines)
    for (k=0; k<WIDTH; k=k+1) begin 
        assign tmp_gnts_rev[(j+1)*WIDTH-1-k] = tmp_gnts[(j)*WIDTH+k];
    end

    // Mask out earlier granted bits from later grant lines.
    // gnt[j] = tmp_gnt[j] & ~tmp_gnt[j-1] & ~tmp_gnt[j-3]...
    for (k=j+1; k<REQS; k=k+2) begin
        assign gnt_bus[(k+1)*WIDTH-1 -: WIDTH] = ~gnt_bus[(j+1)*WIDTH-1 -: WIDTH];
    end
end

// assign final gnt outputs
// gnt_bus is the full-width vector for each request line, so OR everything
for(k = 0; k < REQS; ++k) begin
    assign gnt = gnt_bus[(k+1)*WIDTH-1 -: WIDTH];

    for (x = 0; x < WIDTH; ++x) begin
        assign ld_sz_in_bus[x] = gnt_bus[x + k * WIDTH] ? ld_size[k] : 0;
        assign ld_ROB_idx_in_bus[x] = gnt_bus[x + k * WIDTH] ? ld_ROB_idx[k] : 0;
        assign ld_PRF_idx_in_bus[x] = gnt_bus[x + k * WIDTH] ? ld_PRF_idx[k] : 0;
        assign ld_en_in_bus[x] = gnt_bus[x + k * WIDTH] ? ld_en[k] : 0;
        assign ld_is_signed_in_bus[x] = gnt_bus[x + k * WIDTH] ? ld_is_signed[k] : 0;
        assign sq_tail_in_bus[x] = gnt_bus[x + k * WIDTH] ? sq_tail_in[k] : 0;
    end
end

endmodule


module lq_wand_sel (req,gnt);
  //synopsys template
  parameter WIDTH=`LSQSZ;
  input wire  [WIDTH-1:0] req;
  output wand [WIDTH-1:0] gnt;

  wire  [WIDTH-1:0] req_r;
  wand  [WIDTH-1:0] gnt_r;

  //priority selector
  genvar i;
  // reverse inputs and outputs
  for (i = 0; i < WIDTH; i = i + 1)
  begin : reverse
    assign req_r[WIDTH-1-i] = req[i];
    assign gnt[WIDTH-1-i]   = gnt_r[i];
  end

  for (i = 0; i < WIDTH-1 ; i = i + 1)
  begin : foo
    assign gnt_r [WIDTH-1:i] = {{(WIDTH-1-i){~req_r[i]}},req_r[i]};
  end
  assign gnt_r[WIDTH-1] = req_r[WIDTH-1];

endmodule