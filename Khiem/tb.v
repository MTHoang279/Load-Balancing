//`timescale 1ns / 1ps

//module tb_fpga_lb_server_top;

//    ////////////////////////////////////////////////////////////
//    // 1. SIGNAL DECLARATION
//    ////////////////////////////////////////////////////////////
//    //localparam algo       = 3;
//    localparam servers    = 32;
//    localparam servers_en = servers;
//    localparam bus_width  = 512;

//    reg clk_p = 0;
//    reg clk_n = 1;
//    reg allow_reply;
//    reg rst_in;
//    reg start;
//    reg [1:0]    algo_sel;
//    reg [4:0] server_en; 

//    ////////////////////////////////////////////////////////////
//    // 2. CLOCK GENERATION
//    ////////////////////////////////////////////////////////////
//    always #1.6667 begin
//        clk_p = ~clk_p;
//        clk_n = ~clk_n;
//    end

//    ////////////////////////////////////////////////////////////
//    // 3. DUT INSTANTIATION
//    ////////////////////////////////////////////////////////////
//    fpga_lb_server_top #(
//        .BUS_WIDTH(bus_width),
//        .N_SERVERS(servers)
////        .SERVERS_ALIVE(servers),
////        .N_ALGORITHMS(3)
//    ) dut (
//        .allow_reply(allow_reply),
//        .clk_p(clk_p),
//        .clk_n(clk_n),
//        .server_en(server_en),
//        .rst_in(rst_in),
//        .start(start),
//        .algo_sel(algo_sel)
//    );

//    ////////////////////////////////////////////////////////////
//    // 4. MAIN TEST SEQUENCE
//    ////////////////////////////////////////////////////////////
//    initial begin
//        rst_in    = 1;
//        start     = 0;
//        server_en = 5'd1;
//        algo_sel  = 2'b10;
//        allow_reply =1;
//        $display("[%0t] Switch to Round Robin", $time);

//        #20;
//        rst_in = 0;
//        $display("[%0t] TB: Reset released", $time);
//        server_en = 5'd31;
//        #20000;

//        //------------------------------------------------------
//        // trigger generator
//        //------------------------------------------------------

//        start = 1;
//        //server_en = 5'd0;
//        #200;
//        start = 0;

////        $display("[%0t] TB: Generator started", $time);
////        #5000;
////        $display("[%0t] Sv 3,4 die", $time); 
//        // N?u mu?n test server ch?t, b?n có th? gán: server_en[4:3] = 2'b00;
//        #50000;
////        start = 1;
////        algo_sel  = 2'b11;
////        #200;
////        start = 0;
//          allow_reply =1;
////        #50000;
//        start = 1;
//        algo_sel =2'b01;
//        #50;
//        start = 0;
////        #5000;
////        allow_reply =1;
//    end

//    ////////////////////////////////////////////////////////////
//    // 5. TOTAL COUNTERS (SUM 32 SERVERS)
//    ////////////////////////////////////////////////////////////
//    integer idx;
//    reg [255:0] total_user_req;
//    reg [255:0] total_hb_req;
//    reg [255:0] total_user_reply;
//    reg [255:0] total_hb_reply;

//    always @(*) begin
//        total_user_req   = 0;
//        total_hb_req     = 0;
//        total_user_reply = 0;
//        total_hb_reply   = 0;

//        for (idx = 0; idx < servers; idx = idx + 1) begin
//            total_user_req = total_user_req +
//                tb_fpga_lb_server_top.dut.u_server.cnt_user_req_rx[idx*8 +: 8];

//            total_hb_req = total_hb_req +
//                tb_fpga_lb_server_top.dut.u_server.cnt_hb_req_rx[idx*8 +: 8];

//            total_user_reply = total_user_reply +
//                tb_fpga_lb_server_top.dut.u_server.cnt_user_reply_tx[idx*8 +: 8];

//            total_hb_reply = total_hb_reply +
//                tb_fpga_lb_server_top.dut.u_server.cnt_hb_reply_tx[idx*8 +: 8];
//        end
//    end

//    ////////////////////////////////////////////////////////////
//    // 6. LOAD BALANCING RATIO (REAL)
//    ////////////////////////////////////////////////////////////
//    real ratio_user_req   [0:servers-1];
//    real ratio_user_reply [0:servers-1];
//    integer ridx;

