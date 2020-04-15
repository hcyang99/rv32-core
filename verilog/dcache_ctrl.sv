// write-back no write allocate dcache controller
// serialize only, no forwarding

module dcache_ctrl(
    input                       clock,
    input                       reset,
    input                       except,   // cancel all reads at mispredict? 

    // write dirty entries back
    input                       wb_en_in,
    input [15:0]                wb_addr_in,
    input [63:0]                wb_data_in,
    input [1:0]                 wb_size_in,

    // write directly to mem on wr miss
    input                       wr_en_in,
    input [15:0]                wr_addr_in,
    input [63:0]                wr_data_in,
    input [1:0]                 wr_size_in,

    // read from mem on rd miss
    input                       rd_en_in,
    input [15:0]                rd_addr_in,
    input [`LSQSZ-1:0]          rd_gnt_in,
    input [1:0]                 rd_size_in, // used for lsq feedback only, always ask for DOUBLE from mem

    // from mem
    input [3:0]                 mem2proc_response,// 0 = can't accept, other=tag of transaction
	input [63:0]                mem2proc_data,    // data resulting from a load
	input [3:0]                 mem2proc_tag,     // 0 = no value, other=tag of transaction

    // to mem
    output wor [1:0]            Dmem_command, 
    output logic [15:0]         Dmem_addr,
    output wor [1:0]            Dmem_size,
    output wire [63:0]          Dmem_data,

    // feedback to lsq
    output logic [`LSQSZ-1:0]   mem_feedback,
    output logic [31:0]         mem_data,

    // to dcache
    output logic                mem_wr_en,
    output logic [4:0]          mem_wr_idx,
    output logic [7:0]          mem_wr_tag,
    output logic [63:0]         mem_wr_data
);

parameter WIDTH = 2 * `LSQSZ;

reg [2:0] valid_new_reg;
reg [2:0] [15:0] addr_new_reg;
reg [2:0] is_wr_new_reg;
reg [2:0] is_rd_new_reg;
reg [2:0] [1:0] sz_new_reg;
reg [2:0] [`LSQSZ-1:0] rd_gnt_new_reg;
reg [2:0] [63:0] data_new_reg;

// q1 entries has not gone to mem
reg [WIDTH-1:0] [15:0] addr_q1_reg;
reg [WIDTH-1:0] is_wr_q1_reg;
reg [WIDTH-1:0] is_rd_q1_reg;
reg [WIDTH-1:0] [1:0] sz_q1_reg;
reg [WIDTH-1:0] [`LSQSZ-1:0] rd_gnt_q1_reg;
reg [WIDTH-1:0] [63:0] data_q1_reg;

// q2 entries waiting for mem response one by one, contains both reads and writes
reg [`LSQSZ-1:0] [15:0] addr_q2_reg;
reg [`LSQSZ-1:0] is_wr_q2_reg;
reg [`LSQSZ-1:0] is_rd_q2_reg;
reg [`LSQSZ-1:0] [`LSQSZ-1:0] rd_gnt_q2_reg;
reg [`LSQSZ-1:0] [3:0] mem_tag_q2_reg;
reg [`LSQSZ-1:0] [1:0] sz_q2_reg;

reg [15:0] q1_head_addr_reg;
reg q1_head_is_wr_reg;
reg q1_head_is_rd_reg;
reg [1:0] q1_head_sz_reg;
reg [`LSQSZ-1:0] q1_head_rd_gnt_reg;
reg [63:0] q1_head_data_reg;

reg [15:0] q2_head_addr_reg;
reg q2_head_is_wr_reg;
reg q2_head_is_rd_reg;
reg [`LSQSZ-1:0] q2_head_rd_gnt_reg;
reg [3:0] q2_head_mem_tag_reg;
reg [1:0] q2_head_sz_reg;

reg [WIDTH-1:0] q1_head_reg;
reg [WIDTH-1:0] q1_tail_reg;
reg [`LSQSZ-1:0] q2_head_reg;
reg [`LSQSZ-1:0] q2_tail_reg;


wire q2_head_mem_response;
assign q2_head_mem_response = (q2_head_mem_tag_reg == mem2proc_tag) & q2_head_is_rd_reg;

genvar gi, gj;

