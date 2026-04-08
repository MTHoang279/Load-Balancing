////`timescale 1ns / 1ps

////module CHP #(
////    parameter NUM_SERVERS = 4,
////    parameter VNODES_PER  = 16,
////    parameter HASH_WIDTH  = 32
////)(
////    input  wire                         clk,
////    input  wire                         rst_n,

////    input  wire [NUM_SERVERS*32-1:0]    server_ips_in,

////    /* ------------ Key metadata in ------------ */
////    input  wire                         key_valid,
////    input  wire [31:0]                  src_ip,
////    input  wire [31:0]                  dst_ip,
////    input  wire [15:0]                  src_port,
////    input  wire [15:0]                  dst_port,
////    input  wire [7:0]                   protocol,

////    /* ------------ Hash ring ------------ */
////    input  wire [HASH_WIDTH*NUM_SERVERS*VNODES_PER-1:0] ring_hash,
////    input  wire [$clog2(NUM_SERVERS)*NUM_SERVERS*VNODES_PER-1:0] ring_sid,

////    /* ------------ Output ------------ */
////    output wire                         out_valid,
////    output wire [$clog2(NUM_SERVERS)-1:0] server_id,
////    output wire [31:0]                  out_server_ip
////);

////    /* =========================================================
////     * Parameters
////     * ========================================================= */

////    localparam TOTAL_VNODES = NUM_SERVERS * VNODES_PER;
////    localparam SID_WIDTH    = $clog2(NUM_SERVERS);

////    integer i;

////    /* =========================================================
////     * Jenkins hash (combinational)
////     * ========================================================= */

////    wire [HASH_WIDTH-1:0] hash_key;
////    wire [HASH_WIDTH-1:0] h1;
////    wire [HASH_WIDTH-1:0] h2;
////    wire [HASH_WIDTH-1:0] hash_val;

////    assign hash_key =
////        src_ip ^ dst_ip ^ {src_port, dst_port} ^ {24'b0, protocol};

////    assign h1       = hash_key + (hash_key << 12);
////    assign h2       = h1 ^ (h1 >> 5);
////    assign hash_val = h2 + (h2 << 7);

////    /* =========================================================
////     * Closest vnode search (no sorting required)
////     * ========================================================= */

////    reg [HASH_WIDTH-1:0] best_dist;
////    reg [HASH_WIDTH-1:0] dist;

////    reg [$clog2(TOTAL_VNODES)-1:0] sel_idx;

////    always @(*) begin

////        best_dist = {HASH_WIDTH{1'b1}}; // max value
////        sel_idx   = 0;

////        for(i = 0; i < TOTAL_VNODES; i = i + 1) begin

////            dist = ring_hash[i*HASH_WIDTH +: HASH_WIDTH] - hash_val;

////            if(dist < best_dist) begin
////                best_dist = dist;
////                sel_idx   = i;
////            end

////        end

////    end

////    /* =========================================================
////     * Output
////     * ========================================================= */

////    wire [SID_WIDTH-1:0] sid;

////    assign sid = ring_sid[sel_idx*SID_WIDTH +: SID_WIDTH];

////    assign server_id     = sid;
////    assign out_server_ip = server_ips_in[sid*32 +: 32];
////    assign out_valid     = key_valid;

////endmodule 



