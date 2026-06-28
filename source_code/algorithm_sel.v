
`timescale 1ns / 1ps

module algorithm_selector #(
    parameter DATA_WIDTH = 32,
    parameter IP_WIDTH   = 32,
    parameter NUM_SERVERS = 16,
    parameter SCN_WIDTH  = 12
)(
    input  wire                         clock,
    input  wire                         rst_n,
    
    input  wire [31:0]                  key_src_ip,
    input  wire [31:0]                  key_dst_ip,
    input  wire [15:0]                  key_src_port,
    input  wire [15:0]                  key_dst_port,
    input  wire [7:0]                   key_protocol,
    input  wire                         key_valid,
    
    output wire                         o_ip_full,
    input  wire                         i_ip_full,
    
    output wire [DATA_WIDTH-1:0]        wr_data,
    output wire                         wr_valid,
    
    input  wire [1:0]                   cfg_algo_sel,
    input  wire [NUM_SERVERS-1:0]       health_bitmap,
    
    (* keep = "true" *) output reg                          scn_inc_en,
    (* keep = "true" *) output reg  [$clog2(NUM_SERVERS)-1:0]                   scn_server_idx,
    input  wire                         scn_dec_en,
    input  wire [$clog2(NUM_SERVERS)-1:0]                   scn_dec_idx,
    output reg                          cslb_rd_en,
    
    input  wire [NUM_SERVERS*IP_WIDTH-1:0]  cslb_rd_ip,
    input  wire [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,
    input  wire                         cslb_rd_valid,
   
    output wire [NUM_SERVERS*32-1:0]   rr_pkt_count,
    output wire [NUM_SERVERS*32-1:0]   hash_pkt_count,
    output wire [NUM_SERVERS*32-1:0]   tlcm_pkt_count
);

    reg [NUM_SERVERS*IP_WIDTH-1:0]  server_ip_cache;
    reg [NUM_SERVERS*SCN_WIDTH-1:0] server_scn_cache;
    reg init_done;
    reg [1:0] cfg_algo_sel_d;

    always @(posedge clock or negedge rst_n) begin
        if (!rst_n) begin
            cslb_rd_en       <= 1'b1;
            init_done        <= 1'b0;
            cfg_algo_sel_d   <= 2'b00;
            server_ip_cache  <= {NUM_SERVERS*IP_WIDTH{1'b0}};
            server_scn_cache <= {NUM_SERVERS*SCN_WIDTH{1'b0}};
        end else begin
            // When switching algorithm mode, request a fresh SHM snapshot so
            // TLCM sees up-to-date SCN history accumulated by previous modes.
            if (cfg_algo_sel != cfg_algo_sel_d) begin
                cfg_algo_sel_d <= cfg_algo_sel;
                init_done      <= 1'b0;
                cslb_rd_en     <= 1'b1;
            end

            if (cslb_rd_valid) begin
                server_ip_cache  <= cslb_rd_ip;
                server_scn_cache <= cslb_rd_scn;
                cslb_rd_en       <= 1'b0;
                init_done        <= 1'b1;
            end else if (!init_done) begin
                cslb_rd_en <= 1'b1;
            end
        end
    end

    wire sel_rr   = (cfg_algo_sel == 2'b01);
    wire sel_hash = (cfg_algo_sel == 2'b10);
    wire sel_lc   = (cfg_algo_sel == 2'b11);

    // TLCM must only select healthy servers from SHM bitmap.
    // If bitmap is all-zero, tlcm_core will naturally deassert dst_valid.
    wire [NUM_SERVERS-1:0] tlcm_valid_mask = health_bitmap;
    // Stall key consumption when TLCM has no healthy candidate to prevent key/msg desync.
    wire tlcm_block = sel_lc && (tlcm_valid_mask == {NUM_SERVERS{1'b0}});
    wire key_path_block = i_ip_full || tlcm_block;

    wire algo_key_valid = key_valid && init_done && !key_path_block;
    wire rr_key_valid   = algo_key_valid && sel_rr;
    wire hash_key_valid = algo_key_valid && sel_hash;
    wire lc_key_valid   = algo_key_valid && sel_lc;

    wire [DATA_WIDTH-1:0] rr_ip;
    wire [DATA_WIDTH-1:0] hash_ip;
    wire [DATA_WIDTH-1:0] lc_ip;
    wire rr_valid;
    wire hash_valid;
    wire lc_valid;
    wire [$clog2(NUM_SERVERS)-1:0] rr_id;
    wire [$clog2(NUM_SERVERS)-1:0] hash_id;
    wire [$clog2(NUM_SERVERS)-1:0] lc_id;
    wire [$clog2(NUM_SERVERS)-1:0] scn_idx_mux;
    reg [31:0] tlcm_cnt [0:NUM_SERVERS-1];
    integer t_i;

    generate
        genvar t_gi;
        for (t_gi = 0; t_gi < NUM_SERVERS; t_gi = t_gi + 1) begin : GEN_TLCM_CNT_OUT
            assign tlcm_pkt_count[t_gi*32 +: 32] = tlcm_cnt[t_gi];
        end
    endgenerate

    wire rr_scn_opcode;
    reg [NUM_SERVERS-1:0] rr_health_r;
    round_robin_algo #(
        .IP_WIDTH(IP_WIDTH), // note: use ipv4, v6 will be error
        .N_SERVERS(NUM_SERVERS)
    ) rr_inst (
        .clk        (clock),
        .rst_n      (rst_n),
        .key_valid  (rr_key_valid),
        .i_status(rr_health_r),
        .cfg_ip_list(server_ip_cache), // 512 bit kh?p v?i 128*4
        .rr_ip      (rr_ip),
        .rr_valid   (rr_valid),
        .rr_scn_idx    (rr_id),    // N?i t?n hi?u m?i
        .rr_scn_opcode (rr_scn_opcode)  // N?i t?n hi?u m?i
    );

    hash_algo #(
        .NUM_SERVERS(NUM_SERVERS)
    ) hash_inst (
        .clk          (clock),
        .rst_n        (rst_n),
        .src_ip       (key_src_ip),
        .dst_ip       (key_dst_ip),
        .src_port     (key_src_port),
        .dst_port     (key_dst_port),
        .protocol     (key_protocol),
        .key_valid    (hash_key_valid),
        .server_ips_in(server_ip_cache),
        .i_status     (health_bitmap),
        .out_server_ip(hash_ip),
        .server_id    (hash_id),
        .out_valid    (hash_valid)
    );
    
//    JUMP_HASH #(
//        .NUM_SERVERS(NUM_SERVERS)
//    ) hash_inst (
//        .clk          (clock),
//        .rst_n        (rst_n),
//        .src_ip       (key_src_ip),
//        .dst_ip       (key_dst_ip),
//        .src_port     (key_src_port),
//        .dst_port     (key_dst_port),
//        .protocol     (key_protocol),
//        .key_valid    (hash_key_valid),
//        .server_ips_in(server_ip_cache),
//        .i_status     (4'b1011),
//        .out_server_ip(hash_ip),
//        .server_id    (hash_id),
//        .out_valid    (hash_valid)
//    );

    assign scn_idx_mux = sel_rr ? rr_id :
                         sel_hash ? hash_id :
                         lc_id;

    tlcm_core #(
        .N     (NUM_SERVERS),
        .DATA_W(SCN_WIDTH)
    ) tlcm_inst (
        .clk           (clock),
        .rst_n         (rst_n),
        .data_valid    (lc_key_valid),
        .valid         (tlcm_valid_mask),
        .server_ip     (server_ip_cache),
        .scn_dec_en    (scn_dec_en),
        .scn_dec_index (scn_dec_idx),
        .scn_load_en   (cslb_rd_valid),
        .scn_load_data (cslb_rd_scn),
        .scn_inc_en    (wr_valid),
        .scn_inc_index (scn_idx_mux),
        .dst_valid     (lc_valid),
        .dst_ip        (lc_ip),
        .best_index_out(lc_id)
    );

    always @(posedge clock or negedge rst_n) begin
        if (!rst_n) begin
            for (t_i = 0; t_i < NUM_SERVERS; t_i = t_i + 1)
                tlcm_cnt[t_i] <= 32'd0;
        end else if (lc_valid) begin
            tlcm_cnt[lc_id] <= tlcm_cnt[lc_id] + 1'b1;
        end
    end

    assign wr_data = sel_rr   ? rr_ip :
                     sel_hash ? hash_ip :
                     sel_lc   ? lc_ip :
                     {DATA_WIDTH{1'b0}};

    assign wr_valid = sel_rr   ? rr_valid :
                      sel_hash ? hash_valid :
                      sel_lc   ? lc_valid :
                      1'b0;

    // Backpressure key FIFO when destination FIFO is full or TLCM has no healthy target.
    assign o_ip_full = key_path_block;

    always @(posedge clock or negedge rst_n) begin
        if (!rst_n) begin
            scn_inc_en     <= 1'b0;
            scn_server_idx <= {$clog2(NUM_SERVERS){1'b0}};
        end else begin
            scn_inc_en <= wr_valid;
            if (wr_valid)
                scn_server_idx <= scn_idx_mux;
        end
    end

    always @(posedge clock or negedge rst_n) begin
        if (!rst_n)
            rr_health_r <= {NUM_SERVERS{1'b0}};
        else
            rr_health_r <= health_bitmap;
    end

endmodule

module round_robin_algo #(
    parameter IP_WIDTH  = 32,
    parameter N_SERVERS = 4,
    parameter PTR_W     = (N_SERVERS <= 2)  ? 1 :
                          (N_SERVERS <= 4)  ? 2 :
                          (N_SERVERS <= 8)  ? 3 :
                          (N_SERVERS <= 16) ? 4 :
                          (N_SERVERS <= 32) ? 5 : 6
)(
    input  wire                             clk,
    input  wire                             rst_n,

    input  wire                             key_valid,
    input  wire [N_SERVERS-1:0]            i_status,
    input  wire [IP_WIDTH*N_SERVERS-1:0]  cfg_ip_list,

    output wire [IP_WIDTH-1:0]            rr_ip,
    output wire                            rr_valid,

    output wire [PTR_W-1:0]               rr_scn_idx,
    output wire                            rr_scn_opcode
);

    reg [PTR_W-1:0] ptr;

    // =========================================================
    // Stage-0 : combinational scan
    // =========================================================

    reg [PTR_W-1:0] next_ptr_c;
    reg             found_c;

    integer k;

    reg [PTR_W:0] sum;
    reg [PTR_W-1:0] idx;

    always @(*) begin
        found_c    = 1'b0;
        next_ptr_c = ptr;

        for (k = 0; k < N_SERVERS; k = k + 1) begin

            // ---------------------------------------------
            // ptr + k
            // use lightweight wrap
            // ---------------------------------------------

            sum = ptr + k;

            if (sum >= N_SERVERS)
                idx = sum - N_SERVERS;
            else
                idx = sum[PTR_W-1:0];

            // ---------------------------------------------
            // first alive server wins
            // ---------------------------------------------

            if (!found_c && i_status[idx]) begin
                found_c    = 1'b1;
                next_ptr_c = idx;
            end
        end
    end

    // =========================================================
    // Stage-1 pipeline registers
    // Break critical timing path:
    //
    // ptr/Q -> scan logic -> next_ptr_r
    //
    // instead of:
    //
    // ptr/Q -> scan logic -> ptr/D
    // =========================================================

    reg [PTR_W-1:0] next_ptr_r;
    reg             found_r;
    reg             key_valid_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_ptr_r <= 0;
            found_r    <= 0;
            key_valid_r<= 0;
        end
        else begin
            next_ptr_r <= next_ptr_c;
            found_r    <= found_c;
            key_valid_r<= key_valid;
        end
    end

    // =========================================================
    // Stage-2 output registers
    // =========================================================

    reg [IP_WIDTH-1:0] rr_ip_r;
    reg                rr_valid_r;
    reg [PTR_W-1:0]    rr_idx_r;
    reg                rr_opcode_r;

    assign rr_ip         = rr_ip_r;
    assign rr_valid      = rr_valid_r;
    assign rr_scn_idx    = rr_idx_r;
    assign rr_scn_opcode = rr_opcode_r;

    // =========================================================
    // Sequential output/update logic
    // =========================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            ptr <= 0;

            rr_ip_r      <= 0;
            rr_valid_r   <= 0;
            rr_idx_r     <= 0;
            rr_opcode_r  <= 0;

        end
        else begin

            rr_valid_r  <= key_valid_r & found_r;
            rr_opcode_r <= key_valid_r & found_r;

            if (key_valid_r && found_r) begin

                // -------------------------------------------------
                // registered output
                // -------------------------------------------------

                rr_idx_r <= next_ptr_r;

                rr_ip_r  <= cfg_ip_list[
                                next_ptr_r*IP_WIDTH +: IP_WIDTH
                            ];

                // -------------------------------------------------
                // pointer update
                // short timing path now
                // -------------------------------------------------

                if (next_ptr_r == (N_SERVERS-1))
                    ptr <= 0;
                else
                    ptr <= next_ptr_r + 1'b1;
            end
        end
    end

endmodule