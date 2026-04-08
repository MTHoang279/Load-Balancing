module algorithm_selector #(
    parameter DATA_WIDTH = 32,
    parameter IP_WIDTH  = 32,
    parameter NUM_SERVERS= 4,
    parameter SCN_WIDTH  = 4
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
    
    output wire [DATA_WIDTH-1:0] wr_data,
    output wire                  wr_valid,

    input  wire [2:0]            cfg_algo_sel,
//    input  wire [127:0]          cfg_ip_list,
    input  wire [NUM_SERVERS-1:0]health_bitmap, 
    output reg                   scn_inc_en,
    output reg  [1:0]            scn_server_idx,
    input  wire                   scn_dec_en,
    input  wire  [1:0]            scn_dec_idx,
    
    output reg                   cslb_rd_en,
    input  wire [NUM_SERVERS*IP_WIDTH-1:0]  cslb_rd_ip,
    input  wire [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,
    input  wire                  cslb_rd_valid
);

    //============================================================
    // 1. Internal cache (IP + SCN from SHM)
    //============================================================
    reg [NUM_SERVERS*IP_WIDTH-1:0]  server_ip_cache;
    reg [NUM_SERVERS*SCN_WIDTH-1:0] server_scn_cache;

    reg init_done;

    localparam INIT_IDLE = 2'd0;
    localparam INIT_REQ  = 2'd1;
    localparam INIT_WAIT = 2'd2;
    localparam INIT_DONE = 2'd3;
    
    reg [1:0] init_state;
    
    always @(posedge clock or negedge rst_n) begin
        if(!rst_n) begin
            init_state   <= INIT_IDLE;
            cslb_rd_en   <= 1'b0;
            init_done    <= 1'b0;
        end
        else begin
            case(init_state)
    
            INIT_IDLE: begin
                cslb_rd_en <= 1'b1;   // g?i request
                init_state <= INIT_WAIT;
            end
    
            INIT_WAIT: begin
                cslb_rd_en <= 1'b0;   // ch? pulse 1 cycle
    
                if(cslb_rd_valid) begin
                    server_ip_cache  <= cslb_rd_ip;
                    server_scn_cache <= cslb_rd_scn;
    
                    init_done  <= 1'b1;
                    init_state <= INIT_DONE;
                end
                else begin
                    // retry n?u ch?a có data
                    init_state <= INIT_IDLE;
                end
            end
    
            INIT_DONE: begin
                cslb_rd_en <= 1'b0;
            end
    
            endcase
        end
    end
    //============================================================
    // 1. Decode ch?n thu?t toán (ONE HOT ENABLE)
    //============================================================
    wire sel_rr   = (cfg_algo_sel == 3'b001);
    wire sel_hash = (cfg_algo_sel == 3'b010);
    wire sel_lc   = (cfg_algo_sel == 3'b100);

    //============================================================
    // 2. Gate input theo sel (CH? 1 ALGO NH?N VALID)
    //============================================================
    wire system_ready = init_done && (|health_bitmap);
    wire algo_key_valid = key_valid & system_ready & ~i_ip_full;

    wire rr_key_valid   = algo_key_valid & sel_rr;
    wire hash_key_valid = algo_key_valid & sel_hash;
    wire lc_key_valid   = algo_key_valid & sel_lc;

    //============================================================
    // 3. Output t? các algo
    //============================================================
    wire [DATA_WIDTH-1:0] rr_ip, hash_ip, lc_ip;
    wire rr_valid, hash_valid, lc_valid;
    wire [1:0] rr_id, hash_id, lc_id;

    //============================================================
    // 4. Instantiate các thu?t toán
    //============================================================
    round_robin_algo #(
        .IP_WIDTH(32), // FIX: Truy?n 128 vào ?ây (thay vì m?c ??nh 32) note: use ipv4, v6 will be error
        .N_SERVERS(NUM_SERVERS)
    ) rr_inst (
        .clk        (clock),
        .rst_n      (rst_n),
        .key_valid  (rr_key_valid),
        .cfg_ip_list(server_ip_cache), // 512 bit kh?p v?i 128*4
        .rr_ip      (rr_ip),
        .rr_valid   (rr_valid),
        .rr_id      (rr_id)
    );


    hash_algo #(
        .NUM_SERVERS(NUM_SERVERS)
    ) hash_inst (
        .clk(clock),
        .rst_n(rst_n),
        .src_ip(key_src_ip),
        .dst_ip(key_dst_ip),
        .src_port(key_src_port),
        .dst_port(key_dst_port),
        .protocol(key_protocol),
        .key_valid(hash_key_valid),
        .server_ips_in(server_ip_cache),
        .i_status(health_bitmap),
        .out_server_ip(hash_ip),
        .server_id(hash_id),
        .out_valid(hash_valid)
    );
    
    tlcm_core #(
        .N(NUM_SERVERS ),
        .DATA_W(4),
        .IDX_W(2)
    ) tlcm_inst(
        .clk    (clock),
        .rst_n  (rst_n),
        
        // Request input (AXI-Stream style)
        .data_valid(lc_key_valid),      // tvalid
        .valid(health_bitmap),
        .server_ip(server_ip_cache),
        
        // Interface to external module for SCN decrement
        .scn_dec_en(scn_dec_en),
        .scn_dec_index(scn_dec_idx),
        
        .scn_load_en(cslb_rd_valid),
        .scn_load_data(cslb_rd_scn),
        
        // Outputs to next module
        .dst_valid(lc_valid),       // tvalid
        .dst_ip(lc_ip),          // tdata
        .best_index_out(lc_id)   // metadata
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

    //============================================================
    // 6. Backpressure
    //============================================================
    assign o_ip_full = i_ip_full;
        
    /* MUX output for scn increment */
    always @(*) begin
        scn_inc_en     = wr_valid;
        scn_server_idx = 2'b00;
    
        if (sel_rr)
            scn_server_idx = rr_id;
        else if (sel_hash)
            scn_server_idx = hash_id;
        else if (sel_lc)
            scn_server_idx = lc_id;
    end

endmodule


module round_robin_algo #(
    parameter IP_WIDTH  = 32,
    parameter N_SERVERS = 4
)(
    input  wire                                   clk,
    input  wire                                   rst_n,
    input  wire                                   key_valid,
    input  wire [IP_WIDTH*N_SERVERS-1:0]          cfg_ip_list,

    // Outputs: Chuy?n t? 'reg' sang 'wire' vì dùng logic t? h?p
    output wire [IP_WIDTH-1:0]                    rr_ip,
    output wire                                   rr_valid,
    output wire [$clog2(N_SERVERS)-1:0] rr_id
);

    // Con tr? l?u tr?ng thái (V?n c?n Clock ?? nh?)
    reg [$clog2(N_SERVERS)-1:0] ptr;

    // --------------------------------------------------------
    // 1. Logic T? h?p cho Output (OUTPUT LOGIC)
    // --------------------------------------------------------
    // D? li?u ???c l?y ra NGAY L?P T?C d?a trên giá tr? hi?n t?i c?a ptr
    // Không ch? c?nh lên c?a clock
    assign rr_ip  = cfg_ip_list[ptr * IP_WIDTH +: IP_WIDTH];
    
    // Valid ???c passthrough (truy?n th?ng) t? input
    assign rr_valid = key_valid;
    assign rr_id = ptr;

    // --------------------------------------------------------
    // 2. Logic Tu?n t? cho Tr?ng thái (NEXT STATE LOGIC)
    // --------------------------------------------------------
    // Clock ch? dùng ?? c?p nh?t ptr cho L?N SAU
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptr <= 0;
        end else begin
            if (key_valid) begin
                // Ch? c?p nh?t con tr? khi có yêu c?u h?p l?
                if (ptr == N_SERVERS - 1)
                    ptr <= 0;
                else
                    ptr <= ptr + 1;
            end
        end
    end

