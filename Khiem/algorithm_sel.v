`timescale 1ns / 1ps
module algorithm_selector #(
    parameter DATA_WIDTH = 128,
    parameter KEY_WIDTH  = 32,
    parameter N_SERVERS  = 4, // Thêm parameter để đồng bộ với các module thuật toán
    parameter SCN_W      = 16
)(
    input  wire                  clock,
    input  wire                  rst_n,

    input  wire [31:0]           key_src_ip,
    input  wire [31:0]           key_dst_ip,
    input  wire [15:0]           key_src_port,
    input  wire [15:0]           key_dst_port,
    input  wire [7:0]            key_protocol,
    
    input  wire                  key_valid,
    output wire                  o_ip_full,

    input  wire                  i_ip_full,
    output wire [KEY_WIDTH-1:0] wr_data,
    output wire                  wr_valid,

    input  wire [2:0]            cfg_algo_sel,

    input  wire [N_SERVERS*32-1:0]          cfg_ip_list,
    input  wire [N_SERVERS*SCN_W-1:0]          i_scn,
    input  wire [N_SERVERS-1:0]            i_status,

    output wire [$clog2(N_SERVERS)-1:0] cslb_scn_idx_tx, 
    output wire                         cslb_scn_opcode_tx
);

    //============================================================
    // 1. Decode ch?n thu?t to�n (ONE HOT ENABLE)
    //============================================================
    wire sel_rr   = (cfg_algo_sel == 3'b001);
    wire sel_hash = (cfg_algo_sel == 3'b010);
    wire sel_lc   = (cfg_algo_sel == 3'b100);

    //============================================================
    // 2. Gate input theo sel (CH? 1 ALGO NH?N VALID)
    //============================================================
    wire rr_key_valid   = key_valid & sel_rr   & ~i_ip_full;
    wire hash_key_valid = key_valid & sel_hash & ~i_ip_full;
    wire lc_key_valid   = key_valid & sel_lc   & ~i_ip_full;

    //============================================================
    // 3. Output t? c�c algo
    //============================================================
    wire [KEY_WIDTH-1:0] rr_ip, hash_ip, lc_ip;
    wire rr_valid, hash_valid, lc_valid;

    wire [$clog2(N_SERVERS)-1:0] rr_scn_idx, hash_scn_idx, lc_scn_idx;
    wire                         rr_scn_opcode, hash_scn_opcode, lc_scn_opcode;

    //============================================================
    // 4. Instantiate c�c thu?t to�n
    //============================================================
    round_robin_algo #(
        .IP_WIDTH(KEY_WIDTH), // note: use ipv4, v6 will be error
        .N_SERVERS(N_SERVERS),
        .SCN_W(SCN_W)
    ) rr_inst (
        .clk        (clock),
        .rst_n      (rst_n),
        .key_valid  (rr_key_valid),
        .i_status(i_status),
        .cfg_ip_list(cfg_ip_list), // 512 bit kh?p v?i 128*4
        .rr_ip      (rr_ip),
        .rr_valid   (rr_valid),
        .rr_scn_idx    (rr_scn_idx),    // Nối tín hiệu mới
        .rr_scn_opcode (rr_scn_opcode)  // Nối tín hiệu mới
    );


    hash_algo  #(
        .NUM_SERVERS(N_SERVERS),
        .VNODES_PER    (4), // Số lượng VNode trên mỗi server (tăng để cân bằng tải tốt hơn)
        .HASH_WIDTH    (32),
        .N_SERVERS   (N_SERVERS),
        .SCN_W(SCN_W) // Thêm tham số cho SCN width
    )hash_inst (
        .clk(clock),
        .rst_n(rst_n),
        .src_ip(key_src_ip),
        .dst_ip(key_dst_ip),
        .i_status(i_status),
        .src_port(key_src_port),
        .dst_port(key_dst_port),
        .protocol(key_protocol),
        .key_valid(hash_key_valid),
        .server_ips_in(cfg_ip_list),
        .out_server_ip(hash_ip),
        .out_valid(hash_valid),
        .hash_scn_idx   (hash_scn_idx),
        .hash_scn_opcode(hash_scn_opcode)
    );

    tlcm_algo #(
        .N_SERVERS(N_SERVERS),
        .IP_WIDTH(KEY_WIDTH),
        .SCN_WIDTH(SCN_W)
    )lc_inst (
        .clk(clock),
        .rst_n(rst_n),
        .key_valid(lc_key_valid),
        .cfg_ip_list(cfg_ip_list),
        .i_scn(i_scn),
        .i_status(i_status),
        .out_ip(lc_ip),
        .out_valid(lc_valid),
        .lc_scn_idx     (lc_scn_idx),
        .lc_scn_opcode  (lc_scn_opcode)
    );

    //============================================================
    // 5. MUX output theo sel
    //============================================================
    assign wr_data =
        sel_rr   ? rr_ip   :
        sel_hash ? hash_ip :
        sel_lc   ? lc_ip   :
        {DATA_WIDTH{1'b0}};

    assign wr_valid =
        sel_rr   ? rr_valid   :
        sel_hash ? hash_valid :
        sel_lc   ? lc_valid   :
        1'b0;

    assign cslb_scn_idx_tx = 
        sel_rr   ? rr_scn_idx   :
        sel_hash ? hash_scn_idx :
        sel_lc   ? lc_scn_idx   :
        {($clog2(N_SERVERS)){1'b0}};

    assign cslb_scn_opcode_tx = 
        sel_rr   ? rr_scn_opcode   :
        sel_hash ? hash_scn_opcode :
        sel_lc   ? lc_scn_opcode   :
        1'b0;
    //============================================================
    // 6. Backpressure
    //============================================================
    assign o_ip_full = i_ip_full;

endmodule


module round_robin_algo #(
    parameter IP_WIDTH  = 32,
    parameter N_SERVERS = 8,
    parameter SCN_W     = 16     
)(
    input  wire                               clk,
    input  wire                               rst_n,
    input  wire                               key_valid,
    input  wire [N_SERVERS-1:0]               i_status,
    input  wire [IP_WIDTH*N_SERVERS-1:0]      cfg_ip_list,

    output wire [IP_WIDTH-1:0]                rr_ip,
    output wire                               rr_valid,

    output wire [$clog2(N_SERVERS)-1:0]       rr_scn_idx,
    output wire                               rr_scn_opcode
);

    localparam PTR_W = $clog2(N_SERVERS);

    // (* mark_debug = "true" *) reg [7:0] rr_pkt_count [0:N_SERVERS-1];

    (* mark_debug = "true" *) reg [SCN_W-1:0] rr_pkt_count [0:N_SERVERS-1];
    (* mark_debug = "true" *) wire [N_SERVERS*SCN_W-1:0] rr_pkt_count_dbg;

    genvar g;
    generate
        for (g = 0; g < N_SERVERS; g = g + 1) begin : gen_dbg_flat
            assign rr_pkt_count_dbg[g*SCN_W +: SCN_W] = rr_pkt_count[g];
        end
    endgenerate

    integer l;
    initial begin
        for(l = 0; l < N_SERVERS; l = l + 1) rr_pkt_count[l] = 0;
    end
    reg [PTR_W-1:0] ptr;

    reg [IP_WIDTH-1:0] rr_ip_r;
    reg                rr_valid_r;
    reg [PTR_W-1:0]    rr_idx_r;
    reg                rr_opcode_r;

    assign rr_ip         = rr_ip_r;
    assign rr_valid      = rr_valid_r;
    assign rr_scn_idx    = rr_idx_r;
    assign rr_scn_opcode = rr_opcode_r;


    // ======================================================
    // MẠCH TỔ HỢP TỐI ƯU TIMING: TÌM SERVER ALIVE (Priority Encoder)
    // ======================================================
    reg [PTR_W-1:0] next_ptr;
    reg             found;
    reg [PTR_W-1:0] offset;

    // Kỹ thuật nhân đôi vector status để tránh phải tính Modulo (xoay vòng)
    wire [2*N_SERVERS-1:0] double_status = {i_status, i_status};
    
    // Dịch phải ptr bit. Lúc này window[0] luôn tương ứng với server tại con trỏ ptr.
    wire [2*N_SERVERS-1:0] search_window = double_status >> ptr;

    always @(*) begin
        found  = 1'b1;
        offset = 0;
        
        // Priority Encoder thuần logic (Cực kỳ nhanh, không dùng phép cộng)
        if      (search_window[0]) offset = 0;
        else if (search_window[1]) offset = 1;
        else if (search_window[2]) offset = 2;
        else if (search_window[3]) offset = 3;
        else if (search_window[4]) offset = 4;
        else if (search_window[5]) offset = 5;
        else if (search_window[6]) offset = 6;
        else if (search_window[7]) offset = 7;
        else if (search_window[8]) offset = 8;
        else if (search_window[9]) offset = 9;
        else if (search_window[10]) offset = 10;
        else if (search_window[11]) offset = 11;
        else if (search_window[12]) offset = 12;
        else if (search_window[13]) offset = 13;
        else if (search_window[14]) offset = 14;
        else if (search_window[15]) offset = 15;
        else if (search_window[16]) offset = 16;
        else if (search_window[17]) offset = 17;
        else if (search_window[18]) offset = 18;
        else if (search_window[19]) offset = 19;
        else if (search_window[20]) offset = 20;
        else if (search_window[21]) offset = 21;
        else if (search_window[22]) offset = 22;
        else if (search_window[23]) offset = 23;
        else if (search_window[24]) offset = 24;
        else if (search_window[25]) offset = 25;
        else if (search_window[26]) offset = 26;
        else if (search_window[27]) offset = 27;
        else if (search_window[28]) offset = 28;
        else if (search_window[29]) offset = 29;
        else if (search_window[30]) offset = 30;
        else if (search_window[31]) offset = 31;
        else begin
            offset = 0;
            found  = 1'b0; // Toàn bộ server đã sập
        end
        
        // Tính next_ptr với duy nhất 1 phép cộng và 1 bộ MUX (nhanh hơn rất nhiều)
        if (ptr + offset >= N_SERVERS)
            next_ptr = ptr + offset - N_SERVERS;
        else
            next_ptr = ptr + offset;
    end

    // ======================================================
    // PIPELINE CHO DEBUG COUNTER (Cắt đứt Critical Path)
    // ======================================================
    reg [PTR_W-1:0] ptr_to_count;
    reg             count_valid;

    // ======================================================
    // MẠCH TUẦN TỰ: CẬP NHẬT TRẠNG THÁI
    // ======================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            ptr <= 0;

            rr_valid_r  <= 0;
            rr_ip_r     <= 0;
            rr_idx_r    <= 0;
            rr_opcode_r <= 0;
            
            ptr_to_count <= 0;
            count_valid  <= 0;

        //     for (i = 0; i < N_SERVERS; i = i + 1)
        //         rr_pkt_count[i] <= 0;
        // 
        end 
        else begin
            // 1. Chốt tín hiệu xuất ra
            rr_valid_r  <= key_valid & found;
            rr_opcode_r <= key_valid & found;

            if (key_valid && found) begin
                rr_ip_r  <= cfg_ip_list[next_ptr*IP_WIDTH +: IP_WIDTH];
                rr_idx_r <= next_ptr;

                // Cập nhật con trỏ cho lần sau
                if (next_ptr == N_SERVERS-1)
                    ptr <= 0;
                else
                    ptr <= next_ptr + 1;
            end
            
            // 2. Chốt delay 1 clock cho mạch cộng debug (Giải phóng timing)
            count_valid  <= key_valid & found;
            ptr_to_count <= next_ptr;

            if (count_valid) begin
                rr_pkt_count[ptr_to_count] <= rr_pkt_count[ptr_to_count] + 1;
            end
        end
    end

endmodule


`timescale 1ns / 1ps

