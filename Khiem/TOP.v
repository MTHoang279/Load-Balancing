`timescale 1ns / 1ps

module fpga_lb_server_top #(
    parameter BUS_WIDTH = 512,
    parameter N_SERVERS = 32
    //parameter SERVERS_ALIVE = 8,
    //parameter N_ALGORITHMS = 3
)(
    input  wire        clk_p,
    input  wire        clk_n,
    input  wire        rst_in,
    (* mark_debug = "true" *) input  wire        start,
    (* mark_debug = "true" *) input  wire [4:0]  server_en,
    (* mark_debug = "true" *) input  wire [1:0]  algo_sel,
    (* mark_debug = "true" *) input  wire        allow_reply
);

    (* mark_debug = "true" *) wire [N_SERVERS*16-1:0] cnt_user_req_rx;
    (* mark_debug = "true" *) wire [N_SERVERS*16-1:0] cnt_hb_req_rx;
    (* mark_debug = "true" *) wire [N_SERVERS*16-1:0] cnt_user_reply_tx;
    (* mark_debug = "true" *) wire [N_SERVERS*16-1:0] cnt_hb_reply_tx;

    wire clk;
    wire mmcm_locked;


////////////////////////////////////////////////////////////
// Clock Wizard
////////////////////////////////////////////////////////////

    clk_wiz_0 u_clk_wiz (
         .clk_in1_n(clk_n),
         .clk_in1_p(clk_p),
         .reset    (rst_in),
         .clk_out1 (clk),
         .locked   (mmcm_locked)
     );

////////////////////////////////////////////////////////////
// TỐI ƯU HÓA MẠCH RESET (RESET TREE ARCHITECTURE)
// Khắc phục lỗi High Fanout Routing & An toàn khi mất Clock
////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////
// RESET TREE - FIX HOÀN CHỈNH
////////////////////////////////////////////////////////////

    wire async_rst_n;
    assign async_rst_n = (~rst_in) & mmcm_locked;

    // -----------------------------------------------------------
    // Tách thành 3 always block RIÊNG BIỆT
    // => Synth tool KHÔNG THỂ merge vì khác block
    // => Mỗi block tạo ra FF vật lý độc lập trên silicon
    // -----------------------------------------------------------

    // Nhánh 1: Top-level logic
    (* ASYNC_REG = "TRUE" *) 
    reg [2:0] rst_sync_top;

    always @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) rst_sync_top <= 3'b000;
        else              rst_sync_top <= {rst_sync_top[1:0], 1'b1};
    end

    // Nhánh 2: Load Balancer core
    (* ASYNC_REG = "TRUE" *)
    reg [2:0] rst_sync_lb;

    always @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) rst_sync_lb <= 3'b000;
        else              rst_sync_lb <= {rst_sync_lb[1:0], 1'b1};
    end

    // Nhánh 3: Server cluster
    (* ASYNC_REG = "TRUE" *)
    reg [2:0] rst_sync_srv;

    always @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) rst_sync_srv <= 3'b000;
        else              rst_sync_srv <= {rst_sync_srv[1:0], 1'b1};
    end

    // -----------------------------------------------------------
    // max_fanout đặt trên REG output (stage [2]) — mới có hiệu lực
    // Vivado sẽ tự replicate thêm nếu fanout thực tế > 50
    // -----------------------------------------------------------
    reg rst_n_top_r, rst_n_lb_r, rst_n_srv_r;

    always @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) begin
            rst_n_top_r <= 1'b0;
            rst_n_lb_r  <= 1'b0;
            rst_n_srv_r <= 1'b0;
        end else begin
            rst_n_top_r <= rst_sync_top[2];
            rst_n_lb_r  <= rst_sync_lb[2];
            rst_n_srv_r <= rst_sync_srv[2];
        end
    end

    // Dùng các reg này thay vì wire
    wire rst_n_top = rst_n_top_r;
    wire rst_n_lb  = rst_n_lb_r;
    wire rst_n_srv = rst_n_srv_r;

////////////////////////////////////////////////////////////
// TOP LEVEL CONTROL LOGIC (Sử dụng rst_n_top)
////////////////////////////////////////////////////////////

    reg [N_SERVERS-1:0] server_en_r;
    reg [2:0]           algo_sel_r;
    reg                 allow_reply_r;

    always @(posedge clk) begin
        if (!rst_n_top) begin
            server_en_r   <= {N_SERVERS{1'b0}};
            algo_sel_r    <= 3'b001;   // default RR
            allow_reply_r <= 1'b0;
        end else begin
            // ---------------- ALGO SELECT ----------------
            case (algo_sel)
                2'b01: algo_sel_r <= 3'b001;
                2'b10: algo_sel_r <= 3'b010;
                2'b11: algo_sel_r <= 3'b100;
                default: algo_sel_r <= 3'b001;
            endcase

            // ---------------- SERVER ENABLE ----------------
            // server_en_r <= {N_SERVERS{1'b0}};  // default clear

        case (server_en)
            5'd0 : server_en_r <= 32'b0000_0000_0000_0000_0000_0000_0000_0000; // 0 server
            5'd1 : server_en_r <= 32'b0000_0000_0000_0000_0000_0000_0000_0001; // 1 server
            5'd2 : server_en_r <= 32'b0000_0000_0000_0000_0000_0000_0000_0011; // 2 servers
            5'd3 : server_en_r <= 32'b0000_0000_0000_0000_0000_0000_0000_0111; // 3 servers
            5'd4 : server_en_r <= 32'b0000_0000_0000_0000_0000_0000_0000_1111; // 4 servers
            5'd5 : server_en_r <= 32'b0000_0000_0000_0000_0000_0000_0001_1111; // 5 servers
            5'd6 : server_en_r <= 32'b0000_0000_0000_0000_0000_0000_0011_1111; // 6 servers
            5'd7 : server_en_r <= 32'b0000_0000_0000_0000_0000_0000_0111_1111; // 7 servers
            5'd8 : server_en_r <= 32'b0000_0000_0000_0000_0000_0000_1111_1111; // 8 servers
            5'd9 : server_en_r <= 32'b0000_0000_0000_0000_0000_0001_1111_1111; // 9 servers
            5'd10: server_en_r <= 32'b0000_0000_0000_0000_0000_0011_1111_1111;
            5'd11: server_en_r <= 32'b0000_0000_0000_0000_0000_0111_1111_1111;
            5'd12: server_en_r <= 32'b0000_0000_0000_0000_0000_1111_1111_1111;
            5'd13: server_en_r <= 32'b0000_0000_0000_0000_0001_1111_1111_1111;
            5'd14: server_en_r <= 32'b0000_0000_0000_0000_0011_1111_1111_1111;
            5'd15: server_en_r <= 32'b0000_0000_0000_0000_0111_1111_1111_1111;
            5'd16: server_en_r <= 32'b0000_0000_0000_0000_1111_1111_1111_1111;
            5'd17: server_en_r <= 32'b0000_0000_0000_0001_1111_1111_1111_1111;
            5'd18: server_en_r <= 32'b0000_0000_0000_0011_1111_1111_1111_1111;
            5'd19: server_en_r <= 32'b0000_0000_0000_0111_1111_1111_1111_1111;
            5'd20: server_en_r <= 32'b0000_0000_0000_1111_1111_1111_1111_1111;
            5'd21: server_en_r <= 32'b0000_0000_0001_1111_1111_1111_1111_1111;
            5'd22: server_en_r <= 32'b0000_0000_0011_1111_1111_1111_1111_1111;
            5'd23: server_en_r <= 32'b0000_0000_0111_1111_1111_1111_1111_1111;
            5'd24: server_en_r <= 32'b0000_0000_1111_1111_1111_1111_1111_1111;
            5'd25: server_en_r <= 32'b0000_0001_1111_1111_1111_1111_1111_1111;
            5'd26: server_en_r <= 32'b0000_0011_1111_1111_1111_1111_1111_1111;
            5'd27: server_en_r <= 32'b0000_0111_1111_1111_1111_1111_1111_1111;
            5'd28: server_en_r <= 32'b0000_1111_1111_1111_1111_1111_1111_1111;
            5'd29: server_en_r <= 32'b0001_1111_1111_1111_1111_1111_1111_1111;
            5'd30: server_en_r <= 32'b0011_1111_1111_1111_1111_1111_1111_1111;
            5'd31: server_en_r <= 32'b1111_1111_1111_1111_1111_1111_1111_1111; // 31 servers
            default: server_en_r <= 32'b0000_0000_0000_0000_0000_0000_0000_0000;
        endcase

            // ---------------- OTHER CONTROL ----------------
            allow_reply_r <= allow_reply;
        end
    end

////////////////////////////////////////////////////////////
// START SYNCHRONIZER + EDGE DETECT (Sử dụng rst_n_top)
////////////////////////////////////////////////////////////

    (* ASYNC_REG = "TRUE" *) reg start_meta;
    reg start_r1, start_r2;
    (* KEEP = "TRUE" *) wire start_pulse;

    always @(posedge clk) begin
        if (!rst_n_top) begin
            start_meta <= 1'b0;
            start_r1   <= 1'b0;
            start_r2   <= 1'b0;
        end else begin
            start_meta <= start;
            start_r1   <= start_meta;
            start_r2   <= start_r1;
        end
    end

    assign start_pulse = start_r1 & ~start_r2;

////////////////////////////////////////////////////////////
// LB -> Server Wires
////////////////////////////////////////////////////////////

    wire [BUS_WIDTH-1:0]   lb_tx_tdata;
    wire [BUS_WIDTH/8-1:0] lb_tx_tkeep;
    wire                   lb_tx_tvalid;
    wire                   lb_tx_tlast;
    wire                   lb_tx_tready;

////////////////////////////////////////////////////////////
// Server -> LB Wires
////////////////////////////////////////////////////////////

    wire [BUS_WIDTH-1:0]   srv_tx_tdata;
    wire [BUS_WIDTH/8-1:0] srv_tx_tkeep;
    wire                   srv_tx_tvalid;
    wire                   srv_tx_tlast;
    wire                   srv_tx_tready;

////////////////////////////////////////////////////////////
// Bypass output Wires (reply cho user)
////////////////////////////////////////////////////////////

    wire [BUS_WIDTH-1:0]   bypass_out_tdata;
    wire [BUS_WIDTH/8-1:0] bypass_out_tkeep;
    wire                   bypass_out_tvalid;
    wire                   bypass_out_tlast;

////////////////////////////////////////////////////////////
// Instantiate FPGA Load Balancer Top (Sử dụng rst_n_lb)
////////////////////////////////////////////////////////////

    fpga_top #(
        .BUS_WIDTH(BUS_WIDTH),
        .N_SERVERS(N_SERVERS)
    ) u_fpga_top (
        .clk(clk),
        .rst_n(rst_n_lb),      // <-- Đã đổi sang nhánh Reset của LB
        .start(start_pulse),
        .algo_sel(algo_sel_r),

        // RX từ server reply
        .rx_axis_tdata (srv_tx_tdata),
        .rx_axis_tkeep (srv_tx_tkeep),
        .rx_axis_tvalid(srv_tx_tvalid),
        .rx_axis_tlast (srv_tx_tlast),
        .rx_axis_tready(srv_tx_tready),

        // TX request sang server
        .tx_axis_tdata (lb_tx_tdata),
        .tx_axis_tkeep (lb_tx_tkeep),
        .tx_axis_tvalid(lb_tx_tvalid),
        .tx_axis_tlast (lb_tx_tlast),
        .tx_axis_tready(lb_tx_tready),

        // User output
        .bypass_out_tdata (bypass_out_tdata),
        .bypass_out_tkeep (bypass_out_tkeep),
        .bypass_out_tvalid(bypass_out_tvalid),
        .bypass_out_tlast (bypass_out_tlast),
        .bypass_out_tready(1'b1)
    );

////////////////////////////////////////////////////////////
// Instantiate Server Auto Responder (Sử dụng rst_n_srv)
////////////////////////////////////////////////////////////

    server_auto_responder #(
        .N_SERVERS(N_SERVERS)
    ) u_server (
        .clk(clk),
        .rst_n(rst_n_srv),     // <-- Đã đổi sang nhánh Reset của Server
        .server_en(server_en_r),
        .allow_reply(allow_reply_r),

        // RX từ Load Balancer
        .rx_tdata (lb_tx_tdata),
        .rx_tkeep (lb_tx_tkeep),
        .rx_tvalid(lb_tx_tvalid),
        .rx_tlast (lb_tx_tlast),
        .rx_tready(lb_tx_tready),

        // TX reply về Load Balancer
        .tx_tdata (srv_tx_tdata),
        .tx_tkeep (srv_tx_tkeep),
        .tx_tvalid(srv_tx_tvalid),
        .tx_tlast (srv_tx_tlast),
        .tx_tready(srv_tx_tready),

        .cnt_user_req_rx  (cnt_user_req_rx),
        .cnt_hb_req_rx    (cnt_hb_req_rx),
        .cnt_user_reply_tx(cnt_user_reply_tx),
        .cnt_hb_reply_tx  (cnt_hb_reply_tx)
    );

endmodule