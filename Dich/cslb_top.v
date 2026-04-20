module load_balancer_top #(
    parameter KEY_WIDTH   = 32,
    parameter MSG_WIDTH   = 512,
    parameter IP_WIDTH    = 32,
    parameter NUM_SERVERS = 4,
    parameter SCN_WIDTH   = 4
)(
    input  wire clk,
    input  wire rst_n, // Active Low Reset

    //================ Packet generator input ===================
    input  wire [31:0] i_src_ip,
    input  wire [31:0] i_dst_ip,
    input  wire [15:0] i_src_port,
    input  wire [15:0] i_dst_port,
    input  wire [7:0]  i_protocol,
    input  wire                      i_key_valid,
    output wire                      key_fifo_full,

    input  wire [MSG_WIDTH-1:0]      s_axis_tdata,
    input  wire                      s_axis_tvalid,
    input  wire [MSG_WIDTH/8-1:0]    s_axis_tkeep,
    input  wire                      s_axis_tlast,
    output wire                      s_axis_tready,

    //================ AXI stream output ========================
    output wire [MSG_WIDTH -1:0]         m_axis_tdata,
    output wire                          m_axis_tvalid,
    output wire                          m_axis_tlast,
    output wire [MSG_WIDTH/8-1:0]        m_axis_tkeep,
    input  wire                          m_axis_tready,

    //================ Config ============================
    input  wire [1:0]            cfg_algo_sel,
    output                       scn_inc_en,
    output wire [$clog2(NUM_SERVERS)-1:0]            scn_server_idx,
    input  wire [NUM_SERVERS-1:0]health_bitmap,
    input  wire                   scn_dec_en,
    input  wire [$clog2(NUM_SERVERS)-1:0]            scn_dec_idx,
    
    output wire                  cslb_rd_en,
    input  wire [NUM_SERVERS*IP_WIDTH-1:0]  cslb_rd_ip,
    input  wire [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,
    input  wire                  cslb_rd_valid
);

    //============================================================
    // 1. Reset Logic Fix
    //============================================================
    // Các module con (FIFO) dùng Reset m?c 1 (Active High)
    // Module Top dùng Reset m?c 0 (Active Low) -> C?n ??o bit

    //============================================================
    // Wires
    //============================================================

    // Key FIFO -> Algo;
//    wire [KEY_WIDTH-1:0] key_fifo_data;
    wire [31:0] key_src_ip;
    wire [31:0] key_dst_ip;
    wire [15:0] key_src_port;
    wire [15:0] key_dst_port;
    wire [7:0]  key_protocol;
    wire                 key_fifo_valid;
    
    // Algo -> Dst FIFO
    wire [IP_WIDTH-1:0]  dst_ip;
    wire                 dst_ip_valid;
    wire                 dst_fifo_full;

    // Dst FIFO -> Sync (KEY PATH)
    wire [IP_WIDTH-1:0]  sync_key_data;
    wire                 sync_key_empty;
    wire                 sync_key_valid; // FIX: Thêm dây này
    wire                 rd_sync_key;

    // Msg FIFO -> Sync (MSG PATH)
    wire [MSG_WIDTH-1:0]   msg_data;
    wire                   msg_last;
    wire [MSG_WIDTH/8-1:0] msg_keep;
    wire                   msg_empty;
    wire                   msg_fifo_valid; // FIX: Thêm dây này
    wire                   rd_msg_en;

    //============================================================
    // 2. KEY FIFO (Packet gen -> Algo)
    //============================================================
    key_fifo #(
    ) u_key_fifo (
        .clk        (clk),
        .rst_n      (rst_n),

        .i_src_ip   (i_src_ip),
        .i_dst_ip   (i_dst_ip),
        .i_src_port (i_src_port),
        .i_dst_port (i_dst_port),
        .i_protocol (i_protocol),
        .i_key_valid(i_key_valid),
        .o_full     (key_fifo_full),

        .o_src_ip   (key_src_ip),
        .o_dst_ip   (key_dst_ip),
        .o_src_port (key_src_port),
        .o_dst_port (key_dst_port),
        .o_protocol (key_protocol),
        .o_key_valid(key_fifo_valid),
        .o_ip_full  (dst_fifo_full)   // backpressure t? algo/dst_fifo
    );

