////module key_fifo #(
////    parameter DEPTH = 16
////)(
////    input  wire clk,
////    input  wire rst_n,

////    // -------- Write side --------
////    input  wire [31:0] i_src_ip,
////    input  wire [31:0] i_dst_ip,
////    input  wire [15:0] i_src_port,
////    input  wire [15:0] i_dst_port,
////    input  wire [7:0]  i_protocol,
////    input  wire        i_key_valid,
////    output wire        o_full,

////    // -------- Read side (FWFT) --------
////    output wire [31:0] o_src_ip,
////    output wire [31:0] o_dst_ip,
////    output wire [15:0] o_src_port,
////    output wire [15:0] o_dst_port,
////    output wire [7:0]  o_protocol,
////    output wire        o_key_valid,
////    input  wire        o_ip_full
////);

////    localparam PTR_WIDTH = $clog2(DEPTH);

////    // -------- FIFO memory --------
////    reg [31:0] mem_src_ip    [0:DEPTH-1];
////    reg [31:0] mem_dst_ip    [0:DEPTH-1];
////    reg [15:0] mem_src_port  [0:DEPTH-1];
////    reg [15:0] mem_dst_port  [0:DEPTH-1];
////    reg [7:0]  mem_protocol [0:DEPTH-1];

////    reg [PTR_WIDTH:0] wr_ptr;
////    reg [PTR_WIDTH:0] rd_ptr;

////    wire empty;
////    wire full;
////    wire write_en;
////    wire read_en;

////    // -------- Status --------
////    assign empty = (wr_ptr == rd_ptr);
////    assign full  = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
////                   (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]);

////    assign o_full = full;

////    assign write_en = i_key_valid && !full;

////    // -------- FWFT outputs --------
////    assign o_src_ip    = mem_src_ip   [rd_ptr[PTR_WIDTH-1:0]];
////    assign o_dst_ip    = mem_dst_ip   [rd_ptr[PTR_WIDTH-1:0]];
////    assign o_src_port  = mem_src_port [rd_ptr[PTR_WIDTH-1:0]];
////    assign o_dst_port  = mem_dst_port [rd_ptr[PTR_WIDTH-1:0]];
////    assign o_protocol  = mem_protocol [rd_ptr[PTR_WIDTH-1:0]];
////    assign o_key_valid = !empty;

////    assign read_en = !empty && !o_ip_full;
    
////    (* mark_debug = "true" *) reg [31:0] overflow_count;
////    (* mark_debug = "true" *) reg [31:0] underflow_count;

////    // -------- Sequential logic --------
////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin
////            wr_ptr <= 0;
////            rd_ptr <= 0;
////            overflow_count <= 0;
////            underflow_count <= 0;
////        end else begin
////            if (write_en) begin
////                mem_src_ip   [wr_ptr[PTR_WIDTH-1:0]] <= i_src_ip;
////                mem_dst_ip   [wr_ptr[PTR_WIDTH-1:0]] <= i_dst_ip;
////                mem_src_port [wr_ptr[PTR_WIDTH-1:0]] <= i_src_port;
////                mem_dst_port [wr_ptr[PTR_WIDTH-1:0]] <= i_dst_port;
////                mem_protocol [wr_ptr[PTR_WIDTH-1:0]] <= i_protocol;
////                wr_ptr <= wr_ptr + 1;
////            end
            
////            if (i_key_valid && full) overflow_count <= overflow_count + 1;

////            if (read_en) begin
////                rd_ptr <= rd_ptr + 1;
////            end
            
////            if (!empty && o_ip_full) begin
////                underflow_count <= underflow_count + 1;
////            end
////        end
////    end

////endmodule



////module msg_fifo #(
////    parameter DEPTH = 16,
////    parameter WIDTH = 512
////)(
////    input wire clk,
////    input wire rst_n,

////    // Write Interface (Slave)
////    input wire [WIDTH-1:0]     s_axis_tdata,
////    input wire                 s_axis_tvalid,
////    input wire [WIDTH/8-1:0]   s_axis_tkeep,
////    input wire                 s_axis_tlast,
////    output wire                s_axis_tready,

////    // Read Interface (Master/Message)
////    output wire [WIDTH-1:0]     msg_data,
////    output wire                 msg_valid,
////    output wire                 msg_last,
////    output wire [WIDTH/8-1:0]   msg_keep,
////    output wire                o_empty,
////    input wire                 rd_msg_en
////);

////    // --------------------------------------------------------
////    // Tï¿½nh toï¿½n kï¿½ch th??c
////    // --------------------------------------------------------
////    localparam KEEP_WIDTH = WIDTH / 8;
////    // T?ng ?? r?ng c?n l?u: Data + Keep + Last
////    localparam FIFO_WIDTH = WIDTH + KEEP_WIDTH + 1;
////    localparam PTR_WIDTH  = $clog2(DEPTH);

////    // --------------------------------------------------------
////    // Khai bï¿½o b? nh? vï¿½ con tr?
////    // --------------------------------------------------------
////    // B? nh? l?u t?t c? thï¿½ng tin: {tlast, tkeep, tdata}
////    reg [FIFO_WIDTH-1:0] fifo_mem [0:DEPTH-1];