//    always @(*) begin
//        for (ridx = 0; ridx < servers; ridx = ridx + 1) begin
//            if (total_user_req != 0)
//                ratio_user_req[ridx] =
//                    (tb_fpga_lb_server_top.dut.u_server.cnt_user_req_rx[ridx*8 +: 8] * 1.0) / total_user_req;
//            else
//                ratio_user_req[ridx] = 0.0;

//            if (total_user_reply != 0)
//                ratio_user_reply[ridx] =
//                    (tb_fpga_lb_server_top.dut.u_server.cnt_user_reply_tx[ridx*8 +: 8] * 1.0) / total_user_reply;
//            else
//                ratio_user_reply[ridx] = 0.0;
//        end
//    end

//    ////////////////////////////////////////////////////////////
//    // 7. CSV LOGGER 
//    ////////////////////////////////////////////////////////////
//    integer f;
//    initial begin
//        f = $fopen("D:/VHT/logging.csv", "w");
//        if (f == 0) begin
//            $display("FATAL: cannot open file D:/VHT/logging.csv");
//            $finish;
//        end
//        $display("File opened successfully, handle = %0d", f);
//        $fwrite(f, "time,stage,data,keep,last\n");
//    end

//    always @(posedge clk_p) begin
//        // GEN
//        if (tb_fpga_lb_server_top.dut.u_fpga_top.u_packet_gen.M_AXIS_TVALID &&
//            tb_fpga_lb_server_top.dut.u_fpga_top.u_packet_gen.M_AXIS_TREADY) begin
//            $fwrite(f, "%0t,GEN,%h,%h,%0d\n",
//                $time,
//                tb_fpga_lb_server_top.dut.u_fpga_top.u_packet_gen.M_AXIS_TDATA,
//                tb_fpga_lb_server_top.dut.u_fpga_top.u_packet_gen.M_AXIS_TKEEP,
//                tb_fpga_lb_server_top.dut.u_fpga_top.u_packet_gen.M_AXIS_TLAST
//            );
//        end

//        // FILTER
//        if (tb_fpga_lb_server_top.dut.u_fpga_top.u_packet_filter.m_tvalid &&
//            tb_fpga_lb_server_top.dut.u_fpga_top.u_packet_filter.m_tready) begin
//            $fwrite(f, "%0t,FILTER,%h,%h,%0d\n",
//                $time,
//                tb_fpga_lb_server_top.dut.u_fpga_top.u_packet_filter.m_tdata,
//                tb_fpga_lb_server_top.dut.u_fpga_top.u_packet_filter.m_tkeep,
//                tb_fpga_lb_server_top.dut.u_fpga_top.u_packet_filter.m_tlast
//            );
//        end

//        // ARBITER
//        if (tb_fpga_lb_server_top.dut.u_fpga_top.u_lb_core.u_arbiter.cslb_tvalid &&
//            tb_fpga_lb_server_top.dut.u_fpga_top.u_lb_core.u_arbiter.cslb_tready) begin
//            $fwrite(f, "%0t,ARB,%h,%h,%0d\n",
//                $time,
//                tb_fpga_lb_server_top.dut.u_fpga_top.u_lb_core.u_arbiter.cslb_tdata,
//                tb_fpga_lb_server_top.dut.u_fpga_top.u_lb_core.u_arbiter.cslb_tkeep,
//                tb_fpga_lb_server_top.dut.u_fpga_top.u_lb_core.u_arbiter.cslb_tlast
//            );
//        end

//        // SERVER RX
//        if (tb_fpga_lb_server_top.dut.u_server.rx_tvalid &&
//            tb_fpga_lb_server_top.dut.u_server.rx_tready) begin
//            $fwrite(f, "%0t,SRV_RX,%h,%h,%0d\n",
//                $time,
//                tb_fpga_lb_server_top.dut.u_server.rx_tdata,
//                tb_fpga_lb_server_top.dut.u_server.rx_tkeep,
//                tb_fpga_lb_server_top.dut.u_server.rx_tlast
//            );
//        end

