//////module axis_fifo #(
//////    parameter DEPTH = 16
//////)(
//////    input  wire clk, rst_n,
//////    input  wire         s_valid, s_last,
//////    input  wire [511:0] s_data,
//////    input  wire [63:0]  s_keep,
//////    output wire         s_ready,
//////    output wire         m_valid, m_last,
//////    output wire [511:0] m_data,
//////    output wire [63:0]  m_keep,
//////    input  wire         m_ready
//////);
//////    reg [511:0] data_mem [0:DEPTH-1];
//////    reg [63:0]  keep_mem [0:DEPTH-1];
//////    reg         last_mem [0:DEPTH-1];

//////    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
//////    reg [$clog2(DEPTH):0]   count;

//////    wire write_en = s_valid && s_ready;
//////    wire read_en  = m_valid && m_ready;

//////    assign s_ready = (count < DEPTH);
//////    assign m_valid = (count > 0);

//////    always @(posedge clk) if (write_en) begin
//////        data_mem[wr_ptr] <= s_data;
//////        keep_mem[wr_ptr] <= s_keep;
//////        last_mem[wr_ptr] <= s_last;
//////    end

//////    always @(posedge clk or negedge rst_n) begin
//////        if (!rst_n) begin wr_ptr <= 0; rd_ptr <= 0; count <= 0; end
//////        else begin
//////            if (write_en) wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
//////            if (read_en)  rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
//////            case ({write_en, read_en})
//////                2'b10: count <= count + 1;
//////                2'b01: count <= count - 1;
//////                default: count <= count;
//////            endcase
//////        end
//////    end

//////    // Direct output to minimize latency, or registered for timing
//////    assign m_data = data_mem[rd_ptr];
//////    assign m_keep = keep_mem[rd_ptr];
//////    assign m_last = last_mem[rd_ptr];
//////endmodule
//////module server #(
//////    parameter SERVER_ID = 0,
//////    parameter [31:0] MY_IP = 32'h0A000064
//////)(
//////    input  wire clk, rst_n,
//////    input  wire server_en,  // Server alive/enable signal
//////    input  wire rx_user_valid, rx_user_last,
//////    input  wire [511:0] rx_user_data,
//////    input  wire [63:0]  rx_user_keep,
//////    output wire rx_user_ready,

//////    output wire tx_user_valid, tx_user_last,
//////    output wire [511:0] tx_user_data,
//////    output wire [63:0]  tx_user_keep,
//////    input  wire tx_user_ready,
    
//////    output reg [14:0] cnt_user_req_rx, 
//////    output reg [14:0] cnt_hb_req_rx,
//////    output reg [14:0] cnt_user_reply_tx, 
//////    output reg [14:0] cnt_hb_reply_tx
//////);

//////    // --- 1. Latch lo?i g?i tin t?i SOP ---
//////    reg sop_in;
//////    // Allow consuming packets when server is alive (process) OR dead (discard)
//////    wire fire_in = rx_user_valid && rx_user_ready;
//////    // Only process packets when server is alive
//////    wire fire_in_process = fire_in && server_en;
    
//////    always @(posedge clk or negedge rst_n) begin
//////        if (!rst_n) sop_in <= 1'b1;
//////        // Only update SOP when actually processing (not during discard)
//////        else if (fire_in_process) sop_in <= rx_user_last;
//////    end

//////    reg is_hb_type;
//////    wire hb_match_now = (rx_user_data[223:208] == 16'd8888) && (rx_user_data[239:224] == 16'd9999);
//////    always @(posedge clk or negedge rst_n) begin
//////        if (!rst_n) is_hb_type <= 1'b0;
//////        else if (fire_in_process && sop_in) 
//////        is_hb_type <= hb_match_now;
//////    end

//////    // --- 2. Pipeline Stage (S?a l?i treo t?n hi?u) ---
//////    reg valid_r, last_r, is_hb_r;
//////    reg [511:0] data_r; 
//////    reg [63:0]  keep_r;

//////    wire fire_out = valid_r && tx_user_ready;
//////    // Ready signal: Always ready in discard mode (server dead), or ready when enabled and pipeline free
//////    assign rx_user_ready = !server_en ? 1'b1 : (!valid_r || fire_out);

//////    always @(posedge clk or negedge rst_n) begin
//////        if (!rst_n) begin
//////            valid_r <= 0;
//////            is_hb_r <= 0;
//////            last_r  <= 0;
//////        end else begin
//////            // When server dies (server_en == 0), clear pipeline and enter discard mode
//////            if (!server_en) begin
//////                valid_r <= 1'b0;
//////                is_hb_r <= 1'b0;
//////                last_r  <= 1'b0;
//////            end
//////            // Only latch data when server is alive and consuming packets
//////            else if (fire_in_process) begin
//////                valid_r <= 1'b1;
//////                data_r  <= rx_user_data;
//////                keep_r  <= rx_user_keep;
//////                last_r  <= rx_user_last;
//////                // L?y lo?i g?i tin t? latch ho?c tr?c ti?p t? bus n?u l? g?i 1 beat
//////                is_hb_r <= sop_in ? hb_match_now : is_hb_type;
//////            end 
//////            else if (fire_out) begin
//////                // QUAN TR?NG: X?a valid v? lo?i g?i tin ngay khi v?a ??y xong 1 beat
//////                valid_r <= 1'b0;
//////                is_hb_r <= 1'b0; 
//////                last_r  <= 1'b0;
//////            end
//////        end
//////    end

//////    // --- 3. Output Assignment ---
//////    wire [31:0] src_ip = data_r[303:272];
//////    wire [511:0] hb_reply_data = {72'b0, 32'd0 | SERVER_ID, 32'b0, 64'b0, 8'h02, 32'b0, src_ip, MY_IP, 16'd8888, 16'd9999, 208'b0};

//////    // Only output when server is enabled
//////    assign tx_user_valid = server_en && valid_r;
//////    // last_r ch? c? ? ngh?a khi valid_r ?ang l?n
//////    assign tx_user_last  = (server_en && valid_r) && (is_hb_r ? 1'b1 : last_r); 
//////    assign tx_user_data  = is_hb_r ? hb_reply_data : data_r;
//////    assign tx_user_keep  = is_hb_r ? 64'hFFFFFFFFFFFFFFFF : keep_r;

//////    // --- 4. Counter Logic (Ch?nh x?c t?ng xung) ---
//////    // Only count packets when server is alive (not during discard mode)
//////    always @(posedge clk or negedge rst_n) begin
//////        if (!rst_n) begin
//////            cnt_user_req_rx <= 0;
//////            cnt_hb_req_rx   <= 0;
//////        end else if (fire_in_process && rx_user_last) begin
//////            if (sop_in ? hb_match_now : is_hb_type)
//////                cnt_hb_req_rx <= cnt_hb_req_rx + 1;
//////            else
//////                cnt_user_req_rx <= cnt_user_req_rx + 1;
//////        end
//////    end

//////    always @(posedge clk or negedge rst_n) begin
//////        if (!rst_n) begin
//////            cnt_user_reply_tx <= 0;
//////            cnt_hb_reply_tx   <= 0;
//////        end else if (fire_out && tx_user_last) begin
//////            // V? is_hb_r s? b? x?a ? chu k? sau b?i fire_out, counter ch? t?ng ??ng 1 l?n
//////            if (is_hb_r) 
//////                cnt_hb_reply_tx <= cnt_hb_reply_tx + 1;
//////            else
//////                cnt_user_reply_tx <= cnt_user_reply_tx + 1;
//////        end
//////    end
    
//////endmodule
//////module master_server #(
//////    parameter NUM_SERVERS = 4,
//////    parameter SERVER_ID_WIDTH = $clog2(NUM_SERVERS)
//////)(
//////    input wire clk, rst_n,
//////    input wire [NUM_SERVERS-1:0] server_en,  // Server alive/enable signal
//////    input wire rx_user_valid, rx_user_last,
//////    input wire [511:0] rx_user_data,
//////    input wire [63:0] rx_user_keep,
//////    output wire rx_user_ready,
    