//    assign key_fifo_data ={
//    key_src_ip,
//    key_dst_ip,
//    key_src_port,
//    key_dst_port,
//    key_protocol
//};
    //============================================================
    // 3. ALGORITHM SELECTOR
    //============================================================
    algorithm_selector #(
        .NUM_SERVERS(NUM_SERVERS),
        .SCN_WIDTH(SCN_WIDTH)
    ) u_algo_sel (
        .clock        (clk),
        .rst_n        (rst_n), // Module này dùng rst_n

//        .key_data     (key_fifo_data),
        .key_src_ip   (key_src_ip),
        .key_dst_ip   (key_dst_ip),
        .key_src_port (key_src_port),
        .key_dst_port (key_dst_port),
        .key_protocol (key_protocol),
        .key_valid    (key_fifo_valid),
        .o_ip_full    (), 

        .i_ip_full    (dst_fifo_full),
        .wr_data      (dst_ip),
        .wr_valid     (dst_ip_valid),

        .cfg_algo_sel (cfg_algo_sel),
        
        .health_bitmap(health_bitmap),
        .scn_inc_en   (scn_inc_en),
        .scn_server_idx   (scn_server_idx),
        .scn_dec_en(scn_dec_en),
        .scn_dec_idx(scn_dec_idx),
        
        
        .cslb_rd_en     (cslb_rd_en),
        .cslb_rd_ip  (cslb_rd_ip),
        .cslb_rd_scn    (cslb_rd_scn),
        .cslb_rd_valid  (cslb_rd_valid)
    );

    //============================================================
    // 4. DST FIFO (Algo -> Sync)
    //============================================================
    dst_fifo #(
        .WIDTH(IP_WIDTH)
    ) u_dst_fifo (
        .clk       (clk),
        .rst_n     (rst_n),

        .wr_data   (dst_ip),
        .wr_valid  (dst_ip_valid),
        .o_full    (dst_fifo_full),

        .rd_data   (sync_key_data),
        .rd_valid  (sync_key_valid),    // FIX: N?i dây valid vào ?ây
        .o_empty   (sync_key_empty),
        .rd_key_en (rd_sync_key)
    );

    //============================================================
    // 5. MSG FIFO (Packet gen -> Sync)
    //============================================================
    msg_fifo u_msg_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tkeep  (s_axis_tkeep),
        .s_axis_tlast  (s_axis_tlast),
        .s_axis_tready (s_axis_tready),

        .msg_data      (msg_data),
        .msg_valid     (msg_fifo_valid), // FIX: N?i dây valid vào ?ây
        .msg_last      (msg_last),
        .msg_keep      (msg_keep),
        .o_empty       (msg_empty),
        .rd_msg_en     (rd_msg_en)
    );

    //============================================================
    // 6. SYNC LOGIC (Ghép MSG + DST IP)
    //============================================================
    sync_logic #(
        .MSG_WIDTH (MSG_WIDTH),
        .KEY_WIDTH (IP_WIDTH)
    ) u_sync_logic (
        .clk           (clk),
        .rst_n         (rst_n),

        // Key Path Connection
        .key_data      (sync_key_data),
        .key_empty     (sync_key_empty),
        .key_valid     (sync_key_valid), // FIX: ?ã có tín hi?u t? dst_fifo
        .rd_key_en     (rd_sync_key),

        // Msg Path Connection
        .msg_data      (msg_data),
        .msg_last      (msg_last),
        .msg_valid     (msg_fifo_valid), // FIX: ?ã có tín hi?u t? msg_fifo
        .msg_keep      (msg_keep),
        .msg_empty     (msg_empty),
        .rd_msg_en     (rd_msg_en),

        // Output Connection
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tlast  (m_axis_tlast),
        .m_axis_tkeep  (m_axis_tkeep),
        .m_axis_tready (m_axis_tready)
    );

endmodule