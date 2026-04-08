`timescale 1ns / 1ps

module server_backend_model #(
    parameter RESP_LATENCY = 20,
    parameter Q_DEPTH      = 1024
)(
    input  wire        clk,
    input  wire        rst_n,

    // TX stream from SHM to backend model
    input  wire [511:0] tx_data,
    input  wire [63:0]  tx_keep,
    input  wire         tx_last,
    input  wire         tx_valid,
    output wire         tx_ready,

    // RX stream from backend model back to SHM
    output reg  [511:0] rx_data,
    output reg  [63:0]  rx_keep,
    output reg          rx_last,
    output reg          rx_valid,
    input  wire         rx_ready,

    // Statistics
    output reg [31:0] stat_tx_total,
    output reg [31:0] stat_tx_user,
    output reg [31:0] stat_tx_hb,
    output reg [31:0] stat_tx_s0,
    output reg [31:0] stat_tx_s1,
    output reg [31:0] stat_tx_s2,
    output reg [31:0] stat_tx_s3,
    output reg [31:0] stat_rx_total,
    output reg [31:0] stat_drop
);

    localparam [31:0] S0_IP = 32'h0A000064;
    localparam [31:0] S1_IP = 32'h0A000065;
    localparam [31:0] S2_IP = 32'h0A000066;
    localparam [31:0] S3_IP = 32'h0A000067;

    reg [63:0] cycle_cnt;

    reg in_pkt;
    reg [31:0] pkt_dst_ip;
    reg [15:0] pkt_sport;
    reg [15:0] pkt_dport;

    reg [31:0] cur_dst_ip;
    reg [15:0] cur_sport;
    reg [15:0] cur_dport;

    reg [31:0]  q_src_ip   [0:Q_DEPTH-1];
    reg [15:0]  q_src_port [0:Q_DEPTH-1];
    reg [15:0]  q_dst_port [0:Q_DEPTH-1];
    reg [63:0]  q_due  [0:Q_DEPTH-1];
    reg         q_is_user [0:Q_DEPTH-1];
    reg [1:0]   q_sid     [0:Q_DEPTH-1];

    reg         rx_meta_is_user;
    reg [1:0]   rx_meta_sid;

    integer inflight_s0;
    integer inflight_s1;
    integer inflight_s2;
    integer inflight_s3;

    integer q_wr;
    integer q_rd;
    integer q_cnt;

    integer hb_sid;
    reg [7:0] hb_pending;
    reg [1:0] hb_next_sid;

    assign tx_ready = 1'b1;

    task enqueue_rsp;
        input [31:0] src_ip;
        input [15:0] src_port;
        input [15:0] dst_port;
        input [63:0] due;
        input is_user;
        input [1:0] sid;
        begin
            if (q_cnt < Q_DEPTH) begin
                q_src_ip[q_wr]   = src_ip;
                q_src_port[q_wr] = src_port;
                q_dst_port[q_wr] = dst_port;
                q_due[q_wr]  = due;
                q_is_user[q_wr] = is_user;
                q_sid[q_wr]     = sid;
                q_wr = (q_wr + 1) % Q_DEPTH;
                q_cnt = q_cnt + 1;
            end else begin
                stat_drop <= stat_drop + 1;
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 64'd0;

            in_pkt    <= 1'b0;
            pkt_dst_ip<= 32'd0;
            pkt_sport <= 16'd0;
            pkt_dport <= 16'd0;

            q_wr      <= 0;
            q_rd      <= 0;
            q_cnt     <= 0;

            hb_pending <= 8'd0;
            hb_next_sid <= 2'd0;

            inflight_s0 <= 0;
            inflight_s1 <= 0;
            inflight_s2 <= 0;
            inflight_s3 <= 0;

            rx_data   <= 512'd0;
            rx_keep   <= 64'd0;
            rx_last   <= 1'b0;
            rx_valid  <= 1'b0;
            rx_meta_is_user <= 1'b0;
            rx_meta_sid     <= 2'd0;

            stat_tx_total <= 32'd0;
            stat_tx_user  <= 32'd0;
            stat_tx_hb    <= 32'd0;
            stat_tx_s0    <= 32'd0;
            stat_tx_s1    <= 32'd0;
            stat_tx_s2    <= 32'd0;
            stat_tx_s3    <= 32'd0;
            stat_rx_total <= 32'd0;
            stat_drop     <= 32'd0;
        end else begin
            cycle_cnt <= cycle_cnt + 1'b1;

            // Capture TX packet and schedule synthetic responses.
            if (tx_valid && tx_ready) begin
                if (!in_pkt) begin
                    pkt_dst_ip <= tx_data[271:240];
                    pkt_sport  <= tx_data[239:224];
                    pkt_dport  <= tx_data[223:208];
                    cur_dst_ip = tx_data[271:240];
                    cur_sport  = tx_data[239:224];
                    cur_dport  = tx_data[223:208];
                end else begin
                    cur_dst_ip = pkt_dst_ip;
                    cur_sport  = pkt_sport;
                    cur_dport  = pkt_dport;
                end

                if (tx_last) begin
                    stat_tx_total <= stat_tx_total + 1;

                    // Heartbeat request: sport=9999, dport=8888.
                    if ((cur_sport == 16'd9999) && (cur_dport == 16'd8888)) begin
                        stat_tx_hb <= stat_tx_hb + 1;
                        // Return heartbeat response from all servers with priority.
                        if (hb_pending <= 8'd251)
                            hb_pending <= hb_pending + 8'd4;
                        else
                            hb_pending <= 8'hFF;
                    end else begin
                        stat_tx_user <= stat_tx_user + 1;

                        if (cur_dst_ip == S0_IP) begin
                            stat_tx_s0 <= stat_tx_s0 + 1;
                            inflight_s0 <= inflight_s0 + 1;
                        end else if (cur_dst_ip == S1_IP) begin
                            stat_tx_s1 <= stat_tx_s1 + 1;
                            inflight_s1 <= inflight_s1 + 1;
                        end else if (cur_dst_ip == S2_IP) begin
                            stat_tx_s2 <= stat_tx_s2 + 1;
                            inflight_s2 <= inflight_s2 + 1;
                        end else if (cur_dst_ip == S3_IP) begin
                            stat_tx_s3 <= stat_tx_s3 + 1;
                            inflight_s3 <= inflight_s3 + 1;
                        end

                        if (cur_dst_ip == S0_IP)
                            enqueue_rsp(cur_dst_ip, 16'd80, 16'd443,
                                        cycle_cnt + RESP_LATENCY + inflight_s0, 1'b1, 2'd0);
                        else if (cur_dst_ip == S1_IP)
                            enqueue_rsp(cur_dst_ip, 16'd80, 16'd443,
                                        cycle_cnt + RESP_LATENCY + inflight_s1, 1'b1, 2'd1);
                        else if (cur_dst_ip == S2_IP)
                            enqueue_rsp(cur_dst_ip, 16'd80, 16'd443,
                                        cycle_cnt + RESP_LATENCY + inflight_s2, 1'b1, 2'd2);
                        else
                            enqueue_rsp(cur_dst_ip, 16'd80, 16'd443,
                                        cycle_cnt + RESP_LATENCY + inflight_s3, 1'b1, 2'd3);
                    end
                end

                in_pkt <= !tx_last;
            end

            // Drive RX stream when due.
            if (rx_valid) begin
                if (rx_ready) begin
                    rx_valid <= 1'b0;
                    rx_last  <= 1'b0;
                    stat_rx_total <= stat_rx_total + 1;
                    if (rx_meta_is_user) begin
                        case (rx_meta_sid)
                            2'd0: if (inflight_s0 > 0) inflight_s0 <= inflight_s0 - 1;
                            2'd1: if (inflight_s1 > 0) inflight_s1 <= inflight_s1 - 1;
                            2'd2: if (inflight_s2 > 0) inflight_s2 <= inflight_s2 - 1;
                            2'd3: if (inflight_s3 > 0) inflight_s3 <= inflight_s3 - 1;
                            default: ;
                        endcase
                    end
                end
            end else if (hb_pending > 0) begin
                rx_data  <= 512'd0;
                rx_data[303:272] <= S0_IP + hb_next_sid;
                rx_data[239:224] <= 16'd8888;
                rx_data[223:208] <= 16'd9999;
                rx_keep  <= 64'hFFFF_FFFF_FFFF_FFFF;
                rx_last  <= 1'b1;
                rx_valid <= 1'b1;
                rx_meta_is_user <= 1'b0;
                rx_meta_sid     <= hb_next_sid;

                hb_pending <= hb_pending - 1'b1;
                hb_next_sid <= hb_next_sid + 1'b1;
            end else if (q_cnt > 0) begin
                if (q_due[q_rd] <= cycle_cnt) begin
                    rx_data  <= 512'd0;
                    rx_data[303:272] <= q_src_ip[q_rd];
                    rx_data[239:224] <= q_src_port[q_rd];
                    rx_data[223:208] <= q_dst_port[q_rd];
                    rx_keep  <= 64'hFFFF_FFFF_FFFF_FFFF;
                    rx_last  <= 1'b1;
                    rx_valid <= 1'b1;
                    rx_meta_is_user <= q_is_user[q_rd];
                    rx_meta_sid     <= q_sid[q_rd];

                    q_rd <= (q_rd + 1) % Q_DEPTH;
                    q_cnt <= q_cnt - 1;
                end
            end
        end
    end

endmodule