//////    output wire tx_user_valid, tx_user_last,
//////    output wire [511:0] tx_user_data,
//////    output wire [63:0] tx_user_keep,
//////    input wire tx_user_ready,
    
//////    output wire [NUM_SERVERS*32-1:0] server_ip_list,
//////    output wire                      server_ip_list_valid,
   
//////    output wire [NUM_SERVERS*15-1:0] cnt_user_req_rx, cnt_hb_req_rx,
//////    output wire [NUM_SERVERS*15-1:0] cnt_user_reply_tx, cnt_hb_reply_tx
//////);

//////    // --- 0. Input FIFO (Buffer & Decouple) ---
//////    wire in_fifo_valid, in_fifo_last;
//////    wire [511:0] in_fifo_data;
//////    wire [63:0] in_fifo_keep;
//////    wire in_fifo_ready;

//////    axis_fifo #(.DEPTH(8)) u_input_fifo (
//////        .clk(clk), .rst_n(rst_n),
//////        .s_valid(rx_user_valid), .s_data(rx_user_data),
//////        .s_keep(rx_user_keep), .s_last(rx_user_last),
//////        .s_ready(rx_user_ready),
//////        .m_valid(in_fifo_valid), .m_data(in_fifo_data),
//////        .m_keep(in_fifo_keep), .m_last(in_fifo_last),
//////        .m_ready(in_fifo_consume)
//////    );

//////    // --- 1. SOP Tracking & Sticky Control ---
//////    reg sop;
//////    wire fire = in_fifo_valid && in_fifo_consume;

//////    always @(posedge clk or negedge rst_n) begin
//////        if (!rst_n) sop <= 1'b1;
//////        else if (fire) sop <= in_fifo_last;
//////    end

//////    reg sticky_is_hb;
//////    reg [SERVER_ID_WIDTH-1:0] sticky_target;
    
//////    wire current_is_hb = (in_fifo_data[223:208] == 16'd8888);

//////    // FIX: t?ch field ra
//////    wire [31:0] dst_field;
//////    assign dst_field = in_fifo_data[271:240];

//////    wire [7:0] dst_byte;
//////    assign dst_byte = dst_field[7:0];

//////    wire [SERVER_ID_WIDTH-1:0] current_target;
//////    assign current_target = (dst_byte >= 8'd100) ? (dst_byte - 8'd100) : 0;

//////    always @(posedge clk or negedge rst_n) begin
//////        if (!rst_n) begin 
//////            sticky_is_hb <= 1'b0; 
//////            sticky_target <= {SERVER_ID_WIDTH{1'b0}}; 
//////        end
//////        else if (fire && sop) begin
//////            sticky_is_hb <= current_is_hb;
//////            sticky_target <= current_target;
//////        end
//////    end

//////    wire pkt_is_hb = sop ? current_is_hb : sticky_is_hb;
//////    wire [SERVER_ID_WIDTH-1:0] pkt_target = sop ? current_target : sticky_target;

//////    // --- 2. Input Distribution (Fanout) ---
//////    wire [NUM_SERVERS-1:0] fifo_ready;
//////    reg  [NUM_SERVERS-1:0] fifo_valid_bus;
//////    wire hb_any_ready = |fifo_ready;  // Heartbeat: any server ranh la duoc

//////    always @(*) begin
//////        fifo_valid_bus = {NUM_SERVERS{1'b0}};
//////        if (in_fifo_valid) begin
//////            if (pkt_is_hb)
//////                fifo_valid_bus = {NUM_SERVERS{1'b1}};
//////            else
//////                fifo_valid_bus[pkt_target] = 1'b1;
//////        end
//////    end

//////    // Relax HB ready: chi can any FIFO ranh, khong can tat ca
//////    assign in_fifo_consume = pkt_is_hb ? hb_any_ready : fifo_ready[pkt_target];

//////    // --- 3. Instantiations ---
//////    wire [NUM_SERVERS-1:0] s_valid, s_last, s_ready;
//////    wire [NUM_SERVERS-1:0] resp_valid, resp_last;
//////    wire [NUM_SERVERS-1:0] resp_ready;

//////    wire [511:0] s_data [0:NUM_SERVERS-1];
//////    wire [511:0] resp_data [0:NUM_SERVERS-1];
//////    wire [63:0]  s_keep [0:NUM_SERVERS-1];
//////    wire [63:0]  resp_keep [0:NUM_SERVERS-1];

//////    genvar i;
//////    generate
//////        for (i = 0; i < NUM_SERVERS; i = i + 1) begin : SRV_BLOCK
//////            assign server_ip_list[i*32 +: 32] = 32'h0a000064 + i;
            
//////            axis_fifo u_in_fifo (
//////                .clk(clk), .rst_n(rst_n),
//////                .s_valid(fifo_valid_bus[i] && in_fifo_valid),
//////                .s_data(in_fifo_data),
//////                .s_keep(in_fifo_keep),
//////                .s_last(in_fifo_last),
//////                .s_ready(fifo_ready[i]),

//////                .m_valid(s_valid[i]),
//////                .m_data(s_data[i]),
//////                .m_keep(s_keep[i]),
//////                .m_last(s_last[i]),
//////                .m_ready(s_ready[i])
//////            );

//////            server #(
//////                .SERVER_ID(i),
//////                .MY_IP(32'h0a000064 + i)
//////            ) u_inst (
//////                .clk(clk), .rst_n(rst_n),
//////                .server_en(server_en[i]),  // Pass individual server_en bit

//////                .rx_user_valid(s_valid[i]),
//////                .rx_user_data(s_data[i]),
//////                .rx_user_keep(s_keep[i]),
//////                .rx_user_last(s_last[i]),
//////                .rx_user_ready(s_ready[i]),

//////                .tx_user_valid(resp_valid[i]),
//////                .tx_user_data(resp_data[i]),
//////                .tx_user_keep(resp_keep[i]),
//////                .tx_user_last(resp_last[i]),
//////                .tx_user_ready(resp_ready[i]),

//////                .cnt_user_req_rx(cnt_user_req_rx[i*15 +: 15]),
//////                .cnt_hb_req_rx(cnt_hb_req_rx[i*15 +: 15]),
//////                .cnt_user_reply_tx(cnt_user_reply_tx[i*15 +: 15]),
//////                .cnt_hb_reply_tx(cnt_hb_reply_tx[i*15 +: 15])
//////            );
//////        end
//////    endgenerate
    
//////    assign server_ip_list_valid = 1'b1;

//////    // --- 4. Packet-Aware Arbiter ---
//////    reg [SERVER_ID_WIDTH-1:0] rr_ptr, current_sel;
//////    reg in_prog;

//////    wire out_fifo_ready;
    
//////    integer k;
//////    reg [SERVER_ID_WIDTH-1:0] sel_idx;
//////    reg found;

//////    always @(*) begin
//////        sel_idx = rr_ptr;
//////        found = 1'b0;

//////        if (in_prog) begin
//////            sel_idx = current_sel;
//////            found = resp_valid[current_sel];
//////        end 
//////        else begin
//////            for (k = 0; k < NUM_SERVERS; k = k + 1) begin
//////                if (!found) begin
//////                    if (rr_ptr + k >= NUM_SERVERS)
//////                        sel_idx = rr_ptr + k - NUM_SERVERS;
//////                    else
//////                        sel_idx = rr_ptr + k;

//////                    if (resp_valid[sel_idx])
//////                        found = 1'b1;
//////                end
//////            end
//////        end
//////    end

//////    wire arb_valid = found;

//////    assign resp_ready = (arb_valid && out_fifo_ready) ? (1'b1 << sel_idx) : {NUM_SERVERS{1'b0}};

//////    always @(posedge clk or negedge rst_n) begin
//////        if (!rst_n) begin
//////            rr_ptr <= 0;
//////            current_sel <= 0;
//////            in_prog <= 0;
//////        end 
//////        else if (arb_valid && out_fifo_ready) begin
//////            if (resp_last[sel_idx]) begin
//////                in_prog <= 0;
//////                rr_ptr  <= (sel_idx == NUM_SERVERS-1) ? 0 : sel_idx + 1;
//////            end 
//////            else begin
//////                in_prog <= 1;
//////                current_sel <= sel_idx;
//////            end
//////        end
//////    end