////    // Con tr? c?n thï¿½m 1 bit MSB ?? phï¿½n bi?t Full/Empty
////    reg [PTR_WIDTH:0] wr_ptr;
////    reg [PTR_WIDTH:0] rd_ptr;

////    // --------------------------------------------------------
////    // Tï¿½n hi?u ?i?u khi?n
////    // --------------------------------------------------------
////    wire full;
////    wire empty;
////    wire write_en;
////    wire read_en;

////    // Empty khi con tr? ghi == con tr? ??c (c? bit MSB)
////    assign empty   = (wr_ptr == rd_ptr);
////    assign o_empty = empty;

////    // Full khi ??a ch? trï¿½ng nhau nh?ng bit MSB khï¿½c nhau (?ï¿½ quay vï¿½ng)
////    assign full    = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) && 
////                     (wr_ptr[PTR_WIDTH]     != rd_ptr[PTR_WIDTH]);

////    assign s_axis_tready = !full;
    
////    // Ch? ghi khi cï¿½ Valid vï¿½ ch?a Full
////    assign write_en = s_axis_tvalid && !full;

////    // Ch? ??c khi cï¿½ yï¿½u c?u (rd_msg_en) vï¿½ ch?a Empty
////    assign read_en  = rd_msg_en && !empty;

////    assign {msg_last, msg_keep, msg_data} = fifo_mem[rd_ptr[PTR_WIDTH-1:0]];
////    assign msg_valid = !empty;
    
////    (* mark_debug = "true" *) reg [31:0] overflow_count;
////    (* mark_debug = "true" *) reg [31:0] underflow_count;

////    // --------------------------------------------------------
////    // Main Logic
////    // --------------------------------------------------------
////    always @(posedge clk) begin
////        if (!rst_n) begin
////            wr_ptr    <= 0;
////            rd_ptr    <= 0;
////            overflow_count <= 0;
////            underflow_count <= 0;

////        end else begin
////            // --- WRITE OPERATION ---
////            if (write_en) begin
////                // G?p Data, Keep, Last vï¿½o m?t dï¿½ng nh?
////                fifo_mem[wr_ptr[PTR_WIDTH-1:0]] <= {s_axis_tlast, s_axis_tkeep, s_axis_tdata};
////                wr_ptr <= wr_ptr + 1;
////            end
            
////            if (s_axis_tvalid && full) overflow_count <= overflow_count + 1;

////            // --- READ OPERATION ---
////            if (read_en) begin
////                // Tï¿½ch d? li?u t? b? nh? ra cï¿½c output riï¿½ng bi?t
////                rd_ptr    <= rd_ptr + 1;
////            end 
            
////            if (rd_msg_en && empty) underflow_count <= underflow_count + 1;
////        end
////    end

////endmodule



////module dst_fifo #(
////    parameter DEPTH = 16,
////    parameter WIDTH = 128
////)(
////    input  wire clk,
////    input  wire rst_n,

////    // WRITE
////    input  wire [WIDTH-1:0] wr_data,
////    input  wire             wr_valid,
////    output wire             o_full,

////    // READ (FWFT)
////    // Chuyá»ƒn reg -> wire
////    output wire [WIDTH-1:0] rd_data,
////    output wire             rd_valid,
////    output wire             o_empty,
////    input  wire             rd_key_en
////);

////    localparam PTR = $clog2(DEPTH);

////    reg [WIDTH-1:0] mem [0:DEPTH-1];
////    reg [PTR:0] wr_ptr, rd_ptr;

////    wire empty = (wr_ptr == rd_ptr);
////    wire full  = (wr_ptr[PTR-1:0] == rd_ptr[PTR-1:0]) &&
////                 (wr_ptr[PTR]     != rd_ptr[PTR]);

////    assign o_empty = empty;
////    assign o_full  = full;

////    wire read_en  = rd_key_en && !empty;
////    wire write_en = wr_valid  && !full;

////    // -------- FWFT logic --------
////    assign rd_data  = mem[rd_ptr[PTR-1:0]];
////    assign rd_valid = !empty;
    
////    (* mark_debug = "true" *) reg [31:0] overflow_count;
////    (* mark_debug = "true" *) reg [31:0] underflow_count;

////    // -------- Sequential logic --------
////    always @(posedge clk) begin
////        if (!rst_n) begin
////            wr_ptr <= 0;
////            rd_ptr <= 0;
////            overflow_count <= 0;
////            underflow_count <= 0;
////        end else begin
////            if (write_en) begin
////                mem[wr_ptr[PTR-1:0]] <= wr_data;
////                wr_ptr <= wr_ptr + 1;
////            end
            
////            if (wr_valid && full)
////                overflow_count <= overflow_count + 1;
            
////            if (read_en) begin
////                rd_ptr <= rd_ptr + 1;
////            end
            
////            if (rd_key_en && empty)
////                underflow_count <= underflow_count + 1;
////        end
////    end
////endmodule


//`timescale 1ns / 1ps
//module key_fifo #(
//    parameter DEPTH = 8,
//    parameter ALMOST_FULL_THRESH = DEPTH - 3
//)(
//    input  wire clk,
//    input  wire rst_n,

