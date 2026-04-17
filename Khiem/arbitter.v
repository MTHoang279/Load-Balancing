`timescale 1ns / 1ps
module shm_arbiter (
    input  wire         clk,
    input  wire         rst_n,

    // ---- User traffic from CSLB (tx_cslb) ----
    input  wire [511:0] cslb_tdata,
    input  wire [63:0]  cslb_tkeep,
    input  wire         cslb_tvalid,
    input  wire         cslb_tlast,
    output wire         cslb_tready,

    // ---- Heartbeat packets from Heartbeat Gen ----
    input  wire [511:0] hb_tdata,
    input  wire [63:0]  hb_tkeep,
    input  wire         hb_tvalid,
    input  wire         hb_tlast,
    output wire         hb_tready,


    // ---- Output to TX network path ----
    output wire [511:0] tx_tdata,
    output wire [63:0]  tx_tkeep,
    output wire         tx_tvalid,
    output wire         tx_tlast,
    input  wire         tx_tready
);

    // -------------------------------------------------------------------------
    // 1. In-flight Packet Tracking (Theo dõi ranh giới gói tin)
    // -------------------------------------------------------------------------
    // Cờ này sẽ lên 1 nếu gói tin đã bắt đầu truyền nhưng chưa gặp TLAST
    reg user_in_flight;
    reg hb_in_flight;
    
    // Tín hiệu xác nhận dữ liệu đã được đẩy đi thành công trong chu kỳ hiện tại
    wire user_fire = cslb_tvalid & cslb_tready;
    wire hb_fire   = hb_tvalid & hb_tready;

    always @(posedge clk) begin
        if (!rst_n) begin
            user_in_flight <= 1'b0;
            hb_in_flight   <= 1'b0;
        end else begin
            // Nếu có dữ liệu truyền đi, cập nhật trạng thái "in_flight"
            // Nếu tlast = 1, in_flight sẽ tự động tụt về 0 (giải phóng đường truyền)
            if (user_fire) user_in_flight <= ~cslb_tlast;
            if (hb_fire)   hb_in_flight   <= ~hb_tlast;
        end
    end

    // -------------------------------------------------------------------------
    // 2. Priority MUX Selection Logic (Lõi chuyển mạch)
    // -------------------------------------------------------------------------
    // Luồng Heartbeat (HB) mang quyền ưu tiên tuyệt đối.
    // Tuy nhiên, nó không được phép xé rách gói tin User đang truyền dở.
    // 
    // MUX sẽ chọn ngả HB khi:
    //   - Bản thân HB đang truyền dở 1 gói tin (hb_in_flight = 1)
    //   - HOẶC HB có dữ liệu muốn gửi (hb_tvalid = 1) VÀ luồng User không có gói tin nào đang chặn đường (user_in_flight = 0).
    wire sel_hb = hb_in_flight || (hb_tvalid && !user_in_flight);

    // -------------------------------------------------------------------------
    // 3. Data Routing (Định tuyến Tổ hợp)
    // -------------------------------------------------------------------------
    // Chuyển mạch đường Data (Forward path)
    assign tx_tdata  = sel_hb ? hb_tdata  : cslb_tdata;
    assign tx_tkeep  = sel_hb ? hb_tkeep  : cslb_tkeep;
    assign tx_tvalid = sel_hb ? hb_tvalid : cslb_tvalid;
    assign tx_tlast  = sel_hb ? hb_tlast  : cslb_tlast;

    // Chuyển mạch đường Điều khiển (Back-pressure path)
    assign hb_tready   = sel_hb ? tx_tready : 1'b0;
    assign cslb_tready = sel_hb ? 1'b0      : tx_tready;

endmodule