module sync_logic #(
    parameter MSG_WIDTH  = 512,
    parameter KEY_WIDTH  = 32,
    parameter DATA_WIDTH = MSG_WIDTH
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // ================= KEY FIFO (FWFT) =================
    input  wire [KEY_WIDTH-1:0]         key_data,
    input  wire                         key_valid, // Tương �'ương !key_empty
    input  wire                         key_empty,
    output wire                         rd_key_en,

    // ================= MSG FIFO (FWFT) =================
    input  wire [MSG_WIDTH-1:0]         msg_data,
    input  wire                         msg_valid, // Tương �'ương !msg_empty
    input  wire                         msg_last,
    input  wire [MSG_WIDTH/8-1:0]       msg_keep,
    input  wire                         msg_empty,
    output wire                         rd_msg_en,

    // ================= AXIS OUT =================
    // Chuyển reg -> wire �'ể passthrough dữ liệu từ FWFT ra ngo� i
    output wire [DATA_WIDTH-1:0]        m_axis_tdata,
    output wire                         m_axis_tvalid,
    output wire                         m_axis_tlast,
    output wire [MSG_WIDTH/8-1:0]       m_axis_tkeep,
    input  wire                         m_axis_tready
);

    // ============================================================
    // STATE LOGIC
    // ============================================================
    reg in_packet; // 0: �?ang ch�? beat �'ầu tiên, 1: �?ang ở các beat giữa

    // C�? báo hiệu �'ây l�  nhịp dữ liệu �'ầu tiên của một packet
    wire is_first_beat = !in_packet;

    // ============================================================
    // AXIS HANDSHAKE & DATA PATH (COMBINATIONAL)
    // ============================================================
    // Logic tvalid:
    // - Nếu l�  beat �'ầu: Phải có CẢ msg VÀ key thì mới hợp lệ.
    // - Nếu l�  beat giữa: Chỉ cần có msg l�  hợp lệ (key �'ã x� i xong).
    assign m_axis_tvalid = is_first_beat ? (msg_valid && key_valid) : msg_valid;

    // fire (handshake th� nh công): Cả ta có dữ liệu v�  phía sau �'ã nhận
    wire fire = m_axis_tvalid && m_axis_tready;

    // Ghép dữ liệu: Beat �'ầu �'è KEY v� o phần thấp. Các beat sau truy�?n thẳng MSG.
//    assign m_axis_tdata = is_first_beat ? {msg_data[MSG_WIDTH-1:KEY_WIDTH], key_data} : msg_data;
    assign m_axis_tdata = is_first_beat ? {msg_data[MSG_WIDTH-1:272], key_data, msg_data[239:0]} : msg_data;
    assign m_axis_tkeep = msg_keep;
    assign m_axis_tlast = msg_last;

    // ============================================================
    // FIFO READ CONTROL (POP LOGIC)
    // ============================================================
    // Chỉ "Pop" Key khi �'ẩy th� nh công beat �'ầu tiên của packet
    assign rd_key_en = fire && is_first_beat;

    // MSG thì luôn luôn "Pop" m�-i khi �'ẩy th� nh công bất kỳ beat n� o
    assign rd_msg_en = fire;

    // ============================================================
    // SEQUENTIAL UPDATE
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_packet <= 1'b0;
        end else begin
            if (fire) begin
                if (msg_last) begin
                    // Nếu l�  beat cu�'i, reset trạng thái v�? ch�? packet mới
                    in_packet <= 1'b0;
                end else begin
                    // Nếu chưa phải beat cu�'i, �'ánh dấu �'ang ở giữa packet
                    in_packet <= 1'b1;
                end
            end
        end
    end

endmodule