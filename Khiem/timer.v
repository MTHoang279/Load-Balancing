`timescale 1ns / 1ps
module shm_timer #(
    parameter integer CLK_FREQ_HZ = 322_000_000
)(
    input  wire clk,
    input  wire rst_n,

    output reg  tick_1s,
    output reg  tick_10s
);

    // -------------------------------------------------------------------------
    // Local parameters
    // -------------------------------------------------------------------------
    localparam integer CNT_1S_MAX   = CLK_FREQ_HZ - 1;
    localparam integer CNT_10S_MAX  = (CLK_FREQ_HZ * 10) - 1;
    // localparam integer CNT_10S_MAX  = CLK_FREQ_HZ - 1;

    localparam integer CNT_1S_W     = $clog2(CNT_1S_MAX + 1);
    localparam integer CNT_10S_W    = $clog2(CNT_10S_MAX + 1);

    // -------------------------------------------------------------------------
    // Counters
    // -------------------------------------------------------------------------
    reg [CNT_1S_W-1:0]  cnt_1s;
    reg [CNT_10S_W-1:0] cnt_10s;

    // -------------------------------------------------------------------------
    // 1-second counter & tick
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            cnt_1s  <= {CNT_1S_W{1'b0}};
            tick_1s <= 1'b0;
        end else begin
            if (cnt_1s == CNT_1S_MAX) begin
                cnt_1s  <= {CNT_1S_W{1'b0}};
                tick_1s <= 1'b1;
            end else begin
                cnt_1s  <= cnt_1s + 1'b1;
                tick_1s <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 10-second counter & tick
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            cnt_10s  <= {CNT_10S_W{1'b0}};
            tick_10s <= 1'b0;
        end else begin
            if (cnt_10s == CNT_10S_MAX) begin
                cnt_10s  <= {CNT_10S_W{1'b0}};
                tick_10s <= 1'b1;
            end else begin
                cnt_10s  <= cnt_10s + 1'b1;
                tick_10s <= 1'b0;
            end
        end
    end

endmodule

// `timescale 1ns / 1ps
// module shm_timer#(
//     parameter integer CLK_FREQ_HZ = 322_000_000
// ) (
//     input  wire clk,
//     input  wire rst_n,

//     output reg  tick_1s,
//     output reg  tick_10s
// );

//     // -------------------------------------------------------------------------
//     // Local parameters
//     // -------------------------------------------------------------------------
//     localparam integer CNT_10CLK_MAX  = 10  - 1;
//     localparam integer CNT_100CLK_MAX = 100 - 1;

//     localparam integer CNT_10CLK_W    = $clog2(CNT_10CLK_MAX + 1);
//     localparam integer CNT_100CLK_W   = $clog2(CNT_100CLK_MAX + 1);

//     // -------------------------------------------------------------------------
//     // Counters
//     // -------------------------------------------------------------------------
//     reg [CNT_10CLK_W-1:0]  cnt_10clk;
//     reg [CNT_100CLK_W-1:0] cnt_100clk;

//     // -------------------------------------------------------------------------
//     // 10-clock tick
//     // Phát xung 1 chu kỳ mỗi 10 clock
//     // -------------------------------------------------------------------------
//     always @(posedge clk) begin
//         if (!rst_n) begin
//             cnt_10clk  <= {CNT_10CLK_W{1'b0}};
//             tick_1s <= 1'b0;
//         end else begin
//             if (cnt_10clk == CNT_10CLK_MAX) begin
//                 cnt_10clk  <= {CNT_10CLK_W{1'b0}};
//                 tick_1s <= 1'b1;
//             end else begin
//                 cnt_10clk  <= cnt_10clk + 1'b1;
//                 tick_1s <= 1'b0;
//             end
//         end
//     end

//     // -------------------------------------------------------------------------
//     // 100-clock tick
//     // Phát xung 1 chu kỳ mỗi 100 clock
//     // -------------------------------------------------------------------------
//     always @(posedge clk) begin
//         if (!rst_n) begin
//             cnt_100clk  <= {CNT_100CLK_W{1'b0}};
//             tick_10s <= 1'b0;
//         end else begin
//             if (cnt_100clk == CNT_100CLK_MAX) begin
//                 cnt_100clk  <= {CNT_100CLK_W{1'b0}};
//                 tick_10s <= 1'b1;
//             end else begin
//                 cnt_100clk  <= cnt_100clk + 1'b1;
//                 tick_10s <= 1'b0;
//             end
//         end
//     end

// endmodule