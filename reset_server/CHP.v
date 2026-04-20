`timescale 1ns / 1ps

module CHP #(
    parameter NUM_SERVERS = 4,
    parameter VNODES_PER  = 8,
    parameter HASH_WIDTH  = 32
)(
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [NUM_SERVERS*32-1:0]    server_ips_in,
    input  wire [NUM_SERVERS-1:0]       i_status,

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
     * Jenkins hash (combinational)
     * ========================================================= */

//    wire [HASH_WIDTH-1:0] hash_key;
//    wire [HASH_WIDTH-1:0] h1;
//    wire [HASH_WIDTH-1:0] h2;
//    wire [HASH_WIDTH-1:0] hash_val;

//    assign hash_key =
//        src_ip ^ dst_ip ^ {src_port, dst_port} ^ {24'b0, protocol};

//    assign h1       = hash_key + (hash_key << 12);
//    assign h2       = h1 ^ (h1 >> 5);
//    assign hash_val = h2 + (h2 << 7);

    function [31:0] mix32;
        input [31:0] a;
        reg [31:0] x;
        begin
            x = a;
            x = (x + 32'h7ed55d16) + (x << 12);
            x = (x ^ 32'hc761c23c) ^ (x >> 19);
            x = (x + 32'h165667b1) + (x << 5);
            x = (x + 32'hd3a2646c) ^ (x << 9);
            x = (x + 32'hfd7046c5) + (x << 3);
            x = (x ^ 32'hb55a4f09) ^ (x >> 16);
            mix32 = x;
        end
    endfunction
    
    wire [31:0] key0 = src_ip ^ {dst_ip[15:0], src_port};
    wire [31:0] key1 = {dst_port, protocol, src_ip[7:0]};
    wire [31:0] hash_val = mix32(key0 ^ mix32(key1));

    /* =========================================================
     * Closest vnode search (no sorting required)
     * ========================================================= */
    reg [HASH_WIDTH-1:0] best_dist;
    reg [HASH_WIDTH-1:0] dist;

    reg [$clog2(TOTAL_VNODES)-1:0] sel_idx;

    always @(*) begin
        best_dist = {HASH_WIDTH{1'b1}}; // max
        sel_idx   = 0;
    
        for(i = 0; i < TOTAL_VNODES; i = i + 1) begin
            dist = ring_hash[i*HASH_WIDTH +: HASH_WIDTH] - hash_val;
            // l?y server id c?a vnode này
            if (dist < best_dist) begin
                if (i_status[ ring_sid[i*SID_WIDTH +: SID_WIDTH] ]) begin
                    best_dist = dist;
                    sel_idx   = i;
                end
            end
        end    
    end

    /* =========================================================
     * Output
     * ========================================================= */

    wire [SID_WIDTH-1:0] sid;

    assign sid = ring_sid[sel_idx*SID_WIDTH +: SID_WIDTH];

    assign server_id     = sid;
    assign out_server_ip = server_ips_in[sid*32 +: 32];
    assign out_valid     = key_valid;

endmodule