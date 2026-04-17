`timescale 1ns / 1ps

module heartbeat_gen #(
    parameter LB_IP        = 32'hC0A80001,   // 192.168.0.1
    parameter BROADCAST_IP = 32'hFFFFFFFF,   // 255.255.255.255
    parameter HB_SRC_PORT  = 16'd9000,
    parameter HB_DST_PORT  = 16'd9001
)(
    input  wire         clk,
    input  wire         rst_n,

    // trigger m?i 1s
    input  wire         tick_1s,

    // AXI Stream
    output wire [511:0] hb_tdata,
    output wire [63:0]  hb_tkeep,
    output wire         hb_tvalid,
    output wire         hb_tlast,
    input  wire         hb_tready
);
    reg [31:0] hb_packet_sent_count;
    // ==========================================================
    // Constants
    // ==========================================================

    localparam [7:0]  PKT_TYPE_HB_REQ = 8'h01;
    localparam [7:0]  IP_PROTO_UDP    = 8'h11;
    localparam [7:0]  IP_TTL          = 8'd64;

    localparam [15:0] IP_TOTAL_LEN = 16'd33;
    localparam [15:0] UDP_LEN      = 16'd13;

    localparam [63:0] TKEEP_FULL = 64'hFFFF_FFFF_FFFF_FFFF;

    // ==========================================================
    // Packet template
    // ==========================================================

    wire [511:0] pkt;

    assign pkt = {

        // ===============================
        // Padding (unused bytes)
        // ===============================
        224'd0,

        // ===============================
        // Payload
        // ===============================
        32'hFFFFFFFF,          // Server ID
        PKT_TYPE_HB_REQ,       // App Type

        // ===============================
        // UDP Header
        // ===============================
        16'h0000,              // UDP checksum
        UDP_LEN,
        HB_DST_PORT,
        HB_SRC_PORT,

        // ===============================
        // IPv4 Header
        // ===============================
        BROADCAST_IP,
        LB_IP,
        16'h0000,              // checksum (optional)
        IP_PROTO_UDP,
        IP_TTL,
        16'h4000,
        16'd0,
        IP_TOTAL_LEN,
        8'h00,
        8'h45
    };

    // ==========================================================
    // Pending logic (AXI-safe trigger)
    // ==========================================================

    reg pending;

    always @(posedge clk) begin
        if (!rst_n) begin
            pending <= 1'b1;
            hb_packet_sent_count <= 0;
        end
        else begin
            if (tick_1s) begin
                pending <= 1'b1;
            end
            else if (hb_tvalid && hb_tready) begin
                pending <= 1'b0;
                if (hb_tlast) begin 
                    hb_packet_sent_count <= hb_packet_sent_count + 1;
                end
            end              
        end
    end

    // ==========================================================
    // AXI Stream
    // ==========================================================

    assign hb_tvalid = pending;
    assign hb_tlast  = pending;
    assign hb_tkeep  = TKEEP_FULL;
    assign hb_tdata  = pkt;

endmodule