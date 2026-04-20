
////module tlcm_core #(
////    parameter N      = 16,
////    parameter DATA_W = 12,
////    parameter IDX_W  = $clog2(N)
////)(
////    input                    clk,
////    input                    rst_n,
    
////    // Request input (AXI-Stream style)
////    input                    data_valid,      // tvalid
////    input  [N-1:0]           valid,           // server health state
////    input  [N*32-1:0]        server_ip,       // Connect to cslb_rd_ip from SHM
    
////    // Interface to external module for SCN decrement
////    input                    scn_dec_en,
////    input  [IDX_W-1:0]       scn_dec_index,
    
////    // Interface to load initial SCN from SHM
////    input                    scn_load_en,     // Connect to cslb_rd_valid from SHM
////    input  [N*DATA_W-1:0]    scn_load_data,   // Connect to cslb_rd_scn from SHM

////    // Unified SCN increment from algorithm selector (RR/HASH/TLCM)
////    input                    scn_inc_en,
////    input  [IDX_W-1:0]       scn_inc_index,
    
////    // Outputs to next module
////    output reg               dst_valid,       // tvalid
////    output reg [31:0]        dst_ip,          // tdata
////    output reg [IDX_W-1:0]   best_index_out   // metadata
////);

////    localparam SCORE_W = $clog2(N);

//////    reg [IDX_W-1:0] tie_bias;
////    (* mark_debug = "true", keep = "true" *) reg [31:0] tlcm_pkt_count [0:N-1];

////    integer c_i;
////    (* mark_debug = "true", keep = "true", dont_touch = "true" *)
////    wire [N*32-1:0] tlcm_pkt_count_flat;
    
////    genvar g;
////    generate
////        for (g = 0; g < N; g = g + 1) begin : GEN_TLCM_PKT_COUNT_FLAT
////            assign tlcm_pkt_count_flat[g*32 +: 32] = tlcm_pkt_count[g];
////        end
////    endgenerate

////    // ============================================
////    // Local SCN Buffer (Memory)
////    // ============================================
////    wire [N*DATA_W-1:0] scn_current;
    
////    local_scn_buffer #(
////        .N(N),
////        .DATA_W(DATA_W)
////    ) u_scn_buffer (
////        .clk          (clk),
////        .rst_n        (rst_n),
////        .server_valid (valid),
////        .inc_en       (scn_inc_en),
////        .inc_index    (scn_inc_index),
////        .dec_en       (scn_dec_en),
////        .dec_index    (scn_dec_index),
////        .load_en      (scn_load_en),
////        .load_data    (scn_load_data),
////        .scn_current  (scn_current)
////    );

////    // ========================================
////    // Stage 1: Score computation
////    // ========================================
////    wire [N*N-1:0]  score_part_w;
////    wire            pipe_valid_s1;
////    wire [N-1:0]    server_valid_w1;

////    reg  [N*N-1:0]  score_part_r;
////    reg             pipe_valid_r1;
////    reg  [N-1:0]    server_valid_r1;

////    assign pipe_valid_s1 = data_valid && (|valid);

////    tlcm_stage1 #(
////        .N(N),
////        .DATA_W(DATA_W),
////        .IDX_W(IDX_W)
////    ) u_stage1 (
////        .scn              (scn_current),
////        .server_valid     (valid),
//////        .tie_bias         (tie_bias),
////        .score_part       (score_part_w),
////        .server_valid_out (server_valid_w1)
////    );

////    // ========================================
////    // Stage 2: Sum scores using adder tree
////    // ========================================
////    wire [N*SCORE_W-1:0]  total_score_w;
////    wire            pipe_valid_s2;
////    wire [N-1:0]    server_valid_w2;

////    reg  [N*SCORE_W-1:0]  total_score_r;
////    reg             pipe_valid_r2;
////    reg  [N-1:0]    server_valid_r2;

////    tlcm_stage2 #(
////        .N(N),
////        .SCORE_W(SCORE_W)
////    ) u_stage2 (
////        .score_part       (score_part_r),
////        .pipe_valid_in    (pipe_valid_r1),
////        .server_valid_in  (server_valid_r1),
////        .total_score      (total_score_w),
////        .pipe_valid_out   (pipe_valid_s2),
////        .server_valid_out (server_valid_w2)
////    );

