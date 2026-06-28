module fpga_top#(
    parameter BUS_WIDTH = 512,
    parameter INPUTFILE = "",
    parameter CLK_FREQ_HZ = 1000,
    parameter TICK_MS = 10,
    parameter SCN_WIDTH = 16,
    parameter NUM_SERVERS = 32
)(
    input  wire        clk_p,
    input  wire        clk_n,    
    input  wire        rst_in,     // N?t nh?n GPIO_SW_N (Active High)
    (* mark_debug = "true" *) input  wire        start,      // Asynchronous Input
    (* mark_debug = "true" *) input  wire [1:0]  algo_sel,
    (* mark_debug = "true" *) input  wire [5:0]  server_en,
    (* mark_debug = "true" *) output wire        done       // flag done read pcap
);
    (* keep = "true", dont_touch = "true", mark_debug = "true" *) wire [1:0] algo_sel_dbg;
    assign algo_sel_dbg = algo_sel;

    wire [NUM_SERVERS*15-1:0] cnt_user_req_rx;
    wire [NUM_SERVERS*15-1:0] cnt_hb_req_rx;
    wire [NUM_SERVERS*15-1:0] cnt_user_reply_tx;
    wire [NUM_SERVERS*15-1:0] cnt_hb_reply_tx;

// ============================================================
// DEBUG COUNTERS PER SERVER
// ============================================================

    (* keep = "true", dont_touch = "true", mark_debug = "true" *)
    wire [14:0] dbg_cnt_user_req_rx   [0:NUM_SERVERS-1];
    
    (* keep = "true", dont_touch = "true", mark_debug = "true" *)
    wire [14:0] dbg_cnt_hb_req_rx     [0:NUM_SERVERS-1];
    
    (* keep = "true", dont_touch = "true", mark_debug = "true" *)
    wire [14:0] dbg_cnt_user_reply_tx [0:NUM_SERVERS-1];
    
    (* keep = "true", dont_touch = "true", mark_debug = "true" *)
    genvar gi;

    generate
        for (gi = 0; gi < NUM_SERVERS; gi = gi + 1) begin : GEN_DBG_CNT
    
            assign dbg_cnt_user_req_rx[gi]
                = cnt_user_req_rx[gi*15 +: 15];
    
            assign dbg_cnt_hb_req_rx[gi]
                = cnt_hb_req_rx[gi*15 +: 15];
    
            assign dbg_cnt_user_reply_tx[gi]
                = cnt_user_reply_tx[gi*15 +: 15];
    
            assign dbg_cnt_hb_reply_tx[gi]
                = cnt_hb_reply_tx[gi*15 +: 15];
    
        end
    endgenerate
    wire [14:0] dbg_cnt_hb_reply_tx   [0:NUM_SERVERS-1];
    
    (* mark_debug = "true" *) wire [5:0] server_en_dbg;

    assign server_en_dbg = server_en;
    
       // Bi?n trung gian ?? ch?a Bitmap th?c t? sau khi gi?i mã t? switch
    reg [NUM_SERVERS-1:0] server_en_valid;

    // ============================================================
    // Logic chuy?n ??i t? 6 Switch sang Bitmap N_SERVERS
    // ============================================================
