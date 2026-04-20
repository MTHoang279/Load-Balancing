
//module shm_parser #(
//    parameter SERVER_ID_WIDTH = 4,
//    parameter HEARTBEAT_PORT  = 16'd8888
//)(
//    input  wire clk,
//    input  wire rst_n,

//    input  wire [511:0] rx_user_data,
//    input  wire [63:0]  rx_user_keep,
//    input  wire         rx_user_last,
//    input  wire         rx_user_valid,
//    output reg          rx_user_ready,

//    output wire [511:0] rx_cslb_data,
//    output wire [63:0]  rx_cslb_keep,
//    output wire         rx_cslb_last,
//    output wire         rx_cslb_valid,
//    input  wire         rx_cslb_ready,

//    output wire                       sst_scn_dec_en,
//    output wire [SERVER_ID_WIDTH-1:0] sst_server_idx,

//    output reg                        scn_dec_en,
//    output reg  [SERVER_ID_WIDTH-1:0] server_idx,

//    output reg                        parser_response_valid,
//    output reg [SERVER_ID_WIDTH-1:0]  parser_server_id,
//    input  wire                       parser_response_ready
//);

//    wire [15:0] udp_src_port;
//    wire [15:0] udp_dst_port;
//    wire [31:0] src_ip;
//    wire [7:0]  src_ip_last_octet;
//    wire [SERVER_ID_WIDTH-1:0] extracted_server_id;

//    assign udp_src_port        = rx_user_data[239:224];
//    assign udp_dst_port        = rx_user_data[223:208];
//    assign src_ip              = rx_user_data[303:272];
//    assign src_ip_last_octet   = src_ip[7:0];
//    assign extracted_server_id = src_ip_last_octet - 8'd100;

//    wire is_heartbeat_response;
//    wire is_user_response;

//    assign is_heartbeat_response = (udp_src_port == HEARTBEAT_PORT) &&
//                                   (udp_dst_port == 16'd9999);
//    assign is_user_response      = !is_heartbeat_response;

//    assign rx_cslb_data  = rx_user_data;
//    assign rx_cslb_keep  = rx_user_keep;
//    assign rx_cslb_last  = rx_user_last;
//    assign rx_cslb_valid = rx_user_valid && is_user_response;

//    always @(*) begin
//        if (rx_user_valid) begin
//            if (is_user_response)
//                rx_user_ready = rx_cslb_ready;
//            else
//                rx_user_ready = parser_response_ready;
//        end else begin
//            rx_user_ready = 1'b1;
//        end
//    end

//    // Combinatorial: de controller.always@(posedge) lay mau tai dung clock
//    // handshake (rx_user_valid=1 tu setup clock truoc), tranh race voi
//    // testbench clearing valid trong cung active region cua posedge handshake.
//    assign sst_scn_dec_en = rx_user_valid && rx_user_last &&
//                            is_user_response && rx_cslb_ready;
//    assign sst_server_idx = extracted_server_id;

//    // Registered 1-cycle pulse for CSLB use
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            scn_dec_en <= 1'b0;
//            server_idx <= {SERVER_ID_WIDTH{1'b0}};
//        end else begin
//            scn_dec_en <= sst_scn_dec_en;
//            server_idx <= extracted_server_id;
//        end
//    end

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            parser_response_valid <= 1'b0;
//            parser_server_id      <= {SERVER_ID_WIDTH{1'b0}};
//        end else begin
//            if (rx_user_valid && rx_user_last && is_heartbeat_response && parser_response_ready) begin
//                parser_response_valid <= 1'b1;
//                parser_server_id      <= extracted_server_id;
//            end else begin
//                parser_response_valid <= 1'b0;
//            end
//        end
//    end

//endmodule



module shm_parser #(
    parameter SERVER_ID_WIDTH = 4,
    parameter HEARTBEAT_PORT  = 16'd8888
)(
    input  wire clk,
    input  wire rst_n,

    input  wire [511:0] rx_user_data,
    input  wire [63:0]  rx_user_keep,
    input  wire         rx_user_last,
    input  wire         rx_user_valid,
    output reg          rx_user_ready,

    output wire [511:0] rx_cslb_data,
    output wire [63:0]  rx_cslb_keep,
    output wire         rx_cslb_last,
    output wire         rx_cslb_valid,
    input  wire         rx_cslb_ready,

    output wire                       sst_scn_dec_en,
    output wire [SERVER_ID_WIDTH-1:0] sst_server_idx,

    output reg                        scn_dec_en,
    output reg  [SERVER_ID_WIDTH-1:0] server_idx,

    output reg                        parser_response_valid,
    output reg [SERVER_ID_WIDTH-1:0]  parser_server_id,
    input  wire                       parser_response_ready
);

    wire [15:0] udp_src_port;
    wire [15:0] udp_dst_port;
    wire [31:0] src_ip;
    wire [31:0] dst_ip;
    wire [7:0]  dst_ip_last_octet;
    wire [SERVER_ID_WIDTH-1:0] extracted_server_id;

    assign udp_src_port        = rx_user_data[239:224];
    assign udp_dst_port        = rx_user_data[223:208];
    assign src_ip              = rx_user_data[303:272];
    assign dst_ip              = rx_user_data[271:240];
    assign dst_ip_last_octet   = dst_ip[7:0];
    assign extracted_server_id = dst_ip_last_octet - 8'd100;

    wire is_heartbeat_response;
    wire is_user_response;

    assign is_heartbeat_response = (udp_src_port == HEARTBEAT_PORT) &&
                                   (udp_dst_port == 16'd9999);
    assign is_user_response      = !is_heartbeat_response;

    assign rx_cslb_data  = rx_user_data;
    assign rx_cslb_keep  = rx_user_keep;
    assign rx_cslb_last  = rx_user_last;
    assign rx_cslb_valid = rx_user_valid && is_user_response;

    always @(*) begin
        if (rx_user_valid) begin
            if (is_user_response)
                rx_user_ready = rx_cslb_ready;
            else
                rx_user_ready = parser_response_ready;
        end else begin
            rx_user_ready = 1'b1;
        end
    end

    // Combinatorial: de controller.always@(posedge) lay mau tai dung clock
    // handshake (rx_user_valid=1 tu setup clock truoc), tranh race voi
    // testbench clearing valid trong cung active region cua posedge handshake.
    assign sst_scn_dec_en = rx_user_valid && rx_user_last &&
                            is_user_response && rx_cslb_ready;
    assign sst_server_idx = extracted_server_id;

    // Registered 1-cycle pulse for CSLB use
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scn_dec_en <= 1'b0;
            server_idx <= {SERVER_ID_WIDTH{1'b0}};
        end else begin
            scn_dec_en <= sst_scn_dec_en;
            server_idx <= extracted_server_id;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parser_response_valid <= 1'b0;
            parser_server_id      <= {SERVER_ID_WIDTH{1'b0}};
        end else begin
            if (rx_user_valid && rx_user_last && is_heartbeat_response && parser_response_ready) begin
                parser_response_valid <= 1'b1;
                parser_server_id      <= extracted_server_id;
            end else begin
                parser_response_valid <= 1'b0;
            end
        end
    end

endmodule