module hash_algo #(
    parameter NUM_SERVERS   = 4,
    parameter VNODES_PER    = 4,
    parameter HASH_WIDTH    = 32,
    parameter N_SERVERS     = 4,
    parameter SCN_W         = 16
)(
    input  wire                                 clk,
    input  wire                                 rst_n,
    
    input  wire [NUM_SERVERS*32-1:0]            server_ips_in,

    input  wire                                 key_valid,
    input  wire [NUM_SERVERS-1:0]               i_status,
    input  wire [31:0]                          src_ip,
    input  wire [31:0]                          dst_ip,
    input  wire [15:0]                          src_port,
    input  wire [15:0]                          dst_port,
    input  wire [7:0]                           protocol,

    output reg                                  out_valid,
    output reg  [$clog2(NUM_SERVERS)-1:0]       server_id,
    output reg  [31:0]                          out_server_ip,

    output reg  [$clog2(NUM_SERVERS)-1:0]       hash_scn_idx,
    output reg                                  hash_scn_opcode
);

    // ============================================================
    // PARAMETERS & ARRAYS
    // ============================================================
    localparam TOTAL_VNODES = NUM_SERVERS * VNODES_PER;

    // Phân rã IP Input thành mảng để dễ dàng tạo Multiplexer
    wire [31:0] server_ip_array [0:NUM_SERVERS-1];
    genvar g;
    generate
        for (g = 0; g < NUM_SERVERS; g = g + 1) begin : gen_ip_array
            assign server_ip_array[g] = server_ips_in[g*32 +: 32];
        end
    endgenerate

    // ============================================================
    // FUNCTIONS
    // ============================================================
    // 1. Simple Deterministic Hash
    function [HASH_WIDTH-1:0] vnode_hash;
        input [31:0] sid;
        input [31:0] vid;
        reg [31:0] x;
        begin
            (* use_dsp = "yes" *)
            x = sid * 32'h9E3779B9 ^ vid * 32'h85EBCA6B;
            x = x ^ (x >> 16);
            x = x * 32'h7FEB352D;
            x = x ^ (x >> 15);
            vnode_hash = x;
        end
    endfunction

    // 2. Synthesizable Priority Encoder
    function [$clog2(TOTAL_VNODES)-1:0] get_first_one;
        input [TOTAL_VNODES-1:0] mask;
        integer k;
        begin
            get_first_one = 0;
            // Duyệt ngược từ trên xuống để bit thấp nhất được giữ lại cuối cùng
            for (k = TOTAL_VNODES-1; k >= 0; k = k - 1) begin
                if (mask[k]) get_first_one = k[ $clog2(TOTAL_VNODES)-1:0 ];
            end
        end
    endfunction

    // ============================================================
    // HASH RING (AUTO GENERATED & SORTED)
    // ============================================================
    (* rom_style = "block" *) reg [HASH_WIDTH-1:0]          ring_hash [0:TOTAL_VNODES-1];
    (* rom_style = "block" *) reg [$clog2(NUM_SERVERS)-1:0] ring_sid  [0:TOTAL_VNODES-1];

    integer i, j;
    reg [HASH_WIDTH-1:0]          temp_hash;
    reg [$clog2(NUM_SERVERS)-1:0] temp_sid;

    initial begin
        // 1. Sinh VNode 
        for (i = 0; i < NUM_SERVERS; i = i + 1) begin
            for (j = 0; j < VNODES_PER; j = j + 1) begin
                ring_hash[i*VNODES_PER + j] = vnode_hash(i, j);
                ring_sid [i*VNODES_PER + j] = i;
            end
        end

        // 2. Bubble Sort (Synthesis tool sẽ tính toán trước đoạn này lúc biên dịch)
        for (i = 0; i < TOTAL_VNODES - 1; i = i + 1) begin
            for (j = i + 1; j < TOTAL_VNODES; j = j + 1) begin
                if (ring_hash[i] > ring_hash[j]) begin
                    temp_hash    = ring_hash[i];
                    ring_hash[i] = ring_hash[j];
                    ring_hash[j] = temp_hash;
                    
                    temp_sid    = ring_sid[i];
                    ring_sid[i] = ring_sid[j];
                    ring_sid[j] = temp_sid;
                end
            end
        end
    end

    // ============================================================
    // PIPELINE STAGES (Fully Synchronized)
    // ============================================================
    reg vld_s1, vld_s2, vld_s3, vld_s4, vld_s5, vld_s6, vld_s7;
    
    // Stage 1-3: Jenkins Hash
    reg [31:0] hash_s1, hash_s2, hash_s3;
    wire [31:0] hash_key = src_ip ^ dst_ip ^ src_port ^ dst_port ^ protocol;

    always @(posedge clk) begin
        if (!rst_n) begin
            vld_s1 <= 0; vld_s2 <= 0; vld_s3 <= 0;
            hash_s1 <= 0; hash_s2 <= 0; hash_s3 <= 0;
        end else begin
            vld_s1  <= key_valid;
            hash_s1 <= hash_key + (hash_key << 12);

            vld_s2  <= vld_s1;
            hash_s2 <= hash_s1 ^ (hash_s1 >> 5);

            vld_s3  <= vld_s2;
            hash_s3 <= hash_s2 + (hash_s2 << 7);
        end
    end

    // Stage 4: Comparators
    reg [TOTAL_VNODES-1:0] ge_mask;
    reg [TOTAL_VNODES-1:0] alive_mask;
    integer k;

    always @(posedge clk) begin
        if (!rst_n) begin
            vld_s4 <= 0;
            ge_mask <= 0;
            alive_mask <= 0;
        end else begin
            vld_s4 <= vld_s3;
            if (vld_s3) begin
                for (k = 0; k < TOTAL_VNODES; k = k + 1) begin
                    ge_mask[k]    <= (ring_hash[k] >= hash_s3);
                    alive_mask[k] <= i_status[ring_sid[k]];
                end
            end
        end
    end

    // Stage 5: Mask Generation
    reg [TOTAL_VNODES-1:0] valid_mask;
    reg [TOTAL_VNODES-1:0] wrap_mask;

    always @(posedge clk) begin
        if (!rst_n) begin
            vld_s5 <= 0;
            valid_mask <= 0;
            wrap_mask <= 0;
        end else begin
            vld_s5     <= vld_s4;
            valid_mask <= ge_mask & alive_mask;
            wrap_mask  <= alive_mask;
        end
    end

    // Stage 6: Priority Encoder (Select Index)
    reg [$clog2(TOTAL_VNODES)-1:0] sel_idx;
    reg is_found_s6;

    always @(posedge clk) begin
        if (!rst_n) begin
            vld_s6 <= 0;
            sel_idx <= 0;
            is_found_s6 <= 0;
        end else begin
            vld_s6 <= vld_s5;
            if (vld_s5) begin
                if (|valid_mask) begin
                    sel_idx     <= get_first_one(valid_mask);
                    is_found_s6 <= 1'b1;
                end else if (|wrap_mask) begin
                    sel_idx     <= get_first_one(wrap_mask);
                    is_found_s6 <= 1'b1;
                end else begin
                    sel_idx     <= 0;
                    is_found_s6 <= 1'b0; // Drop packet nếu tất cả server đều chết
                end
            end
        end
    end

    // Stage 7: BRAM Synchronous Read
    reg [$clog2(NUM_SERVERS)-1:0] sid_s7;
    reg is_found_s7;

    always @(posedge clk) begin
        if (!rst_n) begin
            vld_s7 <= 0;
            sid_s7 <= 0;
            is_found_s7 <= 0;
        end else begin
            vld_s7      <= vld_s6;
            is_found_s7 <= is_found_s6;
            // Synchronous BRAM read inference
            sid_s7      <= ring_sid[sel_idx]; 
        end
    end

    // ============================================================
    // Stage 8: OUTPUT LATCH & IP MULTIPLEXER
    // ============================================================
    // (* mark_debug = "true" *) reg [7:0] hash_pkt_count [0:NUM_SERVERS-1];
    (* mark_debug = "true" *) reg [SCN_W-1:0] hash_pkt_count [0:N_SERVERS-1];
    (* mark_debug = "true" *) wire [N_SERVERS*SCN_W-1:0] hash_pkt_count_dbg;

    genvar p;
    generate
        for (p = 0; p < N_SERVERS; p = p + 1) begin : gen_dbg_flat
            assign hash_pkt_count_dbg[p*SCN_W +: SCN_W] = hash_pkt_count[p];
        end
    endgenerate

    integer o;
    initial begin
        for(o = 0; o < N_SERVERS; o = o + 1) hash_pkt_count[o] = 0;
    end


    always @(posedge clk) begin
        if (!rst_n) begin
            out_valid       <= 0;
            server_id       <= 0;
            out_server_ip   <= 0;
            hash_scn_idx    <= 0;
            hash_scn_opcode <= 0;

            // for (m = 0; m < NUM_SERVERS; m = m + 1)
            //     hash_pkt_count[m] <= 0;

        end else begin
            // Chỉ valid nếu tìm được server đang sống (chống treo hệ thống)
            out_valid <= vld_s7 & is_found_s7;

            if (vld_s7 & is_found_s7) begin
                server_id       <= sid_s7;
                out_server_ip   <= server_ip_array[sid_s7]; // Muxing sạch và nhanh

                hash_scn_idx    <= sid_s7;
                hash_scn_opcode <= 1'b1;

                hash_pkt_count[sid_s7] <= hash_pkt_count[sid_s7] + 1;

            end else if (vld_s7 & !is_found_s7) begin
                hash_scn_opcode <= 1'b0;
                // Có thể bổ sung error flag ở đây nếu cần
            end
        end
    end

