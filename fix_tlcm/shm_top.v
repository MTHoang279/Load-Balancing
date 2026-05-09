//module shm_top #(
//    parameter NUM_SERVERS     = 16,
//    parameter SERVER_ID_WIDTH = 4,
//    parameter SCN_WIDTH       = 12,
//    parameter CLK_FREQ_HZ     = 156_250_000,
//    parameter TICK_MS         = 10
//)(
//    input  wire clk,
//    input  wire rst_n,

//    // TX Path
//    input  wire [511:0] tx_cslb_data,
//    input  wire [63:0]  tx_cslb_keep,
//    input  wire         tx_cslb_last,
//    input  wire         tx_cslb_valid,
//    output wire         tx_cslb_ready,

//    output wire [511:0] tx_backend_data,
//    output wire [63:0]  tx_backend_keep,
//    output wire         tx_backend_last,
//    output wire         tx_backend_valid,
//    input  wire         tx_backend_ready,

//    // RX Path
//    input  wire [511:0] rx_backend_data,
//    input  wire [63:0]  rx_backend_keep,
//    input  wire         rx_backend_last,
//    input  wire         rx_backend_valid,
//    output wire         rx_backend_ready,

//    output wire [511:0] rx_cslb_data,
//    output wire [63:0]  rx_cslb_keep,
//    output wire         rx_cslb_last,
//    output wire         rx_cslb_valid,
//    input  wire         rx_cslb_ready,

//    // CSLB Interface
//    input  wire                        cslb_scn_inc_en,
//    input  wire [SERVER_ID_WIDTH-1:0]  cslb_server_idx,

//    input  wire                        cslb_rd_en,
//    output wire [NUM_SERVERS*32-1:0]       cslb_rd_ip,
//    output wire [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,
//    output wire                        cslb_rd_valid,

//    output wire [NUM_SERVERS-1:0]      cslb_health_bitmap,
//    output wire                        cslb_health_update_valid,

//    // CSLB SCN dec notification (registered 1-cycle pulse from parser)
//    output wire                        cslb_scn_dec_en,
//    output wire [SERVER_ID_WIDTH-1:0]  cslb_server_dec_idx,
    
//    input wire [NUM_SERVERS*32-1:0]   server_ip_list,
//    input wire                        server_ip_list_valid
//);

//    // =========================================================================
//    // Internal Signals
//    // =========================================================================

//    // Timer outputs
//    wire heartbeat_gen_trigger;
//    wire heartbeat_checker_trigger;

//    // Heartbeat generator -> arbiter
//    wire [511:0] hb_pkt_data;
//    wire         hb_pkt_valid;
//    wire         hb_pkt_ready;

//    // Parser outputs
//    wire                       parser_response_valid;
//    wire [SERVER_ID_WIDTH-1:0] parser_server_id;
//    wire                       parser_response_ready;
//    wire                       sst_scn_dec_en;
//    wire [SERVER_ID_WIDTH-1:0] sst_server_idx;
//    wire                       parser_scn_dec_en;
//    wire [SERVER_ID_WIDTH-1:0] parser_server_dec_idx;

//    // Heartbeat checker -> SST controller
//    wire                       sst_health_update_valid;
//    wire [NUM_SERVERS-1:0]     sst_health_update_bitmap;

//    // SST controller -> reg file
//    wire                       sst_wr_en;
//    wire [SERVER_ID_WIDTH-1:0] sst_wr_addr;
//    wire [31:0]                sst_wr_ip;
//    wire                       sst_wr_health;
//    wire [SCN_WIDTH-1:0]       sst_wr_scn;

//    // Reg file read port 1 (controller internal)
//    wire [SERVER_ID_WIDTH-1:0] sst_rd_addr;
//    wire [31:0]                sst_rd_ip;
//    wire [SCN_WIDTH-1:0]       sst_rd_scn;

//    // Reg file read port 2 (CSLB broadcast - all servers, combinatorial)
//    wire [NUM_SERVERS*32-1:0]        sst_cslb_rd_ip;
//    wire [NUM_SERVERS*SCN_WIDTH-1:0] sst_cslb_rd_scn;

