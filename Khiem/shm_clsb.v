`timescale 1ns / 1ps
module shm_cslb_merged_top #(
    // --- CSLB Parameters ---
    parameter KEY_WIDTH     = 128,
    parameter MSG_WIDTH     = 512,
    parameter IP_WIDTH      = 32,
    parameter N_SERVERS     = 4,
    parameter SRC_IP_OFFSET = 0, // Vị trí byte của Source IP trong gói tin trả về
    
    // --- SHM Parameters ---
    parameter SERVER_ID_W   = $clog2(N_SERVERS),
    parameter CLK_FREQ_HZ   = 322_000_000,
    parameter LB_IP         = 32'hC0A80001,
    parameter BROADCAST_IP  = 32'hFFFFFFFF,
    parameter HB_SRC_PORT   = 16'd9000,
    parameter HB_DST_PORT   = 16'd9001,
    parameter SCN_W         = 16
)(
    input  wire clk,
    input  wire rst_n, // Active Low Reset

    // =========================================================================
    // 1. GIAO DIỆN VỚI MẠNG BÊN NGOÀI (PHYSICAL/MAC LEVEL)
    // =========================================================================
    // Luồng RX: Nhận gói tin từ mạng (Bao gồm cả User Reply và Heartbeat Reply)
    input  wire [511:0] rx_net_tdata,
    input  wire [63:0]  rx_net_tkeep,
    input  wire         rx_net_tvalid,
    input  wire         rx_net_tlast,
    output wire         rx_net_tready,

    // Luồng TX: Đẩy gói tin ra mạng (Bao gồm User Request đã đổi IP và Heartbeat Req)
    output wire [511:0] tx_net_tdata,
    output wire [63:0]  tx_net_tkeep,
    output wire         tx_net_tvalid,
    output wire         tx_net_tlast,
    input  wire         tx_net_tready,

    // =========================================================================
    // 2. GIAO DIỆN VỚI USER / PACKET GENERATOR (ĐẨY REQUEST LÊN SERVER)
    // =========================================================================
    // Metadata (Key)
    input  wire [31:0]  i_src_ip,
    input  wire [31:0]  i_dst_ip,
    input  wire [15:0]  i_src_port,
    input  wire [15:0]  i_dst_port,
    input  wire [7:0]   i_protocol,
    input  wire         i_key_valid,
    output wire         key_fifo_full,

    // Payload (Data)
    input  wire [MSG_WIDTH-1:0]   s_axis_tdata,
    input  wire [MSG_WIDTH/8-1:0] s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    input  wire                   s_axis_tlast,
    output wire                   s_axis_tready,

    // =========================================================================
    // 3. GIAO DIỆN TRẢ RESULT CHO USER (NHẬN TỪ SERVER TRẢ VỀ) - PATH A
    // =========================================================================
    output wire [511:0] pathA_m_axis_tdata,
    output wire [63:0]  pathA_m_axis_tkeep,
    output wire         pathA_m_axis_tvalid,
    output wire         pathA_m_axis_tlast,
    input  wire         pathA_m_axis_tready,

    // =========================================================================
    // 4. CONFIGURATION
    // =========================================================================
    input  wire [2:0]   cfg_algo_sel
);

    // =========================================================================
    // KHAI BÁO CÁC ĐƯỜNG DÂY KẾT NỐI NỘI BỘ (INTERNAL INTERCONNECTS)
    // =========================================================================
    
    // --- 1. Dây Trạng Thái Server (SST) ---
    wire [N_SERVERS*32-1:0] sst_ip_list;
    wire [N_SERVERS*SCN_W-1:0] sst_scn_list; 
    wire [N_SERVERS-1:0]    sst_status_list;

    // --- 2. Dây Cập nhật SCN ---
    wire [SERVER_ID_W-1:0]  lb_scn_idx_tx;
    wire                    lb_scn_opcode_tx;
    wire  [SERVER_ID_W-1:0]  lb_scn_idx_rx;
    wire                     lb_scn_opcode_rx;

    // --- 3. Dây định tuyến AXI-Stream ---
    // Từ Parser -> RX Snooper
    wire [511:0] rx_cslb_tdata;
    wire [63:0]  rx_cslb_tkeep;
    wire         rx_cslb_tvalid;
    wire         rx_cslb_tlast;
    wire         rx_cslb_tready;

    // Từ Sync Logic -> Arbiter
    wire [511:0] tx_cslb_tdata;
    wire [63:0]  tx_cslb_tkeep;
    wire         tx_cslb_tvalid;
    wire         tx_cslb_tlast;
    wire         tx_cslb_tready;

    // Các luồng Heartbeat nội bộ
    wire [511:0] w_hb_rx_tdata, w_hb_tx_tdata;
    wire [63:0]  w_hb_rx_tkeep, w_hb_tx_tkeep;
    wire         w_hb_rx_tvalid, w_hb_rx_tlast, w_hb_rx_tready;
    wire         w_hb_tx_tvalid, w_hb_tx_tlast, w_hb_tx_tready;

    // Dây cập nhật máu từ Heartbeat Checker -> SST
    wire [1:0]             w_hlth_upd_opcode;
    wire [SERVER_ID_W-1:0] w_hlth_upd_idx;
    wire [31:0]            w_hlth_upd_ip;

    // Timer
    wire w_tick_1s, w_tick_10s;

    // CSLB Internal Data Path
    wire [31:0] key_src_ip, key_dst_ip;
    wire [15:0] key_src_port, key_dst_port;
    wire [7:0]  key_protocol;
    wire        key_fifo_valid;
    
    wire [IP_WIDTH-1:0]  dst_ip;
    wire                 dst_ip_valid;
    wire                 dst_fifo_full;

    wire [IP_WIDTH-1:0]  sync_key_data;
    wire                 sync_key_empty;
    wire                 sync_key_valid;
    wire                 rd_sync_key;

    wire [MSG_WIDTH-1:0]   msg_data;
    wire                   msg_last;
    wire [MSG_WIDTH/8-1:0] msg_keep;
    wire                   msg_empty;
    wire                   msg_fifo_valid;
    wire                   rd_msg_en;

    // =========================================================================
    // PHẦN I: KHỐI QUẢN LÝ MÁU VÀ TRẠNG THÁI SERVER (SHM)
    // =========================================================================

    shm_timer #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_timer (
        .clk(clk), .rst_n(rst_n),
        .tick_1s(w_tick_1s), .tick_10s(w_tick_10s)
    );

    shm_parser #(.N_SERVERS(N_SERVERS), .SERVER_ID_W(SERVER_ID_W)) u_parser (
        .clk(clk), .rst_n(rst_n),
        .rx_tdata(rx_net_tdata), .rx_tkeep(rx_net_tkeep), .rx_tvalid(rx_net_tvalid), .rx_tlast(rx_net_tlast), .rx_tready(rx_net_tready),
        .user_tdata(rx_cslb_tdata), .user_tkeep(rx_cslb_tkeep), .user_tvalid(rx_cslb_tvalid), .user_tlast(rx_cslb_tlast), .user_tready(rx_cslb_tready),
        .hb_resp_tdata(w_hb_rx_tdata), .hb_resp_tkeep(w_hb_rx_tkeep), .hb_resp_tvalid(w_hb_rx_tvalid), .hb_resp_tlast(w_hb_rx_tlast), .hb_resp_tready(w_hb_rx_tready)
    );

    heartbeat_checker_pipelined #(.N_SERVERS(N_SERVERS), .SERVER_ID_W(SERVER_ID_W)) u_hb_checker (
        .clk(clk), .rst_n(rst_n),
        .s_axis_tdata(w_hb_rx_tdata), .s_axis_tkeep(w_hb_rx_tkeep), .s_axis_tlast(w_hb_rx_tlast), .s_axis_tvalid(w_hb_rx_tvalid), .s_axis_tready(w_hb_rx_tready),
        .tick_10s(w_tick_10s),
        .health_update_opcode(w_hlth_upd_opcode), .health_update_idx(w_hlth_upd_idx), .health_update_ip(w_hlth_upd_ip)
    );

    sst_controller #(.N_SERVERS(N_SERVERS), .SERVER_ID_W(SERVER_ID_W)) u_sst_controller (
        .clk(clk), .rst_n(rst_n),
        .shm_update_opcode(w_hlth_upd_opcode), .shm_update_idx(w_hlth_upd_idx), .shm_update_ip(w_hlth_upd_ip),
        .cslb_ip_list_o(sst_ip_list), .cslb_scn_list_o(sst_scn_list), .cslb_status_list_o(sst_status_list),
        .cslb_scn_idx_tx(lb_scn_idx_tx), .cslb_scn_opcode_tx(lb_scn_opcode_tx),
        .cslb_scn_idx_rx(lb_scn_idx_rx), .cslb_scn_opcode_rx(lb_scn_opcode_rx)
    );

    heartbeat_gen #(.LB_IP(LB_IP), .BROADCAST_IP(BROADCAST_IP), .HB_SRC_PORT(HB_SRC_PORT), .HB_DST_PORT(HB_DST_PORT)) u_hb_gen (
        .clk(clk), .rst_n(rst_n), .tick_1s(w_tick_1s),
        .hb_tdata(w_hb_tx_tdata), .hb_tkeep(w_hb_tx_tkeep), .hb_tvalid(w_hb_tx_tvalid), .hb_tlast(w_hb_tx_tlast), .hb_tready(w_hb_tx_tready)
    );

    shm_arbiter u_arbiter (
        .clk(clk), .rst_n(rst_n),
        .cslb_tdata(tx_cslb_tdata), .cslb_tkeep(tx_cslb_tkeep), .cslb_tvalid(tx_cslb_tvalid), .cslb_tlast(tx_cslb_tlast), .cslb_tready(tx_cslb_tready),
        .hb_tdata(w_hb_tx_tdata), .hb_tkeep(w_hb_tx_tkeep), .hb_tvalid(w_hb_tx_tvalid), .hb_tlast(w_hb_tx_tlast), .hb_tready(w_hb_tx_tready),
        .tx_tdata(tx_net_tdata), .tx_tkeep(tx_net_tkeep), .tx_tvalid(tx_net_tvalid), .tx_tlast(tx_net_tlast), .tx_tready(tx_net_tready)
    );

    // =========================================================================
    // PHẦN II: KHỐI CÂN BẰNG TẢI (CSLB)
    // =========================================================================

    key_fifo u_key_fifo (
        .clk(clk), .rst_n(rst_n),
        .i_src_ip(i_src_ip), .i_dst_ip(i_dst_ip), .i_src_port(i_src_port), .i_dst_port(i_dst_port), .i_protocol(i_protocol), .i_key_valid(i_key_valid),
        .o_full(key_fifo_full),
        .o_src_ip(key_src_ip), .o_dst_ip(key_dst_ip), .o_src_port(key_src_port), .o_dst_port(key_dst_port), .o_protocol(key_protocol), .o_key_valid(key_fifo_valid),
        .o_ip_full(dst_fifo_full)
    );

    algorithm_selector #(.N_SERVERS(N_SERVERS)) u_algo_sel (
        .clock(clk), .rst_n(rst_n),
        .key_src_ip(key_src_ip), .key_dst_ip(key_dst_ip), .key_src_port(key_src_port), .key_dst_port(key_dst_port), .key_protocol(key_protocol),
        .key_valid(key_fifo_valid), .o_ip_full(), .i_ip_full(dst_fifo_full),
        .wr_data(dst_ip), .wr_valid(dst_ip_valid),
        .cfg_algo_sel(cfg_algo_sel), 
        .cfg_ip_list(sst_ip_list), .i_scn(sst_scn_list), .i_status(sst_status_list), // Nhận từ SST
        .cslb_scn_idx_tx(lb_scn_idx_tx), .cslb_scn_opcode_tx(lb_scn_opcode_tx)       // Gửi lệnh +1 SCN
    );

    dst_fifo #(.WIDTH(IP_WIDTH)) u_dst_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_data(dst_ip), .wr_valid(dst_ip_valid), .o_full(dst_fifo_full),
        .rd_data(sync_key_data), .rd_valid(sync_key_valid), .o_empty(sync_key_empty), .rd_key_en(rd_sync_key)
    );

    msg_fifo u_msg_fifo (
        .clk(clk), .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid), .s_axis_tkeep(s_axis_tkeep), .s_axis_tlast(s_axis_tlast), .s_axis_tready(s_axis_tready),
        .msg_data(msg_data), .msg_valid(msg_fifo_valid), .msg_last(msg_last), .msg_keep(msg_keep), .o_empty(msg_empty), .rd_msg_en(rd_msg_en)
    );

    sync_logic #(.MSG_WIDTH(MSG_WIDTH), .KEY_WIDTH(IP_WIDTH)) u_sync_logic (
        .clk(clk), .rst_n(rst_n),
        .key_data(sync_key_data), .key_empty(sync_key_empty), .key_valid(sync_key_valid), .rd_key_en(rd_sync_key),
        .msg_data(msg_data), .msg_last(msg_last), .msg_valid(msg_fifo_valid), .msg_keep(msg_keep), .msg_empty(msg_empty), .rd_msg_en(rd_msg_en),
        .cslb_tdata(tx_cslb_tdata), .cslb_tvalid(tx_cslb_tvalid), .cslb_tlast(tx_cslb_tlast), .cslb_tkeep(tx_cslb_tkeep), .cslb_tready(tx_cslb_tready) // Đẩy thẳng ra Arbiter
    );

    // =========================================================================
    // PHẦN III: RX SNOOPER (BÓC TÁCH IP SERVER ĐỂ GIẢM SCN) VÀ FORWARD PATH A
    // =========================================================================

    // Forward trực tiếp luồng mạng trả về ra ngoài cho User
    // assign pathA_m_axis_tdata  = rx_cslb_tdata;
    // assign pathA_m_axis_tkeep  = rx_cslb_tkeep;
    // assign pathA_m_axis_tvalid = rx_cslb_tvalid;
    // assign pathA_m_axis_tlast  = rx_cslb_tlast;
    // assign rx_cslb_tready      = pathA_m_axis_tready;


// ============================================================
// Forward data
// ============================================================

assign pathA_m_axis_tdata  = rx_cslb_tdata;
assign pathA_m_axis_tkeep  = rx_cslb_tkeep;
assign pathA_m_axis_tlast  = rx_cslb_tlast;
assign pathA_m_axis_tvalid = w_hb_rx_tvalid ? 1'b0 : rx_cslb_tvalid;
assign rx_cslb_tready      = pathA_m_axis_tready;


// ============================================================
// Extract server IP
// ============================================================
localparam [31:0] BASE_IP_ADDRESS = 32'hC0A8010A; // 192.168.1.10
wire [31:0] rx_src_ip;
assign rx_src_ip = pathA_m_axis_tdata[31:0];


// ============================================================
// Opcode generation (combinational, no delay)
// ============================================================





// // Opcode: valid nếu IP nằm trong dải BASE_IP_ADDRESS .. BASE_IP_ADDRESS+N_SERVERS-1
// assign lb_scn_opcode_rx = pathA_m_axis_tvalid && (rx_src_ip >= BASE_IP_ADDRESS) && (rx_src_ip < BASE_IP_ADDRESS + N_SERVERS);

// // Index decode: lấy offset từ BASE_IP_ADDRESS
// assign lb_scn_idx_rx = rx_src_ip - BASE_IP_ADDRESS;
// Thay combinational assign bằng registered version
reg         lb_scn_opcode_rx_r;
reg [SERVER_ID_W-1:0] lb_scn_idx_rx_r;

wire scn_ip_in_range;
assign scn_ip_in_range =
       (rx_src_ip >= BASE_IP_ADDRESS) &&
       (rx_src_ip <  BASE_IP_ADDRESS + N_SERVERS);

always @(posedge clk) begin
    if (!rst_n) begin
        lb_scn_opcode_rx_r <= 1'b0;
        lb_scn_idx_rx_r    <= {SERVER_ID_W{1'b0}};
    end else begin
        lb_scn_opcode_rx_r <= pathA_m_axis_tvalid && scn_ip_in_range;

        if (pathA_m_axis_tvalid && scn_ip_in_range)
            lb_scn_idx_rx_r <= rx_src_ip - BASE_IP_ADDRESS;
    end
end

assign lb_scn_opcode_rx = lb_scn_opcode_rx_r;
assign lb_scn_idx_rx    = lb_scn_idx_rx_r;

endmodule