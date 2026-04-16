`timescale 1ns / 1ps

module tb_reset_ip_health_alg;

    localparam NUM_SERVERS     = 16;
    localparam SERVER_ID_WIDTH = 4;
    localparam SCN_WIDTH       = 12;

    reg clk;
    reg rst_n;

    reg  [31:0] i_src_ip;
    reg  [31:0] i_dst_ip;
    reg  [15:0] i_src_port;
    reg  [15:0] i_dst_port;
    reg  [7:0]  i_protocol;
    reg         i_key_valid;
    wire        key_fifo_full;

    reg  [511:0] s_axis_tdata;
    reg          s_axis_tvalid;
    reg  [63:0]  s_axis_tkeep;
    reg          s_axis_tlast;
    wire         s_axis_tready;

    wire [511:0] lb2shm_tdata;
    wire         lb2shm_tvalid;
    wire         lb2shm_tlast;
    wire [63:0]  lb2shm_tkeep;
    wire         lb2shm_tready;

    reg  [1:0] cfg_algo_sel;
    wire       scn_inc_en;
    wire [SERVER_ID_WIDTH-1:0] scn_server_idx;
    wire [NUM_SERVERS-1:0] health_bitmap;
    wire       scn_dec_en;
    wire [SERVER_ID_WIDTH-1:0] scn_dec_idx;

    wire       cslb_rd_en;
    wire [NUM_SERVERS*32-1:0] cslb_rd_ip;
    wire [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn;
    wire       cslb_rd_valid;

    wire [511:0] tx_backend_data;
    wire [63:0]  tx_backend_keep;
    wire         tx_backend_last;
    wire         tx_backend_valid;
    wire         tx_backend_ready;

    wire [511:0] rx_backend_data;
    wire [63:0]  rx_backend_keep;
    wire         rx_backend_last;
    wire         rx_backend_valid;
    wire         rx_backend_ready;

    reg  [NUM_SERVERS-1:0] server_en;

    wire [NUM_SERVERS*15-1:0] cnt_user_req_rx;
    wire [NUM_SERVERS*15-1:0] cnt_hb_req_rx;
    wire [NUM_SERVERS*15-1:0] cnt_user_reply_tx;
    wire [NUM_SERVERS*15-1:0] cnt_hb_reply_tx;

    wire [NUM_SERVERS*32-1:0] srv_ip_list;
    wire                      srv_ip_list_valid;

    integer user_tx_count;
    reg [31:0] last_user_dst_ip;
    integer snapshot_count;
    reg [NUM_SERVERS*SCN_WIDTH-1:0] last_scn_snapshot;
    reg [NUM_SERVERS*SCN_WIDTH-1:0] scn_before_stress;
    reg [NUM_SERVERS*SCN_WIDTH-1:0] scn_after_stress;
    reg [NUM_SERVERS*SCN_WIDTH-1:0] scn_after_hash;
    reg [NUM_SERVERS*SCN_WIDTH-1:0] scn_after_lc;
    reg [NUM_SERVERS*SCN_WIDTH-1:0] scn_after_health;
    time  boot_pulse_time;
    integer prev_tx_count;
    integer n;
    integer hc_wait;
    reg health_down_seen;
    reg cslb_rd_valid_d;

    function [31:0] expected_ip_for_server;
        input integer idx;
        begin
            expected_ip_for_server = 32'h0A000064 + idx;
        end
    endfunction

    // ------------------------------------------------------------
    // DUT chain: LB -> SHM -> master_server -> SHM
    // ------------------------------------------------------------
    load_balancer_top #(
        .NUM_SERVERS(NUM_SERVERS),
        .SCN_WIDTH(SCN_WIDTH)
    ) u_lb (
        .clk           (clk),
        .rst_n         (rst_n),
        .i_src_ip      (i_src_ip),
        .i_dst_ip      (i_dst_ip),
        .i_src_port    (i_src_port),
        .i_dst_port    (i_dst_port),
        .i_protocol    (i_protocol),
        .i_key_valid   (i_key_valid),
        .key_fifo_full (key_fifo_full),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tkeep  (s_axis_tkeep),
        .s_axis_tlast  (s_axis_tlast),
        .s_axis_tready (s_axis_tready),
        .m_axis_tdata  (lb2shm_tdata),
        .m_axis_tvalid (lb2shm_tvalid),
        .m_axis_tlast  (lb2shm_tlast),
        .m_axis_tkeep  (lb2shm_tkeep),
        .m_axis_tready (lb2shm_tready),
        .cfg_algo_sel  (cfg_algo_sel),
        .scn_inc_en    (scn_inc_en),
        .scn_server_idx(scn_server_idx),
        .health_bitmap (health_bitmap),
        .scn_dec_en    (scn_dec_en),
        .scn_dec_idx   (scn_dec_idx),
        .cslb_rd_en    (cslb_rd_en),
        .cslb_rd_ip    (cslb_rd_ip),
        .cslb_rd_scn   (cslb_rd_scn),
        .cslb_rd_valid (cslb_rd_valid)
    );

    shm_top #(
        .NUM_SERVERS(NUM_SERVERS),
        .SERVER_ID_WIDTH(SERVER_ID_WIDTH),
        .SCN_WIDTH(SCN_WIDTH),
        .CLK_FREQ_HZ(2000),
        .TICK_MS(1)
    ) u_shm (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .tx_cslb_data            (lb2shm_tdata),
        .tx_cslb_keep            (lb2shm_tkeep),
        .tx_cslb_last            (lb2shm_tlast),
        .tx_cslb_valid           (lb2shm_tvalid),
        .tx_cslb_ready           (lb2shm_tready),
        .tx_backend_data         (tx_backend_data),
        .tx_backend_keep         (tx_backend_keep),
        .tx_backend_last         (tx_backend_last),
        .tx_backend_valid        (tx_backend_valid),
        .tx_backend_ready        (tx_backend_ready),
        .rx_backend_data         (rx_backend_data),
        .rx_backend_keep         (rx_backend_keep),
        .rx_backend_last         (rx_backend_last),
        .rx_backend_valid        (rx_backend_valid),
        .rx_backend_ready        (rx_backend_ready),
        .rx_cslb_data            (),
        .rx_cslb_keep            (),
        .rx_cslb_last            (),
        .rx_cslb_valid           (),
        .rx_cslb_ready           (1'b1),
        .cslb_scn_inc_en         (scn_inc_en),
        .cslb_server_idx         (scn_server_idx),
        .cslb_rd_en              (cslb_rd_en),
        .cslb_rd_ip              (cslb_rd_ip),
        .cslb_rd_scn             (cslb_rd_scn),
        .cslb_rd_valid           (cslb_rd_valid),
        .server_ip_list             (srv_ip_list),
        .server_ip_list_valid       (srv_ip_list_valid),
        .cslb_health_bitmap      (health_bitmap),
        .cslb_health_update_valid(),
        .cslb_scn_dec_en         (scn_dec_en),
        .cslb_server_dec_idx     (scn_dec_idx)
    );

    master_server #(
        .NUM_SERVERS(NUM_SERVERS)
    ) u_servers (
        .clk               (clk),
        .rst_n             (rst_n),
        .server_en         (server_en),
        .rx_user_valid     (tx_backend_valid),
        .rx_user_last      (tx_backend_last),
        .rx_user_data      (tx_backend_data),
        .rx_user_keep      (tx_backend_keep),
        .rx_user_ready     (tx_backend_ready),
        .tx_user_valid     (rx_backend_valid),
        .tx_user_last      (rx_backend_last),
        .tx_user_data      (rx_backend_data),
        .tx_user_keep      (rx_backend_keep),
        .tx_user_ready     (rx_backend_ready),
        .server_ip_list    (srv_ip_list),
        .server_ip_list_valid(srv_ip_list_valid),
        .cnt_user_req_rx   (cnt_user_req_rx),
        .cnt_hb_req_rx     (cnt_hb_req_rx),
        .cnt_user_reply_tx (cnt_user_reply_tx),
        .cnt_hb_reply_tx   (cnt_hb_reply_tx)
    );

    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Monitor user packets (exclude heartbeat)
    // ------------------------------------------------------------
    always @(posedge clk) begin
        cslb_rd_valid_d <= cslb_rd_valid;

        // Count packets at LB output to avoid backend arbitration side effects.
        if (lb2shm_tvalid && lb2shm_tready) begin
            user_tx_count    <= user_tx_count + 1;
            last_user_dst_ip <= lb2shm_tdata[271:240];
        end

        if (srv_ip_list_valid) begin
            boot_pulse_time <= $time;
            $display("[TB][INFO] srv_ip_list_valid pulse at t=%0t", $time);
        end

        if (cslb_rd_valid_d) begin
            snapshot_count    <= snapshot_count + 1;
            last_scn_snapshot <= cslb_rd_scn;
            $display("[TB][INFO] snapshot#%0d ip=%h scn=%h health=%b t=%0t",
                     snapshot_count, cslb_rd_ip, cslb_rd_scn, health_bitmap, $time);
        end
    end

    function is_known_ip;
        input [31:0] ip;
        integer idx;
        begin
            is_known_ip = 1'b0;
            for (idx = 0; idx < NUM_SERVERS; idx = idx + 1) begin
                if (ip == expected_ip_for_server(idx))
                    is_known_ip = 1'b1;
            end
        end
    endfunction

    function has_nonzero_scn;
        input [NUM_SERVERS*SCN_WIDTH-1:0] scn_vec;
        integer m;
        begin
            has_nonzero_scn = 1'b0;
            for (m = 0; m < NUM_SERVERS; m = m + 1) begin
                if (scn_vec[m*SCN_WIDTH +: SCN_WIDTH] != {SCN_WIDTH{1'b0}})
                    has_nonzero_scn = 1'b1;
            end
        end
    endfunction

    task wait_boot_pulse;
        input integer max_cycles;
        integer k;
        begin
            for (k = 0; k < max_cycles; k = k + 1) begin
                @(posedge clk);
                if (srv_ip_list_valid)
                    disable wait_boot_pulse;
            end
            $display("[TB][FAIL] Timeout waiting srv_ip_list_valid pulse at t=%0t", $time);
            $fatal;
        end
    endtask

    task wait_cslb_snapshot;
        input integer max_cycles;
        integer k;
        begin
            for (k = 0; k < max_cycles; k = k + 1) begin
                @(posedge clk);
                if (cslb_rd_valid) begin
                    // cslb_rd_ip is updated with NBA in RTL at the same edge
                    // where cslb_rd_valid is asserted, so sample next cycle.
                    @(posedge clk);
                    disable wait_cslb_snapshot;
                end
            end
            $display("[TB][FAIL] Timeout waiting cslb_rd_valid at t=%0t", $time);
            $fatal;
        end
    endtask

    task wait_user_packet;
        input integer prev_count;
        input integer max_cycles;
        integer k;
        begin
            for (k = 0; k < max_cycles; k = k + 1) begin
                @(posedge clk);
                if (user_tx_count > prev_count)
                    disable wait_user_packet;
            end
            $display("[TB][FAIL] Timeout waiting user packet at t=%0t", $time);
            $fatal;
        end
    endtask

    task send_packet_once;
        input [31:0] src_ip_in;
        input [31:0] dst_ip_in;
        input [15:0] src_port_in;
        input [15:0] dst_port_in;
        input [7:0]  proto_in;
        reg [511:0] msg;
        begin
            // Push one key to key_fifo (posedge-domain stimulus)
            @(posedge clk);
            i_src_ip    <= src_ip_in;
            i_dst_ip    <= dst_ip_in;
            i_src_port  <= src_port_in;
            i_dst_port  <= dst_port_in;
            i_protocol  <= proto_in;
            i_key_valid <= 1'b1;

            @(posedge clk);
            i_key_valid <= 1'b0;

            // Push one 1-beat message to msg_fifo
            msg = 512'd0;
            msg[303:272] = src_ip_in;
            msg[271:240] = dst_ip_in;
            msg[239:224] = src_port_in;
            msg[223:208] = dst_port_in;

            s_axis_tdata  <= msg;
            s_axis_tkeep  <= 64'hFFFF_FFFF_FFFF_FFFF;
            s_axis_tlast  <= 1'b1;
            s_axis_tvalid <= 1'b1;

            // Hold valid until handshake at posedge.
            while (!(s_axis_tvalid && s_axis_tready))
                @(posedge clk);

            @(posedge clk);
            s_axis_tvalid <= 1'b0;
            s_axis_tlast  <= 1'b0;
            s_axis_tdata  <= 512'd0;
            s_axis_tkeep  <= 64'd0;
        end
    endtask

    initial begin
        // Init
        rst_n        = 1'b0;
        cfg_algo_sel = 2'b01;
        server_en    = {NUM_SERVERS{1'b1}};

        i_src_ip     = 32'd0;
        i_dst_ip     = 32'd0;
        i_src_port   = 16'd0;
        i_dst_port   = 16'd0;
        i_protocol   = 8'd0;
        i_key_valid  = 1'b0;

        s_axis_tdata  = 512'd0;
        s_axis_tvalid = 1'b0;
        s_axis_tkeep  = 64'd0;
        s_axis_tlast  = 1'b0;

        user_tx_count    = 0;
        last_user_dst_ip = 32'd0;
        snapshot_count   = 0;
        last_scn_snapshot = {NUM_SERVERS*SCN_WIDTH{1'b0}};
        scn_before_stress = {NUM_SERVERS*SCN_WIDTH{1'b0}};
        scn_after_stress  = {NUM_SERVERS*SCN_WIDTH{1'b0}};
        scn_after_hash    = {NUM_SERVERS*SCN_WIDTH{1'b0}};
        scn_after_lc      = {NUM_SERVERS*SCN_WIDTH{1'b0}};
        scn_after_health  = {NUM_SERVERS*SCN_WIDTH{1'b0}};
        boot_pulse_time   = 0;
        cslb_rd_valid_d   = 1'b0;

        // Reset
        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        // 1) Verify boot pulse and IP snapshot after reset
        wait_boot_pulse(100);

        // Request a fresh snapshot after boot pulse to avoid stale pre-boot sample.
        cfg_algo_sel = 2'b10;
        wait_cslb_snapshot(300);
        cfg_algo_sel = 2'b01;
        wait_cslb_snapshot(300);

        for (n = 0; n < NUM_SERVERS; n = n + 1) begin
            if (cslb_rd_ip[n*32 +: 32] !== expected_ip_for_server(n)) begin
                $display("[TB][FAIL] IP snapshot mismatch after reset at idx %0d: got=%h exp=%h",
                         n, cslb_rd_ip[n*32 +: 32], expected_ip_for_server(n));
                $fatal;
            end
        end
        $display("[TB][PASS] Boot pulse + IP snapshot observed (boot pulse t=%0t)", boot_pulse_time);

        // 2) Round-robin checks (longer observation)
        cfg_algo_sel = 2'b01;

        prev_tx_count = user_tx_count;
        send_packet_once(32'hC0A80101, 32'hDEADBEEF, 16'd1234, 16'd4321, 8'h11);
        wait_user_packet(prev_tx_count, 400);
        if (last_user_dst_ip !== expected_ip_for_server(0)) begin
            $display("[TB][FAIL] RR pkt1 expected %h got %h", expected_ip_for_server(0), last_user_dst_ip);
            $fatal;
        end

        prev_tx_count = user_tx_count;
        send_packet_once(32'hC0A80102, 32'hDEADBEEF, 16'd1235, 16'd4321, 8'h11);
        wait_user_packet(prev_tx_count, 400);
        if (last_user_dst_ip !== expected_ip_for_server(1)) begin
            $display("[TB][FAIL] RR pkt2 expected %h got %h", expected_ip_for_server(1), last_user_dst_ip);
            $fatal;
        end

        // Send extra RR traffic for easier waveform observation
        for (n = 0; n < 6; n = n + 1) begin
            prev_tx_count = user_tx_count;
            send_packet_once(32'hC0A80110 + n, 32'hDEAD0000 + n, 16'd2000 + n, 16'd4000, 8'h11);
            wait_user_packet(prev_tx_count, 400);
        end
        $display("[TB][PASS] RR algorithm routes correctly");

        // 3) SCN stress check: disable responses so SCN can accumulate
        server_en = {NUM_SERVERS{1'b0}};
        for (n = 0; n < 10; n = n + 1) begin
            prev_tx_count = user_tx_count;
            send_packet_once(32'hAC120000 + n, 32'h11110000 + n, 16'd3000 + n, 16'd4100, 8'h11);
            wait_user_packet(prev_tx_count, 400);
        end

        // Force fresh snapshot by mode switch
        cfg_algo_sel = 2'b10;
        wait_cslb_snapshot(300);
        scn_before_stress = cslb_rd_scn;
        cfg_algo_sel = 2'b01;
        wait_cslb_snapshot(300);
        scn_after_stress = cslb_rd_scn;

        if (!has_nonzero_scn(scn_after_stress)) begin
            $display("[TB][FAIL] SCN did not increase under no-reply stress. scn=%h", scn_after_stress);
            $fatal;
        end
        $display("[TB][PASS] SCN update observed. before=%h after=%h", scn_before_stress, scn_after_stress);

        // Re-enable servers for hash/lc checks
        server_en = {NUM_SERVERS{1'b1}};

        // 4) Hash check (at least produces valid server IP)
        cfg_algo_sel = 2'b10;
        wait_cslb_snapshot(200);

        for (n = 0; n < 6; n = n + 1) begin
            prev_tx_count = user_tx_count;
            send_packet_once(32'hAC100001 + n, 32'h08080808, 16'd5555 + n, 16'd8080, 8'h11);
            wait_user_packet(prev_tx_count, 400);
            if (!is_known_ip(last_user_dst_ip)) begin
                $display("[TB][FAIL] HASH selected invalid IP %h", last_user_dst_ip);
                $fatal;
            end
        end

        // Capture SCN after HASH traffic by switching once to LC (fresh snapshot).
        cfg_algo_sel = 2'b11;
        wait_cslb_snapshot(200);
        scn_after_hash = cslb_rd_scn;
        $display("[TB][PASS] HASH algorithm active");

        // 5) LC check before health change
        if (cfg_algo_sel !== 2'b11) begin
            $display("[TB][FAIL] TB did not enter LC mode, cfg=%b", cfg_algo_sel);
            $fatal;
        end
        $display("[TB][INFO] Enter LC mode, cfg=%b at t=%0t", cfg_algo_sel, $time);

        for (n = 0; n < 6; n = n + 1) begin
            prev_tx_count = user_tx_count;
            send_packet_once(32'hAC100020 + n, 32'h01020304, 16'd6000 + n, 16'd8081, 8'h11);
            wait_user_packet(prev_tx_count, 400);
            if (!is_known_ip(last_user_dst_ip)) begin
                $display("[TB][FAIL] LC selected invalid IP %h", last_user_dst_ip);
                $fatal;
            end
        end

        // Capture SCN after LC traffic.
        cfg_algo_sel = 2'b10;
        wait_cslb_snapshot(200);
        scn_after_lc = cslb_rd_scn;
        cfg_algo_sel = 2'b11;
        wait_cslb_snapshot(200);
        $display("[TB][PASS] LC algorithm active");

        // 6) Health check: disable server #2, wait checker window, verify bitmap
        server_en[2] = 1'b0;

        // Wait multiple checker windows for stable down status.
        health_down_seen = 1'b0;
        begin : health_wait_loop
            for (hc_wait = 0; hc_wait < 250000; hc_wait = hc_wait + 1) begin
                @(posedge clk);
                if (health_bitmap[2] == 1'b0) begin
                    health_down_seen = 1'b1;
                    disable health_wait_loop;
                end
            end
        end

        if (!health_down_seen) begin
            $display("[TB][FAIL] server #2 did not become DOWN stably, bitmap=%b", health_bitmap);
            $fatal;
        end
        $display("[TB][PASS] Health monitor marks server #2 down");

        // 7) LC should avoid down server
        // Force a fresh snapshot because current mode may already be 2'b11.
        cfg_algo_sel = 2'b10;
        wait_cslb_snapshot(200);
        scn_after_health = cslb_rd_scn;
        if (scn_after_health[2*SCN_WIDTH +: SCN_WIDTH] !== {SCN_WIDTH{1'b0}}) begin
            $display("[TB][FAIL] DOWN server SCN not reset. scn=%h", scn_after_health);
            $fatal;
        end
        cfg_algo_sel = 2'b11;
        wait_cslb_snapshot(200);

        for (n = 0; n < 6; n = n + 1) begin
            prev_tx_count = user_tx_count;
            send_packet_once(32'hAC100100 + n, 32'h05060708, 16'd6001 + n, 16'd8082, 8'h11);
            wait_user_packet(prev_tx_count, 400);
            if (last_user_dst_ip === expected_ip_for_server(2)) begin
                $display("[TB][FAIL] LC selected down server IP %h", last_user_dst_ip);
                $fatal;
            end
        end
        $display("[TB][PASS] LC avoids down server after health update");

        $display("[TB][PASS] All checks completed successfully");
        #100;
        $finish;
    end

endmodule