//    // -------- Write side --------
//    input  wire [31:0] i_src_ip,
//    input  wire [31:0] i_dst_ip,
//    input  wire [15:0] i_src_port,
//    input  wire [15:0] i_dst_port,
//    input  wire [7:0]  i_protocol,

//    input  wire        i_key_valid,
//    output wire        o_full,

//    // -------- Read side (FWFT) --------
//    output wire [31:0] o_src_ip,
//    output wire [31:0] o_dst_ip,
//    output wire [15:0] o_src_port,
//    output wire [15:0] o_dst_port,
//    output wire [7:0]  o_protocol,

//    output wire        o_key_valid,
//    input  wire        o_ip_full  // Tính hi?u t? phía sau: 1 = B?n không nh?n, 0 = S?n sàng nh?n
//);

//    localparam PTR_WIDTH = $clog2(DEPTH);
//    localparam KEY_WIDTH = 104;
    
//    //--------------------------------------------------
//    // FIFO memory
//    //--------------------------------------------------
//    reg [KEY_WIDTH-1:0] mem [0:DEPTH-1];

//    reg [PTR_WIDTH:0] wr_ptr;
//    reg [PTR_WIDTH:0] rd_ptr;

//    //--------------------------------------------------
//    // Debug counters
//    //--------------------------------------------------
//    reg [31:0] key_wr_count;
//    reg [31:0] key_rd_count;
//    reg [31:0] key_in_fifo;

//    (* mark_debug = "true" *) reg [31:0] overflow_count;  

//    //--------------------------------------------------
//    // Status
//    //--------------------------------------------------
//    wire empty;
//    wire full;
//    wire write_en;
//    wire read_en;
//    wire o_almost_full;
//    wire [PTR_WIDTH:0] count;

//    assign empty = (wr_ptr == rd_ptr);
//    assign full  = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
//                   (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]);

//    assign count = wr_ptr - rd_ptr; 
//    assign o_almost_full = (count >= ALMOST_FULL_THRESH);

//    // [FIX 1]: o_full ch? ph? thu?c vào tr?ng thái c?a FIFO
//    assign o_full = full || o_almost_full; 
//    assign write_en = i_key_valid && !o_full; 

//    //--------------------------------------------------
//    // FWFT outputs (Combinational Read cho Distributed RAM)
//    //--------------------------------------------------
//    assign {o_src_ip, o_dst_ip, o_src_port, o_dst_port, o_protocol} = mem[rd_ptr[PTR_WIDTH-1:0]];
    
//    assign o_key_valid = !empty;
//    assign read_en     = !empty && !o_ip_full; 

//    //--------------------------------------------------
//    // Tách riêng kh?i ghi Memory (RAM inference an toàn)
//    //--------------------------------------------------
//    always @(posedge clk) begin
//        if (write_en) begin
//            mem[wr_ptr[PTR_WIDTH-1:0]] <= {i_src_ip, i_dst_ip, i_src_port, i_dst_port, i_protocol};
//        end
//    end

//    //--------------------------------------------------
//    // Sequential logic cho Control & Pointers
//    //--------------------------------------------------
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            wr_ptr <= 0;
//            rd_ptr <= 0;

//            key_wr_count <= 0;
//            key_rd_count <= 0;
//            key_in_fifo  <= 0;

//            overflow_count  <= 0;
//        end
//        else begin
//            // B?t l?i overflow khi upstream c? tình ghi lúc FIFO ?ã báo full
//            if (i_key_valid && full)
//                overflow_count <= overflow_count + 1;

//            if (write_en) begin
//                wr_ptr <= wr_ptr + 1;
//                key_wr_count <= key_wr_count + 1;
//            end

//            if (read_en) begin
//                rd_ptr <= rd_ptr + 1;
//                key_rd_count <= key_rd_count + 1;
//            end

//            // Qu?n lý b? ??m in_fifo an toàn
//            if (write_en && !read_en) begin
//                key_in_fifo <= key_in_fifo + 1;
//            end
//            else if (!write_en && read_en) begin
//                key_in_fifo <= key_in_fifo - 1;
//            end
//        end
//    end

//endmodule


//module msg_fifo #(
//    parameter DEPTH = 16,
//    parameter WIDTH = 512,
//    parameter ALMOST_FULL_THRESH  = DEPTH - 4,
//    parameter ALMOST_EMPTY_THRESH = 4           // NEW
//)(
//    input wire clk,
//    input wire rst_n,

//    // Write Interface (Slave)
//    input wire [WIDTH-1:0]     s_axis_tdata,
//    input wire                 s_axis_tvalid,
//    input wire [WIDTH/8-1:0]   s_axis_tkeep,
//    input wire                 s_axis_tlast,
//    output wire                s_axis_tready,
    

//    // Read Interface
//    output wire [WIDTH-1:0]    msg_data,
//    output wire                msg_valid,
//    output wire                msg_last,
//    output wire [WIDTH/8-1:0]  msg_keep,

//    output wire                o_empty,
    
//    input wire                 rd_msg_en
//);

