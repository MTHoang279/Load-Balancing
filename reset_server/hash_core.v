`timescale 1ns / 1ps

module hash_algo #(
    parameter NUM_SERVERS = 4,
    parameter VNODES_PER  = 4,
    parameter HASH_WIDTH  = 32
)(
    input  wire                         clk,
    input  wire                         rst_n,

    /* Server configuration */
    input  wire [NUM_SERVERS*32-1:0]    server_ips_in,
    input  wire [NUM_SERVERS-1:0]       i_status,

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
     * Internal wires between modules
     * ===================================================== */

    wire [HASH_WIDTH*NUM_SERVERS*VNODES_PER-1:0] ring_hash;
    wire [$clog2(NUM_SERVERS)*NUM_SERVERS*VNODES_PER-1:0] ring_sid;
    wire ring_done;

    /* =====================================================
     * Hash Ring Instance
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
     * CHP Instance
     * ===================================================== */

    CHP #(
        .NUM_SERVERS(NUM_SERVERS),
        .VNODES_PER (VNODES_PER),
        .HASH_WIDTH (HASH_WIDTH)
    ) u_chp (
        .clk            (clk),
        .rst_n          (rst_n),

        .server_ips_in  (server_ips_in),
        .i_status       (i_status),

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
        .out_valid      (out_valid),
        .server_id      (server_id),
        .out_server_ip  (out_server_ip)
    );

endmodule