`timescale 1ns / 1ps

module CHP #(
    parameter NUM_SERVERS = 4,
    parameter VNODES_PER  = 16,
    parameter HASH_WIDTH  = 32,
    parameter GROUP_SIZE_CFG = 4
)(
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [NUM_SERVERS*32-1:0]    server_ips_in,

    /* ------------ Key metadata in ------------ */
    input  wire                         key_valid,
    input  wire [31:0]                  src_ip,
    input  wire [31:0]                  dst_ip,
    input  wire [15:0]                  src_port,
    input  wire [15:0]                  dst_port,
    input  wire [7:0]                   protocol,

    /* ------------ Hash ring ------------ */
    input  wire [HASH_WIDTH*NUM_SERVERS*VNODES_PER-1:0] ring_hash,
    input  wire [$clog2(NUM_SERVERS)*NUM_SERVERS*VNODES_PER-1:0] ring_sid,

    /* ------------ Output ------------ */
    output wire                         out_valid,
    output wire [$clog2(NUM_SERVERS)-1:0] server_id,
    output wire [31:0]                  out_server_ip
);

    /* =========================================================
     * Parameters
     * ========================================================= */

    localparam TOTAL_VNODES = NUM_SERVERS * VNODES_PER;
    localparam SID_WIDTH    = $clog2(NUM_SERVERS);

    integer i;

    /* =========================================================
     * Pipeline constants
     * ========================================================= */
    localparam GROUP_SIZE = GROUP_SIZE_CFG;
    localparam GROUP_CNT  = (TOTAL_VNODES + GROUP_SIZE - 1) / GROUP_SIZE;
    localparam VNODE_IDX_W = $clog2(TOTAL_VNODES);
    localparam LEFT_CNT  = GROUP_CNT / 2;
    localparam RIGHT_CNT = GROUP_CNT - LEFT_CNT;
    localparam LEFT0_CNT  = LEFT_CNT / 2;
    localparam LEFT1_CNT  = LEFT_CNT - LEFT0_CNT;
    localparam RIGHT0_CNT = RIGHT_CNT / 2;
    localparam RIGHT1_CNT = RIGHT_CNT - RIGHT0_CNT;

    /* =========================================================
     * Stage 0: Jenkins hash and valid register
     * ========================================================= */
    wire [HASH_WIDTH-1:0] hash_key_c;
    wire [HASH_WIDTH-1:0] h1_c;
    wire [HASH_WIDTH-1:0] h2_c;
    wire [HASH_WIDTH-1:0] hash_val_c;

    (* max_fanout = 8 *) reg  [HASH_WIDTH-1:0] hash_val_r;
    (* max_fanout = 8 *) reg                   key_valid_r;

    assign hash_key_c =
        src_ip ^ dst_ip ^ {src_port, dst_port} ^ {24'b0, protocol};
    assign h1_c       = hash_key_c + (hash_key_c << 12);
    assign h2_c       = h1_c ^ (h1_c >> 5);
    assign hash_val_c = h2_c + (h2_c << 7);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hash_val_r  <= {HASH_WIDTH{1'b0}};
            key_valid_r <= 1'b0;
        end else begin
            hash_val_r  <= hash_val_c;
            key_valid_r <= key_valid;
        end
    end

    /* =========================================================
     * Stage 1: Group-wise minimum distance search
     * ========================================================= */
    reg [HASH_WIDTH-1:0] group_best_dist_c [0:GROUP_CNT-1];
    reg [VNODE_IDX_W-1:0] group_best_idx_c [0:GROUP_CNT-1];

    reg [HASH_WIDTH-1:0] vnode_dist_c [0:TOTAL_VNODES-1];
    (* ram_style = "registers" *) reg [HASH_WIDTH-1:0] vnode_dist_r [0:TOTAL_VNODES-1];

    reg [HASH_WIDTH-1:0] group_best_dist_r [0:GROUP_CNT-1];
    reg [VNODE_IDX_W-1:0] group_best_idx_r [0:GROUP_CNT-1];
    reg key_valid_s1a;
    reg key_valid_s1;

    integer g;
    integer k;
    integer flat_idx;
    integer v;

    always @(*) begin
        for (v = 0; v < TOTAL_VNODES; v = v + 1) begin
            vnode_dist_c[v] = ring_hash[v*HASH_WIDTH +: HASH_WIDTH] - hash_val_r;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_valid_s1a <= 1'b0;
            for (v = 0; v < TOTAL_VNODES; v = v + 1) begin
                vnode_dist_r[v] <= {HASH_WIDTH{1'b1}};
            end
        end else begin
            key_valid_s1a <= key_valid_r;
            for (v = 0; v < TOTAL_VNODES; v = v + 1) begin
                vnode_dist_r[v] <= vnode_dist_c[v];
            end
        end
    end

    always @(*) begin
        for (g = 0; g < GROUP_CNT; g = g + 1) begin
            group_best_dist_c[g] = {HASH_WIDTH{1'b1}};
            group_best_idx_c[g]  = {VNODE_IDX_W{1'b0}};
            for (k = 0; k < GROUP_SIZE; k = k + 1) begin
                flat_idx = g * GROUP_SIZE + k;
                if (flat_idx < TOTAL_VNODES) begin
                    if (vnode_dist_r[flat_idx] < group_best_dist_c[g]) begin
                        group_best_dist_c[g] = vnode_dist_r[flat_idx];
                        group_best_idx_c[g]  = flat_idx[VNODE_IDX_W-1:0];
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_valid_s1 <= 1'b0;
            for (i = 0; i < GROUP_CNT; i = i + 1) begin
                group_best_dist_r[i] <= {HASH_WIDTH{1'b1}};
                group_best_idx_r[i]  <= {VNODE_IDX_W{1'b0}};
            end
        end else begin
            key_valid_s1 <= key_valid_s1a;
            for (i = 0; i < GROUP_CNT; i = i + 1) begin
                group_best_dist_r[i] <= group_best_dist_c[i];
                group_best_idx_r[i]  <= group_best_idx_c[i];
            end
        end
    end

    /* =========================================================
     * Stage 2: Quarter reduction and register
     * ========================================================= */
    reg [HASH_WIDTH-1:0] left0_best_dist_c;
    reg [VNODE_IDX_W-1:0] left0_best_idx_c;
    reg [HASH_WIDTH-1:0] left1_best_dist_c;
    reg [VNODE_IDX_W-1:0] left1_best_idx_c;
    reg [HASH_WIDTH-1:0] right0_best_dist_c;
    reg [VNODE_IDX_W-1:0] right0_best_idx_c;
    reg [HASH_WIDTH-1:0] right1_best_dist_c;
    reg [VNODE_IDX_W-1:0] right1_best_idx_c;

    reg [HASH_WIDTH-1:0] left0_best_dist_r;
    reg [VNODE_IDX_W-1:0] left0_best_idx_r;
    reg [HASH_WIDTH-1:0] left1_best_dist_r;
    reg [VNODE_IDX_W-1:0] left1_best_idx_r;
    reg [HASH_WIDTH-1:0] right0_best_dist_r;
    reg [VNODE_IDX_W-1:0] right0_best_idx_r;
    reg [HASH_WIDTH-1:0] right1_best_dist_r;
    reg [VNODE_IDX_W-1:0] right1_best_idx_r;
    reg key_valid_s2;

    /* =========================================================
     * Stage 2.5: Intermediate quarter-best pipeline register
     * ========================================================= */
    reg [HASH_WIDTH-1:0] left0_best_dist_s2p5;
    reg [VNODE_IDX_W-1:0] left0_best_idx_s2p5;
    reg [HASH_WIDTH-1:0] left1_best_dist_s2p5;
    reg [VNODE_IDX_W-1:0] left1_best_idx_s2p5;
    reg [HASH_WIDTH-1:0] right0_best_dist_s2p5;
    reg [VNODE_IDX_W-1:0] right0_best_idx_s2p5;
    reg [HASH_WIDTH-1:0] right1_best_dist_s2p5;
    reg [VNODE_IDX_W-1:0] right1_best_idx_s2p5;
    reg key_valid_s2p5;

    /* =========================================================
     * Stage 3: Two-way partial reduction and register
     * ========================================================= */
    reg [HASH_WIDTH-1:0] left_best_dist_c;
    reg [VNODE_IDX_W-1:0] left_best_idx_c;
    reg [HASH_WIDTH-1:0] right_best_dist_c;
    reg [VNODE_IDX_W-1:0] right_best_idx_c;

    reg [HASH_WIDTH-1:0] left_best_dist_r;
    reg [VNODE_IDX_W-1:0] left_best_idx_r;
    reg [HASH_WIDTH-1:0] right_best_dist_r;
    reg [VNODE_IDX_W-1:0] right_best_idx_r;
    reg key_valid_s3;

    /* =========================================================
     * Stage 3.5: Intermediate pipeline to break critical path
     * ========================================================= */
    reg [HASH_WIDTH-1:0] left_best_dist_s3p5;
    reg [VNODE_IDX_W-1:0] left_best_idx_s3p5;
    reg [HASH_WIDTH-1:0] right_best_dist_s3p5;
    reg [VNODE_IDX_W-1:0] right_best_idx_s3p5;
    reg key_valid_s3p5;

    /* =========================================================
     * Stage 4: Final compare and output register
     * =========================================================*/
    wire pick_right = (right_best_dist_s3p5 < left_best_dist_s3p5);
    wire [VNODE_IDX_W-1:0] final_sel_idx_w = pick_right ? right_best_idx_s3p5 : left_best_idx_s3p5;

    reg [SID_WIDTH-1:0] sid_r;
    reg                 sid_valid_r;

    reg [SID_WIDTH-1:0] sid_out_r;
    reg [31:0] out_server_ip_r;
    reg out_valid_r;

    always @(*) begin
        left0_best_dist_c = {HASH_WIDTH{1'b1}};
        left0_best_idx_c  = {VNODE_IDX_W{1'b0}};
        for (i = 0; i < LEFT0_CNT; i = i + 1) begin
            if (group_best_dist_r[i] < left0_best_dist_c) begin
                left0_best_dist_c = group_best_dist_r[i];
                left0_best_idx_c  = group_best_idx_r[i];
            end
        end

        left1_best_dist_c = {HASH_WIDTH{1'b1}};
        left1_best_idx_c  = {VNODE_IDX_W{1'b0}};
        for (i = 0; i < LEFT1_CNT; i = i + 1) begin
            if (group_best_dist_r[LEFT0_CNT + i] < left1_best_dist_c) begin
                left1_best_dist_c = group_best_dist_r[LEFT0_CNT + i];
                left1_best_idx_c  = group_best_idx_r[LEFT0_CNT + i];
            end
        end

        right0_best_dist_c = {HASH_WIDTH{1'b1}};
        right0_best_idx_c  = {VNODE_IDX_W{1'b0}};
        for (i = 0; i < RIGHT0_CNT; i = i + 1) begin
            if (group_best_dist_r[LEFT_CNT + i] < right0_best_dist_c) begin
                right0_best_dist_c = group_best_dist_r[LEFT_CNT + i];
                right0_best_idx_c  = group_best_idx_r[LEFT_CNT + i];
            end
        end

        right1_best_dist_c = {HASH_WIDTH{1'b1}};
        right1_best_idx_c  = {VNODE_IDX_W{1'b0}};
        for (i = 0; i < RIGHT1_CNT; i = i + 1) begin
            if (group_best_dist_r[LEFT_CNT + RIGHT0_CNT + i] < right1_best_dist_c) begin
                right1_best_dist_c = group_best_dist_r[LEFT_CNT + RIGHT0_CNT + i];
                right1_best_idx_c  = group_best_idx_r[LEFT_CNT + RIGHT0_CNT + i];
            end
        end
    end

    always @(*) begin
        if (left1_best_dist_s2p5 < left0_best_dist_s2p5) begin
            left_best_dist_c = left1_best_dist_s2p5;
            left_best_idx_c  = left1_best_idx_s2p5;
        end else begin
            left_best_dist_c = left0_best_dist_s2p5;
            left_best_idx_c  = left0_best_idx_s2p5;
        end

        if (right1_best_dist_s2p5 < right0_best_dist_s2p5) begin
            right_best_dist_c = right1_best_dist_s2p5;
            right_best_idx_c  = right1_best_idx_s2p5;
        end else begin
            right_best_dist_c = right0_best_dist_s2p5;
            right_best_idx_c  = right0_best_idx_s2p5;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left0_best_dist_r  <= {HASH_WIDTH{1'b1}};
            left0_best_idx_r   <= {VNODE_IDX_W{1'b0}};
            left1_best_dist_r  <= {HASH_WIDTH{1'b1}};
            left1_best_idx_r   <= {VNODE_IDX_W{1'b0}};
            right0_best_dist_r <= {HASH_WIDTH{1'b1}};
            right0_best_idx_r  <= {VNODE_IDX_W{1'b0}};
            right1_best_dist_r <= {HASH_WIDTH{1'b1}};
            right1_best_idx_r  <= {VNODE_IDX_W{1'b0}};

            left0_best_dist_s2p5  <= {HASH_WIDTH{1'b1}};
            left0_best_idx_s2p5   <= {VNODE_IDX_W{1'b0}};
            left1_best_dist_s2p5  <= {HASH_WIDTH{1'b1}};
            left1_best_idx_s2p5   <= {VNODE_IDX_W{1'b0}};
            right0_best_dist_s2p5 <= {HASH_WIDTH{1'b1}};
            right0_best_idx_s2p5  <= {VNODE_IDX_W{1'b0}};
            right1_best_dist_s2p5 <= {HASH_WIDTH{1'b1}};
            right1_best_idx_s2p5  <= {VNODE_IDX_W{1'b0}};
            key_valid_s2p5 <= 1'b0;

            left_best_dist_r  <= {HASH_WIDTH{1'b1}};
            left_best_idx_r   <= {VNODE_IDX_W{1'b0}};
            right_best_dist_r <= {HASH_WIDTH{1'b1}};
            right_best_idx_r  <= {VNODE_IDX_W{1'b0}};
            key_valid_s2      <= 1'b0;
            key_valid_s3      <= 1'b0;
            
            left_best_dist_s3p5  <= {HASH_WIDTH{1'b1}};
            left_best_idx_s3p5   <= {VNODE_IDX_W{1'b0}};
            right_best_dist_s3p5 <= {HASH_WIDTH{1'b1}};
            right_best_idx_s3p5  <= {VNODE_IDX_W{1'b0}};
            key_valid_s3p5 <= 1'b0;
            sid_r           <= {SID_WIDTH{1'b0}};
            sid_valid_r     <= 1'b0;
            sid_out_r       <= {SID_WIDTH{1'b0}};
            out_server_ip_r <= 32'b0;
            out_valid_r     <= 1'b0;
        end else begin
            left0_best_dist_r  <= left0_best_dist_c;
            left0_best_idx_r   <= left0_best_idx_c;
            left1_best_dist_r  <= left1_best_dist_c;
            left1_best_idx_r   <= left1_best_idx_c;
            right0_best_dist_r <= right0_best_dist_c;
            right0_best_idx_r  <= right0_best_idx_c;
            right1_best_dist_r <= right1_best_dist_c;
            right1_best_idx_r  <= right1_best_idx_c;
            key_valid_s2       <= key_valid_s1;

            left0_best_dist_s2p5  <= left0_best_dist_r;
            left0_best_idx_s2p5   <= left0_best_idx_r;
            left1_best_dist_s2p5  <= left1_best_dist_r;
            left1_best_idx_s2p5   <= left1_best_idx_r;
            right0_best_dist_s2p5 <= right0_best_dist_r;
            right0_best_idx_s2p5  <= right0_best_idx_r;
            right1_best_dist_s2p5 <= right1_best_dist_r;
            right1_best_idx_s2p5  <= right1_best_idx_r;
            key_valid_s2p5 <= key_valid_s2;

            left_best_dist_r  <= left_best_dist_c;
            left_best_idx_r   <= left_best_idx_c;
            right_best_dist_r <= right_best_dist_c;
            right_best_idx_r  <= right_best_idx_c;
            key_valid_s3      <= key_valid_s2p5;

            left_best_dist_s3p5  <= left_best_dist_r;
            left_best_idx_s3p5   <= left_best_idx_r;
            right_best_dist_s3p5 <= right_best_dist_r;
            right_best_idx_s3p5  <= right_best_idx_r;
            key_valid_s3p5 <= key_valid_s3;

            sid_r           <= ring_sid[final_sel_idx_w*SID_WIDTH +: SID_WIDTH];
            sid_valid_r     <= key_valid_s3;

            sid_out_r       <= sid_r;
            out_server_ip_r <= server_ips_in[sid_r*32 +: 32];
            out_valid_r     <= sid_valid_r;
        end
    end

    assign server_id     = sid_out_r;
    assign out_server_ip = out_server_ip_r;
    assign out_valid     = out_valid_r;

endmodule