//////    // --- 5. Output FIFO (Optimized Depth) ---
//////    // Optimize output FIFO depth: NUM_SERVERS / 2 + 2
//////    localparam OUT_FIFO_DEPTH = (NUM_SERVERS >> 1) + 2;
//////    axis_fifo #(
//////        .DEPTH(OUT_FIFO_DEPTH)
//////    ) u_out_fifo (
//////        .clk(clk), .rst_n(rst_n),

//////        .s_valid(arb_valid),
//////        .s_data(resp_data[sel_idx]),
//////        .s_keep(resp_keep[sel_idx]),
//////        .s_last(resp_last[sel_idx]),
//////        .s_ready(out_fifo_ready),

//////        .m_valid(tx_user_valid),
//////        .m_data(tx_user_data),
//////        .m_keep(tx_user_keep),
//////        .m_last(tx_user_last),
//////        .m_ready(tx_user_ready)
//////    );

//////endmodule 

////module axis_fifo #(
////    parameter DEPTH = 16
////)(
////    input  wire clk, rst_n,
////    input  wire         s_valid, s_last,
////    input  wire [511:0] s_data,
////    input  wire [63:0]  s_keep,
////    output wire         s_ready,
////    output wire         m_valid, m_last,
////    output wire [511:0] m_data,
////    output wire [63:0]  m_keep,
////    input  wire         m_ready
////);
////    reg [511:0] data_mem [0:DEPTH-1];
////    reg [63:0]  keep_mem [0:DEPTH-1];
////    reg         last_mem [0:DEPTH-1];

////    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
////    reg [$clog2(DEPTH):0]   count;

////    wire write_en = s_valid && s_ready;
////    wire read_en  = m_valid && m_ready;

////    assign s_ready = (count < DEPTH);
////    assign m_valid = (count > 0);

////    always @(posedge clk) if (write_en) begin
////        data_mem[wr_ptr] <= s_data;
////        keep_mem[wr_ptr] <= s_keep;
////        last_mem[wr_ptr] <= s_last;
////    end

////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin wr_ptr <= 0; rd_ptr <= 0; count <= 0; end
////        else begin
////            if (write_en) wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
////            if (read_en)  rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
////            case ({write_en, read_en})
////                2'b10: count <= count + 1;
////                2'b01: count <= count - 1;
////                default: count <= count;
////            endcase
////        end
////    end

////    // Direct output to minimize latency, or registered for timing
////    assign m_data = data_mem[rd_ptr];
////    assign m_keep = keep_mem[rd_ptr];
////    assign m_last = last_mem[rd_ptr];
////endmodule
////module server #(
////    parameter SERVER_ID = 0,
////    parameter [31:0] MY_IP = 32'h0A000064
////)(
////    input  wire clk, rst_n,
////    input  wire server_en,  // Server alive/enable signal
////    input  wire rx_user_valid, rx_user_last,
////    input  wire [511:0] rx_user_data,
////    input  wire [63:0]  rx_user_keep,
////    output wire rx_user_ready,

////    output wire tx_user_valid, tx_user_last,
////    output wire [511:0] tx_user_data,
////    output wire [63:0]  tx_user_keep,
////    input  wire tx_user_ready,
    
////    output reg [14:0] cnt_user_req_rx, 
////    output reg [14:0] cnt_hb_req_rx,
////    output reg [14:0] cnt_user_reply_tx, 
////    output reg [14:0] cnt_hb_reply_tx
////);

////    // --- 1. Latch lo?i g?i tin t?i SOP ---
////    reg sop_in;
////    // Allow consuming packets when server is alive (process) OR dead (discard)
////    wire fire_in = rx_user_valid && rx_user_ready;
////    // Only process packets when server is alive
////    wire fire_in_process = fire_in && server_en;
    
////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) sop_in <= 1'b1;
////        // Only update SOP when actually processing (not during discard)
////        else if (fire_in_process) sop_in <= rx_user_last;
////    end

////    reg is_hb_type;
////    wire hb_match_now = (rx_user_data[223:208] == 16'd8888) && (rx_user_data[239:224] == 16'd9999);
////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) is_hb_type <= 1'b0;
////        else if (fire_in_process && sop_in) 
////        is_hb_type <= hb_match_now;
////    end

////    // --- 2. Pipeline Stage (S?a l?i treo t?n hi?u) ---
////    reg valid_r, last_r, is_hb_r;
////    reg [511:0] data_r; 
////    reg [63:0]  keep_r;

////    wire fire_out = valid_r && tx_user_ready;
////    // Ready signal: Always ready in discard mode (server dead), or ready when enabled and pipeline free
////    assign rx_user_ready = !server_en ? 1'b1 : (!valid_r || fire_out);

////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin
////            valid_r <= 0;
////            is_hb_r <= 0;
////            last_r  <= 0;
////        end else begin
////            // When server dies (server_en == 0), clear pipeline and enter discard mode
////            if (!server_en) begin
////                valid_r <= 1'b0;
////                is_hb_r <= 1'b0;
////                last_r  <= 1'b0;
////            end
////            // Only latch data when server is alive and consuming packets
////            else if (fire_in_process) begin
////                valid_r <= 1'b1;
////                data_r  <= rx_user_data;
////                keep_r  <= rx_user_keep;
////                last_r  <= rx_user_last;
////                // L?y lo?i g?i tin t? latch ho?c tr?c ti?p t? bus n?u l? g?i 1 beat
////                is_hb_r <= sop_in ? hb_match_now : is_hb_type;
////            end 
////            else if (fire_out) begin
////                // QUAN TR?NG: X?a valid v? lo?i g?i tin ngay khi v?a ??y xong 1 beat
////                valid_r <= 1'b0;
////                is_hb_r <= 1'b0; 
////                last_r  <= 1'b0;
////            end
////        end
////    end

////    // --- 3. Output Assignment ---
////    wire [31:0] src_ip = data_r[303:272];
////    wire [511:0] hb_reply_data = {72'b0, 32'd0 | SERVER_ID, 32'b0, 64'b0, 8'h02, 32'b0, src_ip, MY_IP, 16'd8888, 16'd9999, 208'b0};

////    // Only output when server is enabled
////    assign tx_user_valid = server_en && valid_r;
////    // last_r ch? c? ? ngh?a khi valid_r ?ang l?n
////    assign tx_user_last  = (server_en && valid_r) && (is_hb_r ? 1'b1 : last_r); 
////    assign tx_user_data  = is_hb_r ? hb_reply_data : data_r;
////    assign tx_user_keep  = is_hb_r ? 64'hFFFFFFFFFFFFFFFF : keep_r;

////    // --- 4. Counter Logic (Ch?nh x?c t?ng xung) ---
////    // Only count packets when server is alive (not during discard mode)
////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin
////            cnt_user_req_rx <= 0;
////            cnt_hb_req_rx   <= 0;
////        end else if (fire_in_process && rx_user_last) begin
////            if (sop_in ? hb_match_now : is_hb_type)
////                cnt_hb_req_rx <= cnt_hb_req_rx + 1;
////            else
////                cnt_user_req_rx <= cnt_user_req_rx + 1;
////        end
////    end

////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin
////            cnt_user_reply_tx <= 0;
////            cnt_hb_reply_tx   <= 0;
////        end else if (fire_out && tx_user_last) begin
////            // V? is_hb_r s? b? x?a ? chu k? sau b?i fire_out, counter ch? t?ng ??ng 1 l?n
////            if (is_hb_r) 
////                cnt_hb_reply_tx <= cnt_hb_reply_tx + 1;
////            else
////                cnt_user_reply_tx <= cnt_user_reply_tx + 1;
////        end
////    end
    
////endmodule
////module master_server #(
////    parameter NUM_SERVERS = 4,
////    parameter SERVER_ID_WIDTH = $clog2(NUM_SERVERS)
////)(
////    input wire clk, rst_n,
////    input wire [NUM_SERVERS-1:0] server_en,  // Server alive/enable signal
////    input wire rx_user_valid, rx_user_last,
////    input wire [511:0] rx_user_data,
////    input wire [63:0] rx_user_keep,
////    output wire rx_user_ready,
    
