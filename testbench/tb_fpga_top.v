`timescale 1ns / 1ps

module tb_fpga_top;

    /* --------------------------------------------------
     * PARAMETERS
     * -------------------------------------------------- */
    localparam BUS_WIDTH  = 512;
    localparam CLK_PERIOD = 3.105;   // 125 MHz (IBUFDS output)
    localparam CLK_FREQ_HZ= 1000;
    localparam TICK_MS = 10;
    localparam NUM_SERVERS = 16;

    /* --------------------------------------------------
     * SIGNALS
     * -------------------------------------------------- */
    reg clk_p;
    reg clk_n;

    reg rst_in;        // active high
    reg start;         // async button
    reg [1:0] algo_sel;
    reg [5:0] server_en;

    /* --------------------------------------------------
     * DUT
     * -------------------------------------------------- */
    fpga_top #(
        .NUM_SERVERS(NUM_SERVERS),
        .BUS_WIDTH(BUS_WIDTH),
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .TICK_MS(TICK_MS)
    ) dut (
        .clk_p          (clk_p),
        .clk_n          (clk_n),
        .rst_in         (rst_in),
        .start          (start),
        .algo_sel       (algo_sel),
        .server_en      (server_en)
    );

    /* --------------------------------------------------
     * DIFFERENTIAL CLOCK (board-like)
     * -------------------------------------------------- */
    always #(CLK_PERIOD/2) begin
        clk_p <= ~clk_p;
        clk_n <= ~clk_n;
    end

    /* --------------------------------------------------
     * MONITOR PACKET COUNTERS
     * -------------------------------------------------- */
    integer beat_cnt = 0;
    integer gen_pkt_cnt  = 0;

    wire clk_core = dut.clk_core;

    // Monitor input packets from generator
    always @(posedge clk_core) begin
        if (dut.gen_tvalid && dut.gen_tready) begin
            beat_cnt <= beat_cnt + 1;

            if (dut.gen_tlast) begin
                gen_pkt_cnt  <= gen_pkt_cnt + 1;

                $display("[%0t] GENERATED PACKET %0d DONE",
                         $time, gen_pkt_cnt + 1);
            end
        end
    end

    // Monitor filtered packets
    integer filtered_pkt_cnt = 0;
    always @(posedge clk_core) begin
        if (dut.filt_tvalid && dut.filt_tready && dut.filt_tlast) begin
            filtered_pkt_cnt <= filtered_pkt_cnt + 1;
            $display("[%0t] FILTERED PACKET %0d",
                     $time, filtered_pkt_cnt + 1);
        end
    end
    
        // Monitor HB packets
    integer hb_pkt_cnt = 0;
    always @(posedge clk_core) begin
        if (dut.u_shm_top.u_heartbeat_generator.trigger) begin
            hb_pkt_cnt <= hb_pkt_cnt + 1;
            $display("[%0t] HEARTBEAT PACKET %0d",
                     $time, hb_pkt_cnt + 1);
        end
    end

    // Monitor load-balanced packets
    integer lb_pkt_cnt = 0;
    always @(posedge clk_core) begin
        if (dut.u_shm_top.tx_backend_valid && dut.u_shm_top.tx_backend_last) begin
            lb_pkt_cnt <= lb_pkt_cnt + 1;
            $display("[%0t] LOAD-BALANCED PACKET %0d",
                     $time, lb_pkt_cnt + 1);
        end
    end

    /* --------------------------------------------------
     * STIMULUS
     * -------------------------------------------------- */
    initial begin
        /* init */
        clk_p = 0;
        clk_n = 1;
        rst_in = 1'b1;
        start  = 1'b0;
        algo_sel = 2'b11;
        server_en = 6'b111111; // Enable maximum servers

        /* hold reset (like power-on) */
        #100;
        rst_in = 0;   // release reset

        #100;

        /* --------------------------------------------
         * Single-shot packet generation
         * -------------------------------------------- */
        $display("=== SINGLE SHOT PACKET (100 users x 100 msgs) ===");

        // simulate button press
        @(posedge clk_p);
        start = 1;
        @(posedge clk_p);
        start = 0;

        // Wait enough time to finish 10000 packets
        wait(gen_pkt_cnt == 1000);
        #1000;

        /* Print final statistics */
        $display("=== PACKET STATISTICS ===");
        $display("Generated packets:     %0d", gen_pkt_cnt);
        $display("Filtered packets:      %0d", filtered_pkt_cnt);
        $display("Load-balanced packets: %0d", lb_pkt_cnt);
        
        $display("=== SIMULATION DONE ===");

        print_server_distribution();
        $finish;
    end
    // USER REQ RX
    wire [14:0] cnt_user_req_rx   [0:NUM_SERVERS-1];
    // HB REQ RX
    wire [14:0] cnt_hb_req_rx     [0:NUM_SERVERS-1];
    // USER REPLY TX
    wire [14:0] cnt_user_reply_tx [0:NUM_SERVERS-1];
    // HB REPLY TX
    wire [14:0] cnt_hb_reply_tx   [0:NUM_SERVERS-1];
    
    genvar i;
    generate
        for(i = 0; i < NUM_SERVERS; i = i + 1) begin : SERVER_COUNTER_MAP
    
            assign cnt_user_req_rx[i] =
                dut.u_server.cnt_user_req_rx[i*15 +: 15];
    
            assign cnt_hb_req_rx[i] =
                dut.u_server.cnt_hb_req_rx[i*15 +: 15];
    
            assign cnt_user_reply_tx[i] =
                dut.u_server.cnt_user_reply_tx[i*15 +: 15];
    
            assign cnt_hb_reply_tx[i] =
                dut.u_server.cnt_hb_reply_tx[i*15 +: 15];
    
        end
    endgenerate
    
    /* --------------------------------------------------
     * SERVER DISTRIBUTION ANALYSIS
     * -------------------------------------------------- */
    task print_server_distribution;
        integer i;
        integer total;
        integer min_val;
        integer max_val;
        real avg;
        real variance;
        real std_dev;
        real cv;
        real sum_sq_diff;
        real jain_index;
    
        integer val;
    
    begin
        $display("");
        $display("==============================================");
        $display("      SERVER LOAD DISTRIBUTION ANALYSIS       ");
        $display("==============================================");
    
        total   = 0;
        min_val = 32'h7FFFFFFF;
        max_val = 0;
    
        // --------------------------------------------------
        // Pass 1: total / min / max
        // --------------------------------------------------
        for (i = 0; i < NUM_SERVERS; i = i + 1) begin
            val = cnt_user_req_rx[i];
    
            total = total + val;
    
            if (val < min_val) min_val = val;
            if (val > max_val) max_val = val;
        end
    
        avg = total * 1.0 / NUM_SERVERS;
    
        // --------------------------------------------------
        // Pass 2: variance
        // --------------------------------------------------
        sum_sq_diff = 0.0;
        for (i = 0; i < NUM_SERVERS; i = i + 1) begin
            val = cnt_user_req_rx[i];
            sum_sq_diff = sum_sq_diff + ((val - avg) * (val - avg));
        end
    
        variance = sum_sq_diff / NUM_SERVERS;
        std_dev  = $sqrt(variance);
        cv = (std_dev / avg) * 100.0;
        jain_index = (1/(1+ ((std_dev / avg) * (std_dev / avg))));

        // --------------------------------------------------
        // Print per-server
        // --------------------------------------------------
        $display("\n--- Per-server packet count (USER REQ RX) ---");
        for (i = 0; i < NUM_SERVERS; i = i + 1) begin
            val = cnt_user_req_rx[i];
    
            $display("Server[%0d] = %0d (diff from avg = %0.2f)",
                     i, val, val - avg);
        end
    
        // --------------------------------------------------
        // Summary
        // --------------------------------------------------
        $display("\n--- Summary ---");
        $display("Total packets : %0d", total);
        $display("Average       : %0.2f", avg);
        $display("Min           : %0d", min_val);
        $display("Max           : %0d", max_val);
        $display("Max-Min diff  : %0d", max_val - min_val);
        $display("Coeff. Variation : %0.3f %%", cv);
        $display("Jain Fairness : %0.6f", jain_index);
    
        // imbalance metric (%)
        if (avg != 0)
            $display("Imbalance (max/avg) : %0.2f %%", (max_val * 100 / avg) - 100);
        
        $display("==============================================\n");
    end
    endtask

endmodule