//    // Controller CSLB snapshot outputs (registered, valid=1 cung cycle)
//    wire [NUM_SERVERS*32-1:0]        sst_ctrl_rd_ip;
//    wire [NUM_SERVERS*SCN_WIDTH-1:0] sst_ctrl_rd_scn;

//    // Health bitmap
//    wire [NUM_SERVERS-1:0]     sst_health_bitmap;
//    wire [NUM_SERVERS-1:0]     cslb_health_bitmap_wire;

//    // =========================================================================
//    // CSLB Outputs
//    // =========================================================================
//    // cslb_rd_ip/scn dung registered snapshot tu controller
//    // (khong dung truc tiep sst_cslb_rd_ip/scn vi do la combinatorial,
//    //  co the thay doi ngay ca khi cslb_rd_valid chua len, gay race condition)
//    assign cslb_rd_ip              = sst_ctrl_rd_ip;
//    assign cslb_rd_scn             = sst_ctrl_rd_scn;
//    assign cslb_health_bitmap      = cslb_health_bitmap_wire;
//    assign cslb_health_update_valid = sst_ctrl_health_update_valid;
//    assign cslb_scn_dec_en         = parser_scn_dec_en;
//    assign cslb_server_dec_idx     = parser_server_dec_idx;

//    // cslb_health_update_valid: driven directly from sst_controller
//    // (1-cycle pulse cung the nao voi cslb_health_bitmap NBA update)
//    wire sst_ctrl_health_update_valid;

//    // =========================================================================
//    // 1. SHM Timer
//    // =========================================================================
//    shm_timer #(
//        .CLK_FREQ_HZ(CLK_FREQ_HZ),
//        .TICK_MS    (TICK_MS)
//    ) u_shm_timer (
//        .clk                    (clk),
//        .rst_n                  (rst_n),
//        .heartbeat_gen_trigger  (heartbeat_gen_trigger),
//        .heartbeat_checker_trigger(heartbeat_checker_trigger)
//    );

//    // =========================================================================
//    // 2. Heartbeat Generator
//    // =========================================================================
//    heartbeat_generator u_heartbeat_generator (
//        .clk       (clk),
//        .rst_n     (rst_n),
//        .trigger   (heartbeat_gen_trigger),
//        .pkt_data  (hb_pkt_data),
//        .pkt_valid (hb_pkt_valid),
//        .pkt_ready (hb_pkt_ready),
//        .timestamp (64'h0)
//    );

//    // =========================================================================
//    // 3. SHM Arbiter
//    // =========================================================================
//    shm_arbiter u_shm_arbiter (
//        .clk          (clk),
//        .rst_n        (rst_n),
//        .tx_cslb_data (tx_cslb_data),
//        .tx_cslb_keep (tx_cslb_keep),
//        .tx_cslb_last (tx_cslb_last),
//        .tx_cslb_valid(tx_cslb_valid),
//        .tx_cslb_ready(tx_cslb_ready),
//        .hb_pkt_data  (hb_pkt_data),
//        .hb_pkt_valid (hb_pkt_valid),
//        .hb_pkt_ready (hb_pkt_ready),
//        .tx_user_data (tx_backend_data),
//        .tx_user_keep (tx_backend_keep),
//        .tx_user_last (tx_backend_last),
//        .tx_user_valid(tx_backend_valid),
//        .tx_user_ready(tx_backend_ready)
//    );

//    // =========================================================================
//    // 4. SHM Parser
//    // =========================================================================
//    shm_parser #(
//        .SERVER_ID_WIDTH(SERVER_ID_WIDTH),
//        .HEARTBEAT_PORT (16'd8888)
//    ) u_shm_parser (
//        .clk                  (clk),
//        .rst_n                (rst_n),
//        .rx_user_data         (rx_backend_data),
//        .rx_user_keep         (rx_backend_keep),
//        .rx_user_last         (rx_backend_last),
//        .rx_user_valid        (rx_backend_valid),
//        .rx_user_ready        (rx_backend_ready),
//        .rx_cslb_data         (rx_cslb_data),
//        .rx_cslb_keep         (rx_cslb_keep),
//        .rx_cslb_last         (rx_cslb_last),
//        .rx_cslb_valid        (rx_cslb_valid),
//        .rx_cslb_ready        (rx_cslb_ready),
//        .sst_scn_dec_en       (sst_scn_dec_en),
//        .sst_server_idx       (sst_server_idx),
//        .scn_dec_en           (parser_scn_dec_en),
//        .server_idx           (parser_server_dec_idx),
//        .parser_response_valid(parser_response_valid),
//        .parser_server_id     (parser_server_id),
//        .parser_response_ready(parser_response_ready)
//    );