////    output wire tx_user_valid, tx_user_last,
////    output wire [511:0] tx_user_data,
////    output wire [63:0] tx_user_keep,
////    input wire tx_user_ready,
   
////    output reg  [NUM_SERVERS*32-1:0] server_ip_list,
////    output wire                     server_ip_list_valid,

////    output wire [NUM_SERVERS*15-1:0] cnt_user_req_rx, cnt_hb_req_rx,
////    output wire [NUM_SERVERS*15-1:0] cnt_user_reply_tx, cnt_hb_reply_tx
////);

////    // --- 0. Input FIFO (Buffer & Decouple) ---
////    wire in_fifo_valid, in_fifo_last;
////    wire [511:0] in_fifo_data;
////    wire [63:0] in_fifo_keep;
////    wire in_fifo_ready;

////    axis_fifo #(.DEPTH(8)) u_input_fifo (
////        .clk(clk), .rst_n(rst_n),
////        .s_valid(rx_user_valid), .s_data(rx_user_data),
////        .s_keep(rx_user_keep), .s_last(rx_user_last),
////        .s_ready(rx_user_ready),
////        .m_valid(in_fifo_valid), .m_data(in_fifo_data),
////        .m_keep(in_fifo_keep), .m_last(in_fifo_last),
////        .m_ready(in_fifo_consume)
////    );

////    // --- 1. SOP Tracking & Sticky Control ---
////    reg sop;
////    wire fire = in_fifo_valid && in_fifo_consume;

////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) sop <= 1'b1;
////        else if (fire) sop <= in_fifo_last;
////    end

////    reg sticky_is_hb;
////    reg [SERVER_ID_WIDTH-1:0] sticky_target;
    
////    wire current_is_hb = (in_fifo_data[223:208] == 16'd8888);

////    // FIX: t?ch field ra
////    wire [31:0] dst_field;
////    assign dst_field = in_fifo_data[271:240];

////    wire [7:0] dst_byte;
////    assign dst_byte = dst_field[7:0];

////    wire [SERVER_ID_WIDTH-1:0] current_target;
////    assign current_target = (dst_byte >= 8'd100) ? (dst_byte - 8'd100) : 0;

////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin 
////            sticky_is_hb <= 1'b0; 
////            sticky_target <= {SERVER_ID_WIDTH{1'b0}}; 
////        end
////        else if (fire && sop) begin
////            sticky_is_hb <= current_is_hb;
////            sticky_target <= current_target;
////        end
////    end

////    wire pkt_is_hb = sop ? current_is_hb : sticky_is_hb;
////    wire [SERVER_ID_WIDTH-1:0] pkt_target = sop ? current_target : sticky_target;

////    // --- 2. Input Distribution (Fanout) ---
////    wire [NUM_SERVERS-1:0] fifo_ready;
////    reg  [NUM_SERVERS-1:0] fifo_valid_bus;
////    wire hb_any_ready = |fifo_ready;  // Heartbeat: any server ranh la duoc

////    always @(*) begin
////        fifo_valid_bus = {NUM_SERVERS{1'b0}};
////        if (in_fifo_valid) begin
////            if (pkt_is_hb)
////                fifo_valid_bus = {NUM_SERVERS{1'b1}};
////            else
////                fifo_valid_bus[pkt_target] = 1'b1;
////        end
////    end

////    // Relax HB ready: chi can any FIFO ranh, khong can tat ca
////    assign in_fifo_consume = pkt_is_hb ? hb_any_ready : fifo_ready[pkt_target];

////    // --- 3. Instantiations ---
////    wire [NUM_SERVERS-1:0] s_valid, s_last, s_ready;
////    wire [NUM_SERVERS-1:0] resp_valid, resp_last;
////    wire [NUM_SERVERS-1:0] resp_ready;

////    wire [511:0] s_data [0:NUM_SERVERS-1];
////    wire [511:0] resp_data [0:NUM_SERVERS-1];
////    wire [63:0]  s_keep [0:NUM_SERVERS-1];
////    wire [63:0]  resp_keep [0:NUM_SERVERS-1];

////    reg [1:0] boot_pulse_cnt;
////    reg       server_ip_list_valid_r;
////    integer   ip_i;

////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin
////            boot_pulse_cnt         <= 2'd0;
////            server_ip_list_valid_r <= 1'b0;
////            for (ip_i = 0; ip_i < NUM_SERVERS; ip_i = ip_i + 1)
////                server_ip_list[ip_i*32 +: 32] <= 32'h0A000064 + ip_i;
////        end else begin
////            if (boot_pulse_cnt < 2'd3)
////                boot_pulse_cnt <= boot_pulse_cnt + 1'b1;

////            // 1-cycle pulse at boot so SHM can capture initial server IP list.
////            server_ip_list_valid_r <= (boot_pulse_cnt == 2'd2);

////            for (ip_i = 0; ip_i < NUM_SERVERS; ip_i = ip_i + 1)
////                server_ip_list[ip_i*32 +: 32] <= 32'h0A000064 + ip_i;
////        end
////    end

////    genvar i;
////    generate
////        for (i = 0; i < NUM_SERVERS; i = i + 1) begin : SRV_BLOCK
////            axis_fifo u_in_fifo (
////                .clk(clk), .rst_n(rst_n),
////                .s_valid(fifo_valid_bus[i] && in_fifo_valid),
////                .s_data(in_fifo_data),
////                .s_keep(in_fifo_keep),
////                .s_last(in_fifo_last),
////                .s_ready(fifo_ready[i]),

////                .m_valid(s_valid[i]),
////                .m_data(s_data[i]),
////                .m_keep(s_keep[i]),
////                .m_last(s_last[i]),
////                .m_ready(s_ready[i])
////            );

////            server #(
////                .SERVER_ID(i),
////                .MY_IP(32'h0a000064 + i)
////            ) u_inst (
////                .clk(clk), .rst_n(rst_n),
////                .server_en(server_en[i]),  // Pass individual server_en bit

////                .rx_user_valid(s_valid[i]),
////                .rx_user_data(s_data[i]),
////                .rx_user_keep(s_keep[i]),
////                .rx_user_last(s_last[i]),
////                .rx_user_ready(s_ready[i]),

////                .tx_user_valid(resp_valid[i]),
////                .tx_user_data(resp_data[i]),
////                .tx_user_keep(resp_keep[i]),
////                .tx_user_last(resp_last[i]),
////                .tx_user_ready(resp_ready[i]),

////                .cnt_user_req_rx(cnt_user_req_rx[i*15 +: 15]),
////                .cnt_hb_req_rx(cnt_hb_req_rx[i*15 +: 15]),
////                .cnt_user_reply_tx(cnt_user_reply_tx[i*15 +: 15]),
////                .cnt_hb_reply_tx(cnt_hb_reply_tx[i*15 +: 15])
////            );
////        end
////    endgenerate

////    assign server_ip_list_valid = server_ip_list_valid_r;

////    // --- 4. Packet-Aware Arbiter ---
////    reg [SERVER_ID_WIDTH-1:0] rr_ptr, current_sel;
////    reg in_prog;

////    wire out_fifo_ready;
    
////    integer k;
////    reg [SERVER_ID_WIDTH-1:0] sel_idx;
////    reg found;

////    always @(*) begin
////        sel_idx = rr_ptr;
////        found = 1'b0;

////        if (in_prog) begin
////            sel_idx = current_sel;
////            found = resp_valid[current_sel];
////        end 
////        else begin
////            for (k = 0; k < NUM_SERVERS; k = k + 1) begin
////                if (!found) begin
////                    if (rr_ptr + k >= NUM_SERVERS)
////                        sel_idx = rr_ptr + k - NUM_SERVERS;
////                    else
////                        sel_idx = rr_ptr + k;

////                    if (resp_valid[sel_idx])
////                        found = 1'b1;
////                end
////            end
////        end
////    end

////    wire arb_valid = found;

////    assign resp_ready = (arb_valid && out_fifo_ready) ? (1'b1 << sel_idx) : {NUM_SERVERS{1'b0}};

