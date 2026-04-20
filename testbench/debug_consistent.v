`timescale 1ns / 1ps

module tb_debug_one_file;

    integer f;
    integer ret;
    integer line_num;
    integer success_cnt;
    integer error_cnt;
    integer hb_skip_cnt;

    reg [511:0] data;

    reg [31:0] src_ip;
    reg [31:0] dst_ip;

    reg is_hb;
    reg f_done;

    initial begin
        f = $fopen("E:/10G_Ethernet/track_file/server_3.txt", "r");

        if (f == 0) begin
            $display("ERROR: cannot open file!");
            $finish;
        end
    end

    initial begin
        #10;

        $display("===== DEBUG FILE (NO HB) =====");

        line_num     = 0;
        success_cnt  = 0;
        error_cnt    = 0;
        hb_skip_cnt  = 0;
        f_done       = 0;

        while (!f_done) begin

            line_num = line_num + 1;

            if (!$feof(f)) begin
                ret = $fscanf(f, "%h\n", data);
            end else begin
                f_done = 1;
            end

            if (!f_done && ret == 1) begin

                // ? detect HB
                is_hb = (data[223:208] == 16'd8888) &&
                        (data[239:224] == 16'd9999);

                // ? SKIP heartbeat
                if (is_hb) begin
                    hb_skip_cnt = hb_skip_cnt + 1;
                end
                else begin
                    // Extract IP
                    src_ip = data[303:272];
                    dst_ip = data[271:240];

                    success_cnt = success_cnt + 1;

                    $display("[LINE %0d] DATA = %h", line_num, data);

                    $display("  SRC = %0d.%0d.%0d.%0d",
                        src_ip[31:24], src_ip[23:16],
                        src_ip[15:8],  src_ip[7:0]);

                    $display("  DST = %0d.%0d.%0d.%0d",
                        dst_ip[31:24], dst_ip[23:16],
                        dst_ip[15:8],  dst_ip[7:0]);

                    $display("  -------------------------");
                end

            end 
            else if (!f_done && ret != 1) begin
                error_cnt = error_cnt + 1;
                $display("[LINE %0d] ERROR: fscanf failed!", line_num);
            end

            #10;
        end

        $display("\n===== SUMMARY =====");
        $display("Total lines processed : %0d", line_num - 1);
        $display("Valid data packets    : %0d", success_cnt);
        $display("HB packets skipped    : %0d", hb_skip_cnt);
        $display("Read errors           : %0d", error_cnt);
        $display("===================\n");

        $finish;
    end

endmodule