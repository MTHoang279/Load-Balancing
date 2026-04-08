module key_fifo #(
    parameter DEPTH = 16
)(
    input  wire clk,
    input  wire rst_n,

    // -------- Write side --------
    input  wire [31:0] i_src_ip,
    input  wire [31:0] i_dst_ip,
    input  wire [15:0] i_src_port,
    input  wire [15:0] i_dst_port,
    input  wire [7:0]  i_protocol,
    input  wire        i_key_valid,
    output wire        o_full,

    // -------- Read side (FWFT) --------
    output wire [31:0] o_src_ip,
    output wire [31:0] o_dst_ip,
    output wire [15:0] o_src_port,
    output wire [15:0] o_dst_port,
    output wire [7:0]  o_protocol,
    output wire        o_key_valid,
    input  wire        o_ip_full
);

    localparam PTR_WIDTH = $clog2(DEPTH);

    // -------- FIFO memory --------
    reg [31:0] mem_src_ip    [0:DEPTH-1];
    reg [31:0] mem_dst_ip    [0:DEPTH-1];
    reg [15:0] mem_src_port  [0:DEPTH-1];
    reg [15:0] mem_dst_port  [0:DEPTH-1];
    reg [7:0]  mem_protocol [0:DEPTH-1];

    reg [PTR_WIDTH:0] wr_ptr;
    reg [PTR_WIDTH:0] rd_ptr;

    wire empty;
    wire full;
    wire write_en;
    wire read_en;

    // -------- Status --------
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
                   (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]);

    assign o_full = full;

    assign write_en = i_key_valid && !full;

    // -------- FWFT outputs --------
    assign o_src_ip    = mem_src_ip   [rd_ptr[PTR_WIDTH-1:0]];
    assign o_dst_ip    = mem_dst_ip   [rd_ptr[PTR_WIDTH-1:0]];
    assign o_src_port  = mem_src_port [rd_ptr[PTR_WIDTH-1:0]];
    assign o_dst_port  = mem_dst_port [rd_ptr[PTR_WIDTH-1:0]];
    assign o_protocol  = mem_protocol [rd_ptr[PTR_WIDTH-1:0]];
    assign o_key_valid = !empty;

    assign read_en = !empty && !o_ip_full;

    // -------- Sequential logic --------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (write_en) begin
                mem_src_ip   [wr_ptr[PTR_WIDTH-1:0]] <= i_src_ip;
                mem_dst_ip   [wr_ptr[PTR_WIDTH-1:0]] <= i_dst_ip;
                mem_src_port [wr_ptr[PTR_WIDTH-1:0]] <= i_src_port;
                mem_dst_port [wr_ptr[PTR_WIDTH-1:0]] <= i_dst_port;
                mem_protocol [wr_ptr[PTR_WIDTH-1:0]] <= i_protocol;
                wr_ptr <= wr_ptr + 1;
            end

            if (read_en) begin
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

endmodule



module msg_fifo #(
    parameter DEPTH = 16,
    parameter WIDTH = 512
)(
    input wire clk,
    input wire rst_n,

    // Write Interface (Slave)
    input wire [WIDTH-1:0]     s_axis_tdata,
    input wire                 s_axis_tvalid,
    input wire [WIDTH/8-1:0]   s_axis_tkeep,
    input wire                 s_axis_tlast,
    output wire                s_axis_tready,

    // Read Interface (Master/Message)
    output wire [WIDTH-1:0]     msg_data,
    output wire                 msg_valid,
    output wire                 msg_last,
    output wire [WIDTH/8-1:0]   msg_keep,
    output wire                o_empty,
    input wire                 rd_msg_en
);

    // --------------------------------------------------------
    // T�nh to�n k�ch th??c
    // --------------------------------------------------------
    localparam KEEP_WIDTH = WIDTH / 8;
    // T?ng ?? r?ng c?n l?u: Data + Keep + Last
    localparam FIFO_WIDTH = WIDTH + KEEP_WIDTH + 1;
    localparam PTR_WIDTH  = $clog2(DEPTH);

    // --------------------------------------------------------
    // Khai b�o b? nh? v� con tr?
    // --------------------------------------------------------
    // B? nh? l?u t?t c? th�ng tin: {tlast, tkeep, tdata}
    reg [FIFO_WIDTH-1:0] fifo_mem [0:DEPTH-1];

    // Con tr? c?n th�m 1 bit MSB ?? ph�n bi?t Full/Empty
    reg [PTR_WIDTH:0] wr_ptr;
    reg [PTR_WIDTH:0] rd_ptr;

    // --------------------------------------------------------
    // T�n hi?u ?i?u khi?n
    // --------------------------------------------------------
    wire full;
    wire empty;
    wire write_en;
    wire read_en;

    // Empty khi con tr? ghi == con tr? ??c (c? bit MSB)
    assign empty   = (wr_ptr == rd_ptr);
    assign o_empty = empty;

    // Full khi ??a ch? tr�ng nhau nh?ng bit MSB kh�c nhau (?� quay v�ng)
    assign full    = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) && 
                     (wr_ptr[PTR_WIDTH]     != rd_ptr[PTR_WIDTH]);

    assign s_axis_tready = !full;
    
    // Ch? ghi khi c� Valid v� ch?a Full
    assign write_en = s_axis_tvalid && !full;

    // Ch? ??c khi c� y�u c?u (rd_msg_en) v� ch?a Empty
    assign read_en  = rd_msg_en && !empty;

    assign {msg_last, msg_keep, msg_data} = fifo_mem[rd_ptr[PTR_WIDTH-1:0]];
    assign msg_valid = !empty;

    // --------------------------------------------------------
    // Main Logic
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;

        end else begin
            // --- WRITE OPERATION ---
            if (write_en) begin
                // G?p Data, Keep, Last v�o m?t d�ng nh?
                fifo_mem[wr_ptr[PTR_WIDTH-1:0]] <= {s_axis_tlast, s_axis_tkeep, s_axis_tdata};
                wr_ptr <= wr_ptr + 1;
            end

            // --- READ OPERATION ---
            if (read_en) begin
                // T�ch d? li?u t? b? nh? ra c�c output ri�ng bi?t
                rd_ptr    <= rd_ptr + 1;
            end 
        end
    end

endmodule



module dst_fifo #(
    parameter DEPTH = 16,
    parameter WIDTH = 128
)(
    input  wire clk,
    input  wire rst_n,

    // WRITE
    input  wire [WIDTH-1:0] wr_data,
    input  wire             wr_valid,
    output wire             o_full,

    // READ (FWFT)
    // Chuyển reg -> wire
    output wire [WIDTH-1:0] rd_data,
    output wire             rd_valid,
    output wire             o_empty,
    input  wire             rd_key_en
);

    localparam PTR = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR:0] wr_ptr, rd_ptr;

    wire empty = (wr_ptr == rd_ptr);
    wire full  = (wr_ptr[PTR-1:0] == rd_ptr[PTR-1:0]) &&
                 (wr_ptr[PTR]     != rd_ptr[PTR]);

    assign o_empty = empty;
    assign o_full  = full;

    wire read_en  = rd_key_en && !empty;
    wire write_en = wr_valid  && !full;

    // -------- FWFT logic --------
    assign rd_data  = mem[rd_ptr[PTR-1:0]];
    assign rd_valid = !empty;

    // -------- Sequential logic --------
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (write_en) begin
                mem[wr_ptr[PTR-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1;
            end
            if (read_en) begin
                rd_ptr <= rd_ptr + 1;
            end
        end
    end
endmodule