//    //--------------------------------------------------------
//    // Parameters
//    //--------------------------------------------------------
//    localparam KEEP_WIDTH = WIDTH / 8;
//    localparam FIFO_WIDTH = WIDTH + KEEP_WIDTH + 1;
//    localparam PTR_WIDTH  = $clog2(DEPTH);

//    //--------------------------------------------------------
//    // Memory
//    //--------------------------------------------------------
//    reg [FIFO_WIDTH-1:0] fifo_mem [0:DEPTH-1];

//    reg [PTR_WIDTH:0] wr_ptr;
//    reg [PTR_WIDTH:0] rd_ptr;

//    //--------------------------------------------------------
//    // Debug counters
//    //--------------------------------------------------------
//    reg [31:0] msg_wr_count;
//    reg [31:0] msg_rd_count;
//    reg [31:0] msg_in_fifo;

//    (* mark_debug = "true" *)reg [31:0] overflow_count;  
//    (* mark_debug = "true" *) reg [31:0] underflow_count;

//    //--------------------------------------------------------
//    // Status
//    //--------------------------------------------------------
//    wire full;
//    wire empty;
//    wire [PTR_WIDTH:0] count;

//    assign empty   = (wr_ptr == rd_ptr);
//    assign o_empty = empty;

//    assign full    = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
//                     (wr_ptr[PTR_WIDTH]     != rd_ptr[PTR_WIDTH]);

//    assign count = wr_ptr - rd_ptr; 
//    wire                o_almost_empty;
//    wire                o_almost_full;
//    assign o_almost_full  = (count >= ALMOST_FULL_THRESH); 
//    assign o_almost_empty = (count <= ALMOST_EMPTY_THRESH); // NEW

//    //assign s_axis_tready = !full; 

//    reg tready_reg;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n)
//            tready_reg <= 1'b1;
//        else begin
//            if (count >= ALMOST_FULL_THRESH)
//                tready_reg <= 1'b0;
//            else if (count <= ALMOST_EMPTY_THRESH)
//                tready_reg <= 1'b1;
//        end
//    end
//    assign s_axis_tready = tready_reg && !full;
//    // assign s_axis_tready = tready_reg;
//    //--------------------------------------------------------
//    // Handshake
//    //--------------------------------------------------------
//    // wire write_en = s_axis_tvalid && !full;
//    // wire read_en  = rd_msg_en && !empty;

//    wire write_en = s_axis_tvalid && s_axis_tready; 
//    wire read_en  = rd_msg_en && !empty;

//    //--------------------------------------------------------
//    // FWFT output
//    //--------------------------------------------------------
//    assign {msg_last, msg_keep, msg_data} = fifo_mem[rd_ptr[PTR_WIDTH-1:0]];
//    assign msg_valid = !empty;


//    always @(posedge clk) begin
//            if (write_en) begin
//                fifo_mem[wr_ptr[PTR_WIDTH-1:0]] <= {s_axis_tlast, s_axis_tkeep, s_axis_tdata};
//            end
//        end
//    //--------------------------------------------------------
//    // Main logic
//    //--------------------------------------------------------
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            wr_ptr <= 0;
//            rd_ptr <= 0;

//            msg_wr_count <= 0;
//            msg_rd_count <= 0;
//            msg_in_fifo  <= 0;

//            overflow_count  <= 0;
//            underflow_count <= 0;
//        end
//        else begin

//            //------------------------------------------------
//            // Detect overflow / underflow
//            //------------------------------------------------
//            if (s_axis_tvalid && full)
//                overflow_count <= overflow_count + 1;

//            if (rd_msg_en && empty)
//                underflow_count <= underflow_count + 1;

//            //------------------------------------------------
//            // WRITE
//            //------------------------------------------------
//            if (write_en) begin
//                wr_ptr <= wr_ptr + 1;
//                msg_wr_count <= msg_wr_count + 1;
//            end

//            //------------------------------------------------
//            // READ
//            //------------------------------------------------
//            if (read_en) begin
//                rd_ptr <= rd_ptr + 1;
//                msg_rd_count <= msg_rd_count + 1;
//            end

//            //------------------------------------------------
//            // Qu?n lý b? ??m an toàn
//            //------------------------------------------------
//            if (write_en && !read_en) begin
//                msg_in_fifo <= msg_in_fifo + 1;
//            end
//            else if (!write_en && read_en) begin
//                msg_in_fifo <= msg_in_fifo - 1;
//            end

//        end
//    end

//endmodule

//`timescale 1ns / 1ps
//module dst_fifo #(
//    parameter DEPTH = 8,
//    parameter WIDTH = 128,
//    parameter ALMOST_FULL_THRESH  = DEPTH - 3,
//    parameter ALMOST_EMPTY_THRESH = 4           
//)(
//    input  wire clk,
//    input  wire rst_n,

//    // WRITE
//    input  wire [WIDTH-1:0] wr_data,
//    input  wire             wr_valid,
//    output wire             wr_ready, 
//    output wire             o_full,
//    output wire             o_almost_full, // ?ã m? comment ?? dùng

