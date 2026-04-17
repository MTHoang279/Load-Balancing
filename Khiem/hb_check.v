`timescale 1ns / 1ps

module heartbeat_checker_pipelined #(
    parameter N_SERVERS   = 32,
    parameter SERVER_ID_W = $clog2(N_SERVERS)
)(
    input  wire clk,
    input  wire rst_n,

    // AXI Stream
    input  wire [511:0] s_axis_tdata,
    input  wire [63:0]  s_axis_tkeep,
    input  wire         s_axis_tvalid,
    input  wire         s_axis_tlast,
    output wire         s_axis_tready,

    // timer
    input  wire tick_10s,

    // output sang SST Controller
    output reg  [1:0]               health_update_opcode,
    output reg  [SERVER_ID_W-1:0]   health_update_idx,
    output reg  [31:0]              health_update_ip
);

    assign s_axis_tready = 1'b1;

    reg in_packet;
    always @(posedge clk) begin
        if(!rst_n)
            in_packet <= 0;
        else if(s_axis_tvalid)
            in_packet <= !s_axis_tlast;
    end

    wire first_beat = s_axis_tvalid && !in_packet;

    // Packet fields (Offset Byte: IP=26, Port=36, Index=42)
    wire [31:0] src_ip       = s_axis_tdata[26*8 +: 32];
    wire [15:0] dst_port     = s_axis_tdata[36*8 +: 16];
    wire [31:0] server_index = s_axis_tdata[42*8 +: 32];

    // tkeep check
    wire src_ip_valid = s_axis_tkeep[26] & s_axis_tkeep[27] & s_axis_tkeep[28] & s_axis_tkeep[29];
    wire port_valid   = s_axis_tkeep[36] & s_axis_tkeep[37];
    wire index_valid  = s_axis_tkeep[42] & s_axis_tkeep[43] & s_axis_tkeep[44] & s_axis_tkeep[45];

    // Heartbeat detect
    wire hb_valid = first_beat &&
                    src_ip_valid &&
                    port_valid &&
                    index_valid &&
                    (dst_port == 16'd9001) &&
                    (server_index < N_SERVERS);

    // State
    reg [N_SERVERS-1:0] response_received;
    reg [31:0] ip_cache [0:N_SERVERS-1];

    reg scanning;
    reg [SERVER_ID_W:0] scan_idx; // Thêm 1 bit để chống tràn khi đếm đến N_SERVERS

    integer i;

    always @(posedge clk) begin
        if(!rst_n) begin
            response_received <= 0;
            scanning <= 0;
            scan_idx <= 0;

            health_update_opcode <= 0;
            health_update_idx    <= 0;
            health_update_ip     <= 0;

            for(i=0; i<N_SERVERS; i=i+1)
                ip_cache[i] <= 0;

        end else begin
            // Mặc định không gửi lệnh gì cho SST để tránh rác
            health_update_opcode <= 2'b00;

            // -----------------------------------------------------------------
            // 1. KHI CÓ GÓI HEARTBEAT TỚI: CẬP NHẬT SST NGAY LẬP TỨC
            // -----------------------------------------------------------------
            if (hb_valid) begin
                response_received[server_index] <= 1'b1;
                ip_cache[server_index]          <= src_ip;

                // Bắn tín hiệu sang SST Controller NGAY LẬP TỨC
                health_update_opcode <= 2'b01; // 01 = Báo Alive
                health_update_idx    <= server_index[SERVER_ID_W-1:0];
                health_update_ip     <= src_ip;
            end

            // -----------------------------------------------------------------
            // 2. KHI ĐẾN HẸN 10 GIÂY: CHỈ QUÉT ĐỂ TÌM SERVER ĐÃ CHẾT
            // -----------------------------------------------------------------
            if (tick_10s && !scanning) begin
                scanning <= 1'b1;
                scan_idx <= 0;
            end

            // Ưu tiên xử lý quét (Nhưng nếu có hb_valid chen ngang thì nhường cho hb_valid cập nhật trước)
            if (scanning && !hb_valid) begin
                if (!response_received[scan_idx]) begin
                    // Phát hiện Server không trả lời -> Báo Die
                    health_update_opcode <= 2'b10; // 10 = Báo Die
                    health_update_idx    <= scan_idx[SERVER_ID_W-1:0];
                    // IP không quan trọng khi báo Die, SST tự xoá
                end

                // Xoá cờ đã nhận để chuẩn bị cho chu kỳ 10 giây tiếp theo
                response_received[scan_idx] <= 1'b0;

                // Tăng biến đếm
                if (scan_idx == N_SERVERS-1) begin
                    scan_idx <= 0;
                    scanning <= 1'b0; // Kết thúc quét
                end else begin
                    scan_idx <= scan_idx + 1;
                end
            end

        end
    end

endmodule