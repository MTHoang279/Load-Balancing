module shm_arbiter (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        tx_cslb_valid,
    input  wire [511:0] tx_cslb_data,
    input  wire [63:0] tx_cslb_keep,
    input  wire        tx_cslb_last,
    output reg         tx_cslb_ready,

    input  wire        hb_pkt_valid,
    input  wire [511:0] hb_pkt_data,
    output reg         hb_pkt_ready,

    output reg         tx_user_valid,
    output reg  [511:0] tx_user_data,
    output reg  [63:0] tx_user_keep,
    output reg         tx_user_last,
    input  wire        tx_user_ready
);

    localparam IDLE = 2'b00;
    localparam USER = 2'b01;
    localparam HB   = 2'b10;
    localparam GAP  = 2'b11;

    reg [1:0] state;
    reg hb_pending;
    reg gap_to_hb;

    wire user_hs;
    wire user_last_hs;
    wire hb_hs;

    assign user_hs      = tx_cslb_valid && tx_cslb_ready;
    assign user_last_hs = user_hs && tx_cslb_last;
    assign hb_hs        = hb_pkt_valid && hb_pkt_ready;

    always @(*) begin
        tx_user_valid = 1'b0;
        tx_user_data  = 512'h0;
        tx_user_keep  = 64'h0;
        tx_user_last  = 1'b0;
        tx_cslb_ready = 1'b0;
        hb_pkt_ready  = 1'b0;

        case (state)
            IDLE: begin
                if (hb_pkt_valid) begin
                    tx_user_valid = hb_pkt_valid;
                    tx_user_data  = hb_pkt_data;
                    tx_user_keep  = 64'hFFFF_FFFF_FFFF_FFFF;
                    tx_user_last  = hb_pkt_valid && tx_user_ready;
                    hb_pkt_ready  = tx_user_ready;
                end else if (tx_cslb_valid) begin
                    tx_user_valid = tx_cslb_valid;
                    tx_user_data  = tx_cslb_data;
                    tx_user_keep  = tx_cslb_keep;
                    tx_user_last  = tx_cslb_last && tx_cslb_valid && tx_user_ready;
                    tx_cslb_ready = tx_user_ready;
                end
            end
            USER: begin
                tx_user_valid = tx_cslb_valid;
                tx_user_data  = tx_cslb_data;
                tx_user_keep  = tx_cslb_keep;
                tx_user_last  = tx_cslb_last && tx_cslb_valid && tx_user_ready;
                tx_cslb_ready = tx_user_ready;
            end
            HB: begin
                tx_user_valid = hb_pkt_valid;
                tx_user_data  = hb_pkt_data;
                tx_user_keep  = 64'hFFFF_FFFF_FFFF_FFFF;
                tx_user_last  = hb_pkt_valid && tx_user_ready;
                hb_pkt_ready  = tx_user_ready;
            end
            GAP: begin
                // One-cycle bubble to separate packet boundaries when source changes.
                tx_user_valid = 1'b0;
                tx_user_data  = 512'h0;
                tx_user_keep  = 64'h0;
                tx_user_last  = 1'b0;
                tx_cslb_ready = 1'b0;
                hb_pkt_ready  = 1'b0;
            end
            default: tx_user_valid = 1'b0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            hb_pending <= 1'b0;
            gap_to_hb  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (hb_pkt_valid) begin
                        if (hb_hs) begin
                            // HB packet completed in this cycle: always insert one bubble cycle.
                            gap_to_hb <= 1'b0;
                            state     <= GAP;
                        end else begin
                            state <= HB;
                        end
                    end else if (tx_cslb_valid) begin
                        // If USER single-beat packet completes in IDLE, still force GAP.
                        if (user_last_hs) begin
                            gap_to_hb <= 1'b0;
                            state     <= GAP;
                        end else begin
                            state <= USER;
                        end
                    end
                end
                USER: begin
                    if (hb_pkt_valid) hb_pending <= 1'b1;
                    if (user_last_hs) begin
                        // Clear sticky pending flag on packet boundary.
                        hb_pending <= 1'b0;
                        if (hb_pending || hb_pkt_valid) begin
                            gap_to_hb  <= 1'b1;
                        end else begin
                            gap_to_hb <= 1'b0;
                        end
                        // USER packet completed: always insert one bubble cycle.
                        state <= GAP;
                    end
                end
                HB: begin
                    if (hb_hs) begin
                        // HB packet completed: always insert one bubble cycle.
                        gap_to_hb <= 1'b0;
                        state     <= GAP;
                    end else if (!hb_pkt_valid) begin
                        state <= tx_cslb_valid ? USER : IDLE;
                    end
                end
                GAP: begin
                    // After one bubble cycle, pick next source based on availability.
                    if (gap_to_hb && hb_pkt_valid) begin
                        state <= HB;
                    end else if (tx_cslb_valid) begin
                        state <= USER;
                    end else if (hb_pkt_valid) begin
                        state <= HB;
                    end else begin
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
