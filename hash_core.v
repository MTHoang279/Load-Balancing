`timescale 1ns / 1ps
(* keep_hierarchy = "yes" *)
module hash_algo #(
    parameter NUM_SERVERS = 16,
    parameter VNODES_PER  = 4,
    parameter HASH_WIDTH  = 32,
    parameter CHP_GROUP_SIZE = 4
)(
    input  wire                         clk,
    input  wire                         rst_n,

    /* Server configuration */
    input  wire [NUM_SERVERS*32-1:0]    server_ips_in,

    /* Flow key input */
    input  wire                         key_valid,
    input  wire [31:0]                  src_ip,
    input  wire [31:0]                  dst_ip,
    input  wire [15:0]                  src_port,
    input  wire [15:0]                  dst_port,
    input  wire [7:0]                   protocol,

    /* Output */
    output wire                         out_valid,
    output wire [$clog2(NUM_SERVERS)-1:0] server_id,
    output wire [31:0]                  out_server_ip
);

    /* =====================================================
     * Internal wires
     * ===================================================== */

    wire [HASH_WIDTH*NUM_SERVERS*VNODES_PER-1:0] ring_hash;
    wire [$clog2(NUM_SERVERS)*NUM_SERVERS*VNODES_PER-1:0] ring_sid;
    wire ring_done;

    wire chp_out_valid;
    wire [$clog2(NUM_SERVERS)-1:0] chp_server_id;
    wire [31:0] chp_server_ip;

    /* =====================================================
     * Debug counter (QUAN TR?NG)
     * ===================================================== */

//    (* mark_debug = "true", keep = "true", dont_touch = "true" *)
//    reg [31:0] hash_pkt_count [0:NUM_SERVERS-1];

//    integer i;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            for (i = 0; i < NUM_SERVERS; i = i + 1)
//                hash_pkt_count[i] <= 32'd0;
//        end else begin
//            if (chp_out_valid) begin
//                hash_pkt_count[chp_server_id] <=
//                    hash_pkt_count[chp_server_id] + 1;
//            end
//        end
//    end 

    (* mark_debug = "true", keep = "true", dont_touch = "true" *)
    reg [31:0] hash_pkt_count [0:NUM_SERVERS-1];
    
    (* mark_debug = "true", keep = "true", dont_touch = "true" *)
    wire [NUM_SERVERS*32-1:0] hash_pkt_count_flat;
    
    integer i;
    genvar g;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_SERVERS; i = i + 1)
                hash_pkt_count[i] <= 32'd0;
        end else begin
            if (chp_out_valid) begin
                hash_pkt_count[chp_server_id] <=
                    hash_pkt_count[chp_server_id] + 1;
            end
        end
    end
    
    generate
        for (g = 0; g < NUM_SERVERS; g = g + 1) begin : GEN_HASH_PKT_COUNT_FLAT
            assign hash_pkt_count_flat[g*32 +: 32] = hash_pkt_count[g];
        end
    endgenerate

    /* =====================================================
     * Hash Ring
     * ===================================================== */

    hash_ring #(
        .NUM_SERVERS(NUM_SERVERS),
        .VNODES_PER (VNODES_PER),
        .HASH_WIDTH (HASH_WIDTH)
    ) u_hash_ring (
        .clk       (clk),
        .rst_n     (rst_n),
        .done      (ring_done),

        .ring_hash (ring_hash),
        .ring_sid  (ring_sid)
    );

    /* =====================================================
     * CHP
     * ===================================================== */

    CHP #(
        .NUM_SERVERS(NUM_SERVERS),
        .VNODES_PER (VNODES_PER),
        .HASH_WIDTH (HASH_WIDTH),
        .GROUP_SIZE_CFG(4)
    ) u_chp (
        .clk            (clk),
        .rst_n          (rst_n),

        .server_ips_in  (server_ips_in),

        /* Flow key */
        .key_valid      (key_valid),
        .src_ip         (src_ip),
        .dst_ip         (dst_ip),
        .src_port       (src_port),
        .dst_port       (dst_port),
        .protocol       (protocol),

        /* Ring table */
        .ring_hash      (ring_hash),
        .ring_sid       (ring_sid),

        /* Output */
        .out_valid      (chp_out_valid),
        .server_id      (chp_server_id),
        .out_server_ip  (chp_server_ip)
    );

    /* =====================================================
     * Output pass-through
     * ===================================================== */

    assign out_valid     = chp_out_valid;
    assign server_id     = chp_server_id;
    assign out_server_ip = chp_server_ip;

endmodule