endmodule

module tlcm_algo #(
    parameter N_SERVERS  = 32,                 // Hỗ trợ tối đa 32 server
    parameter IP_WIDTH  = 32,
    parameter SCN_WIDTH = 16
    //parameter IDX_WIDTH = 5                   // log2(32) = 5 bits
)(
    input  wire                               clk,
    input  wire                               rst_n,
    input  wire                               key_valid,

    input  wire [(N_SERVERS*IP_WIDTH)-1:0]     cfg_ip_list,
    input  wire [(N_SERVERS*SCN_WIDTH)-1:0]    i_scn,
    input  wire [N_SERVERS-1:0]                i_status,

    output reg  [IP_WIDTH-1:0]                out_ip,
    output reg                                out_valid,
    output reg  [$clog2(N_SERVERS)-1:0]        lc_scn_idx,
    output reg                                lc_scn_opcode
);
    localparam IDX_WIDTH = $clog2(N_SERVERS);
    localparam STAGES    = $clog2(32); // hoặc giữ 32 fixed nếu bạn muốn
    //(* mark_debug = "true" *) reg [7:0] tlcm_pkt_count [0:N_SERVERS-1];
    (* mark_debug = "true" *) reg [SCN_WIDTH-1:0] tlcm_pkt_count [0:N_SERVERS-1];
    (* mark_debug = "true" *) wire [N_SERVERS*SCN_WIDTH-1:0] tlcm_pkt_count_dbg;

    genvar p;
    generate
        for (p = 0; p < N_SERVERS; p = p + 1) begin : gen_dbg_flat
            assign tlcm_pkt_count_dbg[p*SCN_WIDTH +: SCN_WIDTH] = tlcm_pkt_count[p];
        end
    endgenerate


    integer r, i, i1, i2, i3, i4;
    initial begin
        for(i = 0; i < N_SERVERS; i = i + 1) tlcm_pkt_count[i] = 0;
    end


    // -------------------------------------------------
    // Chuẩn bị dữ liệu: Unpack input và Padding
    // Nếu N_SERVERS < 32, các node còn lại sẽ bị vô hiệu hóa
    // -------------------------------------------------
    wire [SCN_WIDTH-1:0] scn_in [0:31];
    wire                 stat_in[0:31];

    genvar g;
    generate
        for (g = 0; g < 32; g = g + 1) begin : gen_pad
            if (g < N_SERVERS) begin
                assign scn_in[g]  = i_scn[g*SCN_WIDTH +: SCN_WIDTH];
                assign stat_in[g] = i_status[g];
            end else begin
                assign scn_in[g]  = {SCN_WIDTH{1'b1}}; // Giá trị SCN lớn nhất (Penalty)
                assign stat_in[g] = 1'b0;              // Trạng thái Offline
            end
        end
    endgenerate

    // -------------------------------------------------
    // Khai báo các thanh ghi Pipeline cho 6 Stages
    // -------------------------------------------------
    // Stage 1 (32 -> 16)
    reg [SCN_WIDTH-1:0] s1_scn [0:15];
    reg [IDX_WIDTH-1:0] s1_idx [0:15];
    reg                 s1_stat[0:15];
    reg                 s1_val;

    // Stage 2 (16 -> 8)
    reg [SCN_WIDTH-1:0] s2_scn [0:7];
    reg [IDX_WIDTH-1:0] s2_idx [0:7];
    reg                 s2_stat[0:7];
    reg                 s2_val;

    // Stage 3 (8 -> 4)
    reg [SCN_WIDTH-1:0] s3_scn [0:3];
    reg [IDX_WIDTH-1:0] s3_idx [0:3];
    reg                 s3_stat[0:3];
    reg                 s3_val;

    // Stage 4 (4 -> 2)
    reg [SCN_WIDTH-1:0] s4_scn [0:1];
    reg [IDX_WIDTH-1:0] s4_idx [0:1];
    reg                 s4_stat[0:1];
    reg                 s4_val;

    // Stage 5 (2 -> 1) - Tách riêng phần chốt Index
    reg [IDX_WIDTH-1:0] s5_idx;
    reg                 s5_val;

    // -------------------------------------------------
    // Logic Pipeline 6 Stages
    // -------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            out_valid <= 0; out_ip <= 0; lc_scn_idx <= 0; lc_scn_opcode <= 0;
            s1_val <= 0; s2_val <= 0; s3_val <= 0; s4_val <= 0; s5_val <= 0;
            s5_idx <= 0;
            
            for(r=0; r<16; r=r+1) begin s1_scn[r]<=0; s1_idx[r]<=0; s1_stat[r]<=0; end
            for(r=0; r<8;  r=r+1) begin s2_scn[r]<=0; s2_idx[r]<=0; s2_stat[r]<=0; end
            for(r=0; r<4;  r=r+1) begin s3_scn[r]<=0; s3_idx[r]<=0; s3_stat[r]<=0; end
            for(r=0; r<2;  r=r+1) begin s4_scn[r]<=0; s4_idx[r]<=0; s4_stat[r]<=0; end
            // for(r=0; r<32; r=r+1) begin tlcm_pkt_count[r]<=0; end
        end else begin
            
            // ==========================================
            // STAGE 1: Tìm min ở 16 cặp (32 -> 16)
            // ==========================================
            s1_val <= key_valid;
            for (i1 = 0; i1 < 16; i1 = i1 + 1) begin
                if (!stat_in[2*i1] && !stat_in[2*i1+1]) begin
                    s1_scn[i1] <= scn_in[2*i1]; s1_idx[i1] <= 2*i1; s1_stat[i1] <= 0;
                end else if (!stat_in[2*i1]) begin
                    s1_scn[i1] <= scn_in[2*i1+1]; s1_idx[i1] <= 2*i1+1; s1_stat[i1] <= 1;
                end else if (!stat_in[2*i1+1]) begin
                    s1_scn[i1] <= scn_in[2*i1]; s1_idx[i1] <= 2*i1; s1_stat[i1] <= 1;
                end else if (scn_in[2*i1] <= scn_in[2*i1+1]) begin
                    s1_scn[i1] <= scn_in[2*i1]; s1_idx[i1] <= 2*i1; s1_stat[i1] <= 1;
                end else begin
                    s1_scn[i1] <= scn_in[2*i1+1]; s1_idx[i1] <= 2*i1+1; s1_stat[i1] <= 1;
                end
            end

            // ==========================================
            // STAGE 2: Tìm min ở 8 cặp (16 -> 8)
            // ==========================================
            s2_val <= s1_val;
            for (i2 = 0; i2 < 8; i2 = i2 + 1) begin
                if (!s1_stat[2*i2] && !s1_stat[2*i2+1]) begin
                    s2_scn[i2] <= s1_scn[2*i2]; s2_idx[i2] <= s1_idx[2*i2]; s2_stat[i2] <= 0;
                end else if (!s1_stat[2*i2]) begin
                    s2_scn[i2] <= s1_scn[2*i2+1]; s2_idx[i2] <= s1_idx[2*i2+1]; s2_stat[i2] <= 1;
                end else if (!s1_stat[2*i2+1]) begin
                    s2_scn[i2] <= s1_scn[2*i2]; s2_idx[i2] <= s1_idx[2*i2]; s2_stat[i2] <= 1;
                end else if (s1_scn[2*i2] <= s1_scn[2*i2+1]) begin
                    s2_scn[i2] <= s1_scn[2*i2]; s2_idx[i2] <= s1_idx[2*i2]; s2_stat[i2] <= 1;
                end else begin
                    s2_scn[i2] <= s1_scn[2*i2+1]; s2_idx[i2] <= s1_idx[2*i2+1]; s2_stat[i2] <= 1;
                end
            end

            // ==========================================
            // STAGE 3: Tìm min ở 4 cặp (8 -> 4)
            // ==========================================
            s3_val <= s2_val;
            for (i3 = 0; i3 < 4; i3 = i3 + 1) begin
                if (!s2_stat[2*i3] && !s2_stat[2*i3+1]) begin
                    s3_scn[i3] <= s2_scn[2*i3]; s3_idx[i3] <= s2_idx[2*i3]; s3_stat[i3] <= 0;
                end else if (!s2_stat[2*i3]) begin
                    s3_scn[i3] <= s2_scn[2*i3+1]; s3_idx[i3] <= s2_idx[2*i3+1]; s3_stat[i3] <= 1;
                end else if (!s2_stat[2*i3+1]) begin
                    s3_scn[i3] <= s2_scn[2*i3]; s3_idx[i3] <= s2_idx[2*i3]; s3_stat[i3] <= 1;
                end else if (s2_scn[2*i3] <= s2_scn[2*i3+1]) begin
                    s3_scn[i3] <= s2_scn[2*i3]; s3_idx[i3] <= s2_idx[2*i3]; s3_stat[i3] <= 1;
                end else begin
                    s3_scn[i3] <= s2_scn[2*i3+1]; s3_idx[i3] <= s2_idx[2*i3+1]; s3_stat[i3] <= 1;
                end
            end

            // ==========================================
            // STAGE 4: Tìm min ở 2 cặp (4 -> 2)
            // ==========================================
            s4_val <= s3_val;
            for (i4 = 0; i4 < 2; i4 = i4 + 1) begin
                if (!s3_stat[2*i4] && !s3_stat[2*i4+1]) begin
                    s4_scn[i4] <= s3_scn[2*i4]; s4_idx[i4] <= s3_idx[2*i4]; s4_stat[i4] <= 0;
                end else if (!s3_stat[2*i4]) begin
                    s4_scn[i4] <= s3_scn[2*i4+1]; s4_idx[i4] <= s3_idx[2*i4+1]; s4_stat[i4] <= 1;
                end else if (!s3_stat[2*i4+1]) begin
                    s4_scn[i4] <= s3_scn[2*i4]; s4_idx[i4] <= s3_idx[2*i4]; s4_stat[i4] <= 1;
                end else if (s3_scn[2*i4] <= s3_scn[2*i4+1]) begin
                    s4_scn[i4] <= s3_scn[2*i4]; s4_idx[i4] <= s3_idx[2*i4]; s4_stat[i4] <= 1;
                end else begin
                    s4_scn[i4] <= s3_scn[2*i4+1]; s4_idx[i4] <= s3_idx[2*i4+1]; s4_stat[i4] <= 1;
                end
            end

            // ==========================================
            // STAGE 5: So sánh vòng cuối (2 -> 1) - Tách riêng tính Index
            // ==========================================
            s5_val <= s4_val;
            if (s4_val) begin
                if (!s4_stat[0] && !s4_stat[1])      s5_idx <= s4_idx[0];
                else if (!s4_stat[0])                s5_idx <= s4_idx[1];
                else if (!s4_stat[1])                s5_idx <= s4_idx[0];
                else if (s4_scn[0] <= s4_scn[1])     s5_idx <= s4_idx[0];
                else                                 s5_idx <= s4_idx[1];
            end

            // ==========================================
            // STAGE 6: Trích xuất IP & Tăng Counter (An toàn Timing)
            // ==========================================
            out_valid <= s5_val;
            if (s5_val) begin
                lc_scn_opcode <= 1'b1;
                lc_scn_idx    <= s5_idx;
                
                // MUX và Bộ cộng lúc này chỉ phụ thuộc vào thanh ghi s5_idx, không còn bị dồn logic
                tlcm_pkt_count[s5_idx] <= tlcm_pkt_count[s5_idx] + 1;
                out_ip <= cfg_ip_list[s5_idx * IP_WIDTH +: IP_WIDTH];
            end else begin
                lc_scn_opcode <= 1'b0;
                out_ip        <= 0;
            end
            
        end
    end

endmodule
