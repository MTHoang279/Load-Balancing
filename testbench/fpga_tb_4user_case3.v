`timescale 1ns / 1ps

module tb_fpga_top;

    /* ---------------- PARAMETERS ---------------- */
    parameter BUS_WIDTH  = 512;
    parameter CLK_PERIOD = 8.0;
    parameter INPUTFILE  = "E:/10G_Ethernet/4_user.dat";
    parameter CLK_FREQ_HZ = 1000;
    parameter TICK_MS = 10;
    parameter NUM_SERVERS = 4;

    /* ---------------- SIGNALS ---------------- */
    reg clk_p;
    reg clk_n;
    reg rst_in;
    reg start;
    reg [1:0] algo_sel;
    reg [5:0] server_en;
    wire done;

    /* ---------------- DUT ---------------- */
    fpga_top #(
        .BUS_WIDTH (BUS_WIDTH),
        .INPUTFILE (INPUTFILE),
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .TICK_MS(TICK_MS),
        .NUM_SERVERS(NUM_SERVERS)
    ) dut (
        .clk_p    (clk_p),
        .clk_n    (clk_n),
        .rst_in   (rst_in),
        .start    (start),
        .algo_sel (algo_sel),
        .server_en(server_en),
        .done     (done)
    );

    /* ---------------- CLOCK ---------------- */
    initial begin
        clk_p = 0;
        clk_n = 1;
    end

    always #(CLK_PERIOD/2.0) begin
        clk_p = ~clk_p;
        clk_n = ~clk_n;
    end

    /* ---------------- COUNTERS ---------------- */
    integer in_pkt_cnt;
    integer out_pkt_cnt;
    integer pkt_hb;

    initial begin
        in_pkt_cnt  = 0;
        out_pkt_cnt = 0;
        pkt_hb      = 0;
    end

    /* ---------------- HB COUNT ---------------- */
    always @(posedge clk_p) begin
        if (!rst_in) begin
            if (dut.u_shm_top.u_heartbeat_generator.trigger) begin
                pkt_hb = pkt_hb + 1;
                $display("[%0t] HB_PKT %0d", $time, pkt_hb);
            end
        end
    end

    /* ---------------- INPUT PACKET COUNT ---------------- */
    always @(posedge clk_p) begin
        if (!rst_in) begin
            if (dut.u_packet_filter.m_tvalid && dut.u_packet_filter.m_tlast) begin
                in_pkt_cnt = in_pkt_cnt + 1;
            end
        end
    end

    /* ---------------- OUTPUT PACKET COUNT ---------------- */
    reg backend_last_d;

    always @(posedge clk_p) begin
        backend_last_d <= dut.u_server.tx_user_valid && dut.u_server.tx_user_last;

        if (!rst_in) begin
            if (backend_last_d && !(dut.u_server.tx_user_valid && dut.u_server.tx_user_last)) begin
                out_pkt_cnt = out_pkt_cnt + 1;
            end
        end
    end

    /* ---------------- FILE HANDLE ---------------- */
    integer fserver [0:NUM_SERVERS-1];
    integer dist_cnt [0:NUM_SERVERS-1];
    integer i;

    initial begin
        for (i = 0; i < NUM_SERVERS; i = i + 1) begin

            case (i)
                0: fserver[i] = $fopen("E:/10G_Ethernet/track_file/rr_server_0.txt","w");
                1: fserver[i] = $fopen("E:/10G_Ethernet/track_file/rr_server_1.txt","w");
                2: fserver[i] = $fopen("E:/10G_Ethernet/track_file/rr_server_2.txt","w");
                3: fserver[i] = $fopen("E:/10G_Ethernet/track_file/rr_server_3.txt","w");
            endcase

            if (fserver[i] == 0) begin
                $display("ERROR: Cannot open server_%0d.log", i);
                $finish;
            end

            dist_cnt[i] = 0;
        end
    end

    /* ---------------- LOG PER SERVER ---------------- */
    genvar si;
    generate
        for (si = 0; si < NUM_SERVERS; si = si + 1) begin : LOG_SERVER
    
            always @(posedge clk_p) begin
                if (!rst_in) begin
                    if (dut.u_server.s_valid[si] && dut.u_server.s_ready[si]) begin
    
                        // ? CH? GHI KHI END PACKET
                        if (dut.u_server.s_last[si]) begin
                            $fwrite(fserver[si], "%h\n",
                                dut.u_server.s_data[si]
                            );
    
                            dist_cnt[si] = dist_cnt[si] + 1;
                        end
                    end
                end
            end
    
        end
    endgenerate

    /* ---------------- DEBUG ---------------- */
    always @(posedge clk_p) begin
        if (!rst_in) begin
            if (dut.u_server.in_fifo_valid && dut.u_server.in_fifo_consume) begin
                $display("[%0t] SELECT SERVER = %0d | HB=%0d",
                    $time,
                    dut.u_server.pkt_target,
                    dut.u_server.pkt_is_hb
                );
            end
        end
    end

    /* ---------------- DONE CONTROL ---------------- */
    reg done_d;
    reg [3:0] done_cnt;
    reg finish_flag;

    initial begin
        done_d = 0;
        done_cnt = 0;
        finish_flag = 0;
    end

    always @(posedge clk_p) begin
        if (rst_in) begin
            done_d = 0;
            done_cnt = 0;
            finish_flag = 0;
        end else begin
            done_d <= done;

            if (!done_d && done) begin
                $display("[%0t] DONE detected", $time);
                done_cnt = 1;
            end
            else if (done_cnt != 0) begin
                done_cnt = done_cnt + 1;

                if (done_cnt == 10)
                    finish_flag = 1;
            end
        end
    end

    /* ---------------- FINISH ---------------- */
    always @(posedge clk_p) begin
        if (finish_flag) begin
            $display("\n===== FINAL RESULT =====");
            $display("Total IN  packets = %0d", in_pkt_cnt);
            $display("Total OUT packets = %0d", out_pkt_cnt);

            for (i = 0; i < NUM_SERVERS; i = i + 1) begin
                $display("Server %0d: %0d packets", i, dist_cnt[i]);
            end

            $display("========================\n");
            $finish;
        end
    end

    /* ---------------- STIMULUS ---------------- */
    initial begin
        rst_in   = 1'b1;
        start    = 1'b0;
        algo_sel = 2'b01;
        server_en = 6'b111111;

        #(CLK_PERIOD * 10);
        rst_in = 1'b0;

        #(CLK_PERIOD * 5);

        $display("=== START PCAP REPLAY ===");
        start = 1'b1;
        #(CLK_PERIOD);
        start = 1'b0;

        #(CLK_PERIOD*100000);
    end

endmodule