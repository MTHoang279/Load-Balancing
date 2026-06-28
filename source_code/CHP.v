`timescale 1ns / 1ps
module CHP #(
    parameter NUM_SERVERS = 16,
    parameter VNODES_PER = 4,
    parameter HASH_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire [NUM_SERVERS*32-1:0] server_ips_in,
    input wire [NUM_SERVERS-1:0] i_status,
    input wire key_valid,
    input wire [31:0] src_ip,
    input wire [31:0] dst_ip,
    input wire [15:0] src_port,
    input wire [15:0] dst_port,
    input wire [7:0] protocol,
    input wire [HASH_WIDTH*NUM_SERVERS*VNODES_PER-1:0] ring_hash,
    input wire [$clog2(NUM_SERVERS)*NUM_SERVERS*VNODES_PER-1:0] ring_sid,
    output wire out_valid,
    output wire [$clog2(NUM_SERVERS)-1:0] server_id,
    output wire [31:0] out_server_ip
);

///////////////////////////////////////////////////////////////
// PARAMETERS
///////////////////////////////////////////////////////////////
localparam TOTAL_VNODES  = NUM_SERVERS * VNODES_PER;
localparam SID_WIDTH     = $clog2(NUM_SERVERS);
localparam HASH_MAX      = {HASH_WIDTH{1'b1}};

// Tính s? stage và kích th??c sau khi pad lên power-of-2
function integer CLOG2;
    input integer value;
    integer i;
    begin
        value = value - 1;
        for(i=0; value>0; i=i+1)
            value = value >> 1;
        CLOG2 = i;
    end
endfunction

localparam TREE_STAGES   = CLOG2(TOTAL_VNODES);
localparam PADDED_VNODES = (TOTAL_VNODES == 0) ? 1 : (1 << TREE_STAGES);

localparam IDX_WIDTH     = CLOG2(PADDED_VNODES);  // Quan tr?ng: dùng PADDED

integer i, j;

///////////////////////////////////////////////////////////////
// STAGE 0 - Pipeline input
///////////////////////////////////////////////////////////////
reg s0_valid;
reg [31:0] s0_src_ip;
reg [31:0] s0_dst_ip;
reg [15:0] s0_src_port;
reg [15:0] s0_dst_port;
reg [7:0]  s0_protocol;
reg [NUM_SERVERS-1:0] s0_status;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s0_valid     <= 1'b0;
    end else begin
        s0_valid     <= key_valid;
        s0_src_ip    <= src_ip;
        s0_dst_ip    <= dst_ip;
        s0_src_port  <= src_port;
        s0_dst_port  <= dst_port;
        s0_protocol  <= protocol;
        s0_status    <= i_status;
    end
end

///////////////////////////////////////////////////////////////
// STAGE 1 - Hash computation
///////////////////////////////////////////////////////////////
wire [31:0] hash_key;
wire [31:0] h1, h2, hash_val;

assign hash_key = s0_src_ip ^ s0_dst_ip ^ {s0_src_port, s0_dst_port} ^ {24'b0, s0_protocol};
assign h1       = hash_key + (hash_key << 12);
assign h2       = h1 ^ (h1 >> 5);
assign hash_val = h2 + (h2 << 7);

reg s1_valid;
reg [31:0] s1_hash;
reg [NUM_SERVERS-1:0] s1_status;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s1_valid  <= 1'b0;
        s1_hash   <= 32'd0;
        s1_status <= {NUM_SERVERS{1'b0}};
    end else begin
        s1_valid  <= s0_valid;
        s1_hash   <= hash_val;
        s1_status <= s0_status;
    end
end

///////////////////////////////////////////////////////////////
// STAGE 2 - Initial Distances + Padded Tree
///////////////////////////////////////////////////////////////
reg [HASH_WIDTH-1:0] tree_dist [0:TREE_STAGES][0:PADDED_VNODES-1];
reg [IDX_WIDTH-1:0]  tree_idx  [0:TREE_STAGES][0:PADDED_VNODES-1];
reg [TREE_STAGES:0]  tree_valid;

reg [HASH_WIDTH-1:0] vnode_hash;
reg [SID_WIDTH-1:0]  vnode_sid;
reg [HASH_WIDTH-1:0] ring_distance;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tree_valid[0] <= 1'b0;
        for (i = 0; i < PADDED_VNODES; i = i + 1) begin
            tree_dist[0][i] <= HASH_MAX;
            tree_idx[0][i]  <= {IDX_WIDTH{1'b0}};
        end
    end
    else begin
        tree_valid[0] <= s1_valid;

        // Gán d? li?u th?c cho TOTAL_VNODES vnode
        for (i = 0; i < TOTAL_VNODES; i = i + 1) begin
            vnode_hash = ring_hash[i*HASH_WIDTH +: HASH_WIDTH];
            vnode_sid  = ring_sid[i*SID_WIDTH +: SID_WIDTH];

            // Consistent Hash Ring Wrap-around
            if (vnode_hash >= s1_hash)
                ring_distance = vnode_hash - s1_hash;
            else
                ring_distance = (HASH_MAX - s1_hash) + vnode_hash + 1'b1;

            if (s1_status[vnode_sid])
                tree_dist[0][i] <= ring_distance;
            else
                tree_dist[0][i] <= HASH_MAX;

            tree_idx[0][i] <= i[IDX_WIDTH-1:0];
        end

        // Pad ph?n th?a b?ng HASH_MAX
        for (i = TOTAL_VNODES; i < PADDED_VNODES; i = i + 1) begin
            tree_dist[0][i] <= HASH_MAX;
            tree_idx[0][i]  <= {IDX_WIDTH{1'b0}};
        end
    end
end

///////////////////////////////////////////////////////////////
// GENERIC REDUCTION TREE (Padded)
///////////////////////////////////////////////////////////////
genvar gs;
generate
for (gs = 0; gs < TREE_STAGES; gs = gs + 1) begin : GEN_TREE_STAGE
    localparam CUR_SIZE  = PADDED_VNODES >> gs;
    localparam NEXT_SIZE = (CUR_SIZE + 1) >> 1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tree_valid[gs+1] <= 1'b0;
            for (j = 0; j < NEXT_SIZE; j = j + 1) begin
                tree_dist[gs+1][j] <= HASH_MAX;
                tree_idx[gs+1][j]  <= {IDX_WIDTH{1'b0}};
            end
        end
        else begin
            tree_valid[gs+1] <= tree_valid[gs];

            for (j = 0; j < NEXT_SIZE; j = j + 1) begin
                if ((2*j + 1) < CUR_SIZE) begin
                    // So sánh 2 ph?n t?
                    if (tree_dist[gs][2*j] <= tree_dist[gs][2*j+1]) begin
                        tree_dist[gs+1][j] <= tree_dist[gs][2*j];
                        tree_idx[gs+1][j]  <= tree_idx[gs][2*j];
                    end else begin
                        tree_dist[gs+1][j] <= tree_dist[gs][2*j+1];
                        tree_idx[gs+1][j]  <= tree_idx[gs][2*j+1];
                    end
                end else begin
                    // Ch? còn 1 ph?n t?
                    tree_dist[gs+1][j] <= tree_dist[gs][2*j];
                    tree_idx[gs+1][j]  <= tree_idx[gs][2*j];
                end
            end
        end
    end
end
endgenerate

///////////////////////////////////////////////////////////////
// FINAL OUTPUT
///////////////////////////////////////////////////////////////
wire [IDX_WIDTH-1:0] final_idx;
assign final_idx = tree_idx[TREE_STAGES][0];

wire [SID_WIDTH-1:0] final_sid;
assign final_sid = ring_sid[final_idx * SID_WIDTH +: SID_WIDTH];

assign server_id     = final_sid;
assign out_server_ip = server_ips_in[final_sid * 32 +: 32];
assign out_valid     = tree_valid[TREE_STAGES];

endmodule