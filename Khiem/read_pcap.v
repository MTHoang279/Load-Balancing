`timescale 1ns / 1ps

module net2axis_master #(
    // �?ư�?ng dẫn file .mem (đã convert bằng Python)
    parameter INPUTFILE   = "C:/Users/DucKhiem/Downloads/test_case/t1.mem",
    
    //ok     
//    parameter ROM_DEPTH   = 1097, 
    parameter ROM_DEPTH   = 65536,             
    parameter TDATA_WIDTH = 512
)(
    input  wire                   ACLK,
    input  wire                   ARESETN,
    input  wire                   START,

    output reg                    done_packet, // Báo xong 1 gói (khi gặp TLAST)
    output reg                    DONE,        // Báo xong toàn bộ file

    output reg                    M_AXIS_TVALID,
    output wire [TDATA_WIDTH-1:0] M_AXIS_TDATA,
    output wire [(TDATA_WIDTH/8)-1:0] M_AXIS_TKEEP,
    output wire                   M_AXIS_TLAST,
    input  wire                   M_AXIS_TREADY
);
    (* mark_debug = "true" *) reg [19:0] packet_sent_count;
    
    // --------------------------------------------------------
    // �?ịnh nghĩa độ rộng ROM cho file .mem 577 bit
    // --------------------------------------------------------
    localparam ROM_WIDTH = 1 + (TDATA_WIDTH/8) + TDATA_WIDTH; // 577 bit

    // Khai báo bộ nhớ sẽ infer thành BRAM
    (* rom_style = "block" *) reg [ROM_WIDTH-1:0] rom_memory [0:ROM_DEPTH-1];

    // Nạp dữ liệu
    initial begin
        $readmemh(INPUTFILE, rom_memory);
    end

    // Các thanh ghi đi�?u khiển
    reg [$clog2(ROM_DEPTH)-1:0] read_ptr;
    reg                         active;

    // --------------------------------------------------------
    // �?ỌC BRAM �?ỒNG BỘ (BẮT BUỘC �?Ể INFER BRAM)
    // --------------------------------------------------------
    reg [ROM_WIDTH-1:0] raw_data;
    
    // Không dùng Reset cho thanh ghi chứa dữ liệu BRAM để tiết kiệm tài nguyên
    always @(posedge ACLK) begin
        if (active) begin
            raw_data <= rom_memory[read_ptr];
        end else if (START && !active) begin
            // �?�?c nháp (Pre-fetch) data tại địa chỉ 0 ngay khi có START
            // để bù lại 1 chu kỳ trễ của BRAM
            raw_data <= rom_memory[0]; 
        end
    end

    // --------------------------------------------------------
    // Mapping dữ liệu
    // --------------------------------------------------------
    assign M_AXIS_TLAST = raw_data[576];
    assign M_AXIS_TKEEP = raw_data[575:512];
    assign M_AXIS_TDATA = raw_data[511:0];

    // --------------------------------------------------------
    // FSM (�?Ã SỬA THÀNH RESET �?ỒNG BỘ)
    // --------------------------------------------------------
    wire handshake = M_AXIS_TVALID && M_AXIS_TREADY;

    // CHÚ �?: �?ã b�? "negedge ARESETN" kh�?i sensitivity list
    always @(posedge ACLK) begin
        // Reset �?ồng Bộ (Chỉ kiểm tra ARESETN khi có cạnh lên của ACLK)
        if (!ARESETN) begin
            read_ptr          <= 0;
            active            <= 0;
            M_AXIS_TVALID     <= 0;
            done_packet       <= 0;
            DONE              <= 0;
            packet_sent_count <= 0;
        end else begin
            // Xóa c�? done_packet sau 1 chu kỳ
            done_packet <= 0;

            // Bắt đầu khi có xung START và chưa chạy xong
            if (START && !active && !DONE) begin
                active        <= 1'b1;
                M_AXIS_TVALID <= 1'b1;
                read_ptr      <= 1; // Tr�? sẵn đến địa chỉ tiếp theo vì đã pre-fetch addr 0
            end

            // Khi đang hoạt động (Data đang được stream)
            if (active) begin
                if (handshake) begin
                    // Bắt sự kiện hết 1 gói tin
                    if (M_AXIS_TLAST) begin
                        done_packet <= 1'b1;
                        packet_sent_count <= packet_sent_count + 1;
                    end

                    // Kiểm tra đi�?u kiện kết thúc
                    if (read_ptr == ROM_DEPTH -1) begin
                        active        <= 1'b0;
                        M_AXIS_TVALID <= 1'b0;
                        DONE          <= 1'b1;
                    end else begin
                        // Tăng địa chỉ
                        read_ptr <= read_ptr + 1;
                    end
                end
            end
            
            // Cơ chế Reset lại trạng thái để chạy lần 2 nếu START rớt xuống 0 rồi lên 1 lại
            if (DONE && !START) begin
                DONE     <= 0;
                read_ptr <= 0;
            end
        end
    end

endmodule