`timescale 1ns / 1ps
module single_server_node #(
    parameter [31:0]  MY_IP_ADDRESS    = 32'hC0A8010A,
    parameter [31:0]  SERVER_ID_NUM    = 32'd0,
    parameter [511:0] HB_PROBE_PATTERN = 512'h00000000000000000000000000000000000000000000000000000000000000ffffffff010000000d23292328ffffffffc0a80001000011404000000000210045
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         server_en,

    // RX
    input  wire [511:0] rx_tdata,
    input  wire [63:0]  rx_tkeep,   // [THÊM MỚI]
    input  wire         rx_tvalid,
    input  wire         rx_tlast,
    
    // TX
    output wire [511:0] tx_tdata,
    output wire [63:0]  tx_tkeep,   // [THÊM MỚI]
    output wire         tx_tvalid,
    output wire         tx_tlast,
    input  wire         tx_tready,

    // COUNTERS
    output reg [31:0]   cnt_user_req_rx,
    output reg [31:0]   cnt_hb_req_rx,
    output reg [31:0]   cnt_user_reply_tx,
    output reg [31:0]   cnt_hb_reply_tx
);

    // ================= FIFO =================
    localparam FIFO_DEPTH = 64;
    localparam PTR_W = 6;

    reg [63:0] reply_queue [0:FIFO_DEPTH-1];
    reg [PTR_W-1:0] wr_ptr, rd_ptr;

    wire [PTR_W-1:0] next_wr_ptr = wr_ptr + 1'b1;
    wire [PTR_W-1:0] next_rd_ptr = rd_ptr + 1'b1;

    wire fifo_empty = (wr_ptr == rd_ptr);
    wire fifo_full  = (next_wr_ptr == rd_ptr);

    // ================= PARSE DATA =================
    wire [31:0] current_dst_ip  = rx_tdata[31:0];
    wire [31:0] current_user_ip = rx_tdata[303:272];

    wire is_my_ip    = (current_dst_ip == MY_IP_ADDRESS);
    wire is_hb_match = (rx_tdata == HB_PROBE_PATTERN);

    reg is_first_beat;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) is_first_beat <= 1'b1;
        else if (rx_tvalid) is_first_beat <= rx_tlast ? 1'b1 : 1'b0;
    end

    wire user_sop_hit = is_first_beat && rx_tvalid && is_my_ip && server_en;
    wire hb_sop_hit   = is_first_beat && rx_tvalid && is_hb_match && server_en;

    // ================= RX COUNTERS =================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_user_req_rx <= 0;
            cnt_hb_req_rx   <= 0;
        end else begin
            if (user_sop_hit) cnt_user_req_rx <= cnt_user_req_rx + 1;
            if (hb_sop_hit)   cnt_hb_req_rx   <= cnt_hb_req_rx + 1;
        end
    end

    // ================= FIFO WRITE =================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= 0;
        else if (user_sop_hit && !fifo_full) begin
            reply_queue[wr_ptr] <= {current_user_ip, current_dst_ip};
            wr_ptr <= next_wr_ptr;
        end
    end

    // ================= FSM =================
    localparam S_IDLE       = 0;
    localparam S_USER_REPLY = 1;
    localparam S_HB_REPLY   = 2;

    reg [2:0] state;
    reg pending_hb;
    reg [511:0] fsm_tx_tdata;
    reg [63:0]  fsm_tx_tkeep;  // [THÊM MỚI]
    reg fsm_tx_tvalid, fsm_tx_tlast, fsm_is_sending_hb;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pending_hb <= 0;
        else if (hb_sop_hit) pending_hb <= 1'b1;
        else if (tx_tvalid && tx_tready && fsm_is_sending_hb) pending_hb <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; fsm_tx_tvalid <= 0; fsm_tx_tdata <= 0; fsm_tx_tkeep <= 0;
            fsm_tx_tlast <= 0; rd_ptr <= 0; fsm_is_sending_hb <= 0;
        end else begin
            case(state)
                S_IDLE: begin
                    fsm_tx_tvalid <= 0;
                    fsm_is_sending_hb <= 0;
                    if (!server_en) begin
                        state <= S_IDLE;
                    end else if (pending_hb) begin
                        fsm_tx_tdata <= 0;
                        fsm_tx_tdata[175:168] <= 8'h02;
                        fsm_tx_tdata[239:208] <= MY_IP_ADDRESS;
                        fsm_tx_tdata[303:288] <= 16'd9001;
                        fsm_tx_tdata[367:336] <= SERVER_ID_NUM;
                        fsm_tx_tkeep  <= {64{1'b1}}; // [THÊM MỚI] Gói tin 1 beat nên gửi full 64 bytes
                        fsm_tx_tvalid <= 1'b1;
                        fsm_tx_tlast  <= 1'b1;
                        fsm_is_sending_hb <= 1'b1;
                        state <= S_HB_REPLY;
                    end else if (!fifo_empty) begin
                        fsm_tx_tdata <= 512'd0;
                        fsm_tx_tdata[271:240] <= reply_queue[rd_ptr][63:32];
                        fsm_tx_tdata[175:168] <= 8'h00;
                        fsm_tx_tdata[31:0]    <= reply_queue[rd_ptr][31:0];
                        fsm_tx_tkeep  <= {64{1'b1}}; // [THÊM MỚI] Gói tin 1 beat nên gửi full 64 bytes
                        fsm_tx_tvalid <= 1'b1;
                        fsm_tx_tlast  <= 1'b1;
                        state <= S_USER_REPLY;
                    end
                end
                
                S_HB_REPLY: begin
                    if (tx_tvalid && tx_tready) begin
                        fsm_tx_tvalid <= 0;
                        state <= S_IDLE;
                    end
                end

                S_USER_REPLY: begin
                    if (tx_tvalid && tx_tready) begin
                        rd_ptr <= next_rd_ptr;
                        fsm_tx_tvalid <= 0;
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    assign tx_tvalid = fsm_tx_tvalid;
    assign tx_tlast  = fsm_tx_tlast;
    assign tx_tdata  = fsm_tx_tdata;
    assign tx_tkeep  = fsm_tx_tkeep; // [THÊM MỚI]

    // ================= TX COUNTERS =================
    wire tx_fire = tx_tvalid & tx_tready & tx_tlast;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_user_reply_tx <= 0;
            cnt_hb_reply_tx   <= 0;
        end else if (tx_fire) begin
            if (state == S_USER_REPLY) cnt_user_reply_tx <= cnt_user_reply_tx + 1;
            if (state == S_HB_REPLY)   cnt_hb_reply_tx   <= cnt_hb_reply_tx + 1;
        end
    end

endmodule


module server_auto_responder #(
    parameter N_SERVERS = 4
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [N_SERVERS-1:0] server_en,
    
    // RX từ Load Balancer
    input  wire [511:0] rx_tdata,
    input  wire [63:0]  rx_tkeep,   // [THÊM MỚI]
    input  wire         rx_tvalid,
    input  wire         rx_tlast,
    output wire         rx_tready,

    // TX phản h�"i v�? LB
    output reg  [511:0] tx_tdata,
    output reg  [63:0]  tx_tkeep,   // [THÊM MỚI]
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
    wire [63:0]  srv_tx_tkeep  [0:3]; // [THÊM MỚI]
    wire         srv_tx_tvalid [0:3];
    wire         srv_tx_tlast  [0:3];
    wire         srv_tx_tready [0:3];

    assign rx_tready = 1'b1;

    // ================= KHỞI T� O 4 SERVER =================
    // Server A (IP ...10A)
    single_server_node #( .MY_IP_ADDRESS(32'hC0A8010A), .SERVER_ID_NUM(32'd0) ) srv_A (
        .clk(clk), .rst_n(rst_n), .server_en(server_en[3]),
        .rx_tdata(rx_tdata), .rx_tkeep(rx_tkeep), .rx_tvalid(rx_tvalid), .rx_tlast(rx_tlast), // [SỬA L� I]
        .tx_tdata(srv_tx_tdata[0]), .tx_tkeep(srv_tx_tkeep[0]), .tx_tvalid(srv_tx_tvalid[0]), .tx_tlast(srv_tx_tlast[0]), .tx_tready(srv_tx_tready[0]), // [SỬA L� I]
        .cnt_user_req_rx(cnt_user_req_rx[31:0]),     .cnt_hb_req_rx(cnt_hb_req_rx[31:0]),
        .cnt_user_reply_tx(cnt_user_reply_tx[31:0]), .cnt_hb_reply_tx(cnt_hb_reply_tx[31:0])
    );

    // Server B (IP ...10B)
    single_server_node #( .MY_IP_ADDRESS(32'hC0A8010B), .SERVER_ID_NUM(32'd1) ) srv_B (
        .clk(clk), .rst_n(rst_n), .server_en(server_en[2]),
        .rx_tdata(rx_tdata), .rx_tkeep(rx_tkeep), .rx_tvalid(rx_tvalid), .rx_tlast(rx_tlast),
        .tx_tdata(srv_tx_tdata[1]), .tx_tkeep(srv_tx_tkeep[1]), .tx_tvalid(srv_tx_tvalid[1]), .tx_tlast(srv_tx_tlast[1]), .tx_tready(srv_tx_tready[1]),
        .cnt_user_req_rx(cnt_user_req_rx[63:32]),     .cnt_hb_req_rx(cnt_hb_req_rx[63:32]),
        .cnt_user_reply_tx(cnt_user_reply_tx[63:32]), .cnt_hb_reply_tx(cnt_hb_reply_tx[63:32])
    );

    // Server C (IP ...10C)
    single_server_node #( .MY_IP_ADDRESS(32'hC0A8010C), .SERVER_ID_NUM(32'd2) ) srv_C (
        .clk(clk), .rst_n(rst_n), .server_en(server_en[1]),
        .rx_tdata(rx_tdata), .rx_tkeep(rx_tkeep), .rx_tvalid(rx_tvalid), .rx_tlast(rx_tlast),
        .tx_tdata(srv_tx_tdata[2]), .tx_tkeep(srv_tx_tkeep[2]), .tx_tvalid(srv_tx_tvalid[2]), .tx_tlast(srv_tx_tlast[2]), .tx_tready(srv_tx_tready[2]),
        .cnt_user_req_rx(cnt_user_req_rx[95:64]),     .cnt_hb_req_rx(cnt_hb_req_rx[95:64]),
        .cnt_user_reply_tx(cnt_user_reply_tx[95:64]), .cnt_hb_reply_tx(cnt_hb_reply_tx[95:64])
    );

    // Server D (IP ...10D)
    single_server_node #( .MY_IP_ADDRESS(32'hC0A8010D), .SERVER_ID_NUM(32'd3) ) srv_D (
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

    // Gộp tín hiệu ra TX
    always @(*) begin
        tx_tdata  = srv_tx_tdata[grant];
        tx_tkeep  = srv_tx_tkeep[grant]; // [THÊM MỚI]
        tx_tvalid = srv_tx_tvalid[grant];
        tx_tlast  = srv_tx_tlast[grant];
    end

    // Kéo tín hiệu tready trả ngược lại cho Server �'ược cấp quy�?n
    assign srv_tx_tready[0] = (grant == 2'd0) ? tx_tready : 1'b0;
    assign srv_tx_tready[1] = (grant == 2'd1) ? tx_tready : 1'b0;
    assign srv_tx_tready[2] = (grant == 2'd2) ? tx_tready : 1'b0;
    assign srv_tx_tready[3] = (grant == 2'd3) ? tx_tready : 1'b0;

endmodule