endmodule

//module hash_algo #(
//    parameter NUM_SERVERS   = 4,
//    parameter VNODES_PER    = 4,
//    parameter HASH_WIDTH    = 32
//)(
//    input  wire                         clk,
//    input  wire                         rst_n,
    
//    input  wire [NUM_SERVERS*32-1:0]    server_ips_in,

//    /* ------------ Key metadata in ------------ */
//    input  wire                         key_valid,
//    input  wire [31:0]                  src_ip,
//    input  wire [31:0]                  dst_ip,
//    input  wire [15:0]                  src_port,
//    input  wire [15:0]                  dst_port,
//    input  wire [7:0]                   protocol,

//    output wire                         out_valid,
//    output wire [$clog2(NUM_SERVERS)-1:0] server_id,
//    output wire [31:0]                  out_server_ip
//);

//    /* =========================================================
//     * Hash Ring Table
//     * ========================================================= */
//    localparam TOTAL_VNODES = NUM_SERVERS * VNODES_PER;

//    reg [HASH_WIDTH-1:0] ring_hash [0:TOTAL_VNODES-1];
//    reg [$clog2(NUM_SERVERS)-1:0] ring_sid [0:TOTAL_VNODES-1];

//    integer i;

//    initial begin
//        ring_hash[0]  = 32'h10000000; ring_sid[0]  = 0;
//        ring_hash[1]  = 32'h20000000; ring_sid[1]  = 1;
//        ring_hash[2]  = 32'h30000000; ring_sid[2]  = 2;
//        ring_hash[3]  = 32'h40000000; ring_sid[3]  = 3;