////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin
////            rr_ptr <= 0;
////            current_sel <= 0;
////            in_prog <= 0;
////        end 
////        else if (arb_valid && out_fifo_ready) begin
////            if (resp_last[sel_idx]) begin
////                in_prog <= 0;
////                rr_ptr  <= (sel_idx == NUM_SERVERS-1) ? 0 : sel_idx + 1;
////            end 
////            else begin
////                in_prog <= 1;
////                current_sel <= sel_idx;
////            end
////        end
////    end

////    // --- 5. Output FIFO (Optimized Depth) ---
////    // Optimize output FIFO depth: NUM_SERVERS / 2 + 2
////    localparam OUT_FIFO_DEPTH = (NUM_SERVERS >> 1) + 2;
////    axis_fifo #(
////        .DEPTH(OUT_FIFO_DEPTH)
////    ) u_out_fifo (
////        .clk(clk), .rst_n(rst_n),

////        .s_valid(arb_valid),
////        .s_data(resp_data[sel_idx]),
////        .s_keep(resp_keep[sel_idx]),
////        .s_last(resp_last[sel_idx]),
////        .s_ready(out_fifo_ready),

////        .m_valid(tx_user_valid),
////        .m_data(tx_user_data),
////        .m_keep(tx_user_keep),
////        .m_last(tx_user_last),
////        .m_ready(tx_user_ready)
////    );

////endmodule 

//module axis_fifo #(
//    parameter DEPTH = 16
//)(
//    input  wire clk, rst_n,
//    input  wire         s_valid, s_last,
//    input  wire [511:0] s_data,
//    input  wire [63:0]  s_keep,
//    output wire         s_ready,
//    output wire         m_valid, m_last,
//    output wire [511:0] m_data,
//    output wire [63:0]  m_keep,
//    input  wire         m_ready
//);
//    reg [511:0] data_mem [0:DEPTH-1];
//    reg [63:0]  keep_mem [0:DEPTH-1];
//    reg         last_mem [0:DEPTH-1];

//    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
//    reg [$clog2(DEPTH):0]   count;

//    wire write_en = s_valid && s_ready;
//    wire read_en  = m_valid && m_ready;

//    assign s_ready = (count < DEPTH);
//    assign m_valid = (count > 0);

//    always @(posedge clk) if (write_en) begin
//        data_mem[wr_ptr] <= s_data;
//        keep_mem[wr_ptr] <= s_keep;
//        last_mem[wr_ptr] <= s_last;
//    end

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin wr_ptr <= 0; rd_ptr <= 0; count <= 0; end
//        else begin
//            if (write_en) wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
//            if (read_en)  rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
//            case ({write_en, read_en})
//                2'b10: count <= count + 1;
//                2'b01: count <= count - 1;
//                default: count <= count;
//            endcase
//        end
//    end

//    // Direct output to minimize latency, or registered for timing
//    assign m_data = data_mem[rd_ptr];
//    assign m_keep = keep_mem[rd_ptr];
//    assign m_last = last_mem[rd_ptr];
//endmodule
//module server #(
//    parameter SERVER_ID = 0,
//    parameter [31:0] MY_IP = 32'h0A000064
//)(
//    input  wire clk, rst_n,
//    input  wire server_en,  // Server alive/enable signal
//    input  wire rx_user_valid, rx_user_last,
//    input  wire [511:0] rx_user_data,
//    input  wire [63:0]  rx_user_keep,
//    output wire rx_user_ready,

//    output wire tx_user_valid, tx_user_last,
//    output wire [511:0] tx_user_data,
//    output wire [63:0]  tx_user_keep,
//    input  wire tx_user_ready,
    
//    output reg [14:0] cnt_user_req_rx, 
//    output reg [14:0] cnt_hb_req_rx,
//    output reg [14:0] cnt_user_reply_tx, 
//    output reg [14:0] cnt_hb_reply_tx
//);

//    // --- 1. Latch lo?i g?i tin t?i SOP ---
//    reg sop_in;
//    // Allow consuming packets when server is alive (process) OR dead (discard)
//    wire fire_in = rx_user_valid && rx_user_ready;
//    // Only process packets when server is alive
//    wire fire_in_process = fire_in && server_en;
    
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) sop_in <= 1'b1;
//        // Only update SOP when actually processing (not during discard)
//        else if (fire_in_process) sop_in <= rx_user_last;
//    end

//    reg is_hb_type;
//    wire hb_match_now = (rx_user_data[223:208] == 16'd8888) && (rx_user_data[239:224] == 16'd9999);
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) is_hb_type <= 1'b0;
//        else if (fire_in_process && sop_in) 
//        is_hb_type <= hb_match_now;
//    end

//    // --- 2. Pipeline Stage (S?a l?i treo t?n hi?u) ---
//    reg valid_r, last_r, is_hb_r;
//    reg [511:0] data_r; 
//    reg [63:0]  keep_r;

//    wire fire_out = valid_r && tx_user_ready;
//    // Ready signal: Always ready in discard mode (server dead), or ready when enabled and pipeline free
//    assign rx_user_ready = !server_en ? 1'b1 : (!valid_r || fire_out);

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            valid_r <= 0;
//            is_hb_r <= 0;
//            last_r  <= 0;
//        end else begin
//            // When server dies (server_en == 0), clear pipeline and enter discard mode
//            if (!server_en) begin
//                valid_r <= 1'b0;
//                is_hb_r <= 1'b0;
//                last_r  <= 1'b0;
//            end
//            // Only latch data when server is alive and consuming packets
//            else if (fire_in_process) begin
//                valid_r <= 1'b1;
//                data_r  <= rx_user_data;
//                keep_r  <= rx_user_keep;
//                last_r  <= rx_user_last;
//                // L?y lo?i g?i tin t? latch ho?c tr?c ti?p t? bus n?u l? g?i 1 beat
//                is_hb_r <= sop_in ? hb_match_now : is_hb_type;
//            end 
//            else if (fire_out) begin
//                // QUAN TR?NG: X?a valid v? lo?i g?i tin ngay khi v?a ??y xong 1 beat
//                valid_r <= 1'b0;
//                is_hb_r <= 1'b0; 
//                last_r  <= 1'b0;
//            end
//        end
//    end

//    // --- 3. Output Assignment ---
//    wire [31:0] src_ip = data_r[303:272];
//    wire [511:0] hb_reply_data = {72'b0, 32'd0 | SERVER_ID, 32'b0, 64'b0, 8'h02, 32'b0, src_ip, MY_IP, 16'd8888, 16'd9999, 208'b0};

//    // Only output when server is enabled
//    assign tx_user_valid = server_en && valid_r;
//    // last_r ch? c? ? ngh?a khi valid_r ?ang l?n
//    assign tx_user_last  = (server_en && valid_r) && (is_hb_r ? 1'b1 : last_r); 
//    assign tx_user_data  = is_hb_r ? hb_reply_data : data_r;
//    assign tx_user_keep  = is_hb_r ? 64'hFFFFFFFFFFFFFFFF : keep_r;

//    // --- 4. Counter Logic (Ch?nh x?c t?ng xung) ---
//    // Only count packets when server is alive (not during discard mode)
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            cnt_user_req_rx <= 0;
//            cnt_hb_req_rx   <= 0;
//        end else if (fire_in_process && rx_user_last) begin
//            if (sop_in ? hb_match_now : is_hb_type)
//                cnt_hb_req_rx <= cnt_hb_req_rx + 1;
//            else
//                cnt_user_req_rx <= cnt_user_req_rx + 1;
//        end
//    end

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            cnt_user_reply_tx <= 0;
//            cnt_hb_reply_tx   <= 0;
//        end else if (fire_out && tx_user_last) begin
//            // V? is_hb_r s? b? x?a ? chu k? sau b?i fire_out, counter ch? t?ng ??ng 1 l?n
//            if (is_hb_r) 
//                cnt_hb_reply_tx <= cnt_hb_reply_tx + 1;
//            else
//                cnt_user_reply_tx <= cnt_user_reply_tx + 1;
//        end
//    end
    
