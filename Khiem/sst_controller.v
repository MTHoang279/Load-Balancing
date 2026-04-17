`timescale 1ns / 1ps

module sst_controller #(
    parameter N_SERVERS   = 16, // Đã đồng bộ lên 16 server
    parameter SERVER_ID_W = $clog2(N_SERVERS),
    parameter SCN_W       = 16  // Độ rộng đếm SCN an toàn tuyệt đối
)(
    input  wire clk,
    input  wire rst_n,

    // =========================================================================
    // 1. SHM UPDATE
    // =========================================================================
    input  wire [1:0]               shm_update_opcode, // 00: NOP, 01: Alive, 10: Die
    input  wire [SERVER_ID_W-1:0]   shm_update_idx,
    input  wire [31:0]              shm_update_ip,

    // =========================================================================
    // 2. CSLB READ
    // =========================================================================
    output reg  [N_SERVERS*32-1:0]    cslb_ip_list_o,
    output reg  [N_SERVERS*SCN_W-1:0] cslb_scn_list_o, 
    output reg  [N_SERVERS-1:0]       cslb_status_list_o,

    // =========================================================================
    // 3. CSLB WRITE (TX/RX increment)
    // =========================================================================
    input  wire [SERVER_ID_W-1:0]   cslb_scn_idx_tx,
    input  wire                     cslb_scn_opcode_tx,

    input  wire [SERVER_ID_W-1:0]   cslb_scn_idx_rx,
    input  wire                     cslb_scn_opcode_rx
);

    // -------------------------------------------------------------------------
    // STORAGE
    // -------------------------------------------------------------------------
    reg [31:0]      ip_array     [0:N_SERVERS-1];
    reg [SCN_W-1:0] scn_tx_array [0:N_SERVERS-1]; 
    reg [SCN_W-1:0] scn_rx_array [0:N_SERVERS-1]; 
    reg             status_array [0:N_SERVERS-1];

    reg             scn_ge    [0:N_SERVERS-1];   
    reg [SCN_W-1:0] scn_tx_d1 [0:N_SERVERS-1]; 
    reg [SCN_W-1:0] scn_rx_d1 [0:N_SERVERS-1]; 
    reg [SCN_W-1:0] scn_calc  [0:N_SERVERS-1]; 

    integer i, j, k, m;

    // -------------------------------------------------------------------------
    // WRITE LOGIC: XỬ LÝ SONG SONG (Chống nuốt xung)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < N_SERVERS; i = i + 1) begin
                ip_array[i]     <= 32'd0;
                scn_tx_array[i] <= {SCN_W{1'b0}}; 
                scn_rx_array[i] <= {SCN_W{1'b0}}; 
                status_array[i] <= 1'b0;
            end
        end else begin
            for (i = 0; i < N_SERVERS; i = i + 1) begin

                // LUỒNG 1: Ưu tiên tuyệt đối cho lệnh DIE (Reset SCN)
                if ((shm_update_opcode == 2'b10) && (shm_update_idx == i[SERVER_ID_W-1:0])) begin
                    status_array[i] <= 1'b0;
                    scn_tx_array[i] <= {SCN_W{1'b0}};
                    scn_rx_array[i] <= {SCN_W{1'b0}};
                end 
                else begin
                    // LUỒNG 2: Cập nhật trạng thái ALIVE
                    if ((shm_update_opcode == 2'b01) && (shm_update_idx == i[SERVER_ID_W-1:0])) begin
                        ip_array[i]     <= shm_update_ip;
                        status_array[i] <= 1'b1;
                    end
                    
                    // LUỒNG 3: Cộng dồn SCN (Chạy độc lập, không bị else-if cản trở)
                    if (cslb_scn_opcode_tx && (cslb_scn_idx_tx == i[SERVER_ID_W-1:0]))
                    (* use_dsp = "yes" *)
                        scn_tx_array[i] <= scn_tx_array[i] + {{SCN_W-1{1'b0}}, 1'b1};

                    if (cslb_scn_opcode_rx && (cslb_scn_idx_rx == i[SERVER_ID_W-1:0]))
                    (* use_dsp = "yes" *)
                        scn_rx_array[i] <= scn_rx_array[i] + {{SCN_W-1{1'b0}}, 1'b1};
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // PIPELINE STAGES
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            for (j = 0; j < N_SERVERS; j = j + 1) begin
                scn_ge[j]    <= 1'b0;
                scn_tx_d1[j] <= {SCN_W{1'b0}}; 
                scn_rx_d1[j] <= {SCN_W{1'b0}}; 
            end
        end else begin
            for (j = 0; j < N_SERVERS; j = j + 1) begin
                scn_ge[j]    <= (scn_tx_array[j] >= scn_rx_array[j]);
                scn_tx_d1[j] <= scn_tx_array[j]; 
                scn_rx_d1[j] <= scn_rx_array[j]; 
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            for (k = 0; k < N_SERVERS; k = k + 1) scn_calc[k] <= {SCN_W{1'b0}};
        end else begin
            for (k = 0; k < N_SERVERS; k = k + 1) begin
                if (scn_ge[k]) (* use_dsp = "yes" *)scn_calc[k] <= scn_tx_d1[k] - scn_rx_d1[k];
                else           scn_calc[k] <= {SCN_W{1'b0}};
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cslb_scn_list_o    <= {(N_SERVERS*SCN_W){1'b0}};
            cslb_ip_list_o     <= {(N_SERVERS*32){1'b0}};
            cslb_status_list_o <= {N_SERVERS{1'b0}};
        end else begin
            for (m = 0; m < N_SERVERS; m = m + 1) begin
                cslb_scn_list_o[m*SCN_W +: SCN_W] <= scn_calc[m];
                cslb_ip_list_o[m*32 +: 32]        <= ip_array[m];
                cslb_status_list_o[m]             <= status_array[m];
            end
        end
    end

endmodule