//    // =========================================================================
//    // 5. Heartbeat Checker
//    // =========================================================================
//    heartbeat_checker #(
//        .NUM_SERVERS    (NUM_SERVERS),
//        .SERVER_ID_WIDTH(SERVER_ID_WIDTH)
//    ) u_heartbeat_checker (
//        .clk                    (clk),
//        .rst_n                  (rst_n),
//        .trigger                (heartbeat_checker_trigger),
//        .parser_response_valid  (parser_response_valid),
//        .parser_server_id       (parser_server_id),
//        .parser_response_ready  (parser_response_ready),
//        .sst_health_update_valid(sst_health_update_valid),
//        .sst_health_update_bitmap(sst_health_update_bitmap)
//    );

//    // =========================================================================
//    // 6. SST Controller
//    // =========================================================================
//    sst_controller #(
//        .NUM_SERVERS    (NUM_SERVERS),
//        .SERVER_ID_WIDTH(SERVER_ID_WIDTH),
//        .SCN_WIDTH      (SCN_WIDTH)
//    ) u_sst_controller (
//        .clk                    (clk),
//        .rst_n                  (rst_n),
//        .sst_scn_dec_en         (sst_scn_dec_en),
//        .sst_server_idx         (sst_server_idx),
//        .sst_health_update_valid(sst_health_update_valid),
//        .sst_health_update_bitmap(sst_health_update_bitmap),
//        .cslb_scn_inc_en        (cslb_scn_inc_en),
//        .cslb_server_idx        (cslb_server_idx),
//        .cslb_rd_en             (cslb_rd_en),
//        .cslb_rd_ip             (sst_ctrl_rd_ip),
//        .cslb_rd_scn            (sst_ctrl_rd_scn),
//        .cslb_rd_valid          (cslb_rd_valid),
//        .cslb_health_bitmap     (cslb_health_bitmap_wire),
//        .cslb_health_update_valid(sst_ctrl_health_update_valid),
//        .sst_wr_en              (sst_wr_en),
//        .sst_wr_addr            (sst_wr_addr),
//        .sst_wr_ip              (sst_wr_ip),
//        .sst_wr_health          (sst_wr_health),
//        .sst_wr_scn             (sst_wr_scn),
//        .sst_rd_addr            (sst_rd_addr),
//        .sst_rd_ip              (sst_rd_ip),
//        .sst_rd_scn             (sst_rd_scn),
//        .sst_cslb_rd_ip         (sst_cslb_rd_ip),
//        .sst_cslb_rd_scn        (sst_cslb_rd_scn),
//        .sst_health_bitmap      (sst_health_bitmap),
//        .boot_ip_list           (server_ip_list),
//        .boot_ip_valid     (server_ip_list_valid)
//    );

//    // =========================================================================
//    // 7. SST Register File
//    // =========================================================================
//    sst_reg_file #(
//        .NUM_SERVERS    (NUM_SERVERS),
//        .SERVER_ID_WIDTH(SERVER_ID_WIDTH),
//        .SCN_WIDTH      (SCN_WIDTH)
//    ) u_sst_reg_file (
//        .clk           (clk),
//        .rst_n         (rst_n),
//        .wr_en         (sst_wr_en),
//        .wr_addr       (sst_wr_addr),
//        .wr_ip         (sst_wr_ip),
//        .wr_health     (sst_wr_health),
//        .wr_scn        (sst_wr_scn),
//        .boot_ip_list  (server_ip_list),
//        .boot_ip_list_valid(server_ip_list_valid),
//        .rd_addr       (sst_rd_addr),
//        .rd_ip         (sst_rd_ip),
//        .rd_scn        (sst_rd_scn),
//        .cslb_rd_ip    (sst_cslb_rd_ip),
//        .cslb_rd_scn   (sst_cslb_rd_scn),
//        .health_bitmap (sst_health_bitmap)
//    );