//endmodule
//module master_server #(
//    parameter NUM_SERVERS = 4,
//    parameter SERVER_ID_WIDTH = $clog2(NUM_SERVERS)
//)(
//    input wire clk, rst_n,
//    input wire [NUM_SERVERS-1:0] server_en,  // Server alive/enable signal
//    input wire rx_user_valid, rx_user_last,
//    input wire [511:0] rx_user_data,
//    input wire [63:0] rx_user_keep,
//    output wire rx_user_ready,
    
//    output wire tx_user_valid, tx_user_last,
//    output wire [511:0] tx_user_data,
//    output wire [63:0] tx_user_keep,
//    input wire tx_user_ready,
    
//    output wire [NUM_SERVERS*32-1:0] server_ip_list,
//    output wire                      server_ip_list_valid,
   
//    output wire [NUM_SERVERS*15-1:0] cnt_user_req_rx, cnt_hb_req_rx,
//    output wire [NUM_SERVERS*15-1:0] cnt_user_reply_tx, cnt_hb_reply_tx
//);

//    // --- 0. Input FIFO (Buffer & Decouple) ---
//    wire in_fifo_valid, in_fifo_last;
//    wire [511:0] in_fifo_data;
//    wire [63:0] in_fifo_keep;
//    wire in_fifo_ready;

//    axis_fifo #(.DEPTH(8)) u_input_fifo (
//        .clk(clk), .rst_n(rst_n),
//        .s_valid(rx_user_valid), .s_data(rx_user_data),
//        .s_keep(rx_user_keep), .s_last(rx_user_last),
//        .s_ready(rx_user_ready),
//        .m_valid(in_fifo_valid), .m_data(in_fifo_data),
//        .m_keep(in_fifo_keep), .m_last(in_fifo_last),
//        .m_ready(in_fifo_consume)
//    );

//    // --- 1. SOP Tracking & Sticky Control ---
//    reg sop;
//    wire fire = in_fifo_valid && in_fifo_consume;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) sop <= 1'b1;
//        else if (fire) sop <= in_fifo_last;
//    end

//    reg sticky_is_hb;
//    reg [SERVER_ID_WIDTH-1:0] sticky_target;
    
//    wire current_is_hb = (in_fifo_data[223:208] == 16'd8888);

//    // FIX: t?ch field ra
//    wire [31:0] dst_field;
//    assign dst_field = in_fifo_data[271:240];

//    wire [7:0] dst_byte;
//    assign dst_byte = dst_field[7:0];

//    wire [SERVER_ID_WIDTH-1:0] current_target;
//    assign current_target = (dst_byte >= 8'd100) ? (dst_byte - 8'd100) : 0;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin 
//            sticky_is_hb <= 1'b0; 
//            sticky_target <= {SERVER_ID_WIDTH{1'b0}}; 
//        end
//        else if (fire && sop) begin
//            sticky_is_hb <= current_is_hb;
//            sticky_target <= current_target;
//        end
//    end

//    wire pkt_is_hb = sop ? current_is_hb : sticky_is_hb;
//    wire [SERVER_ID_WIDTH-1:0] pkt_target = sop ? current_target : sticky_target;

//    // --- 2. Input Distribution (Fanout) ---
//    wire [NUM_SERVERS-1:0] fifo_ready;
//    reg  [NUM_SERVERS-1:0] fifo_valid_bus;
//    wire hb_any_ready = |fifo_ready;  // Heartbeat: any server ranh la duoc

//    always @(*) begin
//        fifo_valid_bus = {NUM_SERVERS{1'b0}};
//        if (in_fifo_valid) begin
//            if (pkt_is_hb)
//                fifo_valid_bus = {NUM_SERVERS{1'b1}};
//            else
//                fifo_valid_bus[pkt_target] = 1'b1;
//        end
//    end

//    // Relax HB ready: chi can any FIFO ranh, khong can tat ca
//    assign in_fifo_consume = pkt_is_hb ? hb_any_ready : fifo_ready[pkt_target];

//    // --- 3. Instantiations ---
//    wire [NUM_SERVERS-1:0] s_valid, s_last, s_ready;
//    wire [NUM_SERVERS-1:0] resp_valid, resp_last;
//    wire [NUM_SERVERS-1:0] resp_ready;

//    wire [511:0] s_data [0:NUM_SERVERS-1];
//    wire [511:0] resp_data [0:NUM_SERVERS-1];
//    wire [63:0]  s_keep [0:NUM_SERVERS-1];
//    wire [63:0]  resp_keep [0:NUM_SERVERS-1];

//    genvar i;
//    generate
//        for (i = 0; i < NUM_SERVERS; i = i + 1) begin : SRV_BLOCK
//            assign server_ip_list[i*32 +: 32] = 32'h0a000064 + i;
            
//            axis_fifo u_in_fifo (
//                .clk(clk), .rst_n(rst_n),
//                .s_valid(fifo_valid_bus[i] && in_fifo_valid),
//                .s_data(in_fifo_data),
//                .s_keep(in_fifo_keep),
//                .s_last(in_fifo_last),
//                .s_ready(fifo_ready[i]),

//                .m_valid(s_valid[i]),
//                .m_data(s_data[i]),
//                .m_keep(s_keep[i]),
//                .m_last(s_last[i]),
//                .m_ready(s_ready[i])
//            );

//            server #(
//                .SERVER_ID(i),
//                .MY_IP(32'h0a000064 + i)
//            ) u_inst (
//                .clk(clk), .rst_n(rst_n),
//                .server_en(server_en[i]),  // Pass individual server_en bit

//                .rx_user_valid(s_valid[i]),
//                .rx_user_data(s_data[i]),
//                .rx_user_keep(s_keep[i]),
//                .rx_user_last(s_last[i]),
//                .rx_user_ready(s_ready[i]),

//                .tx_user_valid(resp_valid[i]),
//                .tx_user_data(resp_data[i]),
//                .tx_user_keep(resp_keep[i]),
//                .tx_user_last(resp_last[i]),
//                .tx_user_ready(resp_ready[i]),

//                .cnt_user_req_rx(cnt_user_req_rx[i*15 +: 15]),
//                .cnt_hb_req_rx(cnt_hb_req_rx[i*15 +: 15]),
//                .cnt_user_reply_tx(cnt_user_reply_tx[i*15 +: 15]),
//                .cnt_hb_reply_tx(cnt_hb_reply_tx[i*15 +: 15])
//            );
//        end
//    endgenerate
    
//    assign server_ip_list_valid = 1'b1;

//    // --- 4. Packet-Aware Arbiter ---
//    reg [SERVER_ID_WIDTH-1:0] rr_ptr, current_sel;
//    reg in_prog;

//    wire out_fifo_ready;
    
//    integer k;
//    reg [SERVER_ID_WIDTH-1:0] sel_idx;
//    reg found;

//    always @(*) begin
//        sel_idx = rr_ptr;
//        found = 1'b0;

//        if (in_prog) begin
//            sel_idx = current_sel;
//            found = resp_valid[current_sel];
//        end 
//        else begin
//            for (k = 0; k < NUM_SERVERS; k = k + 1) begin
//                if (!found) begin
//                    if (rr_ptr + k >= NUM_SERVERS)
//                        sel_idx = rr_ptr + k - NUM_SERVERS;
//                    else
//                        sel_idx = rr_ptr + k;

//                    if (resp_valid[sel_idx])
//                        found = 1'b1;
//                end
//            end
//        end
//    end

//    wire arb_valid = found;

//    assign resp_ready = (arb_valid && out_fifo_ready) ? (1'b1 << sel_idx) : {NUM_SERVERS{1'b0}};

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            rr_ptr <= 0;
//            current_sel <= 0;
//            in_prog <= 0;
//        end 
//        else if (arb_valid && out_fifo_ready) begin
//            if (resp_last[sel_idx]) begin
//                in_prog <= 0;
//                rr_ptr  <= (sel_idx == NUM_SERVERS-1) ? 0 : sel_idx + 1;
//            end 
//            else begin
//                in_prog <= 1;
//                current_sel <= sel_idx;
//            end
//        end
//    end