////    // ========================================
////    // Stage 3: Find best using max tree
////    // ========================================
////    wire [IDX_W-1:0] best_index_w;
////    wire             pipe_valid_s3;
////    wire [N-1:0]     server_valid_w3;

////    reg  [IDX_W-1:0] best_index_r;
////    reg              pipe_valid_r3;
////    reg  [N-1:0]     server_valid_r3;

////    tlcm_stage3 #(
////        .N(N),
////        .IDX_W(IDX_W),
////        .SCORE_W(SCORE_W)
////    ) u_stage3 (
////        .total_score      (total_score_r),
////        .pipe_valid_in    (pipe_valid_r2),
////        .server_valid_in  (server_valid_r2),
////        .best_index       (best_index_w),
////        .pipe_valid_out   (pipe_valid_s3),
////        .server_valid_out (server_valid_w3)
////    );

////    // ========================================
////    // Stage 4: Output
////    // ========================================
////    wire [31:0]      dst_ip_next;
////    wire             dst_valid_next;
////    wire [IDX_W-1:0] best_index_next;
    
////    assign dst_valid_next  = pipe_valid_r3 && server_valid_r3[best_index_r];
////    assign dst_ip_next     = pipe_valid_r3 ? server_ip[best_index_r*32 +: 32] : 32'b0;
////    assign best_index_next = pipe_valid_r3 ? best_index_r : {IDX_W{1'b0}};

////    // ========================================
////    // Pipeline registers
////    // ========================================
////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin
////            // Reset all pipeline registers
////            pipe_valid_r1     <= 1'b0;
////            pipe_valid_r2     <= 1'b0;
////            pipe_valid_r3     <= 1'b0;
////            server_valid_r1   <= {N{1'b0}};
////            server_valid_r2   <= {N{1'b0}};
////            server_valid_r3   <= {N{1'b0}};
////            score_part_r      <= {(N*N){1'b0}};
////            total_score_r     <= {(N*SCORE_W){1'b0}};
////            best_index_r      <= {IDX_W{1'b0}};
////            dst_ip            <= 32'b0;
////            dst_valid         <= 1'b0;
////            best_index_out    <= {IDX_W{1'b0}};
//////            tie_bias          <= {IDX_W{1'b0}};

////            for (c_i = 0; c_i < N; c_i = c_i + 1)
////                tlcm_pkt_count[c_i] <= 32'd0;
////        end else begin
////            // Rotate tie priority each request to avoid fixed-index starvation when SCN values are equal.
//////            if (data_valid)
//////                tie_bias <= tie_bias + {{(IDX_W-1){1'b0}}, 1'b1};

////            // Stage 1 -> Stage 2
////            if (data_valid) begin
////                score_part_r      <= score_part_w;
////                server_valid_r1   <= server_valid_w1;
////                pipe_valid_r1     <= pipe_valid_s1;
////            end else begin
////                score_part_r      <= {(N*N){1'b0}};
////                server_valid_r1   <= {N{1'b0}};
////                pipe_valid_r1     <= 1'b0;
////            end

////            // Stage 2 -> Stage 3
////            if (pipe_valid_r1) begin
////                total_score_r     <= total_score_w;
////                server_valid_r2   <= server_valid_w2;
////            end else begin
////                total_score_r     <= {(N*SCORE_W){1'b0}};
////                server_valid_r2   <= {N{1'b0}};
////            end
////            pipe_valid_r2     <= pipe_valid_s2;

////            // Stage 3 -> Stage 4
////            if (pipe_valid_r2) begin
////                best_index_r      <= best_index_w;
////                server_valid_r3   <= server_valid_w3;
////            end else begin
////                best_index_r      <= {IDX_W{1'b0}};
////                server_valid_r3   <= {N{1'b0}};
////            end
////            pipe_valid_r3     <= pipe_valid_s3;

////            // Stage 4 -> Output
////            if (pipe_valid_r3) begin
////                dst_ip            <= dst_ip_next;
////                dst_valid         <= dst_valid_next;
////                best_index_out    <= best_index_next;
////                if (dst_valid_next) begin
////                    tlcm_pkt_count[best_index_next] <= tlcm_pkt_count[best_index_next] + 1'b1;
////                end
////            end else begin
////                dst_ip            <= 32'b0;
////                dst_valid         <= 1'b0;
////                best_index_out    <= {IDX_W{1'b0}};
////            end
////        end
////    end