// ============================================================
// Decode server enable
// 0000 : disable all
// 0001 : enable 1 server
// 0010 : enable 4 servers
// 0011 : enable 8 servers
// 0100 : enable 16 servers
// 0101 : enable all servers
// ============================================================

    always @(*) begin
        if (server_en == 0)
            server_en_valid = 32'b0;
        else if (server_en >= 32)
            server_en_valid = {NUM_SERVERS{1'b1}};
        else
            server_en_valid = (32'h1 << server_en) - 1;
    end
    
    // 1. X? l? Clock vi sai
    wire clk_core;
    IBUFDS ibufds_inst (
        .O (clk_core), // Output clock 125MHz d?ng cho to?n b? logic b?n d??i
        .I (clk_p),    
        .IB(clk_n)     
    );

    // 2. X? l? Reset (QUAN TR?NG: Gi? nguy?n d?ng n?y)
    // N?t nh?n ZCU102 l? Active High (1 l? Reset), Core c?n Active Low (0 l? Reset)
    // -> Ph?i ??o bit (~).
    wire rst_n;
    assign rst_n = ~rst_in; 

    //connect from generator to filter
    wire [BUS_WIDTH-1:0]        gen_tdata;
    (* mark_debug = "true" *) wire                        gen_tvalid;
    (* mark_debug = "true" *) wire                        gen_tlast;
    (* mark_debug = "true" *) wire [BUS_WIDTH/8-1:0]      gen_tkeep;
    (* mark_debug = "true" *) wire                        gen_tready;
    
    //connect from filter to CSLB
    wire [BUS_WIDTH-1:0]        filt_tdata;
    wire                        filt_tvalid;
    wire                        filt_tlast;
    wire [BUS_WIDTH/8-1:0]      filt_tkeep;
    wire                        filt_tready;    
    
    // connect from filter to CSLB
    // ================= AXIS Master =================
    wire  [31:0]  key_src_ip;
    wire  [31:0]  key_dst_ip;
    wire  [15:0]  key_src_port;
    wire  [15:0]  key_dst_port;
    wire  [7:0]   key_protocol;
    wire         key_valid;
    
    // connect from CSLB to shm 
    wire                        scn_inc_en;  //scn increament from cslb to stt controller to update status server
    wire  [$clog2(NUM_SERVERS)-1:0]                 server_idx;  // idx comes with scn increment
    wire                        ready_shm2cslb;
    wire                        cslb_rd_en;  // tin hieu tu cslb yeu cau gui danh sach dia chi ip va trang thai ket noi cua server 
    
    wire  [NUM_SERVERS*32-1:0]  cslb_rd_ip;
    wire  [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn;
    wire                        cslb_rd_valid;
    wire  [NUM_SERVERS*32-1:0]  server_ip_list;
    wire                        server_ip_list_valid;
     
    wire  [NUM_SERVERS-1:0]     health_bitmap;
    wire                        scn_dec_en;
    wire  [$clog2(NUM_SERVERS)-1:0]                 scn_dec_idx; 
    
    // input from backend to cslb 
    wire [511:0]  rx_backend_data;
    (* mark_debug = "true" *)wire [63:0]   rx_backend_keep;
    (* mark_debug = "true" *)wire          rx_backend_valid;
    (* mark_debug = "true" *)wire          rx_backend_last;
    (* mark_debug = "true" *)wire          rx_backend_ready;
    
        //output 
    wire [BUS_WIDTH -1:0]       tx_backend_data;
    (* mark_debug = "true" *)wire [BUS_WIDTH/8-1:0]      tx_backend_keep;
    (* mark_debug = "true" *)wire                        tx_backend_last;
    (* mark_debug = "true" *)wire                        tx_backend_valid;
    (* mark_debug = "true" *)wire                        tx_backend_ready;     // tready t? sync FIFO 
    
    (* mark_debug = "true" *) reg [31:0] beat_cnt;
    
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            beat_cnt    <= 0;
        end
        else if (gen_tvalid && gen_tready) begin
            beat_cnt    <= beat_cnt + 1;
        end
    end
    //===============================================
    (* mark_debug = "true" *) reg [31:0] cycle_cnt;
    (* keep = "true", dont_touch = "true", mark_debug = "true" *)
    reg [3:0] first_gen_cycle;
    
    (* keep = "true", dont_touch = "true", mark_debug = "true" *)
    reg [3:0] first_server_cycle;
    reg measure_en;
    reg gen_seen;
    reg server_seen;
    
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n)
            measure_en <= 1'b0;
        else
            measure_en <= (measure_en | start_pulse);
    end
    
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n)
            cycle_cnt <= 32'd0;
        else if (start_pulse)
            cycle_cnt <= 32'd0;
        else if (measure_en)
            cycle_cnt <= cycle_cnt + 1'b1;
    end
    // count first gen
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            gen_seen        <= 1'b0;
            first_gen_cycle <= 4'd0;
        end
        else if (start_pulse) begin
            gen_seen        <= 1'b0;
            first_gen_cycle <= 4'd0;
        end
        else if (!gen_seen &&
                 gen_tlast &&
                 gen_tvalid) begin
    
            gen_seen        <= 1'b1;
            first_gen_cycle <= cycle_cnt;
        end
    end
    
    // count first come server
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            server_seen        <= 1'b0;
            first_server_cycle <= 4'd0;
        end
        else if (start_pulse) begin
            server_seen        <= 1'b0;
            first_server_cycle <= 4'd0;
        end
        else if (!server_seen &&
                 tx_backend_last &&
                 tx_backend_ready) begin
    
            server_seen        <= 1'b1;
            first_server_cycle <= cycle_cnt;
        end
    end
    // ======================================================
    (* keep = "true", dont_touch = "true", mark_debug = "true" *)
    reg [19:0] gen_pkt_cnt;
    
    (* keep = "true", dont_touch = "true", mark_debug = "true" *)
    reg [19:0] filtered_pkt_cnt;
    
    (* keep = "true", dont_touch = "true", mark_debug = "true" *)
    reg [19:0] lb_pkt_cnt;
    
    //-----------
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n)
            gen_pkt_cnt <= 20'd0;
        else if (gen_tvalid && gen_tready && gen_tlast)
            gen_pkt_cnt <= gen_pkt_cnt + 1'b1;
    end
    //------------
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n)
            filtered_pkt_cnt <= 20'd0;
        else if (filt_tvalid && filt_tready && filt_tlast)
            filtered_pkt_cnt <= filtered_pkt_cnt + 1'b1;
    end
    //-------------
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n)
            lb_pkt_cnt <= 20'd0;
        else if (tx_backend_valid &&
                 tx_backend_ready &&
                 tx_backend_last)
            lb_pkt_cnt <= lb_pkt_cnt + 1'b1;
    end
    
    // ================= START SYNCHRONIZER =================
    reg start_r1, start_r2;
    wire start_pulse;
    always @(posedge clk_core or negedge rst_n) begin
    if (!rst_n) begin
            start_r1 <= 1'b0;
            start_r2 <= 1'b0;
        end
        else begin
            start_r1 <= start;
            start_r2 <= start_r1;
        end
    end

