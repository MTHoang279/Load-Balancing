//module local_scn_buffer #(
//    parameter N      = 16,
//    parameter DATA_W = 12
//)(
//    input                    clk,
//    input                    rst_n,
    
//    // Server health state (from SHM)
//    input  [N-1:0]           server_valid,
    
//    // Increment interface (from TLCM core) - just signal, no data!
//    input                    inc_en,
//    input  [$clog2(N)-1:0]   inc_index,
    
//    // Decrement interface (from external controller)
//    input                    dec_en,
//    input  [$clog2(N)-1:0]   dec_index,
    
//    // Load interface (for initial SCN from SHM)
//    input                    load_en,
//    input  [N*DATA_W-1:0]    load_data,
    
//    // Read interface (to Stage 1)
//    output [N*DATA_W-1:0]    scn_current
//);

//    localparam IDX_W = $clog2(N);
    
//    // Local SCN storage
//    reg [DATA_W-1:0] scn_reg [0:N-1];
    
//    integer i;
    
//    // Output assignment - always readable
//    generate
//        genvar k;
//        for (k = 0; k < N; k = k + 1) begin : GEN_OUTPUT
//            assign scn_current[k*DATA_W +: DATA_W] = scn_reg[k];
//        end
//    endgenerate
    
//    // Write logic
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            // Reset all SCN to 0
//            for (i = 0; i < N; i = i + 1) begin
//                scn_reg[i] <= {DATA_W{1'b0}};
//            end
//        end else begin
//            // Load SCN from external (highest priority)
//            if (load_en) begin
//                for (i = 0; i < N; i = i + 1) begin
//                    scn_reg[i] <= load_data[i*DATA_W +: DATA_W];
//                end
//            end else begin
//                // Process each server individually
//                for (i = 0; i < N; i = i + 1) begin
//                    // PRIORITY 1: Server health check - reset SCN if server down
//                    if (!server_valid[i]) begin
//                        scn_reg[i] <= {DATA_W{1'b0}};
//                    end
//                    // PRIORITY 2: Increment and Decrement (only if server alive)
//                    else if (inc_en && inc_index == i && dec_en && dec_index == i) begin
//                        // CONFLICT: Both inc and dec on same server - cancel each other
//                        scn_reg[i] <= scn_reg[i];
//                    end else if (inc_en && inc_index == i) begin
//                        // Saturating increment avoids wrap-around bias.
//                        if (scn_reg[i] != {DATA_W{1'b1}})
//                            scn_reg[i] <= scn_reg[i] + 1'b1;
//                        else
//                            scn_reg[i] <= scn_reg[i];
//                    end else if (dec_en && dec_index == i) begin
//                        // Decrement only when value is non-zero.
//                        if (scn_reg[i] > 0)
//                            scn_reg[i] <= scn_reg[i] - 1'b1;
//                    end
//                    // else: no change
//                end
//            end
//        end
//    end

//endmodule


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
    output [N*DATA_W-1:0]    scn_current
);

    localparam IDX_W = $clog2(N);
    
    // Local SCN storage
    reg [DATA_W-1:0] scn_reg [0:N-1];
    
    integer i;
    
    // Output assignment - always readable
    generate
        genvar k;
        for (k = 0; k < N; k = k + 1) begin : GEN_OUTPUT
            assign scn_current[k*DATA_W +: DATA_W] = scn_reg[k];
        end
    endgenerate
    
    // Write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all SCN to 0
            for (i = 0; i < N; i = i + 1) begin
                scn_reg[i] <= {DATA_W{1'b0}};
            end
        end else begin
            // Load SCN from external (highest priority)
            if (load_en) begin
                for (i = 0; i < N; i = i + 1) begin
                    scn_reg[i] <= load_data[i*DATA_W +: DATA_W];
                end
            end else begin
                // Process each server individually
                for (i = 0; i < N; i = i + 1) begin
                    // PRIORITY 1: Server health check - reset SCN if server down
                    if (!server_valid[i]) begin
                        scn_reg[i] <= {DATA_W{1'b0}};
                    end
                    // PRIORITY 2: Increment and Decrement (only if server alive)
                    else if (inc_en && inc_index == i && dec_en && dec_index == i) begin
                        // CONFLICT: Both inc and dec on same server - cancel each other
                        scn_reg[i] <= scn_reg[i];  // No change
                    end else if (inc_en && inc_index == i) begin
                        // Increment only (server is alive)
                        scn_reg[i] <= scn_reg[i] + 1'b1;
                    end else if (dec_en && dec_index == i) begin
                        // Decrement only (server is alive)
                        if (scn_reg[i] > 0) begin
                            scn_reg[i] <= scn_reg[i] - 1'b1;
                        end
                    end
                    // else: no change, keep current value
                end
            end
        end
    end

endmodule