//    // READ (FWFT)
//    output wire [WIDTH-1:0] rd_data,
//    output wire             rd_valid,
//    output wire             o_empty,
//    output wire             o_almost_empty, // ?ã m? comment ?? dùng
//    input  wire             rd_key_en
//);

//    localparam PTR = $clog2(DEPTH);

//    //--------------------------------------------------
//    // FIFO memory
//    //--------------------------------------------------
//    reg [WIDTH-1:0] mem [0:DEPTH-1];

//    reg [PTR:0] wr_ptr;
//    reg [PTR:0] rd_ptr;

//    //--------------------------------------------------
//    // Debug counters
//    //--------------------------------------------------
//    reg [31:0] ip_hdr_wr_count;    
//    reg [31:0] ip_hdr_rd_count;    
//    reg [31:0] ip_hdr_in_fifo;     

//    (* mark_debug = "true" *) reg [31:0] overflow_count;     
//    (* mark_debug = "true" *) reg [31:0] underflow_count;    

//    //--------------------------------------------------
//    // FIFO status
//    //--------------------------------------------------
//    wire empty = (wr_ptr == rd_ptr);

//    wire full  = (wr_ptr[PTR-1:0] == rd_ptr[PTR-1:0]) &&
//                 (wr_ptr[PTR]     != rd_ptr[PTR]);
                 
//    wire [PTR:0] count = wr_ptr - rd_ptr; 

//    // [FIX 1]: Phân ??nh rõ ràng các tr?ng thái
//    assign o_almost_full  = (count >= ALMOST_FULL_THRESH); 
//    assign o_almost_empty = (count <= ALMOST_EMPTY_THRESH); 
    
//    assign o_empty  = empty; 
//    assign o_full   = full;  

//    // [FIX 2]: wr_ready ng?t s?m ?? b?o v? FIFO
//    assign wr_ready = !full && !o_almost_full; 

//    //--------------------------------------------------
//    // Handshake
//    //--------------------------------------------------
//    wire write_en = wr_valid  && wr_ready; // ?ã s?a ?? ??ng b? v?i wr_ready
//    wire read_en  = rd_key_en && !empty;

//    //--------------------------------------------------
//    // FWFT (First Word Fall Through)
//    //--------------------------------------------------
//    assign rd_data  = mem[rd_ptr[PTR-1:0]];
//    assign rd_valid = !empty;

//    //--------------------------------------------------
//    // [FIX 3]: Tách Memory Inference an toàn
//    //--------------------------------------------------
//    always @(posedge clk) begin
//        if (write_en) begin
//            mem[wr_ptr[PTR-1:0]] <= wr_data;
//        end
//    end

//    //--------------------------------------------------
//    // Sequential logic (Pointers & Counters)
//    //--------------------------------------------------
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            wr_ptr <= 0;
//            rd_ptr <= 0;

//            ip_hdr_wr_count <= 0;
//            ip_hdr_rd_count <= 0;
//            ip_hdr_in_fifo  <= 0;

//            overflow_count  <= 0;
//            underflow_count <= 0;
//        end
//        else begin
//            //--------------------------------------------------
//            // Detect overflow / underflow
//            //--------------------------------------------------
//            if (wr_valid && !wr_ready)
//                overflow_count <= overflow_count + 1;

//            if (rd_key_en && empty)
//                underflow_count <= underflow_count + 1;

//            //--------------------------------------------------
//            // Pointers
//            //--------------------------------------------------
//            if (write_en) begin
//                wr_ptr <= wr_ptr + 1;
//                ip_hdr_wr_count <= ip_hdr_wr_count + 1;
//            end

//            if (read_en) begin
//                rd_ptr <= rd_ptr + 1;
//                ip_hdr_rd_count <= ip_hdr_rd_count + 1;
//            end

//            //--------------------------------------------------
//            // Qu?n lý b? ??m in_fifo an toàn
//            //--------------------------------------------------
//            if (write_en && !read_en) begin
//                ip_hdr_in_fifo <= ip_hdr_in_fifo + 1;
//            end 
//            else if (!write_en && read_en) begin
//                ip_hdr_in_fifo <= ip_hdr_in_fifo - 1;
//            end

//        end
//    end

//endmodule 

//module key_fifo #(
//    parameter DEPTH = 16
//)(
//    input  wire clk,
//    input  wire rst_n,

//    // -------- Write side --------
//    input  wire [31:0] i_src_ip,
//    input  wire [31:0] i_dst_ip,
//    input  wire [15:0] i_src_port,
//    input  wire [15:0] i_dst_port,
//    input  wire [7:0]  i_protocol,
//    input  wire        i_key_valid,
//    output wire        o_full,

//    // -------- Read side (FWFT) --------
//    output wire [31:0] o_src_ip,
//    output wire [31:0] o_dst_ip,
//    output wire [15:0] o_src_port,
//    output wire [15:0] o_dst_port,
//    output wire [7:0]  o_protocol,
//    output wire        o_key_valid,
//    input  wire        o_ip_full
//);

//    localparam PTR_WIDTH = $clog2(DEPTH);