////endmodule


//module tlcm_core #(
//    parameter N      = 16,
//    parameter DATA_W = 12,
//    parameter IDX_W  = $clog2(N)
//)(
//    input                    clk,
//    input                    rst_n,
    
//    // Request input (AXI-Stream style)
//    input                    data_valid,      // tvalid
//    input  [N-1:0]           valid,           // server health state
//    input  [N*32-1:0]        server_ip,       // Connect to cslb_rd_ip from SHM
    
//    // Interface to external module for SCN decrement
//    input                    scn_dec_en,
//    input  [IDX_W-1:0]       scn_dec_index,
    
//    // Interface to load initial SCN from SHM
//    input                    scn_load_en,     // Connect to cslb_rd_valid from SHM
//    input  [N*DATA_W-1:0]    scn_load_data,   // Connect to cslb_rd_scn from SHM

//    // Unified SCN increment from algorithm selector (RR/HASH/TLCM)
//    input                    scn_inc_en,
//    input  [IDX_W-1:0]       scn_inc_index,
    
//    // Outputs to next module
//    output reg               dst_valid,       // tvalid
//    output reg [31:0]        dst_ip,          // tdata
//    output reg [IDX_W-1:0]   best_index_out   // metadata
//);

//    localparam SCORE_W = $clog2(N);

//    reg [IDX_W-1:0] tie_bias;
//    (* mark_debug = "true", keep = "true" *) reg [31:0] tlcm_pkt_count [0:N-1];

//    integer c_i;
//    (* mark_debug = "true", keep = "true", dont_touch = "true" *)
//    wire [N*32-1:0] tlcm_pkt_count_flat;
    
//    genvar g;
//    generate
//        for (g = 0; g < N; g = g + 1) begin : GEN_TLCM_PKT_COUNT_FLAT
//            assign tlcm_pkt_count_flat[g*32 +: 32] = tlcm_pkt_count[g];
//        end
//    endgenerate

//    // ============================================
//    // Local SCN Buffer (Memory)
//    // ============================================
//    wire [N*DATA_W-1:0] scn_current;
    
//    local_scn_buffer #(
//        .N(N),
//        .DATA_W(DATA_W)
//    ) u_scn_buffer (
//        .clk          (clk),
//        .rst_n        (rst_n),
//        .server_valid (valid),
//        .inc_en       (scn_inc_en),
//        .inc_index    (scn_inc_index),
//        .dec_en       (scn_dec_en),
//        .dec_index    (scn_dec_index),
//        .load_en      (scn_load_en),
//        .load_data    (scn_load_data),
//        .scn_current  (scn_current)
//    );

//    // ========================================
//    // Stage 1: Score computation
//    // ========================================
//    wire [N*N-1:0]  score_part_w;
//    wire            pipe_valid_s1;
//    wire [N-1:0]    server_valid_w1;

//    reg  [N*N-1:0]  score_part_r;
//    reg             pipe_valid_r1;
//    reg  [N-1:0]    server_valid_r1;

//    assign pipe_valid_s1 = data_valid && (|valid);

//    tlcm_stage1 #(
//        .N(N),
//        .DATA_W(DATA_W),
//        .IDX_W(IDX_W)
//    ) u_stage1 (
//        .scn              (scn_current),
//        .server_valid     (valid),
//        .tie_bias         (tie_bias),
//        .score_part       (score_part_w),
//        .server_valid_out (server_valid_w1)
//    );

//    // ========================================
//    // Stage 2: Sum scores using adder tree
//    // ========================================
//    wire [N*SCORE_W-1:0]  total_score_w;
//    wire            pipe_valid_s2;
//    wire [N-1:0]    server_valid_w2;

//    reg  [N*SCORE_W-1:0]  total_score_r;
//    reg             pipe_valid_r2;
//    reg  [N-1:0]    server_valid_r2;