//        // SERVER TX
//        if (tb_fpga_lb_server_top.dut.u_server.tx_tvalid &&
//            tb_fpga_lb_server_top.dut.u_server.tx_tready) begin
//            $fwrite(f, "%0t,SRV_TX,%h,%h,%0d\n",
//                $time,
//                tb_fpga_lb_server_top.dut.u_server.tx_tdata,
//                tb_fpga_lb_server_top.dut.u_server.tx_tkeep,
//                tb_fpga_lb_server_top.dut.u_server.tx_tlast
//            );
//        end
//    end

//    ////////////////////////////////////////////////////////////
//    // 8. STATS LOGGER (MEAN, MIN, MAX, STDDEV)
//    ////////////////////////////////////////////////////////////
//    real req_mean, rep_mean;
//    real req_var, rep_var;
//    real req_std, rep_std;
//    integer req_min, req_max;
//    integer rep_min, rep_max;
//    integer current_req, current_rep;
//    integer p_idx;

//    // Hàm toán h?c tính c?n b?c 2 (Newton-Raphson)
//    function real sqrt_real;
//        input real x;
//        real guess, next_guess;
//        integer i;
//        begin
//            if (x <= 0.0) sqrt_real = 0.0;
//            else begin
//                guess = x / 2.0;
//                for (i = 0; i < 20; i = i + 1) begin
//                    next_guess = 0.5 * (guess + (x / guess));
//                    guess = next_guess;
//                end
//                sqrt_real = guess;
//            end
//        end
//    endfunction

//    always begin
//        #20000; // Kho?ng th?i gian log d? li?u ra Terminal
//        if (total_user_req > 0) begin
            
//            // 1. Calculate Mean
//            req_mean = total_user_req * 1.0 / servers;
//            rep_mean = total_user_reply * 1.0 / servers;

//            // 2. Initialize Min/Max/Var
//            req_min = 2147483647; req_max = 0; req_var = 0.0;
//            rep_min = 2147483647; rep_max = 0; rep_var = 0.0;

//            // 3. Find Min/Max and accumulate variance
//            for (p_idx = 0; p_idx < servers; p_idx = p_idx + 1) begin
//                current_req = tb_fpga_lb_server_top.dut.u_server.cnt_user_req_rx[p_idx*8 +: 8];
//                current_rep = tb_fpga_lb_server_top.dut.u_server.cnt_user_reply_tx[p_idx*8 +: 8];

//                if (current_req < req_min) req_min = current_req;
//                if (current_req > req_max) req_max = current_req;

//                if (current_rep < rep_min) rep_min = current_rep;
//                if (current_rep > rep_max) rep_max = current_rep;

//                req_var = req_var + ((current_req - req_mean) * (current_req - req_mean));
//                rep_var = rep_var + ((current_rep - rep_mean) * (current_rep - rep_mean));
//            end

//            // 4. Calculate Standard Deviation
//            req_var = req_var / servers;
//            rep_var = rep_var / servers;
//            req_std = sqrt_real(req_var);
//            rep_std = sqrt_real(rep_var);

//            // 5. Print Summary
//            $display("\n=================== LOAD BALANCING STATS ===================");
//            $display("REQUESTS -> Total: %0d | Mean: %6.2f | Min: %0d | Max: %0d | StdDev: %6.4f", 
//                     total_user_req, req_mean, req_min, req_max, req_std);
//            $display("REPLIES  -> Total: %0d | Mean: %6.2f | Min: %0d | Max: %0d | StdDev: %6.4f", 
//                     total_user_reply, rep_mean, rep_min, rep_max, rep_std);
//            $display("------------------------------------------------------------");

//            // 6. Print Detailed SV Stats
//            for (p_idx = 0; p_idx < servers; p_idx = p_idx + 1) begin
//                $display("SV[%0d] req=%0d (%.4f) | rep=%0d (%.4f)",
//                    p_idx,
//                    tb_fpga_lb_server_top.dut.u_server.cnt_user_req_rx[p_idx*8 +: 8],
//                    ratio_user_req[p_idx],
//                    tb_fpga_lb_server_top.dut.u_server.cnt_user_reply_tx[p_idx*8 +: 8],
//                    ratio_user_reply[p_idx]
//                );
//            end
//        end
//    end