//        ring_hash[4]  = 32'h50000000; ring_sid[4]  = 3;
//        ring_hash[5]  = 32'h60000000; ring_sid[5]  = 1;
//        ring_hash[6]  = 32'h70000000; ring_sid[6]  = 0;
//        ring_hash[7]  = 32'h80000000; ring_sid[7]  = 2;

//        ring_hash[8]  = 32'h90000000; ring_sid[8]  = 0;
//        ring_hash[9]  = 32'hA0000000; ring_sid[9]  = 2;
//        ring_hash[10] = 32'hB0000000; ring_sid[10] = 2;
//        ring_hash[11] = 32'hC0000000; ring_sid[11] = 1;

//        ring_hash[12] = 32'hD0000000; ring_sid[12] = 2;
//        ring_hash[13] = 32'hE0000000; ring_sid[13] = 0;
//        ring_hash[14] = 32'hF0000000; ring_sid[14] = 1;
//        ring_hash[15] = 32'hFF000000; ring_sid[15] = 3;
//    end


//    /* =========================================================
//     * Jenkins Hash Pipeline (3 stages)
//     * ========================================================= */
//    reg [31:0] hash_s1, hash_s2, hash_s3;
//    reg        vld_s1,  vld_s2,  vld_s3;

//    wire [31:0] hash_key =
//        src_ip ^ dst_ip ^ {src_port, dst_port} ^ {24'b0, protocol};

//    always @(posedge clk or negedge rst_n) begin
//        if(!rst_n) begin
//            vld_s1 <= 0;
//            vld_s2 <= 0;
//            vld_s3 <= 0;
//        end
//        else begin
//            vld_s1  <= key_valid;
//            hash_s1 <= hash_key + (hash_key << 12);

//            vld_s2  <= vld_s1;
//            hash_s2 <= hash_s1 ^ (hash_s1 >> 5);

//            vld_s3  <= vld_s2;
//            hash_s3 <= hash_s2 + (hash_s2 << 7);
//        end
//    end


//    /* =========================================================
//     * Comparator (combinational)
//     * ========================================================= */
//    reg found;
//    reg [$clog2(TOTAL_VNODES)-1:0] sel_idx;

//    always @(*) begin
//        found   = 1'b0;
//        sel_idx = 0;

//        for(i = 0; i < TOTAL_VNODES; i = i + 1) begin
//            if(!found && (ring_hash[i] >= hash_s3)) begin
//                sel_idx = i;
//                found   = 1'b1;
//            end
//        end
//        if(!found)
//            sel_idx = 0;
//    end


//    /* =========================================================
//     * Output (COMBINATIONAL -> remove extra pipeline stage)
//     * ========================================================= */

//    assign out_valid = vld_s3;
//    assign server_id =
//        ring_sid[sel_idx];
//    assign out_server_ip =
//        server_ips_in[ ring_sid[sel_idx]*32 +: 32 ];

//endmodule