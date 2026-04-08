`timescale 1ns / 1ps
module single_server_node #(
    parameter [31:0] MY_IP_ADDRESS = 32'hC0A8010A,
    parameter [31:0] SERVER_ID_NUM = 32'd0
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         server_en,

    // RX
    input  wire [511:0] rx_tdata,
    input  wire [63:0]  rx_tkeep,
    input  wire         rx_tvalid,
    input  wire         rx_tlast,

    // TX
    output reg  [511:0] tx_tdata,
    output reg  [63:0]  tx_tkeep,
    output reg          tx_tvalid,
    output reg          tx_tlast,
    input  wire         tx_tready,

    // COUNTERS
    output reg [31:0] cnt_user_req_rx,
    output reg [31:0] cnt_hb_req_rx,
    output reg [31:0] cnt_user_reply_tx,
    output reg [31:0] cnt_hb_reply_tx
);

    // ================= PARSE =================
    wire [31:0] src_ip = rx_tdata[303:272];
    wire [31:0] dst_ip = rx_tdata[271:240];

    wire is_my_ip = (dst_ip == MY_IP_ADDRESS);
    wire is_hb_match = ((rx_tdata[175:160] == 16'd1) &&
                        (rx_tdata[239:224] == 16'd9999));

    // ================= FIRST BEAT =================
    reg is_first_beat;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            is_first_beat <= 1'b1;
        else if (rx_tvalid && tx_tready)
            is_first_beat <= rx_tlast ? 1'b1 : 1'b0;
    end

    wire fire = rx_tvalid && tx_tready;

    wire user_pkt = is_first_beat && is_my_ip && server_en;
    wire hb_pkt   = is_first_beat && is_hb_match && server_en;

    // ================= COUNTERS RX =================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_user_req_rx <= 0;
            cnt_hb_req_rx   <= 0;
        end else if (fire && is_first_beat) begin
            if (user_pkt) cnt_user_req_rx <= cnt_user_req_rx + 1;
            if (hb_pkt)   cnt_hb_req_rx   <= cnt_hb_req_rx + 1;
        end
    end

    // ================= FSM =================
    localparam S_IDLE = 0;
    localparam S_FWD  = 1;
    localparam S_HB   = 2;

    reg [1:0] state;

    // temp data for forward
    reg [511:0] tx_data_next;

    always @(*) begin
        tx_data_next = rx_tdata;

        // modify only first beat
        if (is_first_beat) begin
            // swap MAC
            tx_data_next[511:464] = rx_tdata[463:416];
            tx_data_next[463:416] = rx_tdata[511:464];

            // swap IP
            tx_data_next[303:272] = dst_ip;
            tx_data_next[271:240] = src_ip;

            // swap PORT
            tx_data_next[239:224] = rx_tdata[223:208];
            tx_data_next[223:208] = rx_tdata[239:224];

            tx_data_next[175:168] = 8'h00;
        end
    end

    // ================= MAIN FSM =================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            tx_tvalid <= 0;
        end else begin
            case(state)

            // ================= IDLE =================
            S_IDLE: begin
                tx_tvalid <= 0;

                if (fire && is_first_beat) begin
                    if (hb_pkt) begin
                        // ? generate heartbeat reply
                        tx_tdata <= 0;
                        tx_tdata[175:168] <= 8'h02;
                        tx_tdata[303:272] <= MY_IP_ADDRESS;
                        tx_tdata[239:224] <= 16'd8888;
                        tx_tdata[223:208] <= 16'd9999;
                        tx_tdata[367:336] <= SERVER_ID_NUM;

                        tx_tkeep  <= {64{1'b1}};
                        tx_tlast  <= 1'b1;
                        tx_tvalid <= 1'b1;

                        state <= S_HB;
                    end
                    else begin
                        // forward user packet
                        tx_tdata  <= tx_data_next;
                        tx_tkeep  <= rx_tkeep;
                        tx_tlast  <= rx_tlast;
                        tx_tvalid <= 1'b1;

                        state <= rx_tlast ? S_IDLE : S_FWD;
                    end
                end
            end

            // ================= FORWARD =================
            S_FWD: begin
                if (fire) begin
                    tx_tdata  <= rx_tdata;
                    tx_tkeep  <= rx_tkeep;
                    tx_tlast  <= rx_tlast;
                    tx_tvalid <= 1'b1;

                    if (rx_tlast)
                        state <= S_IDLE;
                end
            end

            // ================= HEARTBEAT =================
            S_HB: begin
                if (tx_tready) begin
                    tx_tvalid <= 0;
                    state <= S_IDLE;
                end
            end

            endcase
        end
    end

    // ================= TX COUNTERS =================
    wire tx_fire = tx_tvalid && tx_tready && tx_tlast;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_user_reply_tx <= 0;
            cnt_hb_reply_tx   <= 0;
        end else if (tx_fire) begin
            if (state == S_FWD) cnt_user_reply_tx <= cnt_user_reply_tx + 1;
            if (state == S_HB)  cnt_hb_reply_tx   <= cnt_hb_reply_tx + 1;
        end
    end

endmodule

module server_auto_responder #(
    parameter N_SERVERS = 4
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [N_SERVERS-1:0] server_en,
    
    // RX t? Load Balancer
    input  wire [511:0] rx_tdata,
    input  wire [63:0]  rx_tkeep,  
    input  wire         rx_tvalid,
    input  wire         rx_tlast,
    output wire         rx_tready,

    // TX ph?n h?i v? LB
    output reg  [511:0] tx_tdata,
    output reg  [63:0]  tx_tkeep,   
    output reg          tx_tvalid,
    output reg          tx_tlast,
    input  wire         tx_tready,

    // COUNTERS (Packed Array 128-bit)
    output wire [N_SERVERS*32-1:0] cnt_user_req_rx,
    output wire [N_SERVERS*32-1:0] cnt_hb_req_rx,
    output wire [N_SERVERS*32-1:0] cnt_user_reply_tx,
    output wire [N_SERVERS*32-1:0] cnt_hb_reply_tx
);

    wire [511:0] srv_tx_tdata  [0:3];
    wire [63:0]  srv_tx_tkeep  [0:3]; 
    wire         srv_tx_tvalid [0:3];
    wire         srv_tx_tlast  [0:3];
    wire         srv_tx_tready [0:3];

    assign rx_tready = 1'b1;

    // ================= KH?I T?O 4 SERVER =================
    // Server A (IP ...10A)
    single_server_node #( .MY_IP_ADDRESS(32'h0a000064), .SERVER_ID_NUM(32'd0) ) srv_A (
        .clk(clk), .rst_n(rst_n), .server_en(server_en[3]),
        .rx_tdata(rx_tdata), .rx_tkeep(rx_tkeep), .rx_tvalid(rx_tvalid), .rx_tlast(rx_tlast), // [S?A L?I]
        .tx_tdata(srv_tx_tdata[0]), .tx_tkeep(srv_tx_tkeep[0]), .tx_tvalid(srv_tx_tvalid[0]), .tx_tlast(srv_tx_tlast[0]), .tx_tready(srv_tx_tready[0]), // [S?A L?I]
        .cnt_user_req_rx(cnt_user_req_rx[31:0]),     .cnt_hb_req_rx(cnt_hb_req_rx[31:0]),
        .cnt_user_reply_tx(cnt_user_reply_tx[31:0]), .cnt_hb_reply_tx(cnt_hb_reply_tx[31:0])
    );

    // Server B (IP ...10B)
    single_server_node #( .MY_IP_ADDRESS(32'h0a000065), .SERVER_ID_NUM(32'd1) ) srv_B (
        .clk(clk), .rst_n(rst_n), .server_en(server_en[2]),
        .rx_tdata(rx_tdata), .rx_tkeep(rx_tkeep), .rx_tvalid(rx_tvalid), .rx_tlast(rx_tlast),
        .tx_tdata(srv_tx_tdata[1]), .tx_tkeep(srv_tx_tkeep[1]), .tx_tvalid(srv_tx_tvalid[1]), .tx_tlast(srv_tx_tlast[1]), .tx_tready(srv_tx_tready[1]),
        .cnt_user_req_rx(cnt_user_req_rx[63:32]),     .cnt_hb_req_rx(cnt_hb_req_rx[63:32]),
        .cnt_user_reply_tx(cnt_user_reply_tx[63:32]), .cnt_hb_reply_tx(cnt_hb_reply_tx[63:32])
    );

    // Server C (IP ...10C)
    single_server_node #( .MY_IP_ADDRESS(32'h0a000066), .SERVER_ID_NUM(32'd2) ) srv_C (
        .clk(clk), .rst_n(rst_n), .server_en(server_en[1]),
        .rx_tdata(rx_tdata), .rx_tkeep(rx_tkeep), .rx_tvalid(rx_tvalid), .rx_tlast(rx_tlast),
        .tx_tdata(srv_tx_tdata[2]), .tx_tkeep(srv_tx_tkeep[2]), .tx_tvalid(srv_tx_tvalid[2]), .tx_tlast(srv_tx_tlast[2]), .tx_tready(srv_tx_tready[2]),
        .cnt_user_req_rx(cnt_user_req_rx[95:64]),     .cnt_hb_req_rx(cnt_hb_req_rx[95:64]),
        .cnt_user_reply_tx(cnt_user_reply_tx[95:64]), .cnt_hb_reply_tx(cnt_hb_reply_tx[95:64])
    );

    // Server D (IP ...10D)
    single_server_node #( .MY_IP_ADDRESS(32'h0a000067), .SERVER_ID_NUM(32'd3) ) srv_D (
        .clk(clk), .rst_n(rst_n), .server_en(server_en[0]),
        .rx_tdata(rx_tdata), .rx_tkeep(rx_tkeep), .rx_tvalid(rx_tvalid), .rx_tlast(rx_tlast),
        .tx_tdata(srv_tx_tdata[3]), .tx_tkeep(srv_tx_tkeep[3]), .tx_tvalid(srv_tx_tvalid[3]), .tx_tlast(srv_tx_tlast[3]), .tx_tready(srv_tx_tready[3]),
        .cnt_user_req_rx(cnt_user_req_rx[127:96]),     .cnt_hb_req_rx(cnt_hb_req_rx[127:96]),
        .cnt_user_reply_tx(cnt_user_reply_tx[127:96]), .cnt_hb_reply_tx(cnt_hb_reply_tx[127:96])
    );

    reg [1:0] grant; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant <= 2'd0;
        end else if (!tx_tvalid || (tx_tvalid && tx_tready && tx_tlast)) begin
            if (srv_tx_tvalid[0]) grant <= 2'd0;
            else if (srv_tx_tvalid[1]) grant <= 2'd1;
            else if (srv_tx_tvalid[2]) grant <= 2'd2;
            else if (srv_tx_tvalid[3]) grant <= 2'd3;
        end
    end

    // G?p tín hi?u ra TX
    always @(*) begin
        tx_tdata  = srv_tx_tdata[grant];
        tx_tkeep  = srv_tx_tkeep[grant]; // [THÊM M?I]
        tx_tvalid = srv_tx_tvalid[grant];
        tx_tlast  = srv_tx_tlast[grant];
    end

    // Kéo tín hi?u tready tr? ng??c l?i cho Server ???c c?p quy?n
    assign srv_tx_tready[0] = (grant == 2'd0) ? tx_tready : 1'b0;
    assign srv_tx_tready[1] = (grant == 2'd1) ? tx_tready : 1'b0;
    assign srv_tx_tready[2] = (grant == 2'd2) ? tx_tready : 1'b0;
    assign srv_tx_tready[3] = (grant == 2'd3) ? tx_tready : 1'b0;

endmodule