//    // -------- FIFO memory --------
//    reg [31:0] mem_src_ip    [0:DEPTH-1];
//    reg [31:0] mem_dst_ip    [0:DEPTH-1];
//    reg [15:0] mem_src_port  [0:DEPTH-1];
//    reg [15:0] mem_dst_port  [0:DEPTH-1];
//    reg [7:0]  mem_protocol [0:DEPTH-1];

//    reg [PTR_WIDTH:0] wr_ptr;
//    reg [PTR_WIDTH:0] rd_ptr;

//    wire empty;
//    wire full;
//    wire write_en;
//    wire read_en;

//    // -------- Status --------
//    assign empty = (wr_ptr == rd_ptr);
//    assign full  = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
//                   (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]);

//    assign o_full = full;

//    assign write_en = i_key_valid && !full;

//    // -------- FWFT outputs --------
//    assign o_src_ip    = mem_src_ip   [rd_ptr[PTR_WIDTH-1:0]];
//    assign o_dst_ip    = mem_dst_ip   [rd_ptr[PTR_WIDTH-1:0]];
//    assign o_src_port  = mem_src_port [rd_ptr[PTR_WIDTH-1:0]];
//    assign o_dst_port  = mem_dst_port [rd_ptr[PTR_WIDTH-1:0]];
//    assign o_protocol  = mem_protocol [rd_ptr[PTR_WIDTH-1:0]];
//    assign o_key_valid = !empty;

//    assign read_en = !empty && !o_ip_full;
    
//    (* mark_debug = "true" *) reg [31:0] overflow_count;
//    (* mark_debug = "true" *) reg [31:0] underflow_count;

//    // -------- Sequential logic --------
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            wr_ptr <= 0;
//            rd_ptr <= 0;
//            overflow_count <= 0;
//            underflow_count <= 0;
//        end else begin
//            if (write_en) begin
//                mem_src_ip   [wr_ptr[PTR_WIDTH-1:0]] <= i_src_ip;
//                mem_dst_ip   [wr_ptr[PTR_WIDTH-1:0]] <= i_dst_ip;
//                mem_src_port [wr_ptr[PTR_WIDTH-1:0]] <= i_src_port;
//                mem_dst_port [wr_ptr[PTR_WIDTH-1:0]] <= i_dst_port;
//                mem_protocol [wr_ptr[PTR_WIDTH-1:0]] <= i_protocol;
//                wr_ptr <= wr_ptr + 1;
//            end
            
//            if (i_key_valid && full) overflow_count <= overflow_count + 1;

//            if (read_en) begin
//                rd_ptr <= rd_ptr + 1;
//            end
            
//            if (!empty && o_ip_full) begin
//                underflow_count <= underflow_count + 1;
//            end
//        end
//    end

//endmodule



//module msg_fifo #(
//    parameter DEPTH = 16,
//    parameter WIDTH = 512
//)(
//    input wire clk,
//    input wire rst_n,

//    // Write Interface (Slave)
//    input wire [WIDTH-1:0]     s_axis_tdata,
//    input wire                 s_axis_tvalid,
//    input wire [WIDTH/8-1:0]   s_axis_tkeep,
//    input wire                 s_axis_tlast,
//    output wire                s_axis_tready,

//    // Read Interface (Master/Message)
//    output wire [WIDTH-1:0]     msg_data,
//    output wire                 msg_valid,
//    output wire                 msg_last,
//    output wire [WIDTH/8-1:0]   msg_keep,
//    output wire                o_empty,
//    input wire                 rd_msg_en
//);

//    // --------------------------------------------------------
//    // T?nh to?n k?ch th??c
//    // --------------------------------------------------------
//    localparam KEEP_WIDTH = WIDTH / 8;
//    // T?ng ?? r?ng c?n l?u: Data + Keep + Last
//    localparam FIFO_WIDTH = WIDTH + KEEP_WIDTH + 1;
//    localparam PTR_WIDTH  = $clog2(DEPTH);

//    // --------------------------------------------------------
//    // Khai b?o b? nh? v? con tr?
//    // --------------------------------------------------------
//    // B? nh? l?u t?t c? th?ng tin: {tlast, tkeep, tdata}
//    reg [FIFO_WIDTH-1:0] fifo_mem [0:DEPTH-1];

//    // Con tr? c?n th?m 1 bit MSB ?? ph?n bi?t Full/Empty
//    reg [PTR_WIDTH:0] wr_ptr;
//    reg [PTR_WIDTH:0] rd_ptr;

//    // --------------------------------------------------------
//    // T?n hi?u ?i?u khi?n
//    // --------------------------------------------------------
//    wire full;
//    wire empty;
//    wire write_en;
//    wire read_en;

//    // Empty khi con tr? ghi == con tr? ??c (c? bit MSB)
//    assign empty   = (wr_ptr == rd_ptr);
//    assign o_empty = empty;

//    // Full khi ??a ch? tr?ng nhau nh?ng bit MSB kh?c nhau (?? quay v?ng)
//    assign full    = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) && 
//                     (wr_ptr[PTR_WIDTH]     != rd_ptr[PTR_WIDTH]);

//    assign s_axis_tready = !full;
    
//    // Ch? ghi khi c? Valid v? ch?a Full
//    assign write_en = s_axis_tvalid && !full;