//    tlcm_stage2 #(
//        .N(N),
//        .SCORE_W(SCORE_W)
//    ) u_stage2 (
//        .score_part       (score_part_r),
//        .pipe_valid_in    (pipe_valid_r1),
//        .server_valid_in  (server_valid_r1),
//        .total_score      (total_score_w),
//        .pipe_valid_out   (pipe_valid_s2),
//        .server_valid_out (server_valid_w2)
//    );

//    // ========================================
//    // Stage 3: Find best using max tree
//    // ========================================
//    wire [IDX_W-1:0] best_index_w;
//    wire             pipe_valid_s3;
//    wire [N-1:0]     server_valid_w3;

//    reg  [IDX_W-1:0] best_index_r;
//    reg              pipe_valid_r3;
//    reg  [N-1:0]     server_valid_r3;

//    tlcm_stage3 #(
//        .N(N),
//        .IDX_W(IDX_W),
//        .SCORE_W(SCORE_W)
//    ) u_stage3 (
//        .total_score      (total_score_r),
//        .pipe_valid_in    (pipe_valid_r2),
//        .server_valid_in  (server_valid_r2),
//        .best_index       (best_index_w),
//        .pipe_valid_out   (pipe_valid_s3),
//        .server_valid_out (server_valid_w3)
//    );

//    // ========================================
//    // Stage 4: Output
//    // ========================================
//    wire [31:0]      dst_ip_next;
//    wire             dst_valid_next;
//    wire [IDX_W-1:0] best_index_next;
//    wire best_alive = server_valid_r3[best_index_r];

//    assign dst_valid_next  = pipe_valid_r3 && best_alive;
//    assign dst_ip_next     = (pipe_valid_r3 && best_alive) ? server_ip[best_index_r*32 +: 32] : 32'b0;
//    assign best_index_next = (pipe_valid_r3 && best_alive) ? best_index_r : {IDX_W{1'b0}};

//    // ========================================
//    // Pipeline registers
//    // ========================================
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            // Reset all pipeline registers
//            pipe_valid_r1     <= 1'b0;
//            pipe_valid_r2     <= 1'b0;
//            pipe_valid_r3     <= 1'b0;
//            server_valid_r1   <= {N{1'b0}};
//            server_valid_r2   <= {N{1'b0}};
//            server_valid_r3   <= {N{1'b0}};
//            score_part_r      <= {(N*N){1'b0}};
//            total_score_r     <= {(N*SCORE_W){1'b0}};
//            best_index_r      <= {IDX_W{1'b0}};
//            dst_ip            <= 32'b0;
//            dst_valid         <= 1'b0;
//            best_index_out    <= {IDX_W{1'b0}};
//            tie_bias          <= {IDX_W{1'b0}};

//            for (c_i = 0; c_i < N; c_i = c_i + 1)
//                tlcm_pkt_count[c_i] <= 32'd0;
//        end else begin
//            // Rotate tie priority each request to avoid fixed-index starvation when SCN values are equal.
//            if (data_valid)
//                tie_bias <= tie_bias + {{(IDX_W-1){1'b0}}, 1'b1};

//            // Stage 1 -> Stage 2
//            if (data_valid) begin
//                score_part_r      <= score_part_w;
//                server_valid_r1   <= server_valid_w1;
//                pipe_valid_r1     <= pipe_valid_s1;
//            end else begin
//                score_part_r      <= {(N*N){1'b0}};
//                server_valid_r1   <= {N{1'b0}};
//                pipe_valid_r1     <= 1'b0;
//            end

//            // Stage 2 -> Stage 3
//            if (pipe_valid_r1) begin
//                total_score_r     <= total_score_w;
//                server_valid_r2   <= server_valid_w2;
//            end else begin
//                total_score_r     <= {(N*SCORE_W){1'b0}};
//                server_valid_r2   <= {N{1'b0}};
//            end
//            pipe_valid_r2     <= pipe_valid_s2;

//            // Stage 3 -> Stage 4
//            if (pipe_valid_r2) begin
//                best_index_r      <= best_index_w;
//                server_valid_r3   <= server_valid_w3;
//            end else begin
//                best_index_r      <= {IDX_W{1'b0}};
//                server_valid_r3   <= {N{1'b0}};
//            end
//            pipe_valid_r3     <= pipe_valid_s3;

