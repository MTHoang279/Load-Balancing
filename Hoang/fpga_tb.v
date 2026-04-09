
`timescale 1ns / 1ps

module tb_fpga_top;
    /* ---------------- PARAMETERS ---------------- */
    localparam BUS_WIDTH  = 512;
    localparam CLK_PERIOD = 8.0; // 125 MHz
    localparam INPUTFILE  = "E:/10G_Ethernet/UDP_sample_10K.mem";
    localparam CLK_FREQ_HZ = 1000;
    localparam TICK_MS = 10;

    localparam DONE_GRACE_CYCLES = 5000;
    localparam MAX_RUN_CYCLES    = 8_000_000;
    localparam NO_PROGRESS_LIMIT = 200_000;
    localparam EXPECTED_IN_PKTS  = 10000;

    /* ---------------- SIGNALS ---------------- */
//    reg clk_p;
//    reg clk_n;
    reg clk;
    reg rst_in;
    reg start;
    reg [2:0] algo_sel;

    wire [511:0] rx_backend_data;
    wire [63:0]  rx_backend_keep;
    wire         rx_backend_last;
    wire         rx_backend_valid;

    wire         tx_backend_ready;
    wire [511:0] tx_backend_data;
    wire [63:0]  tx_backend_keep;
    wire         tx_backend_valid;
    wire         tx_backend_last;
    wire         done;

    wire [31:0] m_tx_total;
    wire [31:0] m_tx_user;
    wire [31:0] m_tx_hb;
    wire [31:0] m_rx_total;
    wire [31:0] m_drop;

    /* ---------------- DUT ---------------- */
    fpga_top #(
        .BUS_WIDTH (BUS_WIDTH),
        .INPUTFILE (INPUTFILE),
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .TICK_MS (TICK_MS)
    ) dut (
//        .clk_p    (clk_p),
//        .clk_n    (clk_n),
        .clk      (clk),
        .rst_in   (rst_in),
        .start    (start),
        .algo_sel (algo_sel),
        .done     (done),

        .tx_backend_ready (tx_backend_ready),
        .tx_backend_data  (tx_backend_data),
        .tx_backend_keep  (tx_backend_keep),
        .tx_backend_valid (tx_backend_valid),
        .tx_backend_last  (tx_backend_last),

        .rx_backend_data  (rx_backend_data),
        .rx_backend_keep  (rx_backend_keep),
        .rx_backend_valid (rx_backend_valid),
        .rx_backend_last  (rx_backend_last)
    );

    // Simulation-only depth override for MEM replay.
    defparam dut.u_packet_gen.ROM_DEPTH = 1097;

    /* ---------------- DIFFERENTIAL CLOCK ---------------- */
    initial begin
//        clk_p = 1'b0;
//        clk_n = 1'b1;
          clk = 1'b0;
    end

    always #(CLK_PERIOD/2.0) begin
//        clk_p = ~clk_p;
//        clk_n = ~clk_n;
        clk = ~clk;
    end

    server_backend_model #(
        .RESP_LATENCY(20),
        .Q_DEPTH(4096)
    ) u_backend (
//        .clk        (clk_p),
        .clk        (clk),
        .rst_n      (!rst_in),
        .tx_data    (tx_backend_data),
        .tx_keep    (tx_backend_keep),
        .tx_last    (tx_backend_last),
        .tx_valid   (tx_backend_valid),
        .tx_ready   (tx_backend_ready),
        .rx_data    (rx_backend_data),
        .rx_keep    (rx_backend_keep),
        .rx_last    (rx_backend_last),
        .rx_valid   (rx_backend_valid),
        .rx_ready   (1'b1),
        .stat_tx_total(m_tx_total),
        .stat_tx_user (m_tx_user),
        .stat_tx_hb   (m_tx_hb),
        .stat_tx_s0   (),
        .stat_tx_s1   (),
        .stat_tx_s2   (),
        .stat_tx_s3   (),
        .stat_rx_total(m_rx_total),
        .stat_drop    (m_drop)
    );

    integer in_pkt_cnt;
    integer out_pkt_cnt;
    integer pkt_hb;

    integer run_cycles;
    integer last_in_pkt;
    integer no_progress_cycles;
    integer done_seen;
    integer stop_run;

    /* Count packet-generator packets at TLAST handshake */
//    always @(posedge clk_p) begin
    always @(posedge clk) begin
        if (rst_in)
            in_pkt_cnt <= 0;
        else if (dut.u_packet_gen.M_AXIS_TVALID && dut.u_packet_gen.M_AXIS_TREADY && dut.u_packet_gen.M_AXIS_TLAST)
            in_pkt_cnt <= in_pkt_cnt + 1;
    end

    /* Count packets leaving SHM backend interface */
//    always @(posedge clk_p) begin
    always @(posedge clk) begin
        if (rst_in)
            out_pkt_cnt <= 0;
        else if (tx_backend_valid && tx_backend_ready && tx_backend_last)
            out_pkt_cnt <= out_pkt_cnt + 1;
    end

    /* Optional heartbeat trigger monitor */
//    always @(posedge clk_p) begin
    always @(posedge clk) begin
        if (rst_in)
            pkt_hb <= 0;
        else if (dut.u_shm_top.u_heartbeat_generator.trigger)
            pkt_hb <= pkt_hb + 1;
    end
    
    always @(posedge clk) begin
        if (dut.u_packet_gen.M_AXIS_TVALID && !dut.u_packet_gen.M_AXIS_TREADY) begin
            $display("STALL at cycle %0t", $time);
        end
    end

    /* ---------------- STIMULUS ---------------- */
    initial begin
        rst_in          = 1'b1;   // Active High
        start           = 1'b0;
        algo_sel        = 3'b100; // Consistent Hash

        in_pkt_cnt      = 0;
        out_pkt_cnt     = 0;
        pkt_hb          = 0;

        run_cycles        = 0;
        last_in_pkt       = 0;
        no_progress_cycles= 0;
        done_seen         = 0;
        stop_run          = 0;

        // Hold reset
        #(CLK_PERIOD * 10);
        rst_in = 1'b0;

        #(CLK_PERIOD * 5);

        // Start MEM replay
        $display("=== START MEM REPLAY ===");
        start = 1'b1;
        #(CLK_PERIOD);
        start = 1'b0;

        while ((run_cycles < MAX_RUN_CYCLES) && (stop_run == 0)) begin
//            @(posedge clk_p);
            @(posedge clk);
            run_cycles = run_cycles + 1;

            if (done)
                done_seen = 1;

            if (in_pkt_cnt != last_in_pkt) begin
                last_in_pkt = in_pkt_cnt;
                no_progress_cycles = 0;
            end else begin
                no_progress_cycles = no_progress_cycles + 1;
            end

            if ((run_cycles % 200000) == 0) begin
                $display("[INFO] cycles=%0d in_pkt=%0d out_pkt=%0d tx_user=%0d tx_hb=%0d rx_total=%0d done=%0d no_prog=%0d",
                         run_cycles, in_pkt_cnt, out_pkt_cnt, m_tx_user, m_tx_hb, m_rx_total,
                         done, no_progress_cycles);
            end

            // Stop only after generator is done and traffic has been stable long enough.
            if (done_seen && (no_progress_cycles >= NO_PROGRESS_LIMIT))
                stop_run = 1;
        end


        if (!done_seen) begin
            $display("[FAIL] Generator DONE not seen. in_pkt=%0d no_prog=%0d", in_pkt_cnt, no_progress_cycles);
        end else if (in_pkt_cnt < EXPECTED_IN_PKTS) begin
            $display("[FAIL] Stopped before %0d packets. in_pkt=%0d no_prog=%0d",
                     EXPECTED_IN_PKTS, in_pkt_cnt, no_progress_cycles);
        end else begin
            $display("[PASS] Reached expected input packets: %0d", EXPECTED_IN_PKTS);
        end

//        repeat (DONE_GRACE_CYCLES) @(posedge clk_p);
        repeat (DONE_GRACE_CYCLES) @(posedge clk);

        $display("[%0t] === FINISH ===", $time);
        $display("Total IN packets  (gen TLAST) = %0d", in_pkt_cnt);
        $display("Total OUT packets (backend)   = %0d", out_pkt_cnt);
        $display("Heartbeat ticks               = %0d", pkt_hb);
        $display("Generator packet_sent_count   = %0d", dut.u_packet_gen.packet_sent_count);
        $display("Backend TX total              = %0d", m_tx_total);
        $display("Backend TX user / hb          = %0d / %0d", m_tx_user, m_tx_hb);
        $display("Backend RX total / drops      = %0d / %0d", m_rx_total, m_drop);
//        $display("Packet filter valid_pkt_count = %0d", dut.valid_pkt_count);
//        $display("FIFO overflow key/msg/dst     = %0d / %0d / %0d",
//                 dut.key_fifo_overflow_count,
//                 dut.msg_fifo_overflow_count,
//                 dut.dst_fifo_overflow_count);
//        $display("FILTER: in=%0d drop=%0d pass=%0d",
//            dut.u_packet_filter.in_pkt_count,
//            dut.u_packet_filter.drop_pkt_count,
//            dut.u_packet_filter.in_pkt_count - dut.u_packet_filter.drop_pkt_count
//        );
        $display("=== END SIMULATION ===");

        $finish;
    end

    /* ---------------- SAFETY TIMEOUT ---------------- */
    initial begin
        #(CLK_PERIOD * 4_000_000);
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule

