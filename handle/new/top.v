module fpga_top#(
    parameter BUS_WIDTH = 512,
    parameter INPUTFILE = "",
    parameter CLK_FREQ_HZ = 1000,
    parameter TICK_MS = 10,
    parameter SCN_WIDTH = 16,
    parameter NUM_SERVERS = 16
)(
    input  wire        clk_p,
    input  wire        clk_n,    
    input  wire        rst_in,     // N?t nh?n GPIO_SW_N (Active High)
    (* mark_debug = "true" *) input  wire        start,      // Asynchronous Input
    (* mark_debug = "true" *) input  wire [2:0]  algo_sel,
//    input  wire        loop_en,
    output wire        done       // flag done read pcap
);
    (* mark_debug = "true" *) wire [NUM_SERVERS*15-1:0] cnt_user_req_rx;
    (* mark_debug = "true" *) wire [NUM_SERVERS*15-1:0] cnt_hb_req_rx;
    (* mark_debug = "true" *) wire [NUM_SERVERS*15-1:0] cnt_user_reply_tx;
    (* mark_debug = "true" *) wire [NUM_SERVERS*15-1:0] cnt_hb_reply_tx;
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
    wire                        gen_tvalid;
    wire                        gen_tlast;
    wire [BUS_WIDTH/8-1:0]      gen_tkeep;
    wire                        gen_tready;
    
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
    wire  [1:0]                 server_idx;  // idx comes with scn increment
    wire                        ready_shm2cslb;
    wire                        cslb_rd_en;  // tin hieu tu cslb yeu cau gui danh sach dia chi ip va trang thai ket noi cua server 
    
    wire  [NUM_SERVERS*32-1:0]  cslb_rd_ip;
    wire  [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn;
    wire                        cslb_rd_valid;
     
    wire  [NUM_SERVERS-1:0]     health_bitmap;
    wire                        scn_dec_en;
    wire  [1:0]                 scn_dec_idx; 
    
    // input from backend to cslb 
    wire [511:0]  rx_backend_data;
    wire [63:0]   rx_backend_keep;
    wire          rx_backend_valid;
    wire          rx_backend_last;
    wire          rx_backend_ready;
    
        //output 
    wire [BUS_WIDTH -1:0]       tx_backend_data;
    wire [BUS_WIDTH/8-1:0]      tx_backend_keep;
    wire                        tx_backend_last;
    wire                        tx_backend_valid;
    wire                        tx_backend_ready;     // tready t? sync FIFO 

    // ================= START SYNCHRONIZER =================
    reg start_r1, start_r2;
    wire start_pulse;


    // ================= Core =====================
    wire [511:0] m_axis_tdata;
    wire         m_axis_tvalid;
    wire         m_axis_tlast;
    wire [63:0]  m_axis_tkeep;
    
    net2axis_master #(
        .TDATA_WIDTH(BUS_WIDTH),
        .INPUTFILE(INPUTFILE)
    ) u_packet_gen (
        .ACLK        (clk_core),
        .ARESETN      (rst_n),
        .START      (start),
        .DONE       (done),
    
        // AXI-Stream master interface
        .M_AXIS_TDATA      (gen_tdata),
        .M_AXIS_TVALID     (gen_tvalid),
        .M_AXIS_TLAST      (gen_tlast),
        .M_AXIS_TKEEP      (gen_tkeep),
        .M_AXIS_TREADY     (gen_tready)
    );
    
//    packet_gen #(
//        .BUS_WIDTH(BUS_WIDTH)
//    ) my_packet_gen(
//        .clk    (clk_core),
//        .rst_n  (rst_n),
//        .start  (start),
//        .loop_en(loop_en),
//        .gap_cycles(16'd10),
        
//        .eth_type(16'h0800),
//        .base_src_ip(32'haaaaa111),
//        .base_dst_ip(32'hbbbbb111),
//        .base_src_port(16'h0880),
//        .base_dst_port(16'h8080),
//        .payload_len(16'd120),
//        .payload_byte(8'h44),
        
//        // AXI-Stream master interface
//        .tdata      (gen_tdata),
//        .tvalid     (gen_tvalid),
//        .tlast      (gen_tlast),
//        .tkeep      (gen_tkeep),
//        .tready     (gen_tready)
//    );
    
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
    );
    load_balancer_top #(
        .NUM_SERVERS (NUM_SERVERS)
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
        .health_bitmap({NUM_SERVERS{1'b1}}),
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
    (* mark_debug = "true" *).tx_backend_data(tx_backend_data),
    (* mark_debug = "true" *).tx_backend_valid(tx_backend_valid),
    (* mark_debug = "true" *).tx_backend_keep(tx_backend_keep),
    (* mark_debug = "true" *).tx_backend_last(tx_backend_last),
    (* mark_debug = "true" *).tx_backend_ready(tx_backend_ready),
    
    // =========================================================================
    // RX Path - From Backend Network
    // =========================================================================
    (* mark_debug = "true" *).rx_backend_data(rx_backend_data),
    (* mark_debug = "true" *).rx_backend_valid(rx_backend_valid),
    (* mark_debug = "true" *).rx_backend_keep(rx_backend_keep),
    (* mark_debug = "true" *).rx_backend_last(rx_backend_last),
    (* mark_debug = "true" *).rx_backend_ready(rx_backend_ready),
    
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
    
    .cslb_health_bitmap(),
    .cslb_health_update_valid(),
    
    .cslb_scn_dec_en(scn_dec_en),
    .cslb_server_dec_idx(scn_dec_idx)
);

//server_auto_responder #(
//    .N_SERVERS(NUM_SERVERS)
//)
//    u_server(
//    .clk(clk_core),
//    .rst_n(rst_n),
//    .server_en(4'b1111),

//    // ================= INPUT: t? SHM =================
//    .rx_tdata(tx_backend_data),
//    .rx_tkeep(tx_backend_keep),
//    .rx_tvalid(tx_backend_valid),
//    .rx_tlast(tx_backend_last),
//    .rx_tready(tx_backend_ready),

//    // ================= OUTPUT: v? SHM =================
//    .tx_tdata(rx_backend_data),
//    .tx_tkeep(rx_backend_keep),
//    .tx_tvalid(rx_backend_valid),
//    .tx_tlast(rx_backend_last),
//    .tx_tready(rx_backend_ready)
    
//    );

master_server #(
    .NUM_SERVERS(NUM_SERVERS)
)
    u_server(
    .clk(clk_core),
    .rst_n(rst_n),

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
    
    .cnt_user_req_rx(cnt_user_req_rx),
    .cnt_hb_req_rx(cnt_hb_req_rx),
    .cnt_user_reply_tx(cnt_user_reply_tx),
    .cnt_hb_reply_tx(cnt_hb_reply_tx)
    );

endmodule