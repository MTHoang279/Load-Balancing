`timescale 1ns / 1ps

module file_compare_wave;

    integer fin, fout;
    integer r1, r2;
    integer line, i;

    reg [511:0] in_data;
    reg [511:0] out_data;

    reg [511:0] diff_mask;
    reg diff;

    reg fin_done, fout_done;

    integer diff_cnt;   // <<< bi?n ??m s? l?n diff

    initial begin

        fin  = $fopen("E:/10G_Ethernet/in_packets1.txt","r");
        fout = $fopen("E:/10G_Ethernet/out_packets1.txt","r");

        if (fin == 0 || fout == 0) begin
            $display("ERROR: Cannot open file!");
            $finish;
        end

        line = 0;
        diff_cnt = 0;   // <<< init

        fin_done  = 0;
        fout_done = 0;

        while (!(fin_done && fout_done)) begin

            line = line + 1;

            if (!$feof(fin)) begin
                r1 = $fscanf(fin, "%h\n", in_data);
            end else begin
                fin_done = 1;
            end

            if (!$feof(fout)) begin
                r2 = $fscanf(fout, "%h\n", out_data);
            end else begin
                fout_done = 1;
            end

            // ===== CASE 1: c? 2 ??u còn d? li?u =====
            if (!fin_done && !fout_done) begin

                diff_mask = in_data ^ out_data;

                diff = 1'b0;
                for(i = 0; i < 512; i = i + 1) begin
                    if(diff_mask[i])
                        diff = 1'b1;
                end

                if(diff) begin
                    diff_cnt = diff_cnt + 1;   // <<< t?ng counter

                    $display("DIFF line %0d", line);
                    $display("IN  = %h", in_data);
                    $display("OUT = %h", out_data);
                    $display("MASK= %h", diff_mask);
                end

            end

            // ===== CASE 2 =====
            else if (!fin_done && fout_done) begin
                diff_cnt = diff_cnt + 1;   // coi nh? mismatch
                $display("MISSING OUTPUT at line %0d", line);
                $display("IN = %h", in_data);
            end

            // ===== CASE 3 =====
            else if (fin_done && !fout_done) begin
                diff_cnt = diff_cnt + 1;   // mismatch
                $display("EXTRA OUTPUT at line %0d", line);
                $display("OUT = %h", out_data);
            end

            #10;
        end

        // ===== SUMMARY =====
        $display("=== COMPARE DONE ===");
        $display("Total lines checked : %0d", line);
        $display("Total mismatches    : %0d", diff_cnt);

        if (diff_cnt == 0)
            $display("RESULT: PASS ?");
        else
            $display("RESULT: FAIL ?");

        $finish;

    end

endmodule