//    // Ch? ??c khi c? y?u c?u (rd_msg_en) v? ch?a Empty
//    assign read_en  = rd_msg_en && !empty;

//    assign {msg_last, msg_keep, msg_data} = fifo_mem[rd_ptr[PTR_WIDTH-1:0]];
//    assign msg_valid = !empty;
    
//    (* mark_debug = "true" *) reg [31:0] overflow_count;
//    (* mark_debug = "true" *) reg [31:0] underflow_count;

//    // --------------------------------------------------------
//    // Main Logic
//    // --------------------------------------------------------
//    always @(posedge clk) begin
//        if (!rst_n) begin
//            wr_ptr    <= 0;
//            rd_ptr    <= 0;
//            overflow_count <= 0;
//            underflow_count <= 0;

//        end else begin
//            // --- WRITE OPERATION ---
//            if (write_en) begin
//                // G?p Data, Keep, Last v?o m?t d?ng nh?
//                fifo_mem[wr_ptr[PTR_WIDTH-1:0]] <= {s_axis_tlast, s_axis_tkeep, s_axis_tdata};
//                wr_ptr <= wr_ptr + 1;
//            end
            
//            if (s_axis_tvalid && full) overflow_count <= overflow_count + 1;

//            // --- READ OPERATION ---
//            if (read_en) begin
//                // T?ch d? li?u t? b? nh? ra c?c output ri?ng bi?t
//                rd_ptr    <= rd_ptr + 1;
//            end 
            
//            if (rd_msg_en && empty) underflow_count <= underflow_count + 1;
//        end
//    end

//endmodule



//module dst_fifo #(
//    parameter DEPTH = 16,
//    parameter WIDTH = 128
//)(
//    input  wire clk,
//    input  wire rst_n,

//    // WRITE
//    input  wire [WIDTH-1:0] wr_data,
//    input  wire             wr_valid,
//    output wire             o_full,

//    // READ (FWFT)
//    // Chuy?n reg -> wire
//    output wire [WIDTH-1:0] rd_data,
//    output wire             rd_valid,
//    output wire             o_empty,
//    input  wire             rd_key_en
//);

//    localparam PTR = $clog2(DEPTH);

//    reg [WIDTH-1:0] mem [0:DEPTH-1];
//    reg [PTR:0] wr_ptr, rd_ptr;

//    wire empty = (wr_ptr == rd_ptr);
//    wire full  = (wr_ptr[PTR-1:0] == rd_ptr[PTR-1:0]) &&
//                 (wr_ptr[PTR]     != rd_ptr[PTR]);

//    assign o_empty = empty;
//    assign o_full  = full;

//    wire read_en  = rd_key_en && !empty;
//    wire write_en = wr_valid  && !full;

//    // -------- FWFT logic --------
//    assign rd_data  = mem[rd_ptr[PTR-1:0]];
//    assign rd_valid = !empty;
    
//    (* mark_debug = "true" *) reg [31:0] overflow_count;
//    (* mark_debug = "true" *) reg [31:0] underflow_count;

//    // -------- Sequential logic --------
//    always @(posedge clk) begin
//        if (!rst_n) begin
//            wr_ptr <= 0;
//            rd_ptr <= 0;
//            overflow_count <= 0;
//            underflow_count <= 0;
//        end else begin
//            if (write_en) begin
//                mem[wr_ptr[PTR-1:0]] <= wr_data;
//                wr_ptr <= wr_ptr + 1;
//            end
            
//            if (wr_valid && full)
//                overflow_count <= overflow_count + 1;
            
//            if (read_en) begin
//                rd_ptr <= rd_ptr + 1;
//            end
            
