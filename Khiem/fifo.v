`timescale 1ns / 1ps
module key_fifo #(
    parameter DEPTH = 8,
    parameter ALMOST_FULL_THRESH = DEPTH - 3
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
    input  wire        o_ip_full  // Tính hiệu từ phía sau: 1 = Bận không nhận, 0 = Sẵn sàng nhận
);

    localparam PTR_WIDTH = $clog2(DEPTH);
    localparam KEY_WIDTH = 104;
    
    //--------------------------------------------------
    // FIFO memory
    //--------------------------------------------------
    reg [KEY_WIDTH-1:0] mem [0:DEPTH-1];

    reg [PTR_WIDTH:0] wr_ptr;
    reg [PTR_WIDTH:0] rd_ptr;

    //--------------------------------------------------
    // Debug counters
    //--------------------------------------------------
    //reg [31:0] key_wr_count;
    //reg [31:0] key_rd_count;
    //reg [31:0] key_in_fifo;

    // (* mark_debug = "true" *) reg [31:0] overflow_count;  
    reg [31:0] overflow_count;  

    //--------------------------------------------------
    // Status
    //--------------------------------------------------
    wire empty;
    wire full;
    wire write_en;
    wire read_en;
    wire o_almost_full;
    wire [PTR_WIDTH:0] count;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
                   (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]);

    assign count = wr_ptr - rd_ptr; 
    assign o_almost_full = (count >= ALMOST_FULL_THRESH);

    // [FIX 1]: o_full chỉ phụ thuộc vào trạng thái của FIFO
    assign o_full = full || o_almost_full; 
    assign write_en = i_key_valid && !o_full; 

    //--------------------------------------------------
    // FWFT outputs (Combinational Read cho Distributed RAM)
    //--------------------------------------------------
    assign {o_src_ip, o_dst_ip, o_src_port, o_dst_port, o_protocol} = mem[rd_ptr[PTR_WIDTH-1:0]];
    
    assign o_key_valid = !empty;
    assign read_en     = !empty && !o_ip_full; 

    //--------------------------------------------------
    // Tách riêng khối ghi Memory (RAM inference an toàn)
    //--------------------------------------------------
    always @(posedge clk) begin
        if (write_en) begin
            mem[wr_ptr[PTR_WIDTH-1:0]] <= {i_src_ip, i_dst_ip, i_src_port, i_dst_port, i_protocol};
        end
    end

    //--------------------------------------------------
    // Sequential logic cho Control & Pointers
    //--------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;

            //key_wr_count <= 0;
            //key_rd_count <= 0;
            //key_in_fifo  <= 0;

            overflow_count  <= 0;
        end
        else begin
            // Bắt lỗi overflow khi upstream cố tình ghi lúc FIFO đã báo full
            if (i_key_valid && full)
                overflow_count <= overflow_count + 1;

            if (write_en) begin
                wr_ptr <= wr_ptr + 1;
                //key_wr_count <= key_wr_count + 1;
            end

            if (read_en) begin
                rd_ptr <= rd_ptr + 1;
                //key_rd_count <= key_rd_count + 1;
            end

            // Quản lý bộ đếm in_fifo an toàn
            // if (write_en && !read_en) begin
            //     key_in_fifo <= key_in_fifo + 1;
            // end
            // else if (!write_en && read_en) begin
            //     key_in_fifo <= key_in_fifo - 1;
            // end
        end
    end

endmodule


module msg_fifo #(
    parameter DEPTH = 16,
    parameter WIDTH = 512,
    parameter ALMOST_FULL_THRESH  = DEPTH - 4,
    parameter ALMOST_EMPTY_THRESH = 4           // NEW
)(
    input wire clk,
    input wire rst_n,

    // Write Interface (Slave)
    input wire [WIDTH-1:0]     s_axis_tdata,
    input wire                 s_axis_tvalid,
    input wire [WIDTH/8-1:0]   s_axis_tkeep,
    input wire                 s_axis_tlast,
    output wire                s_axis_tready,
    

    // Read Interface
    output wire [WIDTH-1:0]    msg_data,
    output wire                msg_valid,
    output wire                msg_last,
    output wire [WIDTH/8-1:0]  msg_keep,

    output wire                o_empty,
    
    input wire                 rd_msg_en
);

    //--------------------------------------------------------
    // Parameters
    //--------------------------------------------------------
    localparam KEEP_WIDTH = WIDTH / 8;
    localparam FIFO_WIDTH = WIDTH + KEEP_WIDTH + 1;
    localparam PTR_WIDTH  = $clog2(DEPTH);

    //--------------------------------------------------------
    // Memory
    //--------------------------------------------------------
    reg [FIFO_WIDTH-1:0] fifo_mem [0:DEPTH-1];

    reg [PTR_WIDTH:0] wr_ptr;
    reg [PTR_WIDTH:0] rd_ptr;

    //--------------------------------------------------------
    // Debug counters
    //--------------------------------------------------------
    //reg [31:0] msg_wr_count;
    //reg [31:0] msg_rd_count;
    //reg [31:0] msg_in_fifo;

    // (* mark_debug = "true" *)reg [31:0] overflow_count;  
    // (* mark_debug = "true" *) reg [31:0] underflow_count;
    reg [31:0] underflow_count;
    reg [31:0] overflow_count;  

    //--------------------------------------------------------
    // Status
    //--------------------------------------------------------
    wire full;
    wire empty;
    wire [PTR_WIDTH:0] count;

    assign empty   = (wr_ptr == rd_ptr);
    assign o_empty = empty;

    assign full    = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
                     (wr_ptr[PTR_WIDTH]     != rd_ptr[PTR_WIDTH]);

    assign count = wr_ptr - rd_ptr; 
    wire                o_almost_empty;
    wire                o_almost_full;
    assign o_almost_full  = (count >= ALMOST_FULL_THRESH); 
    assign o_almost_empty = (count <= ALMOST_EMPTY_THRESH); // NEW

    //assign s_axis_tready = !full; 

    reg tready_reg;

    always @(posedge clk) begin
        if (!rst_n)
            tready_reg <= 1'b1;
        else begin
            if (count >= ALMOST_FULL_THRESH)
                tready_reg <= 1'b0;
            else if (count <= ALMOST_EMPTY_THRESH)
                tready_reg <= 1'b1;
        end
    end
    assign s_axis_tready = tready_reg && !full;
    // assign s_axis_tready = tready_reg;
    //--------------------------------------------------------
    // Handshake
    //--------------------------------------------------------
    // wire write_en = s_axis_tvalid && !full;
    // wire read_en  = rd_msg_en && !empty;

    wire write_en = s_axis_tvalid && s_axis_tready; 
    wire read_en  = rd_msg_en && !empty;

    //--------------------------------------------------------
    // FWFT output
    //--------------------------------------------------------
    assign {msg_last, msg_keep, msg_data} = fifo_mem[rd_ptr[PTR_WIDTH-1:0]];
    assign msg_valid = !empty;


    always @(posedge clk) begin
            if (write_en) begin
                fifo_mem[wr_ptr[PTR_WIDTH-1:0]] <= {s_axis_tlast, s_axis_tkeep, s_axis_tdata};
            end
        end
    //--------------------------------------------------------
    // Main logic
    //--------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;

            //msg_wr_count <= 0;
            //msg_rd_count <= 0;
            //msg_in_fifo  <= 0;

            overflow_count  <= 0;
            underflow_count <= 0;
        end
        else begin

            //------------------------------------------------
            // Detect overflow / underflow
            //------------------------------------------------
            if (s_axis_tvalid && full)
                overflow_count <= overflow_count + 1;

            if (rd_msg_en && empty)
                underflow_count <= underflow_count + 1;

            //------------------------------------------------
            // WRITE
            //------------------------------------------------
            if (write_en) begin
                wr_ptr <= wr_ptr + 1;
                //msg_wr_count <= msg_wr_count + 1;
            end

            //------------------------------------------------
            // READ
            //------------------------------------------------
            if (read_en) begin
                rd_ptr <= rd_ptr + 1;
                //msg_rd_count <= msg_rd_count + 1;
            end

            //------------------------------------------------
            // Quản lý bộ đếm an toàn
            //------------------------------------------------
            // if (write_en && !read_en) begin
            //     msg_in_fifo <= msg_in_fifo + 1;
            // end
            // else if (!write_en && read_en) begin
            //     msg_in_fifo <= msg_in_fifo - 1;
            // end

        end
    end

endmodule

`timescale 1ns / 1ps
module dst_fifo #(
    parameter DEPTH = 8,
    parameter WIDTH = 128,
    parameter ALMOST_FULL_THRESH  = DEPTH - 3,
    parameter ALMOST_EMPTY_THRESH = 4           
)(
    input  wire clk,
    input  wire rst_n,

    // WRITE
    input  wire [WIDTH-1:0] wr_data,
    input  wire             wr_valid,
    output wire             wr_ready, 
    output wire             o_full,
    output wire             o_almost_full, // Đã mở comment để dùng

    // READ (FWFT)
    output wire [WIDTH-1:0] rd_data,
    output wire             rd_valid,
    output wire             o_empty,
    output wire             o_almost_empty, // Đã mở comment để dùng
    input  wire             rd_key_en
);

    localparam PTR = $clog2(DEPTH);

    //--------------------------------------------------
    // FIFO memory
    //--------------------------------------------------
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    reg [PTR:0] wr_ptr;
    reg [PTR:0] rd_ptr;

    //--------------------------------------------------
    // Debug counters
    //--------------------------------------------------
    // reg [31:0] ip_hdr_wr_count;    
    // reg [31:0] ip_hdr_rd_count;    
    // reg [31:0] ip_hdr_in_fifo;     

    // (* mark_debug = "true" *) reg [31:0] overflow_count;     
    // (* mark_debug = "true" *) reg [31:0] underflow_count;    
    reg [31:0] underflow_count;  
    reg [31:0] overflow_count;     

    //--------------------------------------------------
    // FIFO status
    //--------------------------------------------------
    wire empty = (wr_ptr == rd_ptr);

    wire full  = (wr_ptr[PTR-1:0] == rd_ptr[PTR-1:0]) &&
                 (wr_ptr[PTR]     != rd_ptr[PTR]);
                 
    wire [PTR:0] count = wr_ptr - rd_ptr; 

    // [FIX 1]: Phân định rõ ràng các trạng thái
    assign o_almost_full  = (count >= ALMOST_FULL_THRESH); 
    assign o_almost_empty = (count <= ALMOST_EMPTY_THRESH); 
    
    assign o_empty  = empty; 
    assign o_full   = full;  

    // [FIX 2]: wr_ready ngắt sớm để bảo vệ FIFO
    assign wr_ready = !full && !o_almost_full; 

    //--------------------------------------------------
    // Handshake
    //--------------------------------------------------
    wire write_en = wr_valid  && wr_ready; // Đã sửa để đồng bộ với wr_ready
    wire read_en  = rd_key_en && !empty;

    //--------------------------------------------------
    // FWFT (First Word Fall Through)
    //--------------------------------------------------
    assign rd_data  = mem[rd_ptr[PTR-1:0]];
    assign rd_valid = !empty;

    //--------------------------------------------------
    // [FIX 3]: Tách Memory Inference an toàn
    //--------------------------------------------------
    always @(posedge clk) begin
        if (write_en) begin
            mem[wr_ptr[PTR-1:0]] <= wr_data;
        end
    end

    //--------------------------------------------------
    // Sequential logic (Pointers & Counters)
    //--------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;

            // ip_hdr_wr_count <= 0;
            // ip_hdr_rd_count <= 0;
            // ip_hdr_in_fifo  <= 0;

            overflow_count  <= 0;
            underflow_count <= 0;
        end
        else begin
            //--------------------------------------------------
            // Detect overflow / underflow
            //--------------------------------------------------
            if (wr_valid && !wr_ready)
                overflow_count <= overflow_count + 1;

            if (rd_key_en && empty)
                underflow_count <= underflow_count + 1;

            //--------------------------------------------------
            // Pointers
            //--------------------------------------------------
            if (write_en) begin
                wr_ptr <= wr_ptr + 1;
                //ip_hdr_wr_count <= ip_hdr_wr_count + 1;
            end

            if (read_en) begin
                rd_ptr <= rd_ptr + 1;
                //ip_hdr_rd_count <= ip_hdr_rd_count + 1;
            end

            //--------------------------------------------------
            // Quản lý bộ đếm in_fifo an toàn
            //--------------------------------------------------
            // if (write_en && !read_en) begin
            //     ip_hdr_in_fifo <= ip_hdr_in_fifo + 1;
            // end 
            // else if (!write_en && read_en) begin
            //     ip_hdr_in_fifo <= ip_hdr_in_fifo - 1;
            // end

        end
    end

endmodule