assign start_pulse = start_r1 & ~start_r2;


    // ================= Core =====================
    wire [511:0] m_axis_tdata;
    wire         m_axis_tvalid;
    wire         m_axis_tlast;
    wire [63:0]  m_axis_tkeep;
    
//    net2axis_master #(
//        .TDATA_WIDTH(BUS_WIDTH),
//        .INPUTFILE(INPUTFILE)
//    ) u_packet_gen (
//        .ACLK        (clk_core),
//        .ARESETN      (rst_n),
//        .START      (start),
//        .DONE       (done),
////        .done_packet(),
    
//        // AXI-Stream master interface
//        .M_AXIS_TDATA      (gen_tdata),
//        .M_AXIS_TVALID     (gen_tvalid),
//        .M_AXIS_TLAST      (gen_tlast),
//        .M_AXIS_TKEEP      (gen_tkeep),
//        .M_AXIS_TREADY     (gen_tready)
//    );
    
    packet_gen #(
        .BUS_WIDTH(BUS_WIDTH)
    ) my_packet_gen(
        .clk    (clk_core),
        .rst_n  (rst_n),
        .start  (start_pulse),
        .gap_cycles(16'd10),
        
        .eth_type(16'h0800),
        .base_src_ip(32'h0a00011),
        .base_dst_ip(32'h0b234111),
        .base_src_port(16'h0880),
        .base_dst_port(16'h8080),
        .payload_len(16'd120),
        .payload_byte(8'h44),
        .done_gen(done),
        
        // AXI-Stream master interface
        .tdata      (gen_tdata),
        .tvalid     (gen_tvalid),
        .tlast      (gen_tlast),
        .tkeep      (gen_tkeep),
        .tready     (gen_tready)
    );
    
    packet_filter #(
        .BUS_WIDTH(BUS_WIDTH)
    ) u_packet_filter (
        .clk        (clk_core),
        .rst_n      (rst_n),
    
        // AXI-Stream slave (t? generator)
        .s_tdata    (gen_tdata),
        .s_tvalid   (gen_tvalid),
        .s_tlast    (gen_tlast),
        .s_tkeep    (gen_tkeep),
        .s_tready   (gen_tready),
    
        // AXI-Stream master (n?u c?n forward packet, hi?n t?i kh?ng d?ng ? tie ready)
        .m_tdata    (filt_tdata),
        .m_tvalid   (filt_tvalid),
        .m_tlast    (filt_tlast),
        .m_tkeep    (filt_tkeep),
        .m_tready   (filt_tready),
    
        // Metadata output (5-tuple)
        .meta_tvalid (key_valid),
        .src_ip      (key_src_ip),
        .dst_ip      (key_dst_ip),
        .src_port    (key_src_port),
        .dst_port    (key_dst_port),
        .protocol    (key_protocol)
        // done_fil
    );
    load_balancer_top #(
        .NUM_SERVERS (NUM_SERVERS),
        .SCN_WIDTH(SCN_WIDTH)
    ) u_core (
        .clk            (clk_core), // S?A: clk -> clk_core
        .rst_n          (rst_n),

        .i_src_ip       (key_src_ip),
        .i_dst_ip       (key_dst_ip),
        .i_src_port     (key_src_port),
        .i_dst_port     (key_dst_port),
        .i_protocol     (key_protocol),
        .i_key_valid    (key_valid),
        .key_fifo_full  (),

        .s_axis_tdata   (filt_tdata),
        .s_axis_tvalid  (filt_tvalid),
        .s_axis_tkeep   (filt_tkeep),
        .s_axis_tlast   (filt_tlast),
        .s_axis_tready  (filt_tready),

        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tlast   (m_axis_tlast),
        .m_axis_tkeep   (m_axis_tkeep),
        .m_axis_tready  (ready_shm2cslb),

        .cfg_algo_sel   (algo_sel),
//        .cfg_ip_list    ({32'hc0a8010a, 32'hc0a8010b, 32'hc0a8010c, 32'hc0a8010d}),
        .scn_inc_en     (scn_inc_en),
        .scn_server_idx (server_idx),
        // wire health_bitmap
        .health_bitmap(health_bitmap),
        .scn_dec_en(scn_dec_en),
        .scn_dec_idx(scn_dec_idx),
        
        .cslb_rd_en     (cslb_rd_en),
        .cslb_rd_ip     (cslb_rd_ip),
        .cslb_rd_scn    (cslb_rd_scn),
        .cslb_rd_valid  (cslb_rd_valid)
    );

    shm_top #(
    .NUM_SERVERS(NUM_SERVERS),
    .SERVER_ID_WIDTH($clog2(NUM_SERVERS)),
    .SCN_WIDTH(SCN_WIDTH),
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .TICK_MS(TICK_MS)
) u_shm_top (
    .clk    (clk_core),
    .rst_n  (rst_n),
    
    // =========================================================================
    // TX Path - To Backend Network
    // =========================================================================
    // User data t? CSLB (load balancer output)
    .tx_cslb_data(m_axis_tdata),
    .tx_cslb_valid(m_axis_tvalid),
    .tx_cslb_keep(m_axis_tkeep),
    .tx_cslb_last(m_axis_tlast),
    .tx_cslb_ready(ready_shm2cslb),
    
    // Combined output (user data + heartbeat packets)
    .tx_backend_data(tx_backend_data),
    .tx_backend_valid(tx_backend_valid),
    .tx_backend_keep(tx_backend_keep),
    .tx_backend_last(tx_backend_last),
    .tx_backend_ready(tx_backend_ready),
    
    // =========================================================================
    // RX Path - From Backend Network
    // =========================================================================
    .rx_backend_data(rx_backend_data),
    .rx_backend_valid(rx_backend_valid),
    .rx_backend_keep(rx_backend_keep),
    .rx_backend_last(rx_backend_last),
    .rx_backend_ready(rx_backend_ready),
    
    // User responses t?i CSLB
    .rx_cslb_data(),
    .rx_cslb_valid(),
    .rx_cslb_keep(),
    .rx_cslb_last(),
    .rx_cslb_ready(1'b1),
    
    // =========================================================================
    // CSLB Interface - SST Access
    // =========================================================================
    // CSLB write: Increment SCN when sending request
    .cslb_scn_inc_en(scn_inc_en),
    .cslb_server_idx(server_idx),
    
    // CSLB read: Get server info for load balancing
    .cslb_rd_en(cslb_rd_en),
    .cslb_rd_ip(cslb_rd_ip),
    .cslb_rd_scn(cslb_rd_scn),
    .cslb_rd_valid(cslb_rd_valid),
    // wire cslb_health_bitmatp
    .cslb_health_bitmap(health_bitmap),
    .cslb_health_update_valid(),
    
    .cslb_scn_dec_en(scn_dec_en),
    .cslb_server_dec_idx(scn_dec_idx),
    
    .server_ip_list(server_ip_list),
    .server_ip_list_valid(server_ip_list_valid)
);


master_server #(
    .NUM_SERVERS(NUM_SERVERS)
)
    u_server(
    .clk(clk_core),
    .rst_n(rst_n),
    .server_en(server_en_valid),
   // .resp_delay_bypass(algo_sel == 2'b10),

    // ================= INPUT: t? SHM =================
    .rx_user_data(tx_backend_data),
    .rx_user_keep(tx_backend_keep),
    .rx_user_valid(tx_backend_valid),
    .rx_user_last(tx_backend_last),
    .rx_user_ready(tx_backend_ready),

    // ================= OUTPUT: v? SHM =================
    .tx_user_data(rx_backend_data),
    .tx_user_keep(rx_backend_keep),
    .tx_user_valid(rx_backend_valid),
    .tx_user_last(rx_backend_last),
    .tx_user_ready(rx_backend_ready),
    
    .server_ip_list(server_ip_list),
    .server_ip_list_valid(server_ip_list_valid),
    
    .cnt_user_req_rx(cnt_user_req_rx),
    .cnt_hb_req_rx(cnt_hb_req_rx),
    .cnt_user_reply_tx(cnt_user_reply_tx),
    .cnt_hb_reply_tx(cnt_hb_reply_tx)
    );

endmodule