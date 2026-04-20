`timescale 1ns / 1ps

module net2axis_master #(
    // ?????ng d?n file .mem (?ã convert b?ng Python)
    parameter INPUTFILE   = "C:/Users/DucKhiem/Downloads/test_case/t1.mem",
    parameter ROM_DEPTH   = 65536,
    //ok      
    //parameter ROM_DEPTH   = 65536,             
    parameter TDATA_WIDTH = 512
)(
    input  wire                   ACLK,
    input  wire                   ARESETN,
    input  wire                   START,

    output reg                    done_packet, // Báo xong 1 gói (khi g?p TLAST)
    output reg                    DONE,        // Báo xong toàn b? file

    output reg                    M_AXIS_TVALID,
    output wire [TDATA_WIDTH-1:0] M_AXIS_TDATA,
    output wire [(TDATA_WIDTH/8)-1:0] M_AXIS_TKEEP,
    output wire                   M_AXIS_TLAST,
    input  wire                   M_AXIS_TREADY
);
    (* mark_debug = "true" *) reg [31:0] packet_sent_count;
    
    // --------------------------------------------------------
    // ???nh ngh?a ?? r?ng ROM cho file .mem 577 bit
    // --------------------------------------------------------
    localparam ROM_WIDTH = 1 + (TDATA_WIDTH/8) + TDATA_WIDTH; // 577 bit

    // Khai báo b? nh? s? infer thành BRAM
    (* rom_style = "block" *) reg [ROM_WIDTH-1:0] rom_memory [0:ROM_DEPTH-1];

    // N?p d? li?u
    initial begin
        $readmemh(INPUTFILE, rom_memory);
    end

    // Các thanh ghi ?i??u khi?n
    reg [$clog2(ROM_DEPTH)-1:0] read_ptr;
    reg                         active;

    // --------------------------------------------------------
    // ???C BRAM ???NG B? (B?T BU?C ??? INFER BRAM)
    // --------------------------------------------------------
    reg [ROM_WIDTH-1:0] raw_data;
    
    // Không dùng Reset cho thanh ghi ch?a d? li?u BRAM ?? ti?t ki?m tài nguyên
    always @(posedge ACLK) begin
        if (active) begin
            raw_data <= rom_memory[read_ptr];
        end else if (START && !active) begin
            // ????c nháp (Pre-fetch) data t?i ??a ch? 0 ngay khi có START
            // ?? bù l?i 1 chu k? tr? c?a BRAM
            raw_data <= rom_memory[0]; 
        end
    end

    // --------------------------------------------------------
    // Mapping d? li?u
    // --------------------------------------------------------
    assign M_AXIS_TLAST = raw_data[576];
    assign M_AXIS_TKEEP = raw_data[575:512];
    assign M_AXIS_TDATA = raw_data[511:0];

    // --------------------------------------------------------
    // FSM (??Ã S?A THÀNH RESET ???NG B?)
    // --------------------------------------------------------
    wire handshake = M_AXIS_TVALID && M_AXIS_TREADY;

    // CHÚ ??: ??ã b?? "negedge ARESETN" kh??i sensitivity list
    always @(posedge ACLK) begin
        // Reset ???ng B? (Ch? ki?m tra ARESETN khi có c?nh lên c?a ACLK)
        if (!ARESETN) begin
            read_ptr          <= 0;
            active            <= 0;
            M_AXIS_TVALID     <= 0;
            done_packet       <= 0;
            DONE              <= 0;
            packet_sent_count <= 0;
        end else begin
            // Xóa c?? done_packet sau 1 chu k?
            done_packet <= 0;

            // B?t ??u khi có xung START và ch?a ch?y xong
            if (START && !active && !DONE) begin
                active        <= 1'b1;
                M_AXIS_TVALID <= 1'b1;
                read_ptr      <= 1; // Tr?? s?n ??n ??a ch? ti?p theo vì ?ã pre-fetch addr 0
            end

            // Khi ?ang ho?t ??ng (Data ?ang ???c stream)
            if (active) begin
                if (handshake) begin
                    // B?t s? ki?n h?t 1 gói tin
                    if (M_AXIS_TLAST) begin
                        done_packet <= 1'b1;
                        packet_sent_count <= packet_sent_count + 1;
                    end

                    // Ki?m tra ?i??u ki?n k?t thúc
                    if (read_ptr == ROM_DEPTH -1) begin
                        active        <= 1'b0;
                        M_AXIS_TVALID <= 1'b0;
                        DONE          <= 1'b1;
                    end else begin
                        // T?ng ??a ch?
                        read_ptr <= read_ptr + 1;
                    end
                end
            end
            
            // C? ch? Reset l?i tr?ng thái ?? ch?y l?n 2 n?u START r?t xu?ng 0 r?i lên 1 l?i
            if (DONE && !START) begin
                DONE     <= 0;
                read_ptr <= 0;
            end
        end
    end

endmodule