// add new entries, clear old entries
// q2
wor [`LSQSZ-1:0] [15:0] addr_q2_next;
wor [`LSQSZ-1:0] is_wr_q2_next;
wor [`LSQSZ-1:0] is_rd_q2_next;
wor [`LSQSZ-1:0] [`LSQSZ-1:0] rd_gnt_q2_next;
wor [`LSQSZ-1:0] [3:0] mem_tag_q2_next;
wor [`LSQSZ-1:0] [1:0] sz_q2_next;

wor [15:0] q2_head_addr_next;
wor q2_head_is_wr_next;
wor q2_head_is_rd_next;
wor [`LSQSZ-1:0] q2_head_rd_gnt_next;
wor [3:0] q2_head_mem_tag_next;
wor [1:0] q2_head_sz_next;

wire [`LSQSZ-1:0] q2_head_tmp;
wire [`LSQSZ-1:0] q2_head_next;
wire q2_incoming; 
wire q2_empty;
wire [`LSQSZ-1:0] q2_tail_next;

assign q2_empty = q2_head_reg == q2_tail_reg;
assign q2_incoming = q1_head_is_rd_reg;
assign q2_head_tmp = q2_head_mem_response ? {q2_head_reg[`LSQSZ-2:0], q2_head_reg[`LSQSZ-1]} : q2_head_reg;
assign q2_head_next = q2_empty ? q2_head_reg : q2_head_tmp;
assign q2_tail_next = q2_incoming ? {q2_tail_reg[`LSQSZ-2:0], q2_tail_reg[`LSQSZ-1]} : q2_tail_reg;
generate;
    // q2 head reg
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        // note: no fwd to q2
        assign q2_head_addr_next = q2_head_next[gi] ? addr_q2_next[gi] : 0;
        assign q2_head_is_wr_next = q2_head_next[gi] ? is_wr_q2_next[gi] : 0;
        assign q2_head_is_rd_next = q2_head_next[gi] ? is_rd_q2_next[gi] : 0;
        assign q2_head_rd_gnt_next = q2_head_next[gi] ? rd_gnt_q2_next[gi] : 0;
        assign q2_head_mem_tag_next = q2_head_next[gi] ? mem_tag_q2_next[gi] : 0;
        assign q2_head_sz_next = q2_head_next[gi] ? sz_q2_next[gi] : 0;
    end
    // clear curr q2 head
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        assign addr_q2_next[gi] = (q2_head_reg[gi] & q2_head_mem_response) ? 0 : addr_q2_reg[gi];
        assign is_wr_q2_next[gi] = (q2_head_reg[gi] & q2_head_mem_response) ? 0 : is_wr_q2_reg[gi];
        assign is_rd_q2_next[gi] = (q2_head_reg[gi] & q2_head_mem_response) ? 0 : (is_rd_q2_reg[gi] & ~except);
        assign rd_gnt_q2_next[gi] = (q2_head_reg[gi] & q2_head_mem_response) ? 0 : rd_gnt_q2_reg[gi];
        assign mem_tag_q2_next[gi] = (q2_head_reg[gi] & q2_head_mem_response) ? 0 : mem_tag_q2_reg[gi];
        assign sz_q2_next[gi] = (q2_head_reg[gi] & q2_head_mem_response) ? 0 : sz_q2_reg[gi];
    end
    // write curr q2 tail
    for (gi = 0; gi < `LSQSZ; ++gi) begin
        assign addr_q2_next[gi] = (q2_incoming & q2_tail_reg[gi]) ? q1_head_addr_reg : 0;
        assign is_wr_q2_next[gi] = (q2_incoming & q2_tail_reg[gi]) ? q1_head_is_wr_reg : 0;
        assign is_rd_q2_next[gi] = (q2_incoming & q2_tail_reg[gi]) ? (q1_head_is_rd_reg & ~except) : 0;
        assign rd_gnt_q2_next[gi] = (q2_incoming & q2_tail_reg[gi]) ? q1_head_rd_gnt_reg : 0;
        assign mem_tag_q2_next[gi] = (q2_incoming & q2_tail_reg[gi]) ? mem2proc_response : 0;
        assign sz_q2_next[gi] = (q2_incoming & q2_tail_reg[gi]) ? q1_head_sz_reg : 0;
    end
