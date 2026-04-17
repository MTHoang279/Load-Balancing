`timescale 1ns / 1ps
module fpga_top#(
    parameter BUS_WIDTH = 512,
    parameter N_SERVERS = 4
)(
    // input  wire        clk_p,
    // input  wire        clk_n,   
    input wire         clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [2:0]  algo_sel,

    // User Request & Heartbeat Probe từ ngoài vào (Từ MAC/PHY)
    input  wire [511:0] rx_axis_tdata,
    input  wire [63:0]  rx_axis_tkeep,
    input  wire         rx_axis_tvalid,
    input  wire         rx_axis_tlast,
    output wire         rx_axis_tready,

    // User Request & Heartbeat Probe từ trong ra ngoài (Từ Load Balancer)
    output wire [511:0] tx_axis_tdata,
    output wire [63:0]  tx_axis_tkeep,
    output wire         tx_axis_tvalid,
    output wire         tx_axis_tlast,
    input  wire         tx_axis_tready,
    
    // Giao diện kết quả trả về cho User (đã lọc HB và trừ SCN)
    output wire [511:0] bypass_out_tdata,
    output wire [63:0]  bypass_out_tkeep,
    output wire         bypass_out_tvalid,
    output wire         bypass_out_tlast,
    input  wire         bypass_out_tready
);

    // ================= 4. KHAI BÁO DÂY KẾT NỐI NỘI BỘ =================
    
    // Generator -> Filter
    wire [BUS_WIDTH-1:0]        gen_tdata;
    wire                        gen_tvalid;
    wire                        gen_tlast;
    wire [BUS_WIDTH/8-1:0]      gen_tkeep;
    wire                        gen_tready;
    
    // Filter -> Load Balancer (User Path TX)
    wire [BUS_WIDTH-1:0]        filt_tdata;
    wire                        filt_tvalid;
    wire                        filt_tlast;
    wire [BUS_WIDTH/8-1:0]      filt_tkeep;
    wire                        filt_tready;
    
    // Filter -> Load Balancer (Metadata)
    wire  [31:0]  key_src_ip;
    wire  [31:0]  key_dst_ip;
    wire  [15:0]  key_src_port;
    wire  [15:0]  key_dst_port;
    wire  [7:0]   key_protocol;
    wire          key_valid;


    // ================= 5. INSTANTIATE CÁC MODULE CON =================
    
    net2axis_master #(
        
    ) u_packet_gen (
        .ACLK               (clk),
        .ARESETN            (rst_n),
        .START              (start),
        .M_AXIS_TDATA       (gen_tdata),
        .M_AXIS_TVALID      (gen_tvalid),
        .M_AXIS_TLAST       (gen_tlast),
        .M_AXIS_TKEEP       (gen_tkeep),
        .M_AXIS_TREADY      (gen_tready)
    );

    packet_filter #(
        .BUS_WIDTH(BUS_WIDTH)
    ) u_packet_filter (
        .clk         (clk),
        .rst_n       (rst_n),
        .s_tdata     (gen_tdata),
        .s_tvalid    (gen_tvalid),
        .s_tlast     (gen_tlast),
        .s_tkeep     (gen_tkeep),
        .s_tready    (gen_tready),
        .m_tdata     (filt_tdata),
        .m_tvalid    (filt_tvalid),
        .m_tlast     (filt_tlast),
        .m_tkeep     (filt_tkeep),
        .m_tready    (filt_tready),
        .meta_tvalid (key_valid),
        .src_ip      (key_src_ip),
        .dst_ip      (key_dst_ip),
        .src_port    (key_src_port),
        .dst_port    (key_dst_port),
        .protocol    (key_protocol)
    );

    // ==========================================================
    // INSTANTIATE MERGED LOAD BALANCER & SHM CORE
    // ==========================================================
    shm_cslb_merged_top #(
        .N_SERVERS(N_SERVERS)
    ) u_lb_core (
        .clk                 (clk),
        .rst_n               (rst_n),

        // --- GIAO DIỆN MẠNG VẬT LÝ ---
        // Nhận dữ liệu từ ngoài vào (Server Reply / Heartbeat Reply)
        .rx_net_tdata        (rx_axis_tdata),
        .rx_net_tkeep        (rx_axis_tkeep),
        .rx_net_tvalid       (rx_axis_tvalid),
        .rx_net_tlast        (rx_axis_tlast),
        .rx_net_tready       (rx_axis_tready),

        // Đẩy dữ liệu ra ngoài (User Request đã đổi IP / Heartbeat Probe)
        .tx_net_tdata        (tx_axis_tdata),
        .tx_net_tkeep        (tx_axis_tkeep),
        .tx_net_tvalid       (tx_axis_tvalid),
        .tx_net_tlast        (tx_axis_tlast),
        .tx_net_tready       (tx_axis_tready),

        // --- GIAO DIỆN VỚI GENERATOR / FILTER ---
        // Đẩy Request của User lên CSLB
        .i_src_ip            (key_src_ip),
        .i_dst_ip            (key_dst_ip),
        .i_src_port          (key_src_port),
        .i_dst_port          (key_dst_port),
        .i_protocol          (key_protocol),
        .i_key_valid         (key_valid),
        .key_fifo_full       (),

        .s_axis_tdata        (filt_tdata),
        .s_axis_tkeep        (filt_tkeep),
        .s_axis_tvalid       (filt_tvalid),
        .s_axis_tlast        (filt_tlast),
        .s_axis_tready       (filt_tready),

        // --- GIAO DIỆN KẾT QUẢ CHO USER ---
        // Gói tin từ Server trả về (đã lọc HB và trừ SCN) đẩy ra cho User
        .pathA_m_axis_tdata  (bypass_out_tdata),
        .pathA_m_axis_tkeep  (bypass_out_tkeep),
        .pathA_m_axis_tvalid (bypass_out_tvalid),
        .pathA_m_axis_tlast  (bypass_out_tlast),
        .pathA_m_axis_tready (bypass_out_tready),

        // --- CẤU HÌNH ---
        .cfg_algo_sel        (algo_sel)
    );

endmodule