//    ////////////////////////////////////////////////////////////
//    // 9. END OF SIMULATION
//    ////////////////////////////////////////////////////////////
//    initial begin
//        #10000;
//        $display("\n[%0t] Simulation finished", $time);
//        $fclose(f);
//        server_en = 5'd31;
//        #2000;
//        start = 1;
//        //server_en = 5'd0;
//        #200;
//        start = 0;
//        //$finish; // D?ng ti?n trình mô ph?ng an toàn
//    end

//endmodule

`timescale 1ns / 1ps

module tb_fpga_lb_server_top;

    ////////////////////////////////////////////////////////////
    // 1. SIGNAL DECLARATION
    ////////////////////////////////////////////////////////////
    localparam servers    = 32;
    localparam servers_en = servers;
    localparam bus_width  = 512;

    reg clk_p = 0;
    reg clk_n = 1;
    reg allow_reply;
    reg rst_in;
    reg start;
    reg [1:0] algo_sel;
    reg [4:0] server_en;

    ////////////////////////////////////////////////////////////
    // 2. CLOCK GENERATION
    ////////////////////////////////////////////////////////////
    always #1.6667 begin
        clk_p = ~clk_p;
        clk_n = ~clk_n;
    end

    ////////////////////////////////////////////////////////////
    // 3. DUT INSTANTIATION
    ////////////////////////////////////////////////////////////
    fpga_lb_server_top #(
        .BUS_WIDTH(bus_width),
        .N_SERVERS(servers)
    ) dut (
        .allow_reply(allow_reply),
        .clk_p(clk_p),
        .clk_n(clk_n),
        .server_en(server_en),
        .rst_in(rst_in),
        .start(start),
        .algo_sel(algo_sel)
    );

    ////////////////////////////////////////////////////////////
    // 4. MAIN TEST SEQUENCE
    ////////////////////////////////////////////////////////////
    initial begin
        rst_in      = 1;
        start       = 0;
        server_en   = 5'd16;
        algo_sel    = 2'b01;   // ví d?: RR / algo hi?n t?i c?a b?n
        allow_reply = 1;

        $display("[%0t] TB: Init", $time);

        #20;
        rst_in = 0;

        $display("[%0t] TB: Reset released", $time);

//        server_en = 5'd31;   // enable nhi?u server
        #2000;
        start  = 1;
        #200;
        start = 0;
        
//        #6000;
//        //------------------------------------------------------
//        // Trigger generator l?n 1
//        //------------------------------------------------------
//        $display("[%0t] TB: Start traffic - algo=%0d", $time, algo_sel);
//        server_en   = 5'd8;
//        algo_sel    = 2'b11; 
//        start = 1;
//        #200;
//        start = 0;

//        #5000;
//        server_en   = 5'd31;
//        //------------------------------------------------------
//        // Switch algorithm
//        //------------------------------------------------------
//        allow_reply = 1;
//        algo_sel    = 2'b10;
//        $display("[%0t] TB: Switch algo -> %0d", $time, algo_sel);

//        start = 1;
//        #50;
//        start = 0;

//        #50000;

        $display("\n[%0t] TB: Simulation finished", $time);
        $finish;
    end

    ////////////////////////////////////////////////////////////
    // 5. TOTAL COUNTERS (SUM 32 SERVERS)
    ////////////////////////////////////////////////////////////
    integer idx;
    reg [511:0] total_user_req;
    reg [511:0] total_hb_req;
    reg [511:0] total_user_reply;
    reg [511:0] total_hb_reply;

    always @(*) begin
        total_user_req   = 0;
        total_hb_req     = 0;
        total_user_reply = 0;
        total_hb_reply   = 0;

        for (idx = 0; idx < servers; idx = idx + 1) begin
            total_user_req = total_user_req +
                tb_fpga_lb_server_top.dut.u_server.cnt_user_req_rx[idx*16 +: 16];

            total_hb_req = total_hb_req +
                tb_fpga_lb_server_top.dut.u_server.cnt_hb_req_rx[idx*16 +: 16];

            total_user_reply = total_user_reply +
                tb_fpga_lb_server_top.dut.u_server.cnt_user_reply_tx[idx*16 +: 16];

            total_hb_reply = total_hb_reply +
                tb_fpga_lb_server_top.dut.u_server.cnt_hb_reply_tx[idx*16 +: 16];
        end
    end

    ////////////////////////////////////////////////////////////
    // 6. LOAD BALANCING RATIO (REAL)
    ////////////////////////////////////////////////////////////
    real ratio_user_req   [0:servers-1];
    real ratio_user_reply [0:servers-1];
    integer ridx;

    always @(*) begin
        for (ridx = 0; ridx < servers; ridx = ridx + 1) begin
            if (total_user_req != 0)
                ratio_user_req[ridx] =
                    (tb_fpga_lb_server_top.dut.u_server.cnt_user_req_rx[ridx*16 +: 16] * 1.0) / total_user_req;
            else
                ratio_user_req[ridx] = 0.0;

            if (total_user_reply != 0)
                ratio_user_reply[ridx] =
                    (tb_fpga_lb_server_top.dut.u_server.cnt_user_reply_tx[ridx*16 +: 16] * 1.0) / total_user_reply;
            else
                ratio_user_reply[ridx] = 0.0;
        end
    end

    ////////////////////////////////////////////////////////////
    // 7. STATS LOGGER (MEAN, MIN, MAX, STDDEV)
    ////////////////////////////////////////////////////////////
    real req_mean, rep_mean;
    real req_var, rep_var;
    real req_std, rep_std;
    integer req_min, req_max;
    integer rep_min, rep_max;
    integer current_req, current_rep;
    integer p_idx;

    // Hàm sqrt b?ng Newton-Raphson
    function real sqrt_real;
        input real x;
        real guess, next_guess;
        integer i;
        begin
            if (x <= 0.0) sqrt_real = 0.0;
            else begin
                guess = x / 2.0;
                for (i = 0; i < 20; i = i + 1) begin
                    next_guess = 0.5 * (guess + (x / guess));
                    guess = next_guess;
                end
                sqrt_real = guess;
            end
        end
    endfunction

    always begin
        #20000; // m?i 20us log 1 l?n
        if (total_user_req > 0) begin

            // 1. Mean
            req_mean = total_user_req * 1.0 / servers;
            rep_mean = total_user_reply * 1.0 / servers;

            // 2. Init
            req_min = 2147483647; req_max = 0; req_var = 0.0;
            rep_min = 2147483647; rep_max = 0; rep_var = 0.0;

            // 3. Min / Max / Variance
            for (p_idx = 0; p_idx < 16; p_idx = p_idx + 1) begin
                current_req = tb_fpga_lb_server_top.dut.u_server.cnt_user_req_rx[p_idx*16 +: 16];
                current_rep = tb_fpga_lb_server_top.dut.u_server.cnt_user_reply_tx[p_idx*16 +: 16];

                if (current_req < req_min) req_min = current_req;
                if (current_req > req_max) req_max = current_req;

                if (current_rep < rep_min) rep_min = current_rep;
                if (current_rep > rep_max) rep_max = current_rep;

                req_var = req_var + ((current_req - req_mean) * (current_req - req_mean));
                rep_var = rep_var + ((current_rep - rep_mean) * (current_rep - rep_mean));
            end

            // 4. StdDev
            req_var = req_var / servers;
            rep_var = rep_var / servers;
            req_std = sqrt_real(req_var);
            rep_std = sqrt_real(rep_var);

            // 5. Summary
            $display("\n=================== LOAD BALANCING STATS ===================");
            $display("Time      = %0t", $time);
            $display("Algo      = %0d", algo_sel);
            $display("REQ Total = %0d | Mean = %6.2f | Min = %0d | Max = %0d | StdDev = %6.4f",
                     total_user_req, req_mean, req_min, req_max, req_std);
            $display("REP Total = %0d | Mean = %6.2f | Min = %0d | Max = %0d | StdDev = %6.4f",
                     total_user_reply, rep_mean, rep_min, rep_max, rep_std);
            $display("------------------------------------------------------------");

            // 6. Detailed per server
            for (p_idx = 0; p_idx < servers; p_idx = p_idx + 1) begin
                $display("SV[%0d] req=%0d (%.4f) | rep=%0d (%.4f)",
                    p_idx,
                    tb_fpga_lb_server_top.dut.u_server.cnt_user_req_rx[p_idx*16 +: 16],
                    ratio_user_req[p_idx],
                    tb_fpga_lb_server_top.dut.u_server.cnt_user_reply_tx[p_idx*16 +: 16],
                    ratio_user_reply[p_idx]
                );
            end
        end
    end

endmodule