`timescale 1ns / 1ps

// ============================================================================
// TOP MODULE: SERVER CLUSTER AUTO RESPONDER
// FIX: Replace O(N) Round-Robin for-loop with Bitmap Arbiter O(log2 N)
//      => Helps resolve timing violation when N_SERVERS = 32
// ============================================================================
module server_auto_responder #(
    parameter N_SERVERS = 8,
    parameter SCN_W     = 16
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [N_SERVERS-1:0] server_en,
    input  wire allow_reply,

    // RX from Load Balancer
    input  wire [511:0] rx_tdata,
    input  wire [63:0]  rx_tkeep,
    input  wire         rx_tvalid,
    input  wire         rx_tlast,
    output wire         rx_tready,

    // TX reply back to LB
    output reg  [511:0] tx_tdata,
    output reg  [63:0]  tx_tkeep,
    output reg          tx_tvalid,
    output reg          tx_tlast,
    input  wire         tx_tready,

    // COUNTERS
    output wire [N_SERVERS*SCN_W-1:0] cnt_user_req_rx,
    output wire [N_SERVERS*SCN_W-1:0] cnt_hb_req_rx,
    output wire [N_SERVERS*SCN_W-1:0] cnt_user_reply_tx,
    output wire [N_SERVERS*SCN_W-1:0] cnt_hb_reply_tx
);

    localparam GRANT_W = $clog2(N_SERVERS);
    localparam [31:0] BASE_IP_ADDRESS = 32'hC0A8010A;

    wire [511:0] srv_tx_tdata  [0:N_SERVERS-1];
    wire [63:0]  srv_tx_tkeep  [0:N_SERVERS-1];
    wire         srv_tx_tvalid [0:N_SERVERS-1];
    wire         srv_tx_tlast  [0:N_SERVERS-1];
    wire         srv_tx_tready [0:N_SERVERS-1];
    wire         srv_rx_tready [0:N_SERVERS-1];

    // =========================================================================
    // 1. GENERATE BLOCK
    // =========================================================================
    genvar i;
    generate
        for (i = 0; i < N_SERVERS; i = i + 1) begin : gen_srv
            single_server_node #(
                .MY_IP_ADDRESS(BASE_IP_ADDRESS + i),
                .SERVER_ID_NUM(i)
            ) srv_inst (
                .clk(clk),
                .rst_n(rst_n),
                .server_en(server_en[i]),
                .allow_reply(allow_reply),

                .rx_tdata(rx_tdata),
                .rx_tkeep(rx_tkeep),
                .rx_tvalid(rx_tvalid),
                .rx_tlast(rx_tlast),
                .rx_tready(srv_rx_tready[i]),

                .tx_tdata(srv_tx_tdata[i]),
                .tx_tkeep(srv_tx_tkeep[i]),
                .tx_tvalid(srv_tx_tvalid[i]),
                .tx_tlast(srv_tx_tlast[i]),
                .tx_tready(srv_tx_tready[i]),

                .cnt_user_req_rx  (cnt_user_req_rx  [i*SCN_W +: SCN_W]),
                .cnt_hb_req_rx    (cnt_hb_req_rx    [i*SCN_W +: SCN_W]),
                .cnt_user_reply_tx(cnt_user_reply_tx[i*SCN_W +: SCN_W]),
                .cnt_hb_reply_tx  (cnt_hb_reply_tx  [i*SCN_W +: SCN_W])
            );
        end
    endgenerate

    // =========================================================================
    // 2. ADDRESS-AWARE RX READY
    // =========================================================================
    wire [31:0] dest_ip         = rx_tdata[31:0];
    wire [31:0] target_idx      = dest_ip - BASE_IP_ADDRESS;
    wire        target_is_valid = (target_idx < N_SERVERS);

    assign rx_tready = target_is_valid ? srv_rx_tready[target_idx] : 1'b1;

    // =========================================================================
    // 3. BITMAP ROUND-ROBIN ARBITER (O(log2 N) depth, timing-safe @ N=32)
    //
    // Principle:
    //   a) Rotate srv_tx_tvalid left by current "grant"
    //      => slot immediately after grant appears at rotated_valid[0]
    //   b) Priority encoder picks first LSB = 1
    //   c) Convert rotated index back to real server index
    //   d) Register once: next_grant / any_req
    // =========================================================================

    // --- 3a. Pack valid signals into a vector ---
    wire [N_SERVERS-1:0] valid_vec;
    genvar v;
    generate
        for (v = 0; v < N_SERVERS; v = v + 1) begin : gen_valid_vec
            assign valid_vec[v] = srv_tx_tvalid[v];
        end
    endgenerate

    // --- 3b. Rotate left by (grant + 1) for true round-robin ---
    reg [GRANT_W-1:0] grant;

    wire [GRANT_W-1:0] next_check = (grant == N_SERVERS - 1) ? 0 : grant + 1'b1;

    wire [N_SERVERS-1:0] rotated_valid;
    genvar r;
    generate
        for (r = 0; r < N_SERVERS; r = r + 1) begin : gen_rotate
            wire [GRANT_W:0] check_idx = r + next_check;
            assign rotated_valid[r] = valid_vec[
                (check_idx >= N_SERVERS) ? (check_idx - N_SERVERS) : check_idx
            ];
        end
    endgenerate

    // --- 3c. Priority Encoder ---
    wire [GRANT_W-1:0] prio_idx;
    wire               any_req_comb = |rotated_valid;

    function automatic [GRANT_W-1:0] find_first;
        input [N_SERVERS-1:0] vec;
        integer k;
        begin
            find_first = 0;
            for (k = N_SERVERS-1; k >= 0; k = k - 1)
                if (vec[k]) find_first = k[GRANT_W-1:0];
        end
    endfunction

    assign prio_idx = find_first(rotated_valid);

    // --- 3d. Convert rotated index back to real index ---
    wire [GRANT_W:0] raw_next = prio_idx + next_check;
    wire [GRANT_W-1:0] next_grant_comb =
        (raw_next >= N_SERVERS) ? raw_next[GRANT_W-1:0] - N_SERVERS[GRANT_W-1:0]
                                : raw_next[GRANT_W-1:0];

    // --- 3e. Register arbiter outputs ---
    reg [GRANT_W-1:0] next_grant_r;
    reg               any_req_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            next_grant_r <= 0;
            any_req_r    <= 1'b0;
        end else begin
            next_grant_r <= next_grant_comb;
            any_req_r    <= any_req_comb;
        end
    end

    // =========================================================================
    // 4. LOCK / GRANT STATE MACHINE
    // =========================================================================
    reg               locked;
    reg [GRANT_W-1:0] grant_idx;

    wire               out_ready       = tx_tready || !tx_tvalid;
    wire [GRANT_W-1:0] active_idx      = locked ? grant_idx : next_grant_r;
    wire               active_req      = locked ? srv_tx_tvalid[grant_idx] : any_req_r;
    wire               active_tlast    = srv_tx_tlast[active_idx];
    wire               accept_transfer = out_ready && active_req;
    wire               end_of_packet   = accept_transfer && active_tlast;

    always @(posedge clk) begin
        if (!rst_n) begin
            locked    <= 1'b0;
            grant_idx <= 0;
            grant     <= 0;
        end else begin
            if (!locked) begin
                if (any_req_r && out_ready) begin
                    grant <= next_grant_r;
                    if (!active_tlast) begin
                        locked    <= 1'b1;
                        grant_idx <= next_grant_r;
                    end
                end
            end else begin
                if (end_of_packet) locked <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 5. TX MULTIPLEXER (Skid Buffer)
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) tx_tvalid <= 1'b0;
        else if (out_ready) tx_tvalid <= active_req;
    end

    always @(posedge clk) begin
        if (out_ready && active_req) begin
            tx_tdata <= srv_tx_tdata[active_idx];
            tx_tkeep <= srv_tx_tkeep[active_idx];
            tx_tlast <= active_tlast;
        end
    end

    genvar k;
    generate
        for (k = 0; k < N_SERVERS; k = k + 1) begin : gen_tx_ready
            assign srv_tx_tready[k] = (active_idx == k) ? out_ready : 1'b0;
        end
    endgenerate

endmodule


// ============================================================================
// SUB-MODULE: SINGLE SERVER NODE
// FIX: Pipeline 512-bit comparator into 2 stages to avoid timing violation
//      Stage 1: Compare 4 parallel 128-bit chunks -> hb_q0..3
//      Stage 2: AND 4 compare results            -> is_hb_match_r2
//      is_first_beat, rx_valid, rx_ready are also delayed by 2 cycles
//      to align with comparator pipeline
// ============================================================================
`timescale 1ns / 1ps