endgenerate

always_ff @(posedge clock) begin
    if (reset) begin
        addr_q2_reg <= 0;
        is_wr_q2_reg <= 0;
        is_rd_q2_reg <= 0;
        rd_gnt_q2_reg <= 0;
        mem_tag_q2_reg <= 0;
        sz_q2_reg <= 0;

        q2_head_addr_reg <= 0;
        q2_head_is_wr_reg <= 0;
        q2_head_is_rd_reg <= 0;
        q2_head_rd_gnt_reg <= 0;
        q2_head_mem_tag_reg <= 0;
        q2_head_sz_reg <= 0;

        q2_head_reg <= `LSQSZ'b1;
        q2_tail_reg <= `LSQSZ'b1;
    end
    else begin
        addr_q2_reg <= addr_q2_next;
        is_wr_q2_reg <= is_wr_q2_next;
        is_rd_q2_reg <= is_rd_q2_next;
        rd_gnt_q2_reg <= rd_gnt_q2_next;
        mem_tag_q2_reg <= mem_tag_q2_next;
        sz_q2_reg <= sz_q2_next;

        q2_head_addr_reg <= q2_head_addr_next;
        q2_head_is_wr_reg <= q2_head_is_wr_next;
        q2_head_is_rd_reg <= q2_head_is_rd_next;
        q2_head_rd_gnt_reg <= q2_head_rd_gnt_next;
        q2_head_mem_tag_reg <= q2_head_mem_tag_next;
        q2_head_sz_reg <= q2_head_sz_next;

        q2_head_reg <= q2_head_next;
        q2_tail_reg <= q2_tail_next;
    end
end

