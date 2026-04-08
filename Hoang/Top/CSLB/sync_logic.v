//module sync_logic #(
//    parameter MSG_WIDTH  = 512,
//    parameter KEY_WIDTH  = 128,
//    parameter DATA_WIDTH = MSG_WIDTH
//)(
//    input  wire                         clk,
//    input  wire                         rst_n,

//    // ================= KEY FIFO (FWFT) =================
//    input  wire [KEY_WIDTH-1:0]         key_data,
//    input  wire                         key_valid, // Tương �'ương !key_empty
//    input  wire                         key_empty,
//    output wire                         rd_key_en,

//    // ================= MSG FIFO (FWFT) =================
//    input  wire [MSG_WIDTH-1:0]         msg_data,
//    input  wire                         msg_valid, // Tương �'ương !msg_empty
//    input  wire                         msg_last,
//    input  wire [MSG_WIDTH/8-1:0]       msg_keep,
//    input  wire                         msg_empty,
//    output wire                         rd_msg_en,

//    // ================= AXIS OUT =================
//    // Chuyển reg -> wire �'ể passthrough dữ liệu từ FWFT ra ngo� i
//    output wire [DATA_WIDTH-1:0]        m_axis_tdata,
//    output wire                         m_axis_tvalid,
//    output wire                         m_axis_tlast,
//    output wire [MSG_WIDTH/8-1:0]       m_axis_tkeep,
//    input  wire                         m_axis_tready
//);

//    // ============================================================
//    // STATE LOGIC
//    // ============================================================
//    reg in_packet; // 0: �?ang ch�? beat �'ầu tiên, 1: �?ang ở các beat giữa

//    // C�? báo hiệu �'ây l�  nhịp dữ liệu �'ầu tiên của một packet
//    wire is_first_beat = !in_packet;

//    // ============================================================
//    // AXIS HANDSHAKE & DATA PATH (COMBINATIONAL)
//    // ============================================================
//    // Logic tvalid:
//    // - Nếu l�  beat �'ầu: Phải có CẢ msg VÀ key thì mới hợp lệ.
//    // - Nếu l�  beat giữa: Chỉ cần có msg l�  hợp lệ (key �'ã x� i xong).
//    assign m_axis_tvalid = is_first_beat ? (msg_valid && key_valid) : msg_valid;

//    // fire (handshake th� nh công): Cả ta có dữ liệu v�  phía sau �'ã nhận
//    wire fire = m_axis_tvalid && m_axis_tready;

//    // Ghép dữ liệu: Beat �'ầu �'è KEY v� o phần thấp. Các beat sau truy�?n thẳng MSG.
//    assign m_axis_tdata = is_first_beat ? {msg_data[MSG_WIDTH-1:KEY_WIDTH], key_data} : msg_data;
//    assign m_axis_tkeep = msg_keep;
//    assign m_axis_tlast = msg_last;

//    // ============================================================
//    // FIFO READ CONTROL (POP LOGIC)
//    // ============================================================
//    // Chỉ "Pop" Key khi �'ẩy th� nh công beat �'ầu tiên của packet
//    assign rd_key_en = fire && is_first_beat;

//    // MSG thì luôn luôn "Pop" m�-i khi �'ẩy th� nh công bất kỳ beat n� o
//    assign rd_msg_en = fire;

//    // ============================================================
//    // SEQUENTIAL UPDATE
//    // ============================================================
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            in_packet <= 1'b0;
//        end else begin
//            if (fire) begin
//                if (msg_last) begin
//                    // Nếu l�  beat cu�'i, reset trạng thái v�? ch�? packet mới
//                    in_packet <= 1'b0;
//                end else begin
//                    // Nếu chưa phải beat cu�'i, �'ánh dấu �'ang ở giữa packet
//                    in_packet <= 1'b1;
//                end
//            end
//        end
//    end

//endmodule

`timescale 1ns / 1ps

module sync_logic #(
    parameter MSG_WIDTH  = 512,
    parameter IP_WIDTH   = 32,
    parameter DST_IP_MSB = 271,
    parameter DST_IP_LSB = 240
)(
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [IP_WIDTH-1:0]          key_data,
    input  wire                         key_valid,
    input  wire                         key_empty,
    output wire                         rd_key_en,

    input  wire [MSG_WIDTH-1:0]         msg_data,
    input  wire                         msg_valid,
    input  wire                         msg_last,
    input  wire [MSG_WIDTH/8-1:0]       msg_keep,
    input  wire                         msg_empty,
    output wire                         rd_msg_en,

    output wire [MSG_WIDTH-1:0]         m_axis_tdata,
    output wire                         m_axis_tvalid,
    output wire                         m_axis_tlast,
    output wire [MSG_WIDTH/8-1:0]       m_axis_tkeep,
    input  wire                         m_axis_tready
);

    reg in_packet;
    reg [MSG_WIDTH-1:0] out_data_r;
    reg [MSG_WIDTH/8-1:0] out_keep_r;
    reg out_last_r;
    reg out_valid_r;
    wire is_first_beat = !in_packet;

    wire msg_ok = msg_valid && !msg_empty;
    wire key_ok = key_valid && !key_empty;

    wire have_input = is_first_beat ? (msg_ok && key_ok) : msg_ok;
    wire can_take_input = !out_valid_r || m_axis_tready;
    wire take_input = can_take_input && have_input;

    wire [MSG_WIDTH-1:0] patched_first_beat = {
        msg_data[MSG_WIDTH-1:DST_IP_MSB+1],
        key_data,
        msg_data[DST_IP_LSB-1:0]
    };

    assign m_axis_tdata  = out_data_r;
    assign m_axis_tkeep  = out_keep_r;
    assign m_axis_tlast  = out_last_r;
    assign m_axis_tvalid = out_valid_r;

    assign rd_key_en = take_input && is_first_beat;
    assign rd_msg_en = take_input;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_packet <= 1'b0;
            out_data_r <= {MSG_WIDTH{1'b0}};
            out_keep_r <= {MSG_WIDTH/8{1'b0}};
            out_last_r <= 1'b0;
            out_valid_r <= 1'b0;
        end else if (can_take_input) begin
            if (take_input) begin
                out_data_r <= is_first_beat ? patched_first_beat : msg_data;
                out_keep_r <= msg_keep;
                out_last_r <= msg_last;
                out_valid_r <= 1'b1;
                in_packet <= !msg_last;
            end else begin
                out_valid_r <= 1'b0;
            end
        end
    end

endmodule