module single_server_node #(
    parameter [31:0]  MY_IP_ADDRESS    = 32'hC0A8010A,
    parameter [31:0]  SERVER_ID_NUM    = 32'd0,
    parameter [511:0] HB_PROBE_PATTERN = 512'h00000000000000000000000000000000000000000000000000000000000000ffffffff010000000d23292328ffffffffc0a80001000011404000000000210045,
    parameter         MAX_BEATS_PER_PKT = 4,
    parameter SCN_W             = 16
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         server_en,
    input  wire         allow_reply,

    // RX
    input  wire [511:0] rx_tdata,
    input  wire [63:0]  rx_tkeep,
    input  wire         rx_tvalid,
    input  wire         rx_tlast,
    output wire         rx_tready,

    // TX
    output wire [511:0] tx_tdata,
    output wire [63:0]  tx_tkeep,
    output wire         tx_tvalid,
    output wire         tx_tlast,
    input  wire         tx_tready,

    // COUNTERS
    output reg [SCN_W - 1:0]    cnt_user_req_rx,
    output reg [SCN_W - 1:0]    cnt_hb_req_rx,
    output reg [SCN_W - 1:0]    cnt_user_reply_tx,
    output reg [SCN_W - 1:0]    cnt_hb_reply_tx
);

    // =========================================================================
    // PARSE DATA - PIPELINED 2 STAGE
    // =========================================================================
    wire [31:0] current_dst_ip  = rx_tdata[31:0];
    wire [31:0] current_user_ip = rx_tdata[303:272];
    wire        is_heavy_task   = rx_tdata[64];

    // --- STAGE 1 ---
    reg hb_q0, hb_q1, hb_q2, hb_q3;
    reg is_my_ip_r1;
    reg [31:0] dst_ip_r1, user_ip_r1;
    reg        heavy_task_r1;

    // --- STAGE 2 ---
    reg is_hb_match_r2;
    reg is_my_ip_r2;
    reg [31:0] dst_ip_r2, user_ip_r2;
    reg        heavy_task_r2;

    // =========================================================================
    // Beat tracking
    // =========================================================================
    reg is_first_beat;
    reg is_first_beat_r1, is_first_beat_r2;
    reg rx_valid_r1, rx_valid_r2;
    reg rx_ready_r1, rx_ready_r2;

    // =========================================================================
    // FIFO ARCHITECTURE
    // =========================================================================
    localparam FIFO_DEPTH     = 64;
    localparam PTR_W          = 6;
    localparam ALMOST_FULL_TH = FIFO_DEPTH - MAX_BEATS_PER_PKT;

    (* ram_style = "distributed" *) reg [64:0] reply_queue [0:FIFO_DEPTH-1];

    reg [PTR_W-1:0] wr_ptr, rd_ptr;
    reg [PTR_W:0]   fifo_count;
    reg             is_receiving_pkt;

    wire [PTR_W-1:0] next_wr_ptr = wr_ptr + 1'b1;
    wire [PTR_W-1:0] next_rd_ptr = rd_ptr + 1'b1;

    wire fifo_empty  = (fifo_count == 0);
    wire fifo_full   = (fifo_count == FIFO_DEPTH);
    wire almost_full = (fifo_count >= ALMOST_FULL_TH);

    assign rx_tready = is_receiving_pkt ? !fifo_full : !almost_full;

    // =========================================================================
    // FSM / TX
    // =========================================================================
    localparam S_IDLE       = 2'd0;
    localparam S_USER_REPLY = 2'd1;
    localparam S_HB_REPLY   = 2'd2;

    reg [1:0] state;
    reg       pending_hb;

    reg [511:0] fsm_tx_tdata;
    reg [63:0]  fsm_tx_tkeep;
    reg         fsm_tx_tvalid, fsm_tx_tlast, fsm_is_sending_hb;

    assign tx_tvalid = fsm_tx_tvalid;
    assign tx_tlast  = fsm_tx_tlast;
    assign tx_tdata  = fsm_tx_tdata;
    assign tx_tkeep  = fsm_tx_tkeep;

    // =========================================================================
    // POWER-UP INIT (FPGA-friendly, gi?m ph? thu?c reset runtime)
    // =========================================================================
    initial begin
        hb_q0 = 1'b0; hb_q1 = 1'b0; hb_q2 = 1'b0; hb_q3 = 1'b0;
        is_my_ip_r1 = 1'b0;
        is_hb_match_r2 = 1'b0;
        is_my_ip_r2 = 1'b0;

        is_first_beat    = 1'b1;
        is_first_beat_r1 = 1'b1;
        is_first_beat_r2 = 1'b1;
        rx_valid_r1      = 1'b0;
        rx_valid_r2      = 1'b0;
        rx_ready_r1      = 1'b0;
        rx_ready_r2      = 1'b0;

        wr_ptr           = {PTR_W{1'b0}};
        rd_ptr           = {PTR_W{1'b0}};
        fifo_count       = {(PTR_W+1){1'b0}};
        is_receiving_pkt = 1'b0;

        state            = S_IDLE;
        pending_hb       = 1'b0;
        fsm_tx_tvalid    = 1'b0;
        fsm_tx_tlast     = 1'b0;
        fsm_is_sending_hb = 1'b0;

        cnt_user_req_rx   = 16'd0;
        cnt_hb_req_rx     = 16'd0;
        cnt_user_reply_tx = 16'd0;
        cnt_hb_reply_tx   = 16'd0;
    end

    // =========================================================================
    // STAGE 1 PARSE
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            hb_q0      <= 1'b0;
            hb_q1      <= 1'b0;
            hb_q2      <= 1'b0;
            hb_q3      <= 1'b0;
            is_my_ip_r1 <= 1'b0;
        end else begin
            hb_q0 <= (rx_tdata[127:0]   == HB_PROBE_PATTERN[127:0]);
            hb_q1 <= (rx_tdata[255:128] == HB_PROBE_PATTERN[255:128]);
            hb_q2 <= (rx_tdata[383:256] == HB_PROBE_PATTERN[383:256]);
            hb_q3 <= (rx_tdata[511:384] == HB_PROBE_PATTERN[511:384]);

            is_my_ip_r1 <= (current_dst_ip == MY_IP_ADDRESS);

            // data path -> kh�ng c?n reset
            dst_ip_r1     <= current_dst_ip;
            user_ip_r1    <= current_user_ip;
            heavy_task_r1 <= is_heavy_task;
        end
    end

    // =========================================================================
    // STAGE 2 PARSE
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            is_hb_match_r2 <= 1'b0;
            is_my_ip_r2    <= 1'b0;
        end else begin
            is_hb_match_r2 <= hb_q0 & hb_q1 & hb_q2 & hb_q3;
            is_my_ip_r2    <= is_my_ip_r1;

            // data path -> kh�ng c?n reset
            dst_ip_r2      <= dst_ip_r1;
            user_ip_r2     <= user_ip_r1;
            heavy_task_r2  <= heavy_task_r1;
        end
    end

    // =========================================================================
    // Beat tracking align
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            is_first_beat <= 1'b1;
        end else if (rx_tvalid && rx_tready) begin
            is_first_beat <= rx_tlast ? 1'b1 : 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            is_first_beat_r1 <= 1'b1;
            is_first_beat_r2 <= 1'b1;
            rx_valid_r1      <= 1'b0;
            rx_valid_r2      <= 1'b0;
            rx_ready_r1      <= 1'b0;
            rx_ready_r2      <= 1'b0;
        end else begin
            is_first_beat_r1 <= is_first_beat;
            is_first_beat_r2 <= is_first_beat_r1;
            rx_valid_r1      <= rx_tvalid;
            rx_valid_r2      <= rx_valid_r1;
            rx_ready_r1      <= rx_tready;
            rx_ready_r2      <= rx_ready_r1;
        end
    end

    wire user_sop_hit = is_first_beat_r2 & rx_valid_r2 & rx_ready_r2
                      & is_my_ip_r2 & server_en;

    wire hb_sop_hit   = is_first_beat_r2 & rx_valid_r2 & rx_ready_r2
                      & is_hb_match_r2 & server_en;

    // =========================================================================
    // RX COUNTERS
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            cnt_user_req_rx <= 16'd0;
            cnt_hb_req_rx   <= 16'd0;
        end else begin
            if (user_sop_hit) cnt_user_req_rx <= cnt_user_req_rx + 1'b1;
            if (hb_sop_hit)   cnt_hb_req_rx   <= cnt_hb_req_rx + 1'b1;
        end
    end

    // =========================================================================
    // RX packet tracking
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            is_receiving_pkt <= 1'b0;
        end else if (rx_tvalid && rx_tready) begin
            if (rx_tlast) is_receiving_pkt <= 1'b0;
            else          is_receiving_pkt <= 1'b1;
        end
    end

    // =========================================================================
    // FIFO PUSH/POP
    // =========================================================================
    wire fifo_push = user_sop_hit && !fifo_full;
    wire fifo_pop  = (state == S_USER_REPLY) && tx_tvalid && tx_tready;

    always @(posedge clk) begin
        if (!rst_n) begin
            fifo_count <= {(PTR_W+1){1'b0}};
        end else begin
            case ({fifo_push, fifo_pop})
                2'b10:   fifo_count <= fifo_count + 1'b1;
                2'b01:   fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end

    // RAM data -> kh�ng reset
    always @(posedge clk) begin
        if (fifo_push)
            reply_queue[wr_ptr] <= {heavy_task_r2, user_ip_r2, dst_ip_r2};
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= {PTR_W{1'b0}};
        end else if (fifo_push) begin
            wr_ptr <= next_wr_ptr;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr <= {PTR_W{1'b0}};
        end else if (fifo_pop) begin
            rd_ptr <= next_rd_ptr;
        end
    end

    wire [64:0] current_reply_data = reply_queue[rd_ptr];
    wire [31:0] popped_user_ip     = current_reply_data[63:32];
    wire [31:0] popped_dst_ip      = current_reply_data[31:0];

    // =========================================================================
    // HEARTBEAT CATCHER
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            pending_hb <= 1'b0;
        end else if (hb_sop_hit) begin
            pending_hb <= 1'b1;
        end else if (tx_tvalid && tx_tready && fsm_is_sending_hb) begin
            pending_hb <= 1'b0;
        end
    end

    // =========================================================================
    // FSM
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            state             <= S_IDLE;
            fsm_tx_tvalid     <= 1'b0;
            fsm_tx_tlast      <= 1'b0;
            fsm_is_sending_hb <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    fsm_tx_tvalid     <= 1'b0;
                    fsm_is_sending_hb <= 1'b0;

                    if (!server_en) begin
                        state <= S_IDLE;
                    end
                    else if (pending_hb) begin
                        fsm_tx_tdata             <= 512'd0;
                        fsm_tx_tdata[175:168]    <= 8'h02;
                        fsm_tx_tdata[239:208]    <= MY_IP_ADDRESS;
                        fsm_tx_tdata[303:288]    <= 16'd9001;
                        fsm_tx_tdata[367:336]    <= SERVER_ID_NUM;
                        fsm_tx_tkeep             <= {64{1'b1}};
                        fsm_tx_tvalid            <= 1'b1;
                        fsm_tx_tlast             <= 1'b1;
                        fsm_is_sending_hb        <= 1'b1;
                        state                    <= S_HB_REPLY;
                    end
                    else if (!fifo_empty && (allow_reply || almost_full)) begin
                        fsm_tx_tdata             <= 512'd0;
                        fsm_tx_tdata[271:240]    <= popped_user_ip;
                        fsm_tx_tdata[175:168]    <= 8'h00;
                        fsm_tx_tdata[31:0]       <= popped_dst_ip;
                        fsm_tx_tkeep             <= {64{1'b1}};
                        fsm_tx_tvalid            <= 1'b1;
                        fsm_tx_tlast             <= 1'b1;
                        fsm_is_sending_hb        <= 1'b0;
                        state                    <= S_USER_REPLY;
                    end
                end

                S_HB_REPLY: begin
                    if (tx_tvalid && tx_tready) begin
                        fsm_tx_tvalid <= 1'b0;
                        state         <= S_IDLE;
                    end
                end

                S_USER_REPLY: begin
                    if (tx_tvalid && tx_tready) begin
                        fsm_tx_tvalid <= 1'b0;
                        state         <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // =========================================================================
    // TX COUNTERS
    // =========================================================================
    wire tx_fire = tx_tvalid & tx_tready & tx_tlast;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt_user_reply_tx <= 8'd0;
            cnt_hb_reply_tx   <= 8'd0;
        end else if (tx_fire) begin
            if (state == S_USER_REPLY) cnt_user_reply_tx <= cnt_user_reply_tx + 1'b1;
            if (state == S_HB_REPLY)   cnt_hb_reply_tx   <= cnt_hb_reply_tx + 1'b1;
        end
    end

endmodule