//            // Stage 4 -> Output
//            if (pipe_valid_r3) begin
//                dst_ip            <= dst_ip_next;
//                dst_valid         <= dst_valid_next;
//                best_index_out    <= best_index_next;
//                if (dst_valid_next) begin
//                    tlcm_pkt_count[best_index_next] <= tlcm_pkt_count[best_index_next] + 1'b1;
//                end
//            end else begin
//                dst_ip            <= 32'b0;
//                dst_valid         <= 1'b0;
//                best_index_out    <= {IDX_W{1'b0}};
//            end
//        end
//    end

//endmodule

module tlcm_core #(
    parameter N      = 16,
    parameter DATA_W = 12,
    parameter IDX_W  = $clog2(N)
)(
    input                    clk,
    input                    rst_n,
    
    // Request input (AXI-Stream style)
    input                    data_valid,      // tvalid
    input  [N-1:0]           valid,           // server health state
    input  [N*32-1:0]        server_ip,       // Connect to cslb_rd_ip from SHM
    
    // Interface to external module for SCN decrement
    input                    scn_dec_en,
    input  [IDX_W-1:0]       scn_dec_index,
    
    // Interface to load initial SCN from SHM
    input                    scn_load_en,     // Connect to cslb_rd_valid from SHM
    input  [N*DATA_W-1:0]    scn_load_data,   // Connect to cslb_rd_scn from SHM

    // Unified SCN increment from algorithm selector (RR/HASH/TLCM)
    input                    scn_inc_en,
    input  [IDX_W-1:0]       scn_inc_index,
    
    // Outputs to next module
    output reg               dst_valid,       // tvalid
    output reg [31:0]        dst_ip,          // tdata
    output reg [IDX_W-1:0]   best_index_out   // metadata
);

    localparam SCORE_W = $clog2(N);

    reg [IDX_W-1:0] tie_bias;
    // ============================================
    // Local SCN Buffer (Memory)
    // ============================================
    wire [N*DATA_W-1:0] scn_current;
    wire                scn_inc_local_en;
    wire [IDX_W-1:0]    scn_inc_local_index;
    
    local_scn_buffer #(
        .N(N),
        .DATA_W(DATA_W)
    ) u_scn_buffer (
        .clk          (clk),
        .rst_n        (rst_n),
        .server_valid (valid),
//        .inc_en       (scn_inc_en),
//        .inc_index    (scn_inc_index),
        .inc_en       (scn_inc_local_en),
        .inc_index    (scn_inc_local_index),
        .dec_en       (scn_dec_en),
        .dec_index    (scn_dec_index),
        .load_en      (scn_load_en),
        .load_data    (scn_load_data),
        .scn_current  (scn_current)
    );
    integer c_i;

    // ========================================
    // Stage 1: Score computation
    // ========================================
    wire [N*N-1:0]  score_part_w;
    wire            pipe_valid_s1;
    wire [N-1:0]    server_valid_w1;

    reg  [N*N-1:0]  score_part_r;
    reg             pipe_valid_r1;
    reg  [N-1:0]    server_valid_r1;

    assign pipe_valid_s1 = data_valid && (|valid);

    tlcm_stage1 #(
        .N(N),
        .DATA_W(DATA_W),
        .IDX_W(IDX_W)
    ) u_stage1 (
        .scn              (scn_current),
        .server_valid     (valid),
        .tie_bias         (tie_bias),
        .score_part       (score_part_w),
        .server_valid_out (server_valid_w1)
    );

    // ========================================
    // Stage 2: Sum scores using adder tree
    // ========================================
    wire [N*SCORE_W-1:0]  total_score_w;
    wire            pipe_valid_s2;
    wire [N-1:0]    server_valid_w2;

    reg  [N*SCORE_W-1:0]  total_score_r;
    reg             pipe_valid_r2;
    reg  [N-1:0]    server_valid_r2;

    tlcm_stage2 #(
        .N(N),
        .SCORE_W(SCORE_W)
    ) u_stage2 (
        .score_part       (score_part_r),
        .pipe_valid_in    (pipe_valid_r1),
        .server_valid_in  (server_valid_r1),
        .total_score      (total_score_w),
        .pipe_valid_out   (pipe_valid_s2),
        .server_valid_out (server_valid_w2)
    );

    // ========================================
    // Stage 3: Find best using max tree
    // ========================================
    wire [IDX_W-1:0] best_index_w;
    wire             pipe_valid_s3;
    wire [N-1:0]     server_valid_w3;

    reg  [IDX_W-1:0] best_index_r;
    reg              pipe_valid_r3;
    reg  [N-1:0]     server_valid_r3;

    tlcm_stage3 #(
        .N(N),
        .IDX_W(IDX_W),
        .SCORE_W(SCORE_W)
    ) u_stage3 (
        .total_score      (total_score_r),
        .pipe_valid_in    (pipe_valid_r2),
        .server_valid_in  (server_valid_r2),
        .best_index       (best_index_w),
        .pipe_valid_out   (pipe_valid_s3),
        .server_valid_out (server_valid_w3)
    );
    
    assign scn_inc_local_en = pipe_valid_r2 && pipe_valid_s3;
    assign scn_inc_local_index = best_index_w;

    // ========================================
    // Stage 4: Output
    // ========================================
    wire [31:0]      dst_ip_next;
    wire             dst_valid_next;
    wire [IDX_W-1:0] best_index_next;
    
    assign dst_valid_next  = pipe_valid_r3 && server_valid_r3[best_index_r];
    assign dst_ip_next     = pipe_valid_r3 ? server_ip[best_index_r*32 +: 32] : 32'b0;
    assign best_index_next = pipe_valid_r3 ? best_index_r : {IDX_W{1'b0}};

    // ========================================
    // Pipeline registers
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all pipeline registers
            pipe_valid_r1     <= 1'b0;
            pipe_valid_r2     <= 1'b0;
            pipe_valid_r3     <= 1'b0;
            server_valid_r1   <= {N{1'b0}};
            server_valid_r2   <= {N{1'b0}};
            server_valid_r3   <= {N{1'b0}};
            score_part_r      <= {(N*N){1'b0}};
            total_score_r     <= {(N*SCORE_W){1'b0}};
            best_index_r      <= {IDX_W{1'b0}};
            dst_ip            <= 32'b0;
            dst_valid         <= 1'b0;
            best_index_out    <= {IDX_W{1'b0}};
            tie_bias          <= {IDX_W{1'b1}};
        end else begin
            // Rotate tie priority on accepted output events for deterministic phase alignment.
//            if (scn_inc_en)
////                tie_bias <= tie_bias + {{(IDX_W-1){1'b0}}, 1'b1};
//                tie_bias <= (tie_bias == {IDX_W{1'b0}}) ? {IDX_W{1'b1}} : (tie_bias - {{(IDX_W-1){1'b0}}, 1'b1});
            if (dst_valid_next)
                tie_bias <= tie_bias + {{(IDX_W-1){1'b0}},1'b1};
            // Stage 1 -> Stage 2
            if (data_valid) begin
                score_part_r      <= score_part_w;
                server_valid_r1   <= server_valid_w1;
                pipe_valid_r1     <= pipe_valid_s1;
            end else begin
                score_part_r      <= {(N*N){1'b0}};
                server_valid_r1   <= {N{1'b0}};
                pipe_valid_r1     <= 1'b0;
            end

            // Stage 2 -> Stage 3
            if (pipe_valid_r1) begin
                total_score_r     <= total_score_w;
                server_valid_r2   <= server_valid_w2;
            end else begin
                total_score_r     <= {(N*SCORE_W){1'b0}};
                server_valid_r2   <= {N{1'b0}};
            end
            pipe_valid_r2     <= pipe_valid_s2;

            // Stage 3 -> Stage 4
            if (pipe_valid_r2) begin
                best_index_r      <= best_index_w;
                server_valid_r3   <= server_valid_w3;
            end else begin
                best_index_r      <= {IDX_W{1'b0}};
                server_valid_r3   <= {N{1'b0}};
            end
            pipe_valid_r3     <= pipe_valid_s3;

            // Stage 4 -> Output
            if (pipe_valid_r3) begin
                dst_ip            <= dst_ip_next;
                dst_valid         <= dst_valid_next;
                best_index_out    <= best_index_next;
            end else begin
                dst_ip            <= 32'b0;
                dst_valid         <= 1'b0;
                best_index_out    <= {IDX_W{1'b0}};
            end
        end
    end

endmodule

