`timescale 1ns / 1ps
module sync_logic #(
    parameter MSG_WIDTH  = 512,
    parameter KEY_WIDTH  = 128,
    parameter DATA_WIDTH = MSG_WIDTH
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // KEY FIFO
    input  wire [KEY_WIDTH-1:0]         key_data,
    input  wire                         key_valid,
    input  wire                         key_empty,
    output reg                          rd_key_en,

    // MSG FIFO
    input  wire [MSG_WIDTH-1:0]         msg_data,
    input  wire                         msg_valid,
    input  wire                         msg_last,
    input  wire [MSG_WIDTH/8-1:0]       msg_keep,
    input  wire                         msg_empty,
    output reg                          rd_msg_en,

    // AXIS OUT
    output reg  [DATA_WIDTH-1:0]        cslb_tdata,
    output reg                          cslb_tvalid,
    output reg                          cslb_tlast,
    output reg  [MSG_WIDTH/8-1:0]       cslb_tkeep,
    input  wire                         cslb_tready
);

    //--------------------------------------------------
    // FSM
    //--------------------------------------------------
    localparam IDLE = 1'b0; // Trạng thái chờ nhịp đầu tiên (SOP)
    localparam SEND = 1'b1; // Trạng thái gửi các nhịp tiếp theo

    reg state;

    //--------------------------------------------------
    // packet counters
    //--------------------------------------------------
    reg [31:0] cnt_pkt_sop;
    reg [31:0] cnt_pkt_eop;

    wire tx_fire = cslb_tvalid & cslb_tready;

    //--------------------------------------------------
    // 1. COMBINATIONAL LOGIC CHO AXI-STREAM ROUTING
    // Không dùng clock để tránh trễ 1 nhịp và lỗi overwrite
    //--------------------------------------------------
    always @(*) begin
        // Giá trị mặc định để tránh chốt (latch)
        cslb_tvalid = 0;
        cslb_tdata  = msg_data;
        cslb_tkeep  = msg_keep;
        cslb_tlast  = msg_last;
        
        rd_msg_en   = 0;
        rd_key_en   = 0;

        case(state)
            IDLE: begin
                // Phải có cả KEY và MSG mới bắt đầu ghép gói
                if (key_valid && msg_valid) begin
                    cslb_tvalid = 1;
                    // Lấy KEY trực tiếp từ cửa sổ FWFT, không cần thanh ghi tạm
                    cslb_tdata  = {msg_data[MSG_WIDTH-1:KEY_WIDTH], key_data}; 

                    // Khi phía sau chấp nhận, Pop cả KEY và MSG cùng 1 lúc
                    if (cslb_tready) begin
                        rd_key_en = 1;
                        rd_msg_en = 1;
                    end
                end
            end

            SEND: begin
                // Các nhịp giữa: Chỉ quan tâm đến MSG
                if (msg_valid) begin
                    cslb_tvalid = 1;
                    
                    if (cslb_tready) begin
                        rd_msg_en = 1;
                    end
                end
            end
        endcase
    end

    //--------------------------------------------------
    // 2. SEQUENTIAL LOGIC CHO TRẠNG THÁI VÀ BỘ ĐẾM
    //--------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= IDLE;
            cnt_pkt_sop <= 0;
            cnt_pkt_eop <= 0;
        end
        else begin
            // Đếm gói
            if (tx_fire) begin
                if (state == IDLE)  cnt_pkt_sop <= cnt_pkt_sop + 1;
                if (cslb_tlast)     cnt_pkt_eop <= cnt_pkt_eop + 1;
            end

            // Chuyển trạng thái FSM
            case(state)
                IDLE: begin
                    // Nếu gửi thành công nhịp đầu, và không phải nhịp cuối -> Chuyển sang SEND
                    if (tx_fire && !cslb_tlast) begin
                        state <= SEND;
                    end
                end

                SEND: begin
                    // Nếu gửi thành công nhịp cuối -> Quay về IDLE đón gói mới
                    if (tx_fire && cslb_tlast) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule