`timescale 1ns / 1ps
module fpga_lb_server_top #(
    parameter BUS_WIDTH = 512,
    parameter N_SERVERS = 16
)(
    input  wire        clk_p,
    input  wire        clk_n,
    input  wire        rst_in,
    (* mark_debug = "true" *) input  wire        start,
    (* mark_debug = "true" *) input  wire [5:0]  server_en,
    (* mark_debug = "true" *) input  wire [1:0]  algo_sel,
    output wire        done_led
);
    (* mark_debug = "true" *) wire [N_SERVERS*32-1:0] cnt_user_req_rx;
    (* mark_debug = "true" *)wire [N_SERVERS*32-1:0] cnt_hb_req_rx;
    (* mark_debug = "true" *) wire [N_SERVERS*32-1:0] cnt_user_reply_tx;
    (* mark_debug = "true" *) wire [N_SERVERS*32-1:0] cnt_hb_reply_tx;
    wire clk;
    wire clk_bufg;
    
    // Bi?n trung gian ?? ch?a Bitmap th?c t? sau khi gi?i mã t? switch
    reg [N_SERVERS-1:0] server_en_valid;

    // ============================================================
    // Logic chuy?n ??i t? 6 Switch sang Bitmap N_SERVERS
    // ============================================================
    always @(*) begin
        // M?c ??nh toàn b? server b? t?t
        server_en_valid = {N_SERVERS{1'b0}}; 

        case(server_en)
            6'b000000: server_en_valid = {N_SERVERS{1'b0}};                   // 0 server
            
            6'b000001: server_en_valid[0] = 1'b1;                             // B?t server 0
            
            6'b000011: begin
                if (N_SERVERS >= 4) server_en_valid[3:0] = 4'hF;              // B?t 4 server
                else server_en_valid = {N_SERVERS{1'b1}};
            end
            
            6'b000111: begin
                if (N_SERVERS >= 8) server_en_valid[7:0] = 8'hFF;             // B?t 8 server
                else server_en_valid = {N_SERVERS{1'b1}};
            end
            
            6'b001111: begin
                if (N_SERVERS >= 16) server_en_valid[15:0] = 16'hFFFF;        // B?t 16 server
                else server_en_valid = {N_SERVERS{1'b1}};
            end
            
            6'b011111: server_en_valid = {N_SERVERS{1'b1}};                   // B?t t?i ?a (32 ho?c N)
            
            6'b111111: server_en_valid = {N_SERVERS{1'b1}};                   // B?t t?t c?
            
            default:   server_en_valid = {N_SERVERS{1'b0}};
        endcase
    end
    
//    (* keep = "true" *) wire dummy_algo;
//    wire dummy;
//    assign dummy = |server_en;
//    assign dummy_algo = ^algo_sel; // dùng h?t bit
////////////////////////////////////////////////////////////
// AXIS wires giá»¯a Load Balancer vÃ  Server
////////////////////////////////////////////////////////////
    IBUFDS #(
        .DIFF_TERM("FALSE"),     // <-- Sá»­a thÃ nh FALSE á»Ÿ Ä'Ã¢y
        .IBUF_LOW_PWR("FALSE")
    ) u_ibufds (
        .I (clk_p),
        .IB(clk_n),
        .O (clk_bufg)
    );
    
    BUFG u_bufg (
        .I(clk_bufg),
        .O(clk)
    );

    wire rst_n;
    assign rst_n = ~rst_in;

        // ================= 3. LOGIC START SYNCHRONIZER =================
    reg start_r1, start_r2;
    (* KEEP = "TRUE" *) wire start_pulse;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_r1 <= 0;
            start_r2 <= 0;
        end else begin
            start_r1 <= start;      
            start_r2 <= start_r1;   
        end
    end
    assign start_pulse = start_r1 && !start_r2; 

// LB -> Server
wire [BUS_WIDTH-1:0] lb_tx_tdata;
wire [63:0]          lb_tx_tkeep;
wire                 lb_tx_tvalid;
wire                 lb_tx_tlast;
wire                 lb_tx_tready;

// Server -> LB
wire [BUS_WIDTH-1:0] srv_tx_tdata;
wire [63:0]          srv_tx_tkeep;
wire                 srv_tx_tvalid;
wire                 srv_tx_tlast;
wire                 srv_tx_tready;

(* mark_debug = "true" *)
reg [1:0] algo_sel_dbg;
(* mark_debug = "true" *)
reg [5:0] server_en_dbg;

always @(posedge clk) begin
    algo_sel_dbg <= algo_sel;
    server_en_dbg <= server_en;
end

fpga_top #(
    .BUS_WIDTH(BUS_WIDTH),
    .NUM_SERVERS(N_SERVERS)
) u_fpga_top (

//     .clk_p(clk_p),
//     .clk_n(clk_n),
    .clk(clk),
    .rst_in(rst_in),
    .start(start_pulse),
    .algo_sel(algo_sel),
    .done(done_led),

    .tx_backend_data(lb_tx_tdata),
    .tx_backend_keep(lb_tx_tkeep),
    .tx_backend_last(lb_tx_tlast),
    .tx_backend_ready(lb_tx_tready),
    .tx_backend_valid(lb_tx_tvalid),
    
    .rx_backend_data(srv_tx_tdata),
    .rx_backend_keep(srv_tx_tkeep),
    .rx_backend_last(srv_tx_tlast),
    .rx_backend_valid(srv_tx_tvalid)
);

////////////////////////////////////////////////////////////
// Instantiate Server Auto Responder
////////////////////////////////////////////////////////////

server_auto_responder #(
    .N_SERVERS(N_SERVERS)
) u_server (

    .clk(clk),   // hoáº·c clk_core náº¿u expose
    .rst_n(rst_n),
    .server_en(server_en),
    // RX tá»« Load Balancer
    (* mark_debug = "true" *) .rx_tdata (lb_tx_tdata),
    (* mark_debug = "true" *) .rx_tkeep (lb_tx_tkeep),
    (* mark_debug = "true" *) .rx_tvalid(lb_tx_tvalid),
    (* mark_debug = "true" *) .rx_tlast (lb_tx_tlast),
    (* mark_debug = "true" *) .rx_tready(lb_tx_tready),

    // TX reply vï¿½? Load Balancer
    (* mark_debug = "true" *).tx_tdata (srv_tx_tdata),
    (* mark_debug = "true" *) .tx_tkeep (srv_tx_tkeep),
    (* mark_debug = "true" *) .tx_tvalid(srv_tx_tvalid),
    (* mark_debug = "true" *) .tx_tlast (srv_tx_tlast),
    (* mark_debug = "true" *) .tx_tready(srv_tx_tready),
    .cnt_user_req_rx(cnt_user_req_rx),
    .cnt_hb_req_rx(cnt_hb_req_rx),
    .cnt_user_reply_tx(cnt_user_reply_tx),
    .cnt_hb_reply_tx(cnt_hb_reply_tx)
);

endmodule