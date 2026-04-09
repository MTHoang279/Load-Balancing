`timescale 1ns / 1ps

module tb_fpga_top;
    /* ---------------- PARAMETERS ---------------- */
    localparam BUS_WIDTH  = 512;
    localparam CLK_PERIOD = 8.0; // 125 MHz
    localparam INPUTFILE  = "E:/10G_Ethernet/UDP_sample_10K.mem";
    localparam CLK_FREQ_HZ = 1000;
    localparam TICK_MS = 10;
    localparam NUM_SERVERS = 16;

    /* ---------------- SIGNALS ---------------- */
    reg clk_p;
    reg clk_n;
    reg rst_in;
    reg start;
    reg [1:0] algo_sel;
    wire    done;

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
        .done     (done)
    );

    /* ---------------- DIFFERENTIAL CLOCK ---------------- */
    initial begin
        clk_p = 0;
        clk_n = 1;
    end

    always #(CLK_PERIOD/2.0) begin
        clk_p = ~clk_p;
        clk_n = ~clk_n;
    end

    integer in_pkt_cnt = 0;
    integer out_pkt_cnt = 0;
    integer pkt_hb = 0;

    always @(posedge clk_p) begin
        if (!rst_in) begin
            if(dut.u_shm_top.u_heartbeat_generator.trigger) begin
                pkt_hb <= pkt_hb +1;
                $display("[%0t] HB_PKT %0d", $time, pkt_hb);
            end
        end
    end
    
    reg m_tlast_d;
    always @(posedge clk_p) begin
        m_tlast_d <= dut.u_packet_filter.m_tlast;
        if (!rst_in) begin
            // detect falling edge: 1 -> 0
//            if (m_tlast_d && !dut.u_packet_filter.m_tlast && dut.u_packet_filter.m_tvalid) begin
            if (dut.u_packet_filter.m_tlast && dut.u_packet_filter.m_tvalid) begin
                in_pkt_cnt <= in_pkt_cnt + 1;
                $display("[%0t] IN_PKT %0d", $time, in_pkt_cnt);
            end
        end
    end
    
    reg backend_tlast_d;
    always @(posedge clk_p) begin
        backend_tlast_d <= (dut.u_server.tx_user_last && dut.u_server.tx_user_valid);
        if (!rst_in) begin
            // detect falling edge: 1 -> 0
            if (backend_tlast_d && !(dut.u_server.tx_user_last && dut.u_server.tx_user_valid)) begin
                out_pkt_cnt <= out_pkt_cnt + 1;
                $display("[%0t] IN_PKT %0d", $time, out_pkt_cnt);
            end
        end
    end
    
    /* ---------------- DONE CONTROL ---------------- */
    reg done_d;
    reg [3:0] done_cnt;
    reg finish_flag;

    always @(posedge clk_p) begin
        if (rst_in) begin
            done_d      <= 0;
            done_cnt    <= 0;
            finish_flag <= 0;
        end else begin
            done_d <= done;

            // detect rising edge
            if (!done_d && done) begin
                $display("[%0t] DONE detected", $time);
                done_cnt <= 1;
            end
            else if (done_cnt != 0) begin
                done_cnt <= done_cnt + 1;

                if (done_cnt == 10)
                    finish_flag <= 1;
            end
        end
    end

    always @(posedge clk_p) begin
        if (finish_flag) begin
            $display("[%0t] === FINISH AFTER 10 CLK ===", $time);
            $display("Total IN  packets = %0d", in_pkt_cnt);
            $display("Total OUT packets = %0d", out_pkt_cnt);
            $finish;
        end
    end
    /* ---------------- STIMULUS ---------------- */
    initial begin
        rst_in   = 1'b1;   // Active High
        start   = 1'b0;
        algo_sel = 2'b10;   // Consistent Hash
//        tx_backend_ready = 1'b1;
//        rx_backend_valid = 1'b0;
//        rx_backend_last  = 1'b0;


        // Hold reset
        #(CLK_PERIOD * 10);
        rst_in = 1'b0;

        #(CLK_PERIOD * 5);

        // Start packet generator
        $display("=== START PCAP REPLAY ===");
        start = 1'b1;
        #(CLK_PERIOD);
        start = 1'b0;
        
        #(CLK_PERIOD*200);        

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
//    integer fin;
//    initial begin
//        fin = $fopen("E:/10G_Ethernet/in_packets1.txt","w");
//    end
    
//    always @(posedge clk_p) begin
//        if(dut.u_packet_filter.m_tvalid && dut.u_packet_filter.m_tready) begin
//            $fwrite(fin,"%h\n",
//                dut.u_packet_filter.m_tdata
//            );
//        end
//    end
    
//    integer fout;
//    initial begin
//        fout = $fopen("E:/10G_Ethernet/out_packets1.txt","w");
//    end
    
//    always @(posedge clk_p) begin
//        if(dut.u_server.rx_tvalid && dut.u_server.rx_tready && !((dut.u_server.rx_tdata[239:224] == 16'd8888) && (dut.u_server.rx_tdata[223:208] == 16'd9999))) begin
//            $fwrite(fout,"%h\n",
//                dut.u_server.rx_tdata
//            );
//        end
//    end



endmodule