//            if (rd_key_en && empty)
//                underflow_count <= underflow_count + 1;
//        end
//    end
//endmodule


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
    input  wire        o_ip_full  // T?nh hi?u t? ph?a sau: 1 = B?n kh?ng nh?n, 0 = S?n s?ng nh?n
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
    reg [31:0] key_wr_count;
    reg [31:0] key_rd_count;
    reg [31:0] key_in_fifo;

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

    // [FIX 1]: o_full ch? ph? thu?c v?o tr?ng th?i c?a FIFO
    assign o_full = full || o_almost_full; 
    assign write_en = i_key_valid && !o_full; 

    //--------------------------------------------------
    // FWFT outputs (Combinational Read cho Distributed RAM)
    //--------------------------------------------------
    assign {o_src_ip, o_dst_ip, o_src_port, o_dst_port, o_protocol} = mem[rd_ptr[PTR_WIDTH-1:0]];
    
    assign o_key_valid = !empty;
    assign read_en     = !empty && !o_ip_full; 

    //--------------------------------------------------
    // T?ch ri?ng kh?i ghi Memory (RAM inference an to?n)
    //--------------------------------------------------
    always @(posedge clk) begin
        if (write_en) begin
            mem[wr_ptr[PTR_WIDTH-1:0]] <= {i_src_ip, i_dst_ip, i_src_port, i_dst_port, i_protocol};
        end
    end

    //--------------------------------------------------
    // Sequential logic cho Control & Pointers
    //--------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;

            key_wr_count <= 0;
            key_rd_count <= 0;
            key_in_fifo  <= 0;

            overflow_count  <= 0;
        end
        else begin
            // B?t l?i overflow khi upstream c? t?nh ghi l?c FIFO ?? b?o full
            if (i_key_valid && full)
                overflow_count <= overflow_count + 1;

            if (write_en) begin
                wr_ptr <= wr_ptr + 1;
                key_wr_count <= key_wr_count + 1;
            end

            if (read_en) begin
                rd_ptr <= rd_ptr + 1;
                key_rd_count <= key_rd_count + 1;
            end

            // Qu?n l? b? ??m in_fifo an to?n
            if (write_en && !read_en) begin
                key_in_fifo <= key_in_fifo + 1;
            end
            else if (!write_en && read_en) begin
                key_in_fifo <= key_in_fifo - 1;
            end
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
    (* ram_style = "distributed" *) reg [FIFO_WIDTH-1:0] fifo_mem [0:DEPTH-1];

    reg [PTR_WIDTH:0] wr_ptr;
    reg [PTR_WIDTH:0] rd_ptr;

    //--------------------------------------------------------
    // Debug counters
    //--------------------------------------------------------
    reg [31:0] msg_wr_count;
    reg [31:0] msg_rd_count;
    reg [31:0] msg_in_fifo;

    reg [31:0] overflow_count;  
    reg [31:0] underflow_count;

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

    always @(posedge clk or negedge rst_n) begin
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
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;

            msg_wr_count <= 0;
            msg_rd_count <= 0;
            msg_in_fifo  <= 0;

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
                msg_wr_count <= msg_wr_count + 1;
            end

            //------------------------------------------------
            // READ
            //------------------------------------------------
            if (read_en) begin
                rd_ptr <= rd_ptr + 1;
                msg_rd_count <= msg_rd_count + 1;
            end

            //------------------------------------------------
            // Qu?n l? b? ??m an to?n
            //------------------------------------------------
            if (write_en && !read_en) begin
                msg_in_fifo <= msg_in_fifo + 1;
            end
            else if (!write_en && read_en) begin
                msg_in_fifo <= msg_in_fifo - 1;
            end

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
    output wire             o_almost_full, // ?? m? comment ?? d?ng

    // READ (FWFT)
    output wire [WIDTH-1:0] rd_data,
    output wire             rd_valid,
    output wire             o_empty,
    output wire             o_almost_empty, // ?? m? comment ?? d?ng
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
    reg [31:0] ip_hdr_wr_count;    
    reg [31:0] ip_hdr_rd_count;    
    reg [31:0] ip_hdr_in_fifo;     

    reg [31:0] overflow_count;     
    reg [31:0] underflow_count;    

    //--------------------------------------------------
    // FIFO status
    //--------------------------------------------------
    wire empty = (wr_ptr == rd_ptr);

    wire full  = (wr_ptr[PTR-1:0] == rd_ptr[PTR-1:0]) &&
                 (wr_ptr[PTR]     != rd_ptr[PTR]);
                 
    wire [PTR:0] count = wr_ptr - rd_ptr; 

    // [FIX 1]: Ph?n ??nh r? r?ng c?c tr?ng th?i
    assign o_almost_full  = (count >= ALMOST_FULL_THRESH); 
    assign o_almost_empty = (count <= ALMOST_EMPTY_THRESH); 
    
    assign o_empty  = empty; 
    assign o_full   = full;  

    // [FIX 2]: wr_ready ng?t s?m ?? b?o v? FIFO
    assign wr_ready = !full && !o_almost_full; 

    //--------------------------------------------------
    // Handshake
    //--------------------------------------------------
    wire write_en = wr_valid  && wr_ready; // ?? s?a ?? ??ng b? v?i wr_ready
    wire read_en  = rd_key_en && !empty;

    //--------------------------------------------------
    // FWFT (First Word Fall Through)
    //--------------------------------------------------
    assign rd_data  = mem[rd_ptr[PTR-1:0]];
    assign rd_valid = !empty;

    //--------------------------------------------------
    // [FIX 3]: T?ch Memory Inference an to?n
    //--------------------------------------------------
    always @(posedge clk) begin
        if (write_en) begin
            mem[wr_ptr[PTR-1:0]] <= wr_data;
        end
    end

    //--------------------------------------------------
    // Sequential logic (Pointers & Counters)
    //--------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;

            ip_hdr_wr_count <= 0;
            ip_hdr_rd_count <= 0;
            ip_hdr_in_fifo  <= 0;

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
                ip_hdr_wr_count <= ip_hdr_wr_count + 1;
            end

            if (read_en) begin
                rd_ptr <= rd_ptr + 1;
                ip_hdr_rd_count <= ip_hdr_rd_count + 1;
            end

            //--------------------------------------------------
            // Qu?n l? b? ??m in_fifo an to?n
            //--------------------------------------------------
            if (write_en && !read_en) begin
                ip_hdr_in_fifo <= ip_hdr_in_fifo + 1;
            end 
            else if (!write_en && read_en) begin
                ip_hdr_in_fifo <= ip_hdr_in_fifo - 1;
            end

        end
    end

endmodule