//    // --- 5. Output FIFO (Optimized Depth) ---
//    // Optimize output FIFO depth: NUM_SERVERS / 2 + 2
//    localparam OUT_FIFO_DEPTH = (NUM_SERVERS >> 1) + 2;
//    axis_fifo #(
//        .DEPTH(OUT_FIFO_DEPTH)
//    ) u_out_fifo (
//        .clk(clk), .rst_n(rst_n),

//        .s_valid(arb_valid),
//        .s_data(resp_data[sel_idx]),
//        .s_keep(resp_keep[sel_idx]),
//        .s_last(resp_last[sel_idx]),
//        .s_ready(out_fifo_ready),

//        .m_valid(tx_user_valid),
//        .m_data(tx_user_data),
//        .m_keep(tx_user_keep),
//        .m_last(tx_user_last),
//        .m_ready(tx_user_ready)
//    );

//endmodule 


module axis_fifo #(
    parameter DEPTH = 16
)(
    input  wire clk, rst_n,
    input  wire         s_valid, s_last,
    input  wire [511:0] s_data,
    input  wire [63:0]  s_keep,
    output wire         s_ready,
    output wire         m_valid, m_last,
    output wire [511:0] m_data,
    output wire [63:0]  m_keep,
    input  wire         m_ready
);
    reg [511:0] data_mem [0:DEPTH-1];
    reg [63:0]  keep_mem [0:DEPTH-1];
    reg         last_mem [0:DEPTH-1];

    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    reg [$clog2(DEPTH):0]   count;

    wire write_en = s_valid && s_ready;
    wire read_en  = m_valid && m_ready;

    assign s_ready = (count < DEPTH);
    assign m_valid = (count > 0);

    always @(posedge clk) if (write_en) begin
        data_mem[wr_ptr] <= s_data;
        keep_mem[wr_ptr] <= s_keep;
        last_mem[wr_ptr] <= s_last;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin wr_ptr <= 0; rd_ptr <= 0; count <= 0; end
        else begin
            if (write_en) wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
            if (read_en)  rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
            case ({write_en, read_en})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: count <= count;
            endcase
        end
    end

    // Direct output to minimize latency, or registered for timing
    assign m_data = data_mem[rd_ptr];
    assign m_keep = keep_mem[rd_ptr];
    assign m_last = last_mem[rd_ptr];
