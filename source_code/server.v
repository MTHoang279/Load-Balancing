`timescale 1ns / 1ps

module axis_fifo #(
    parameter DEPTH = 16,
    parameter DATA_WIDTH = 512,
    parameter KEEP_WIDTH = DATA_WIDTH/8
)(
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire                   s_valid,
    input  wire                   s_last,
    input  wire [DATA_WIDTH-1:0]  s_data,
    input  wire [KEEP_WIDTH-1:0]  s_keep,
    output wire                   s_ready,

    output reg                    m_valid,
    output reg                    m_last,
    output reg [DATA_WIDTH-1:0]   m_data,
    output reg [KEEP_WIDTH-1:0]   m_keep,
    input  wire                   m_ready
);

    localparam ADDR_W = $clog2(DEPTH);

    // ============================================================
    // MEMORY
    // ============================================================
    reg [DATA_WIDTH-1:0] mem_data [0:DEPTH-1];
    reg [KEEP_WIDTH-1:0] mem_keep [0:DEPTH-1];
    reg                  mem_last [0:DEPTH-1];

    reg [ADDR_W-1:0] wr_ptr;
    reg [ADDR_W-1:0] rd_ptr;

    reg [ADDR_W:0] count;

    // ============================================================
    // HANDSHAKE
    // ============================================================
    wire full  = (count == DEPTH);
    wire empty = (count == 0);

    assign s_ready = !full;

    wire write_en = s_valid & s_ready;
    wire read_en  = m_valid & m_ready;

    // ============================================================
    // WRITE
    // ============================================================
    always @(posedge clk) begin
        if (write_en) begin
            mem_data[wr_ptr] <= s_data;
            mem_keep[wr_ptr] <= s_keep;
            mem_last[wr_ptr] <= s_last;
        end
    end

    // ============================================================
    // POINTERS
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end
        else begin

            if (write_en)
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1'b1;

            if (read_en)
                rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1'b1;

            case ({write_en, read_en})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
            endcase
        end
    end

    // ============================================================
    // REGISTERED OUTPUT
    // ============================================================
    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            m_valid <= 1'b0;
        end
        else begin

            // consume
            if (read_en)
                m_valid <= 1'b0;

            // load next
            if (!m_valid && !empty) begin

                m_data  <= mem_data[rd_ptr];
                m_keep  <= mem_keep[rd_ptr];
                m_last  <= mem_last[rd_ptr];

                m_valid <= 1'b1;
            end
        end
    end

endmodule

module server #(
    parameter SERVER_ID = 0,
    parameter [31:0] MY_IP = 32'h0A000064
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         server_en,

    // RX AXIS (T? Per-Server FIFO)
    input  wire         rx_user_valid,
    input  wire         rx_user_last,
    input  wire [511:0] rx_user_data,
    input  wire [63:0]  rx_user_keep,
    output wire         rx_user_ready,

    // TX AXIS (T?i Per-Server Output FIFO)
    output wire         tx_user_valid,
    output wire         tx_user_last,
    output wire [511:0] tx_user_data,
    output wire [63:0]  tx_user_keep,
    input  wire         tx_user_ready,

    // Counters (Pipelined Outputs)
    output reg [14:0]   cnt_user_req_rx,
    output reg [14:0]   cnt_hb_req_rx,
    output reg [14:0]   cnt_user_reply_tx,
    output reg [14:0]   cnt_hb_reply_tx
);

    localparam [15:0] HB_SRC_PORT = 16'd8888;
    localparam [15:0] HB_DST_PORT = 16'd9999;

    // =====================================================
    // T?NG 1: SERVER INPUT REG (Khóa tín hi?u t? FIFO vào)
    // =====================================================
    reg         in_reg_valid, in_reg_last;
    reg [511:0] in_reg_data;
    reg [63:0]  in_reg_keep;
    wire        in_reg_ready;

    // C? ch? s?n sàng cô l?p t?ng tr??c
    assign rx_user_ready = !in_reg_valid || in_reg_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_reg_valid <= 1'b0;
            in_reg_last  <= 1'b0;
            in_reg_data  <= 512'd0;
            in_reg_keep  <= 64'd0;
        end else if (rx_user_ready) begin
            in_reg_valid <= rx_user_valid && server_en;
            in_reg_last  <= rx_user_last;
            in_reg_data  <= rx_user_data;
            in_reg_keep  <= rx_user_keep;
        end
    end

    // Handshake n?i b? T?ng 1 -> T?ng 2
    wire fire_in_reg = in_reg_valid && in_reg_ready;

    reg sop_in;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)          sop_in <= 1'b1;
        else if (fire_in_reg) sop_in <= in_reg_last;
    end

    // Phân lo?i gói tin t? h?p ng?n t? t?ng Input Reg
    wire hb_match_now = (in_reg_data[223:208] == HB_SRC_PORT) && 
                        (in_reg_data[239:224] == HB_DST_PORT);

    // =====================================================
    // T?NG 2: SERVER PROCESS REG (X? lý Core & Gói Tin)
    // =====================================================
    reg         proc_reg_valid, proc_reg_last, proc_is_hb;
    reg [511:0] proc_reg_data;
    reg [63:0]  proc_reg_keep;
    wire        proc_reg_ready;

    assign in_reg_ready = !proc_reg_valid || proc_reg_ready;

    // Theo dõi tr?ng thái lo?i gói tin xuyên su?t
    reg is_hb_type;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)               is_hb_type <= 1'b0;
        else if (fire_in_reg && sop_in) is_hb_type <= hb_match_now;
    end

    // Tính toán tr??c c?u trúc gói Heartbeat Reply ngay t?i t?ng x? lý
    reg [511:0] hb_reply_precompute;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) hb_reply_precompute <= 512'd0;
        else if (fire_in_reg && sop_in && hb_match_now) begin
            hb_reply_precompute <= {
                72'b0,
                SERVER_ID[31:0],
                32'b0, 64'b0, 8'h02, 32'b0,
                in_reg_data[303:272], // M??n IP ngu?n làm IP ?ích ph?n h?i
                MY_IP,                 
                HB_SRC_PORT, HB_DST_PORT,
                208'b0
            };
        end
    end

    // ??y d? li?u qua thanh ghi x? lý ???ng ?ng
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            proc_reg_valid <= 1'b0;
            proc_reg_last  <= 1'b0;
            proc_is_hb     <= 1'b0;
        end else if (in_reg_ready) begin
            proc_reg_valid <= in_reg_valid;
            proc_reg_last  <= in_reg_last;
            proc_is_hb     <= sop_in ? hb_match_now : is_hb_type;
        end
    end

    always @(posedge clk) begin
        if (in_reg_ready && in_reg_valid) begin
            proc_reg_data <= hb_match_now ? 512'd0 : in_reg_data; // Xóa data n?u là HB nh?m ti?t ki?m n?ng l??ng trung gian
            proc_reg_keep <= in_reg_keep;
        end
    end

    // Handshake n?i b? T?ng 2 -> T?ng 3
    wire fire_proc_reg = proc_reg_valid && proc_reg_ready;

    // =====================================================
    // T?NG 3: SERVER OUTPUT REG (?óng gói ??u ra c?ng)
    // =====================================================
    reg         out_reg_valid, out_reg_last;
    reg [511:0] out_reg_data;
    reg [63:0]  out_reg_keep;

    assign proc_reg_ready = !out_reg_valid || tx_user_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_reg_valid <= 1'b0;
            out_reg_last  <= 1'b0;
            out_reg_data  <= 512'd0;
            out_reg_keep  <= 64'd0;
        end else if (proc_reg_ready) begin
            out_reg_valid <= proc_reg_valid;
            out_reg_last  <= proc_is_hb ? 1'b1 : proc_reg_last;
            out_reg_data  <= proc_is_hb ? hb_reply_precompute : proc_reg_data;
            out_reg_keep  <= proc_is_hb ? 64'hFFFFFFFFFFFFFFFF : proc_reg_keep;
        end
    end

    // Ánh x? ra các c?ng ngo?i vi bên ngoài Server Core
    assign tx_user_valid = out_reg_valid;
    assign tx_user_last  = out_reg_last;
    assign tx_user_data  = out_reg_data;
    assign tx_user_keep  = out_reg_keep;

    // =====================================================
    // B? ??M TH?NG KÊ HI?U N?NG (???ng ?ng hóa tri?t ??)
    // =====================================================
    // Vi?c tính toán kích ho?t t?ng b? ??m d?a vào tín hi?u Handshake
    // ?ã ???c tách bi?t hoàn toàn ?? tránh m??n ???ng t? h?p t? module khác.
    
    reg rx_cnt_inc_hb, rx_cnt_inc_user;
    reg tx_cnt_inc_hb, tx_cnt_inc_user;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_cnt_inc_hb   <= 1'b0; rx_cnt_inc_user <= 1'b0;
            tx_cnt_inc_hb   <= 1'b0; tx_cnt_inc_user <= 1'b0;
        end else begin
            // ??m s? ki?n t?i T?ng X? lý (N?i b? n?i h?t)
            rx_cnt_inc_hb   <= fire_proc_reg && proc_reg_last && proc_is_hb;
            rx_cnt_inc_user <= fire_proc_reg && proc_reg_last && !proc_is_hb;

            // ??m s? ki?n t?i T?ng ??u ra
            tx_cnt_inc_hb   <= tx_user_valid && tx_user_ready && tx_user_last && proc_is_hb;
            tx_cnt_inc_user <= tx_user_valid && tx_user_ready && tx_user_last && !proc_is_hb;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_hb_req_rx     <= 15'd0;   cnt_user_req_rx   <= 15'd0;
            cnt_hb_reply_tx   <= 15'd0;   cnt_user_reply_tx <= 15'd0;
        end else begin
            if (rx_cnt_inc_hb)   cnt_hb_req_rx     <= cnt_hb_req_rx + 1'b1;
            if (rx_cnt_inc_user) cnt_user_req_rx   <= cnt_user_req_rx + 1'b1;
            if (tx_cnt_inc_hb)   cnt_hb_reply_tx   <= cnt_hb_reply_tx + 1'b1;
            if (tx_cnt_inc_user) cnt_user_reply_tx <= cnt_user_reply_tx + 1'b1;
        end
    end
endmodule

module master_server #(
    parameter NUM_SERVERS     = 32,
    parameter SERVER_ID_WIDTH = $clog2(NUM_SERVERS)
)(
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [NUM_SERVERS-1:0]       server_en,

    // =====================================================
    // SYSTEM RX
    // =====================================================

    input  wire                         rx_user_valid,
    input  wire                         rx_user_last,
    input  wire [511:0]                 rx_user_data,
    input  wire [63:0]                  rx_user_keep,
    output wire                         rx_user_ready,

    // =====================================================
    // SYSTEM TX
    // =====================================================

    output wire                         tx_user_valid,
    output wire                         tx_user_last,
    output wire [511:0]                 tx_user_data,
    output wire [63:0]                  tx_user_keep,
    input  wire                         tx_user_ready,

    // =====================================================
    // SERVER INFO
    // =====================================================

    output reg  [NUM_SERVERS*32-1:0]    server_ip_list,
    output wire                         server_ip_list_valid,

    // =====================================================
    // COUNTERS
    // =====================================================

    output wire [NUM_SERVERS*15-1:0]    cnt_user_req_rx,
    output wire [NUM_SERVERS*15-1:0]    cnt_hb_req_rx,

    output wire [NUM_SERVERS*15-1:0]    cnt_user_reply_tx,
    output wire [NUM_SERVERS*15-1:0]    cnt_hb_reply_tx
);

    // =====================================================
    // 1. INPUT FIFO
    // =====================================================

    wire         in_fifo_valid;
    wire         in_fifo_last;
    wire [511:0] in_fifo_data;
    wire [63:0]  in_fifo_keep;

    wire in_fifo_consume;

    axis_fifo #(
        .DEPTH(8)
    )
    u_input_fifo (
        .clk(clk),
        .rst_n(rst_n),

        .s_valid(rx_user_valid),
        .s_data (rx_user_data),
        .s_keep (rx_user_keep),
        .s_last (rx_user_last),
        .s_ready(rx_user_ready),

        .m_valid(in_fifo_valid),
        .m_data (in_fifo_data),
        .m_keep (in_fifo_keep),
        .m_last (in_fifo_last),
        .m_ready(in_fifo_consume)
    );

    // =====================================================
    // 2. ROUTE REGISTER
    // =====================================================

    reg sop;

    wire route_fire;

    assign route_fire =
        in_fifo_valid &&
        in_fifo_consume;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n)
            sop <= 1'b1;

        else if (route_fire)
            sop <= in_fifo_last;
    end

    // -----------------------------------------------------
    // Route decode
    // -----------------------------------------------------

    wire current_is_hb;

    assign current_is_hb =
        (in_fifo_data[223:208] == 16'd8888);

    wire [7:0] dst_byte;

    assign dst_byte =
        in_fifo_data[247:240];

    wire [SERVER_ID_WIDTH-1:0] current_target;

    assign current_target =
        (dst_byte >= 8'd100) ?
        (dst_byte - 8'd100) :
        {SERVER_ID_WIDTH{1'b0}};

    // -----------------------------------------------------
    // Sticky route registers
    // -----------------------------------------------------

    reg                        r_pkt_is_hb;
    reg [SERVER_ID_WIDTH-1:0]  r_pkt_target;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            r_pkt_is_hb  <= 1'b0;
            r_pkt_target <= 0;

        end
        else if (route_fire && sop) begin

            r_pkt_is_hb  <= current_is_hb;
            r_pkt_target <= current_target;

        end
    end

    wire pkt_is_hb;

    wire [SERVER_ID_WIDTH-1:0] pkt_target;

    assign pkt_is_hb =
        sop ? current_is_hb : r_pkt_is_hb;

    assign pkt_target =
        sop ? current_target : r_pkt_target;

    // =====================================================
    // 3. PER SERVER RX FIFO
    // =====================================================

    wire [NUM_SERVERS-1:0] per_srv_rx_ready;

    reg  [NUM_SERVERS-1:0] per_srv_rx_valid;

    always @(*) begin

        per_srv_rx_valid =
            {NUM_SERVERS{1'b0}};

        if (in_fifo_valid) begin

            if (pkt_is_hb)
                per_srv_rx_valid =
                    {NUM_SERVERS{1'b1}};

            else
                per_srv_rx_valid[pkt_target] =
                    1'b1;
        end
    end

    assign in_fifo_consume =
        pkt_is_hb ?
        (|per_srv_rx_ready) :
        per_srv_rx_ready[pkt_target];

    // =====================================================
    // INTERNAL BUS
    // =====================================================

    wire [NUM_SERVERS-1:0] s_valid;
    wire [NUM_SERVERS-1:0] s_last;
    wire [NUM_SERVERS-1:0] s_ready;

    wire [511:0] s_data [0:NUM_SERVERS-1];
    wire [63:0]  s_keep [0:NUM_SERVERS-1];

    wire [NUM_SERVERS-1:0] srv_tx_valid;
    wire [NUM_SERVERS-1:0] srv_tx_last;
    wire [NUM_SERVERS-1:0] srv_tx_ready;

    wire [511:0] srv_tx_data [0:NUM_SERVERS-1];
    wire [63:0]  srv_tx_keep [0:NUM_SERVERS-1];

    wire [NUM_SERVERS-1:0] per_srv_tx_valid;
    wire [NUM_SERVERS-1:0] per_srv_tx_last;
    wire [NUM_SERVERS-1:0] per_srv_tx_ready;

    wire [511:0] per_srv_tx_data [0:NUM_SERVERS-1];
    wire [63:0]  per_srv_tx_keep [0:NUM_SERVERS-1];

    // =====================================================
    // 4~7. SERVER PIPELINE
    // =====================================================

    genvar i;

    generate

        for (i = 0; i < NUM_SERVERS; i = i + 1) begin : GEN_SERVER_CHANNELS

            // -------------------------------------------------
            // PER SERVER RX FIFO
            // -------------------------------------------------

            axis_fifo #(
                .DEPTH(4)
            )
            u_per_server_fifo_rx (
                .clk(clk),
                .rst_n(rst_n),

                .s_valid(per_srv_rx_valid[i] && in_fifo_valid),
                .s_data (in_fifo_data),
                .s_keep (in_fifo_keep),
                .s_last (in_fifo_last),
                .s_ready(per_srv_rx_ready[i]),

                .m_valid(s_valid[i]),
                .m_data (s_data[i]),
                .m_keep (s_keep[i]),
                .m_last (s_last[i]),
                .m_ready(s_ready[i])
            );

            // -------------------------------------------------
            // SERVER CORE
            // -------------------------------------------------

            server #(
                .SERVER_ID(i),
                .MY_IP(32'h0A000064 + i)
            )
            u_server_core (
                .clk(clk),
                .rst_n(rst_n),

                .server_en(server_en[i]),

                .rx_user_valid(s_valid[i]),
                .rx_user_last (s_last[i]),
                .rx_user_data (s_data[i]),
                .rx_user_keep (s_keep[i]),
                .rx_user_ready(s_ready[i]),

                .tx_user_valid(srv_tx_valid[i]),
                .tx_user_last (srv_tx_last[i]),
                .tx_user_data (srv_tx_data[i]),
                .tx_user_keep (srv_tx_keep[i]),
                .tx_user_ready(srv_tx_ready[i]),

                .cnt_user_req_rx (
                    cnt_user_req_rx[i*15 +: 15]
                ),

                .cnt_hb_req_rx (
                    cnt_hb_req_rx[i*15 +: 15]
                ),

                .cnt_user_reply_tx (
                    cnt_user_reply_tx[i*15 +: 15]
                ),

                .cnt_hb_reply_tx (
                    cnt_hb_reply_tx[i*15 +: 15]
                )
            );

            // -------------------------------------------------
            // PER SERVER OUTPUT FIFO
            // -------------------------------------------------

            axis_fifo #(
                .DEPTH(4)
            )
            u_per_server_fifo_tx (
                .clk(clk),
                .rst_n(rst_n),

                .s_valid(srv_tx_valid[i]),
                .s_data (srv_tx_data[i]),
                .s_keep (srv_tx_keep[i]),
                .s_last (srv_tx_last[i]),
                .s_ready(srv_tx_ready[i]),

                .m_valid(per_srv_tx_valid[i]),
                .m_data (per_srv_tx_data[i]),
                .m_keep (per_srv_tx_keep[i]),
                .m_last (per_srv_tx_last[i]),
                .m_ready(per_srv_tx_ready[i])
            );

        end

    endgenerate

    // =====================================================
    // 8. REGISTERED RR ARBITER
    // =====================================================

    reg [SERVER_ID_WIDTH-1:0] rr_ptr;

    // -----------------------------------------------------
    // Stage 1
    // -----------------------------------------------------

    reg                        scan_valid_r;
    reg [SERVER_ID_WIDTH-1:0] scan_sel_r;

    integer k;

    reg                        found_comb;
    reg [SERVER_ID_WIDTH-1:0] sel_comb;

    always @(*) begin

        found_comb = 1'b0;
        sel_comb   = rr_ptr;

        for (k = 0; k < NUM_SERVERS; k = k + 1) begin

            if (!found_comb) begin

                if ((rr_ptr + k) >= NUM_SERVERS)
                    sel_comb = rr_ptr + k - NUM_SERVERS;
                else
                    sel_comb = rr_ptr + k;

                if (per_srv_tx_valid[sel_comb])
                    found_comb = 1'b1;
            end
        end
    end

    // -----------------------------------------------------
    // Stage 2
    // -----------------------------------------------------

    reg         arb_reg_valid;
    reg         arb_reg_last;

    reg [511:0] arb_reg_data;
    reg [63:0]  arb_reg_keep;

    wire arb_stage_ready;

    wire tx_fifo_ready_in;

    assign arb_stage_ready =
        !arb_reg_valid ||
        tx_fifo_ready_in;

    wire scan_stage_ready;

    assign scan_stage_ready =
        !scan_valid_r ||
        arb_stage_ready;

    // -----------------------------------------------------
    // Scan register
    // -----------------------------------------------------

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            scan_valid_r <= 1'b0;
            scan_sel_r   <= 0;

        end
        else if (scan_stage_ready) begin

            scan_valid_r <= found_comb;
            scan_sel_r   <= sel_comb;

        end
    end

    // -----------------------------------------------------
    // READY generation
    // -----------------------------------------------------

    genvar r;

    generate

        for (r = 0; r < NUM_SERVERS; r = r + 1) begin : READY_GEN

            assign per_srv_tx_ready[r] =
                scan_valid_r &&
                arb_stage_ready &&
                (scan_sel_r == r);

        end

    endgenerate

    // -----------------------------------------------------
    // Register mux output
    // -----------------------------------------------------

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            arb_reg_valid <= 1'b0;
            arb_reg_last  <= 1'b0;

            arb_reg_data  <= 512'd0;
            arb_reg_keep  <= 64'd0;

        end
        else if (arb_stage_ready) begin

            arb_reg_valid <= scan_valid_r;

            arb_reg_last <=
                per_srv_tx_last[scan_sel_r];

            arb_reg_data <=
                per_srv_tx_data[scan_sel_r];

            arb_reg_keep <=
                per_srv_tx_keep[scan_sel_r];

        end
    end

    // -----------------------------------------------------
    // RR pointer update
    // -----------------------------------------------------

    wire arb_fire;

    assign arb_fire =
        scan_valid_r &&
        arb_stage_ready;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            rr_ptr <= 0;

        end
        else if (arb_fire) begin

            if (scan_sel_r == NUM_SERVERS-1)
                rr_ptr <= 0;
            else
                rr_ptr <= scan_sel_r + 1'b1;
        end
    end

    // =====================================================
    // 9. OUTPUT FIFO
    // =====================================================

    localparam OUT_FIFO_DEPTH =
        (NUM_SERVERS >> 1) + 4;

    axis_fifo #(
        .DEPTH(OUT_FIFO_DEPTH)
    )
    u_final_out_fifo (
        .clk(clk),
        .rst_n(rst_n),

        .s_valid(arb_reg_valid),
        .s_data (arb_reg_data),
        .s_keep (arb_reg_keep),
        .s_last (arb_reg_last),
        .s_ready(tx_fifo_ready_in),

        .m_valid(tx_user_valid),
        .m_data (tx_user_data),
        .m_keep (tx_user_keep),
        .m_last (tx_user_last),
        .m_ready(tx_user_ready)
    );

    // =====================================================
    // SERVER IP LIST
    // =====================================================

    reg [1:0] boot_pulse_cnt;

    reg server_ip_list_valid_r;

    integer ip_i;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            boot_pulse_cnt         <= 2'd0;
            server_ip_list_valid_r <= 1'b0;

            for (ip_i = 0;
                 ip_i < NUM_SERVERS;
                 ip_i = ip_i + 1) begin

                server_ip_list[ip_i*32 +: 32]
                    <= 32'h0A000064 + ip_i;
            end
        end
        else begin

            if (boot_pulse_cnt < 2'd3)
                boot_pulse_cnt <= boot_pulse_cnt + 1'b1;

            server_ip_list_valid_r
                <= (boot_pulse_cnt == 2'd2);

            for (ip_i = 0;
                 ip_i < NUM_SERVERS;
                 ip_i = ip_i + 1) begin

                server_ip_list[ip_i*32 +: 32]
                    <= 32'h0A000064 + ip_i;
            end
        end
    end

    assign server_ip_list_valid =
        server_ip_list_valid_r;

endmodule