//endmodule
module shm_top #(
    parameter NUM_SERVERS     = 16,
    parameter SERVER_ID_WIDTH = 4,
    parameter SCN_WIDTH       = 12,
    parameter CLK_FREQ_HZ     = 156_250_000,
    parameter TICK_MS         = 10
)(
    input  wire clk,
    input  wire rst_n,

    // TX Path
    input  wire [511:0] tx_cslb_data,
    input  wire [63:0]  tx_cslb_keep,
    input  wire         tx_cslb_last,
    input  wire         tx_cslb_valid,
    output wire         tx_cslb_ready,

    output wire [511:0] tx_backend_data,
    output wire [63:0]  tx_backend_keep,
    output wire         tx_backend_last,
    output wire         tx_backend_valid,
    input  wire         tx_backend_ready,

    // RX Path
    input  wire [511:0] rx_backend_data,
    input  wire [63:0]  rx_backend_keep,
    input  wire         rx_backend_last,
    input  wire         rx_backend_valid,
    output wire         rx_backend_ready,

    output wire [511:0] rx_cslb_data,
    output wire [63:0]  rx_cslb_keep,
    output wire         rx_cslb_last,
    output wire         rx_cslb_valid,
    input  wire         rx_cslb_ready,

    // CSLB Interface
    input  wire                        cslb_scn_inc_en,
    input  wire [SERVER_ID_WIDTH-1:0]  cslb_server_idx,

    input  wire                        cslb_rd_en,
    output wire [NUM_SERVERS*32-1:0]       cslb_rd_ip,
    output wire [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,
    output wire                        cslb_rd_valid,

    output wire [NUM_SERVERS-1:0]      cslb_health_bitmap,
    output wire                        cslb_health_update_valid,

    // CSLB SCN dec notification (registered 1-cycle pulse from parser)
    output wire                        cslb_scn_dec_en,
    output wire [SERVER_ID_WIDTH-1:0]  cslb_server_dec_idx,
    
    input wire [NUM_SERVERS*32-1:0]   server_ip_list,
    input wire                        server_ip_list_valid
);

    // =========================================================================
    // Internal Signals
    // =========================================================================

    // Timer outputs
    wire heartbeat_gen_trigger;
    wire heartbeat_checker_trigger;

    // Heartbeat generator -> arbiter
    wire [511:0] hb_pkt_data;
    wire         hb_pkt_valid;
    wire         hb_pkt_ready;

    // Parser outputs
    wire                       parser_response_valid;
    wire [SERVER_ID_WIDTH-1:0] parser_server_id;
    wire                       parser_response_ready;
    wire                       sst_scn_dec_en;
    wire [SERVER_ID_WIDTH-1:0] sst_server_idx;
    wire                       parser_scn_dec_en;
    wire [SERVER_ID_WIDTH-1:0] parser_server_dec_idx;

    // Heartbeat checker -> SST controller
    wire                       sst_health_update_valid;
    wire [NUM_SERVERS-1:0]     sst_health_update_bitmap;

    // SST controller -> reg file
    wire                       sst_wr_en;
    wire [SERVER_ID_WIDTH-1:0] sst_wr_addr;
    wire [31:0]                sst_wr_ip;
    wire                       sst_wr_health;
    wire [SCN_WIDTH-1:0]       sst_wr_scn;

    // Reg file read port 1 (controller internal)
    wire [SERVER_ID_WIDTH-1:0] sst_rd_addr;
    wire [31:0]                sst_rd_ip;
    wire [SCN_WIDTH-1:0]       sst_rd_scn;

    // Reg file read port 2 (CSLB broadcast - all servers, combinatorial)
    wire [NUM_SERVERS*32-1:0]        sst_cslb_rd_ip;
    wire [NUM_SERVERS*SCN_WIDTH-1:0] sst_cslb_rd_scn;

    // Controller CSLB snapshot outputs (registered, valid=1 cung cycle)
    wire [NUM_SERVERS*32-1:0]        sst_ctrl_rd_ip;
    wire [NUM_SERVERS*SCN_WIDTH-1:0] sst_ctrl_rd_scn;

    // Health bitmap
    wire [NUM_SERVERS-1:0]     sst_health_bitmap;
    wire [NUM_SERVERS-1:0]     cslb_health_bitmap_wire;

    // =========================================================================
    // CSLB Outputs
    // =========================================================================
    // cslb_rd_ip/scn dung registered snapshot tu controller
    // (khong dung truc tiep sst_cslb_rd_ip/scn vi do la combinatorial,
    //  co the thay doi ngay ca khi cslb_rd_valid chua len, gay race condition)
    assign cslb_rd_ip              = sst_ctrl_rd_ip;
    assign cslb_rd_scn             = sst_ctrl_rd_scn;
    assign cslb_health_bitmap      = cslb_health_bitmap_wire;
    wire sst_ctrl_health_update_valid;
    assign cslb_health_update_valid = sst_ctrl_health_update_valid;
    assign cslb_scn_dec_en         = parser_scn_dec_en;
    assign cslb_server_dec_idx     = parser_server_dec_idx;

    // cslb_health_update_valid: driven directly from sst_controller
    // (1-cycle pulse cung the nao voi cslb_health_bitmap NBA update)

    // =========================================================================
    // 1. SHM Timer
    // =========================================================================
    shm_timer #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .TICK_MS    (TICK_MS)
    ) u_shm_timer (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .heartbeat_gen_trigger  (heartbeat_gen_trigger),
        .heartbeat_checker_trigger(heartbeat_checker_trigger)
    );

    // =========================================================================
    // 2. Heartbeat Generator
    // =========================================================================
    heartbeat_generator u_heartbeat_generator (
        .clk       (clk),
        .rst_n     (rst_n),
        .trigger   (heartbeat_gen_trigger),
        .pkt_data  (hb_pkt_data),
        .pkt_valid (hb_pkt_valid),
        .pkt_ready (hb_pkt_ready),
        .timestamp (64'h0)
    );

    // =========================================================================
    // 3. SHM Arbiter
    // =========================================================================
    shm_arbiter u_shm_arbiter (
        .clk          (clk),
        .rst_n        (rst_n),
        .tx_cslb_data (tx_cslb_data),
        .tx_cslb_keep (tx_cslb_keep),
        .tx_cslb_last (tx_cslb_last),
        .tx_cslb_valid(tx_cslb_valid),
        .tx_cslb_ready(tx_cslb_ready),
        .hb_pkt_data  (hb_pkt_data),
        .hb_pkt_valid (hb_pkt_valid),
        .hb_pkt_ready (hb_pkt_ready),
        .tx_user_data (tx_backend_data),
        .tx_user_keep (tx_backend_keep),
        .tx_user_last (tx_backend_last),
        .tx_user_valid(tx_backend_valid),
        .tx_user_ready(tx_backend_ready)
    );

    // =========================================================================
    // 4. SHM Parser
    // =========================================================================
    shm_parser #(
        .SERVER_ID_WIDTH(SERVER_ID_WIDTH),
        .HEARTBEAT_PORT (16'd8888)
    ) u_shm_parser (
        .clk                  (clk),
        .rst_n                (rst_n),
        .rx_user_data         (rx_backend_data),
        .rx_user_keep         (rx_backend_keep),
        .rx_user_last         (rx_backend_last),
        .rx_user_valid        (rx_backend_valid),
        .rx_user_ready        (rx_backend_ready),
        .rx_cslb_data         (rx_cslb_data),
        .rx_cslb_keep         (rx_cslb_keep),
        .rx_cslb_last         (rx_cslb_last),
        .rx_cslb_valid        (rx_cslb_valid),
        .rx_cslb_ready        (rx_cslb_ready),
        .sst_scn_dec_en       (sst_scn_dec_en),
        .sst_server_idx       (sst_server_idx),
        .scn_dec_en           (parser_scn_dec_en),
        .server_idx           (parser_server_dec_idx),
        .parser_response_valid(parser_response_valid),
        .parser_server_id     (parser_server_id),
        .parser_response_ready(parser_response_ready)
    );

    // =========================================================================
    // 5. Heartbeat Checker
    // =========================================================================
    heartbeat_checker #(
        .NUM_SERVERS    (NUM_SERVERS),
        .SERVER_ID_WIDTH(SERVER_ID_WIDTH),
        .HEARTBEATS_REQUIRED(5)
    ) u_heartbeat_checker (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .heartbeat_tick         (heartbeat_gen_trigger),
        .trigger                (heartbeat_checker_trigger),
        .parser_response_valid  (parser_response_valid),
        .parser_server_id       (parser_server_id),
        .parser_response_ready  (parser_response_ready),
        .sst_health_update_valid(sst_health_update_valid),
        .sst_health_update_bitmap(sst_health_update_bitmap)
    );

    // =========================================================================
    // 6. SST Controller
    // =========================================================================
    sst_controller #(
        .NUM_SERVERS    (NUM_SERVERS),
        .SERVER_ID_WIDTH(SERVER_ID_WIDTH),
        .SCN_WIDTH      (SCN_WIDTH)
    ) u_sst_controller (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .sst_scn_dec_en         (sst_scn_dec_en),
        .sst_server_idx         (sst_server_idx),
        .sst_health_update_valid(sst_health_update_valid),
        .sst_health_update_bitmap(sst_health_update_bitmap),
        .cslb_scn_inc_en        (cslb_scn_inc_en),
        .cslb_server_idx        (cslb_server_idx),
        .cslb_rd_en             (cslb_rd_en),
        .cslb_rd_ip             (sst_ctrl_rd_ip),
        .cslb_rd_scn            (sst_ctrl_rd_scn),
        .cslb_rd_valid          (cslb_rd_valid),
        .cslb_health_bitmap     (cslb_health_bitmap_wire),
        .cslb_health_update_valid(sst_ctrl_health_update_valid),
        .sst_wr_en              (sst_wr_en),
        .sst_wr_addr            (sst_wr_addr),
        .sst_wr_ip              (sst_wr_ip),
        .sst_wr_health          (sst_wr_health),
        .sst_wr_scn             (sst_wr_scn),
        .sst_rd_addr            (sst_rd_addr),
        .sst_rd_ip              (sst_rd_ip),
        .sst_rd_scn             (sst_rd_scn),
        .sst_cslb_rd_ip         (sst_cslb_rd_ip),
        .sst_cslb_rd_scn        (sst_cslb_rd_scn),
        .sst_health_bitmap      (sst_health_bitmap),
        .boot_ip_list           (server_ip_list),
        .boot_ip_valid     (server_ip_list_valid)
    );

    // =========================================================================
    // 7. SST Register File
    // =========================================================================
    sst_reg_file #(
        .NUM_SERVERS    (NUM_SERVERS),
        .SERVER_ID_WIDTH(SERVER_ID_WIDTH),
        .SCN_WIDTH      (SCN_WIDTH)
    ) u_sst_reg_file (
        .clk           (clk),
        .rst_n         (rst_n),
        .wr_en         (sst_wr_en),
        .wr_addr       (sst_wr_addr),
        .wr_ip         (sst_wr_ip),
        .wr_health     (sst_wr_health),
        .wr_scn        (sst_wr_scn),
        .boot_ip_list  (server_ip_list),
        .boot_ip_list_valid(server_ip_list_valid),
        .rd_addr       (sst_rd_addr),
        .rd_ip         (sst_rd_ip),
        .rd_scn        (sst_rd_scn),
        .cslb_rd_ip    (sst_cslb_rd_ip),
        .cslb_rd_scn   (sst_cslb_rd_scn),
        .health_bitmap (sst_health_bitmap)
    );

endmodule