endmodule
module server #(
    parameter SERVER_ID = 0,
    parameter [31:0] MY_IP = 32'h0A000064,
    parameter USER_RESP_EN = 1
)(
    input  wire clk, rst_n,
    input  wire server_en,  // Server alive/enable signal
    input  wire rx_user_valid, rx_user_last,
    input  wire [511:0] rx_user_data,
    input  wire [63:0]  rx_user_keep,
    output wire rx_user_ready,

    output wire tx_user_valid, tx_user_last,
    output wire [511:0] tx_user_data,
    output wire [63:0]  tx_user_keep,
    input  wire tx_user_ready,
    
    output reg [14:0] cnt_user_req_rx, 
    output reg [14:0] cnt_hb_req_rx,
    output reg [14:0] cnt_user_reply_tx, 
    output reg [14:0] cnt_hb_reply_tx
);

    // --- 1. Latch lo?i g?i tin t?i SOP ---
    reg sop_in;
    // Allow consuming packets when server is alive (process) OR dead (discard)
    wire fire_in = rx_user_valid && rx_user_ready;
    // Only process packets when server is alive
    wire fire_in_process = fire_in && server_en;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sop_in <= 1'b1;
        // Only update SOP when actually processing (not during discard)
        else if (fire_in_process) sop_in <= rx_user_last;
    end

    reg is_hb_type;
    wire hb_match_now = (rx_user_data[223:208] == 16'd8888) && (rx_user_data[239:224] == 16'd9999);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) is_hb_type <= 1'b0;
        else if (fire_in_process && sop_in) 
        is_hb_type <= hb_match_now;
    end

    // --- 2. Pipeline Stage (S?a l?i treo t?n hi?u) ---
    reg valid_r, last_r, is_hb_r;
    reg [511:0] data_r; 
    reg [63:0]  keep_r;

    wire tx_emit_en = server_en && (is_hb_r || USER_RESP_EN);
    wire drop_user_noresp = valid_r && !is_hb_r && !USER_RESP_EN;
    wire fire_out = tx_emit_en && valid_r && tx_user_ready;
    // Ready signal: Always ready in discard mode (server dead), or ready when enabled and pipeline free
    assign rx_user_ready = !server_en ? 1'b1 : (!valid_r || fire_out || drop_user_noresp);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_r <= 0;
            is_hb_r <= 0;
            last_r  <= 0;
        end else begin
            // When server dies (server_en == 0), clear pipeline and enter discard mode
            if (!server_en) begin
                valid_r <= 1'b0;
                is_hb_r <= 1'b0;
                last_r  <= 1'b0;
            end
            // Only latch data when server is alive and consuming packets
            else if (fire_in_process) begin
                valid_r <= 1'b1;
                data_r  <= rx_user_data;
                keep_r  <= rx_user_keep;
                last_r  <= rx_user_last;
                // L?y lo?i g?i tin t? latch ho?c tr?c ti?p t? bus n?u l? g?i 1 beat
                is_hb_r <= sop_in ? hb_match_now : is_hb_type;
            end 
            else if (fire_out) begin
                // QUAN TR?NG: X?a valid v? lo?i g?i tin ngay khi v?a ??y xong 1 beat
                valid_r <= 1'b0;
                is_hb_r <= 1'b0; 
                last_r  <= 1'b0;
            end else if (drop_user_noresp) begin
                // Test mode: consume user requests but do not generate user responses.
                valid_r <= 1'b0;
                is_hb_r <= 1'b0;
                last_r  <= 1'b0;
            end
        end
    end

    // --- 3. Output Assignment ---
    wire [31:0] src_ip = data_r[303:272];
    wire [511:0] user_reply_data = {data_r[511:304],
                                    MY_IP,
                                    src_ip,
                                    data_r[223:208],
                                    data_r[239:224],
                                    data_r[207:0]};
    wire [511:0] hb_reply_data = {72'b0, 32'd0 | SERVER_ID, 32'b0, 64'b0, 8'h02, 32'b0, src_ip, MY_IP, 16'd8888, 16'd9999, 208'b0};

    // Only output when server is enabled
    assign tx_user_valid = tx_emit_en && valid_r;
    // last_r ch? c? ? ngh?a khi valid_r ?ang l?n
    assign tx_user_last  = tx_user_valid && (is_hb_r ? 1'b1 : last_r); 
    assign tx_user_data  = is_hb_r ? hb_reply_data : user_reply_data;
    assign tx_user_keep  = is_hb_r ? 64'hFFFFFFFFFFFFFFFF : keep_r;

    // --- 4. Counter Logic (Ch?nh x?c t?ng xung) ---
    // Only count packets when server is alive (not during discard mode)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_user_req_rx <= 0;
            cnt_hb_req_rx   <= 0;
        end else if (fire_in_process && rx_user_last) begin
            if (sop_in ? hb_match_now : is_hb_type)
                cnt_hb_req_rx <= cnt_hb_req_rx + 1;
            else
                cnt_user_req_rx <= cnt_user_req_rx + 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_user_reply_tx <= 0;
            cnt_hb_reply_tx   <= 0;
        end else if (fire_out && tx_user_last) begin
            // V? is_hb_r s? b? x?a ? chu k? sau b?i fire_out, counter ch? t?ng ??ng 1 l?n
            if (is_hb_r) 
                cnt_hb_reply_tx <= cnt_hb_reply_tx + 1;
            else
                cnt_user_reply_tx <= cnt_user_reply_tx + 1;
        end
    end
    
endmodule
module master_server #(
    parameter NUM_SERVERS = 4,
    parameter SERVER_ID_WIDTH = $clog2(NUM_SERVERS),
    parameter USER_RESP_EN = 1
)(
    input wire clk, rst_n,
    input wire [NUM_SERVERS-1:0] server_en,  // Server alive/enable signal
    input wire rx_user_valid, rx_user_last,
    input wire [511:0] rx_user_data,
    input wire [63:0] rx_user_keep,
    output wire rx_user_ready,
    
    output wire tx_user_valid, tx_user_last,
    output wire [511:0] tx_user_data,
    output wire [63:0] tx_user_keep,
    input wire tx_user_ready,
    
    output wire [NUM_SERVERS*32-1:0] server_ip_list,
    output wire                      server_ip_list_valid,
   
    output wire [NUM_SERVERS*15-1:0] cnt_user_req_rx, cnt_hb_req_rx,
    output wire [NUM_SERVERS*15-1:0] cnt_user_reply_tx, cnt_hb_reply_tx
);

    // --- 0. Input FIFO (Buffer & Decouple) ---
    wire in_fifo_valid, in_fifo_last;
    wire [511:0] in_fifo_data;
    wire [63:0] in_fifo_keep;
    wire in_fifo_ready;

    axis_fifo #(.DEPTH(8)) u_input_fifo (
        .clk(clk), .rst_n(rst_n),
        .s_valid(rx_user_valid), .s_data(rx_user_data),
        .s_keep(rx_user_keep), .s_last(rx_user_last),
        .s_ready(rx_user_ready),
        .m_valid(in_fifo_valid), .m_data(in_fifo_data),
        .m_keep(in_fifo_keep), .m_last(in_fifo_last),
        .m_ready(in_fifo_consume)
    );

    // --- 1. SOP Tracking & Sticky Control ---
    reg sop;
    wire fire = in_fifo_valid && in_fifo_consume;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sop <= 1'b1;
        else if (fire) sop <= in_fifo_last;
    end

    reg sticky_is_hb;
    reg [SERVER_ID_WIDTH-1:0] sticky_target;
    
    wire current_is_hb = (in_fifo_data[223:208] == 16'd8888);

    // FIX: t?ch field ra
    wire [31:0] dst_field;
    assign dst_field = in_fifo_data[271:240];

    wire [7:0] dst_byte;
    assign dst_byte = dst_field[7:0];

    wire [SERVER_ID_WIDTH-1:0] current_target;
    assign current_target = (dst_byte >= 8'd100) ? (dst_byte - 8'd100) : 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            sticky_is_hb <= 1'b0; 
            sticky_target <= {SERVER_ID_WIDTH{1'b0}}; 
        end
        else if (fire && sop) begin
            sticky_is_hb <= current_is_hb;
            sticky_target <= current_target;
        end
    end

    wire pkt_is_hb = sop ? current_is_hb : sticky_is_hb;
    wire [SERVER_ID_WIDTH-1:0] pkt_target = sop ? current_target : sticky_target;

    // --- 2. Input Distribution (Fanout) ---
    wire [NUM_SERVERS-1:0] fifo_ready;
    reg  [NUM_SERVERS-1:0] fifo_valid_bus;
    wire hb_any_ready = |fifo_ready;  // Heartbeat: any server ranh la duoc

    always @(*) begin
        fifo_valid_bus = {NUM_SERVERS{1'b0}};
        if (in_fifo_valid) begin
            if (pkt_is_hb)
                fifo_valid_bus = {NUM_SERVERS{1'b1}};
            else
                fifo_valid_bus[pkt_target] = 1'b1;
        end
    end

    // Relax HB ready: chi can any FIFO ranh, khong can tat ca
    assign in_fifo_consume = pkt_is_hb ? hb_any_ready : fifo_ready[pkt_target];

    // --- 3. Instantiations ---
    wire [NUM_SERVERS-1:0] s_valid, s_last, s_ready;
    wire [NUM_SERVERS-1:0] resp_valid, resp_last;
    wire [NUM_SERVERS-1:0] resp_ready;

    wire [511:0] s_data [0:NUM_SERVERS-1];
    wire [511:0] resp_data [0:NUM_SERVERS-1];
    wire [63:0]  s_keep [0:NUM_SERVERS-1];
    wire [63:0]  resp_keep [0:NUM_SERVERS-1];

    genvar i;
    generate
        for (i = 0; i < NUM_SERVERS; i = i + 1) begin : SRV_BLOCK
            assign server_ip_list[i*32 +: 32] = 32'h0a000064 + i;
            
            axis_fifo u_in_fifo (
                .clk(clk), .rst_n(rst_n),
                .s_valid(fifo_valid_bus[i] && in_fifo_valid),
                .s_data(in_fifo_data),
                .s_keep(in_fifo_keep),
                .s_last(in_fifo_last),
                .s_ready(fifo_ready[i]),

                .m_valid(s_valid[i]),
                .m_data(s_data[i]),
                .m_keep(s_keep[i]),
                .m_last(s_last[i]),
                .m_ready(s_ready[i])
            );

            server #(
                .SERVER_ID(i),
                .MY_IP(32'h0a000064 + i),
                .USER_RESP_EN(USER_RESP_EN)
            ) u_inst (
                .clk(clk), .rst_n(rst_n),
                .server_en(server_en[i]),  // Pass individual server_en bit

                .rx_user_valid(s_valid[i]),
                .rx_user_data(s_data[i]),
                .rx_user_keep(s_keep[i]),
                .rx_user_last(s_last[i]),
                .rx_user_ready(s_ready[i]),

                .tx_user_valid(resp_valid[i]),
                .tx_user_data(resp_data[i]),
                .tx_user_keep(resp_keep[i]),
                .tx_user_last(resp_last[i]),
                .tx_user_ready(resp_ready[i]),

                .cnt_user_req_rx(cnt_user_req_rx[i*15 +: 15]),
                .cnt_hb_req_rx(cnt_hb_req_rx[i*15 +: 15]),
                .cnt_user_reply_tx(cnt_user_reply_tx[i*15 +: 15]),
                .cnt_hb_reply_tx(cnt_hb_reply_tx[i*15 +: 15])
            );
        end
    endgenerate
    
    assign server_ip_list_valid = 1'b1;

    // --- 4. Packet-Aware Arbiter ---
    reg [SERVER_ID_WIDTH-1:0] rr_ptr, current_sel;
    reg in_prog;

    wire out_fifo_ready;
    
    integer k;
    reg [SERVER_ID_WIDTH-1:0] sel_idx;
    reg found;

    always @(*) begin
        sel_idx = rr_ptr;
        found = 1'b0;

        if (in_prog) begin
            sel_idx = current_sel;
            found = resp_valid[current_sel];
        end 
        else begin
            for (k = 0; k < NUM_SERVERS; k = k + 1) begin
                if (!found) begin
                    if (rr_ptr + k >= NUM_SERVERS)
                        sel_idx = rr_ptr + k - NUM_SERVERS;
                    else
                        sel_idx = rr_ptr + k;

                    if (resp_valid[sel_idx])
                        found = 1'b1;
                end
            end
        end
    end

    wire arb_valid = found;

    assign resp_ready = (arb_valid && out_fifo_ready) ? (1'b1 << sel_idx) : {NUM_SERVERS{1'b0}};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_ptr <= 0;
            current_sel <= 0;
            in_prog <= 0;
        end 
        else if (arb_valid && out_fifo_ready) begin
            if (resp_last[sel_idx]) begin
                in_prog <= 0;
                rr_ptr  <= (sel_idx == NUM_SERVERS-1) ? 0 : sel_idx + 1;
            end 
            else begin
                in_prog <= 1;
                current_sel <= sel_idx;
            end
        end
    end

    // --- 5. Output FIFO (Optimized Depth) ---
    // Optimize output FIFO depth: NUM_SERVERS / 2 + 2
    localparam OUT_FIFO_DEPTH = (NUM_SERVERS >> 1) + 2;
    axis_fifo #(
        .DEPTH(OUT_FIFO_DEPTH)
    ) u_out_fifo (
        .clk(clk), .rst_n(rst_n),

        .s_valid(arb_valid),
        .s_data(resp_data[sel_idx]),
        .s_keep(resp_keep[sel_idx]),
        .s_last(resp_last[sel_idx]),
        .s_ready(out_fifo_ready),

        .m_valid(tx_user_valid),
        .m_data(tx_user_data),
        .m_keep(tx_user_keep),
        .m_last(tx_user_last),
        .m_ready(tx_user_ready)
    );

endmodule 
