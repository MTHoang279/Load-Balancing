module local_scn_buffer #(
    parameter N      = 16,
    parameter DATA_W = 12
)(
    input                    clk,
    input                    rst_n,
    
    // Server health state (from SHM)
    input  [N-1:0]           server_valid,
    
    // Increment interface (from TLCM core) - just signal, no data!
    input                    inc_en,
    input  [$clog2(N)-1:0]   inc_index,
    
    // Decrement interface (from external controller)
    input                    dec_en,
    input  [$clog2(N)-1:0]   dec_index,
    
    // Load interface (for initial SCN from SHM)
    input                    load_en,
    input  [N*DATA_W-1:0]    load_data,
    
    // Read interface (to Stage 1)
    output reg [N*DATA_W-1:0] scn_current
);

    localparam IDX_W = $clog2(N);
    
    // Local SCN storage
    reg [DATA_W-1:0] scn_reg [0:N-1];
    reg [DATA_W-1:0] scn_next [0:N-1];
    
    integer i;
    
    // Combinational next-state for immediate SCN visibility
    always @(*) begin
        for (i = 0; i < N; i = i + 1) begin
            scn_next[i] = scn_reg[i];
        end

        if (load_en) begin
            for (i = 0; i < N; i = i + 1) begin
                scn_next[i] = load_data[i*DATA_W +: DATA_W];
            end
        end else begin
            for (i = 0; i < N; i = i + 1) begin
                if (!server_valid[i]) begin
                    scn_next[i] = {DATA_W{1'b0}};
                end else if (inc_en && inc_index == i && dec_en && dec_index == i) begin
                    scn_next[i] = scn_reg[i];
                end else if (inc_en && inc_index == i) begin
                    scn_next[i] = scn_reg[i] + 1'b1;
                end else if (dec_en && dec_index == i) begin
                    if (scn_reg[i] > 0)
                        scn_next[i] = scn_reg[i] - 1'b1;
                end
            end
        end
    end
    
    // Write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all SCN to 0
            for (i = 0; i < N; i = i + 1) begin
                scn_reg[i] <= {DATA_W{1'b0}};
            end
        end else begin
            for (i = 0; i < N; i = i + 1) begin
                scn_reg[i] <= scn_next[i];
            end
            scn_current <= {N*DATA_W{1'b0}};
            for (i = 0; i < N; i = i + 1) begin
                scn_current[i*DATA_W +: DATA_W] <= scn_next[i];
            end
        end
    end

endmodule