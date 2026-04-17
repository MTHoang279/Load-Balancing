`timescale 1ns / 1ps
module shm_parser #(
    parameter N_SERVERS   = 4,
    parameter SERVER_ID_W = $clog2(N_SERVERS)
)(
    input  wire         clk,
    input  wire         rst_n,

    input  wire [511:0] rx_tdata,
    input  wire [63:0]  rx_tkeep,
    input  wire         rx_tvalid,
    input  wire         rx_tlast,
    output wire         rx_tready,

    // USER PATH
    output wire [511:0] user_tdata,
    output wire [63:0]  user_tkeep,
    output wire         user_tvalid,
    output wire         user_tlast,
    input  wire         user_tready,

    // HEARTBEAT PATH
    output wire [511:0] hb_resp_tdata,
    output wire [63:0]  hb_resp_tkeep,
    output wire         hb_resp_tvalid,
    output wire         hb_resp_tlast,
    input  wire         hb_resp_tready
);

//////////////////////////////////////////////////////////////
// Heartbeat magic
//////////////////////////////////////////////////////////////

localparam [31:0] HB_MAGIC = 32'h0000_0002;

wire [31:0] magic = rx_tdata[199:168];

wire is_hb_packet =
        rx_tvalid &&
        rx_tlast  &&
        (magic == HB_MAGIC);

//////////////////////////////////////////////////////////////
// Routing decision
//////////////////////////////////////////////////////////////

wire route_hb   = is_hb_packet;
wire route_user = rx_tvalid && !is_hb_packet;

assign user_tdata  = rx_tdata;
assign user_tkeep  = rx_tkeep;
assign user_tlast  = rx_tlast;
assign user_tvalid = route_user;

assign hb_resp_tdata  = rx_tdata;
assign hb_resp_tkeep  = rx_tkeep;
assign hb_resp_tlast  = rx_tlast;
assign hb_resp_tvalid = route_hb;

//////////////////////////////////////////////////////////////
// Backpressure
//////////////////////////////////////////////////////////////

assign rx_tready =
        route_hb   ? hb_resp_tready :
                     user_tready;

endmodule