// new entries
wor [2:0] [2:0] insert_pos;    // [incoming idx] [new reg idx] 
assign insert_pos[0] = {2'b0, wb_en_in};

assign insert_pos[1] = wb_en_in ? {1'b0, wr_en_in, 1'b0} : {2'b0, wr_en_in};

assign insert_pos[2] = (wb_en_in | wr_en_in) ?
                    ((wb_en_in & wr_en_in) ? {rd_en_in, 2'b0} : {1'b0, rd_en_in, 1'b0}) 
                    : {2'b0, rd_en_in};

wire [2:0] valid_new_in;
wire [2:0] [15:0] addr_new_in;
wire [2:0] is_wr_new_in;
wire [2:0] is_rd_new_in;
wire [2:0] [1:0] sz_new_in;
wire [2:0] [`LSQSZ-1:0] rd_gnt_new_in;
wire [2:0] [63:0] data_new_in;
assign valid_new_in = {rd_en_in, wr_en_in, wb_en_in};
assign addr_new_in = {rd_addr_in, wr_addr_in, wb_addr_in};
assign is_wr_new_in = {1'b0, wr_en_in, wb_en_in};
assign is_rd_new_in = {rd_en_in, 2'b0};
assign sz_new_in = {rd_size_in, wr_size_in, DOUBLE};
assign rd_gnt_new_in = {rd_gnt_in, `LSQSZ'b0, `LSQSZ'b0};
assign data_new_in = {64'b0, wr_data_in, wb_data_in};

wor [2:0] valid_new_next;
wor [2:0] [15:0] addr_new_next;
wor [2:0] is_wr_new_next;
wor [2:0] is_rd_new_next;
wor [2:0] [1:0] sz_new_next;
wor [2:0] [`LSQSZ-1:0] rd_gnt_new_next;
wor [2:0] [63:0] data_new_next;

for (gi = 0; gi < 3; ++gi) begin
    for (gj = 0; gj < 3; ++gj) begin 
        assign valid_new_next[gj] = insert_pos[gi][gj]; // [incoming idx] [new reg idx]
        assign addr_new_next[gj] = insert_pos[gi][gj] ? addr_new_in[gi] : 0;
        assign is_wr_new_next[gj] = insert_pos[gi][gj] ? is_wr_new_in[gi] : 0;
        assign is_rd_new_next[gj] = insert_pos[gi][gj] ? (is_rd_new_in[gi] & ~except) : 0;
        assign sz_new_next[gj] = insert_pos[gi][gj] ? sz_new_in[gi] : 0;
        assign rd_gnt_new_next[gj] = insert_pos[gi][gj] ? rd_gnt_new_in[gi] : 0;
        assign data_new_next[gj] = insert_pos[gi][gj] ? data_new_in[gi] : 0;
    end
end

always_ff @(posedge clock) begin
    if (reset) begin
        valid_new_reg <= 0;
        addr_new_reg <= 0;
        is_wr_new_reg <= 0;
        is_rd_new_reg <= 0;
        sz_new_reg <= 0;
        rd_gnt_new_reg <= 0;
        data_new_reg <= 0;
    end
    else begin
        valid_new_reg <= valid_new_next;
        addr_new_reg <= addr_new_next;
        is_wr_new_reg <= is_wr_new_next;
        is_rd_new_reg <= is_rd_new_next;
        sz_new_reg <= sz_new_next;
        rd_gnt_new_reg <= rd_gnt_new_next;
        data_new_reg <= data_new_next;
    end
end

// q1
wor [WIDTH-1:0] [15:0] addr_q1_next;
wor [WIDTH-1:0] is_wr_q1_next;
wor [WIDTH-1:0] is_rd_q1_next;
wor [WIDTH-1:0] [1:0] sz_q1_next;
wor [WIDTH-1:0] [`LSQSZ-1:0] rd_gnt_q1_next;
wor [WIDTH-1:0] [63:0] data_q1_next;

wor [15:0] q1_head_addr_next;
wor q1_head_is_wr_next;
wor q1_head_is_rd_next;
wor [1:0] q1_head_sz_next;
wor [`LSQSZ-1:0] q1_head_rd_gnt_next;
wor [63:0] q1_head_data_next;

wire [WIDTH-1:0] q1_head_next;
wire [WIDTH-1:0] q1_tail_next;
wire [3:0] [WIDTH-1:0] q1_tail_tmp;
wire q1_empty;
assign q1_empty = q1_head_reg == q1_tail_reg;
assign q1_head_next = q1_empty ? q1_head_reg : {q1_head_reg[WIDTH-2:0], q1_head_reg[WIDTH-1]};

assign q1_tail_tmp[0] = q1_tail_reg;
generate;
    // positions to insert
    for (gi = 1; gi < 4; ++gi) begin
        assign q1_tail_tmp[gi] = valid_new_reg[gi-1] ? {q1_tail_tmp[gi-1][WIDTH-2:0], q1_tail_tmp[gi-1][WIDTH-1]} 
            : q1_tail_tmp[gi-1];
    end
    assign q1_tail_next = q1_tail_tmp[3];
    // q1 head reg
    for (gi = 0; gi < WIDTH; ++gi) begin
        // note: no fwd to q1 head
        assign q1_head_addr_next = q1_head_next[gi] ? addr_q1_next[gi] : 0;
        assign q1_head_is_wr_next = q1_head_next[gi] ? is_wr_q1_next[gi] : 0;
        assign q1_head_is_rd_next = q1_head_next[gi] ? is_rd_q1_next[gi] : 0;
        assign q1_head_rd_gnt_next = q1_head_next[gi] ? rd_gnt_q1_next[gi] : 0;
        assign q1_head_sz_next = q1_head_next[gi] ? sz_q1_next[gi] : 0;
        assign q1_head_data_next = q1_head_next[gi] ? data_q1_next[gi] : 0;
    end
    // clear curr q1 head
    for (gi = 0; gi < WIDTH; ++gi) begin
        assign addr_q1_next[gi] = q1_head_reg[gi] ? 0 : addr_q1_reg[gi];
        assign is_wr_q1_next[gi] = q1_head_reg[gi] ? 0 : is_wr_q1_reg[gi];
        assign is_rd_q1_next[gi] = q1_head_reg[gi] ? 0 : (is_rd_q1_reg[gi] & ~except);
        assign rd_gnt_q1_next[gi] = q1_head_reg[gi] ? 0 : rd_gnt_q1_reg[gi];
        assign sz_q1_next[gi] = q1_head_reg[gi] ? 0 : sz_q1_reg[gi];
        assign data_q1_next[gi] = q1_head_reg[gi] ? 0 : data_q1_reg[gi];
    end
    // add new entries to tail
    for (gi = 0; gi < 3; ++gi) begin
        for (gj = 0; gj < WIDTH; ++gj) begin
            assign addr_q1_next[gj] = q1_tail_tmp[gi][gj] ? addr_new_reg[gi] : 0;
            assign is_wr_q1_next[gj] = q1_tail_tmp[gi][gj] ? is_wr_new_reg[gi] : 0;
            assign is_rd_q1_next[gj] = q1_tail_tmp[gi][gj] ? (is_rd_new_reg[gi] & ~except) : 0;
            assign rd_gnt_q1_next[gj] = q1_tail_tmp[gi][gj] ? rd_gnt_new_reg[gi] : 0;
            assign sz_q1_next[gj] = q1_tail_tmp[gi][gj] ? sz_new_reg[gi] : 0;
            assign data_q1_next[gj] = q1_tail_tmp[gi][gj] ? data_new_reg[gi] : 0;
        end
    end
endgenerate

always_ff @(posedge clock) begin
    if (reset) begin
        addr_q1_reg <= 0;
        is_wr_q1_reg <= 0;
        is_rd_q1_reg <= 0;
        sz_q1_reg <= 0;
        rd_gnt_q1_reg <= 0;
        data_q1_reg <= 0;

        q1_head_addr_reg <= 0;
        q1_head_is_wr_reg <= 0;
        q1_head_is_rd_reg <= 0;
        q1_head_sz_reg <= 0;
        q1_head_rd_gnt_reg <= 0;
        q1_head_data_reg <= 0;

        q1_head_reg <= {{(WIDTH-1){1'b0}}, 1'b1};
        q1_tail_reg <= {{(WIDTH-1){1'b0}}, 1'b1};
    end
    else begin
        addr_q1_reg <= addr_q1_next;
        is_wr_q1_reg <= is_wr_q1_next;
        is_rd_q1_reg <= is_rd_q1_next;
        sz_q1_reg <= sz_q1_next;
        rd_gnt_q1_reg <= rd_gnt_q1_next;
        data_q1_reg <= data_q1_next;

        q1_head_addr_reg <= q1_head_addr_next;
        q1_head_is_wr_reg <= q1_head_is_wr_next;
        q1_head_is_rd_reg <= q1_head_is_rd_next;
        q1_head_sz_reg <= q1_head_sz_next;
        q1_head_rd_gnt_reg <= q1_head_rd_gnt_next;
        q1_head_data_reg <= q1_head_data_next;

        q1_head_reg <= q1_head_next;
        q1_tail_reg <= q1_tail_next;
    end
end

// q1 head to mem
assign Dmem_command = q1_head_is_rd_reg ? BUS_LOAD : BUS_NONE;
assign Dmem_command = q1_head_is_wr_reg ? BUS_STORE : BUS_NONE;
assign Dmem_addr = q1_head_addr_reg;
assign Dmem_size = q1_head_is_rd_reg ? DOUBLE : 0;
assign Dmem_size = q1_head_is_wr_reg ? q1_head_sz_reg : 0;
assign Dmem_data = q1_head_is_wr_reg ? q1_head_data_reg : 0;

// feedback to lsq & dcache, responds only if is_rd
assign mem_wr_en = q2_head_mem_response;
assign mem_wr_idx = q2_head_addr_reg[7:3];
assign mem_wr_tag = q2_head_addr_reg[15:8];
assign mem_wr_data = mem2proc_data;

logic [63:0] mem_data_msk;
wire [63:0] mem_data_tmp;

assign mem_feedback = q2_head_mem_response ? q2_head_rd_gnt_reg : 0;
always_comb begin
    case(q2_head_sz_reg)
        BYTE:      mem_data_msk = {56'b0, {8{1'b1}}};
        HALF:      mem_data_msk = {48'b0, {16{1'b1}}};
        WORD:      mem_data_msk = {32'b0, {32{1'b1}}};
        default:    mem_data_msk = {64{1'b1}};
    endcase
end
assign mem_data_tmp = (mem2proc_data >> {q2_head_addr_reg[2:0], 3'b0}) & mem_data_msk;
assign mem_data = q2_head_mem_response ? mem_data_tmp[31:0] : 0;


endmodule

