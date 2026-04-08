module shm_timer #(
    parameter CLK_FREQ_HZ = 156_250_000,
    parameter TICK_MS = 10
)(
    input  wire clk,
    input  wire rst_n,
    output reg  heartbeat_gen_trigger,
    output reg  heartbeat_checker_trigger
);

    // CLOCKS_PER_TICK = CLK_FREQ_HZ * TICK_MS / 1000
    // VD: 156,250,000 * 10 / 1000 = 1,562,500 clocks
    localparam CLOCKS_PER_TICK = (CLK_FREQ_HZ * TICK_MS) / 1000;

    localparam TICKS_1S  = 1000 / TICK_MS;   // 1s (1000ms / 10ms = 100 ticks)
    localparam TICKS_10S = 10000 / TICK_MS;  // 10s (10000ms / 10ms = 1000 ticks)

    localparam CLK_CNT_WIDTH   = $clog2(CLOCKS_PER_TICK);
    localparam TICK_1S_WIDTH   = $clog2(TICKS_1S);
    localparam TICK_10S_WIDTH  = $clog2(TICKS_10S);

    reg [CLK_CNT_WIDTH-1:0]   clock_counter;
    reg [TICK_1S_WIDTH-1:0]   tick_counter_1s;
    reg [TICK_10S_WIDTH-1:0]  tick_counter_10s;

    wire tick_pulse;
    wire clock_cnt_max;

    wire tick_1s_max;
    wire tick_10s_max;
    
    assign clock_cnt_max = (clock_counter == CLOCKS_PER_TICK - 1);
    assign tick_pulse = clock_cnt_max;
    
    assign tick_1s_max = (tick_counter_1s == TICKS_1S - 1);
    assign tick_10s_max = (tick_counter_10s == TICKS_10S - 1);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clock_counter <= 0;
        end
        else begin
            if (clock_cnt_max) begin
                clock_counter <= 0;
            end
            else begin
                clock_counter <= clock_counter + 1;
            end
        end
    end
    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_counter_1s <= 0;
            heartbeat_gen_trigger <= 1'b0;
        end
        else begin
            heartbeat_gen_trigger <= 1'b0;
            
            if (tick_pulse) begin
                if (tick_1s_max) begin
                    heartbeat_gen_trigger <= 1'b1;
                    tick_counter_1s <= 0;
                end
                else begin
                    tick_counter_1s <= tick_counter_1s + 1;
                end
            end
        end
    end
    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_counter_10s <= 0;
            heartbeat_checker_trigger <= 1'b0;
        end
        else begin
            heartbeat_checker_trigger <= 1'b0;
            
            if (tick_pulse) begin
                if (tick_10s_max) begin
                    heartbeat_checker_trigger <= 1'b1;
                    tick_counter_10s <= 0;
                end
                else begin
                    tick_counter_10s <= tick_counter_10s + 1;
                end
            end
        end
    end

endmodule
