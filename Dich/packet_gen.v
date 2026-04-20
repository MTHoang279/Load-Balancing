`timescale 1ns / 1ps

module packet_gen #(
    parameter BUS_WIDTH = 512,
    parameter NUM_USERS     = 10,
    parameter PKTS_PER_USER = 1000,
    parameter [47:0] SRC_MAC = 48'hE86A64E7E830,
    parameter [47:0] DST_MAC = 48'h080027FBDD65
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // Control
    input  wire                    start,      // async
    input  wire [15:0]             gap_cycles, // inter-packet gap

    // Packet config
    input  wire [15:0]             eth_type,
    input  wire [31:0]             base_src_ip,
    input  wire [31:0]             base_dst_ip,
    input  wire [15:0]             base_src_port,
    input  wire [15:0]             base_dst_port,
    input  wire [15:0]             payload_len,
    input  wire [7:0]              payload_byte,

    // AXI-Stream out
    output reg                     tvalid,
    output reg  [BUS_WIDTH-1:0]    tdata,
    output reg                     tlast,
    output reg  [BUS_WIDTH/8-1:0]  tkeep,
    input  wire                    tready,

    // Status
    output reg                     busy,
    output reg                     done_gen,
    output reg  [31:0]             pkt_count
);

    // ------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------
    localparam BYTES_PER_BEAT = BUS_WIDTH / 8;
    localparam ETH_HDR_LEN   = 14;
    localparam IP_HDR_LEN    = 20;
    localparam UDP_HDR_LEN   = 8;
    localparam TOTAL_HDR_LEN = ETH_HDR_LEN + IP_HDR_LEN + UDP_HDR_LEN;
    localparam HDR_REMAIN    = BYTES_PER_BEAT - TOTAL_HDR_LEN;

    // FSM
    localparam ST_IDLE    = 3'd0;
    localparam ST_HDR     = 3'd1;
    localparam ST_PAYLOAD = 3'd2;
    localparam ST_GAP     = 3'd3;

    reg [2:0] state;

    // ------------------------------------------------------------
    // Start synchronizer
    // ------------------------------------------------------------
    reg start_r1, start_r2;
    wire start_pulse;

    always @(posedge clk) begin
        start_r1 <= start;
        start_r2 <= start_r1;
    end

    assign start_pulse = start_r1 & ~start_r2;

    // ------------------------------------------------------------
    // Packet bookkeeping
    // ------------------------------------------------------------
    reg [15:0] remain_bytes;
    reg [15:0] gap_cnt;
    
    reg [31:0] user_idx;
    reg [31:0] pkt_idx;

    wire fire = tvalid && tready;

    // Flow variation for 100 users, each sends 100 packets
    wire [31:0] src_ip  = base_src_ip  + (user_idx*13);
    // diverse dst ip to ensure CHP hashing distributes well
    wire [31:0] dst_ip  = base_dst_ip  + (user_idx * 19); 
    wire [15:0] src_prt = base_src_port + user_idx*5;
    wire [15:0] dst_prt = base_dst_port+ user_idx *33;// + pkt_idx;
    
    // Dynamic MACs
    wire [47:0] dyn_src_mac = SRC_MAC + user_idx;
    wire [47:0] dyn_dst_mac = DST_MAC + (user_idx * 3);

    // Lengths
    wire [15:0] ip_total_len  = IP_HDR_LEN + UDP_HDR_LEN + payload_len;
    wire [15:0] udp_total_len = UDP_HDR_LEN + payload_len;

    // Headers (big endian)
    wire [ETH_HDR_LEN*8-1:0] eth_hdr = {dyn_dst_mac, dyn_src_mac, eth_type};
    wire [IP_HDR_LEN*8-1:0]  ip_hdr  = {
        8'h45, 8'h00, ip_total_len,
        16'h0000, 16'h4000,
        8'h40, 8'h11,
        16'h0000,
        src_ip, dst_ip
    };
    wire [UDP_HDR_LEN*8-1:0] udp_hdr = {
        src_prt, dst_prt, udp_total_len, 16'h0000
    };

    wire [TOTAL_HDR_LEN*8-1:0] full_hdr = {eth_hdr, ip_hdr, udp_hdr};

    // ------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            tvalid       <= 0;
            tlast        <= 0;
            tkeep        <= 0;
            tdata        <= 0;
            remain_bytes <= 0;
            gap_cnt      <= 0;
            pkt_count    <= 0;
            user_idx     <= 0;
            pkt_idx      <= 0;
            busy         <= 0;
            done_gen     <= 0;
        end else begin
            done_gen <= 1'b0;

            case (state)
            // ------------------------------------------------
            ST_IDLE: begin
                tvalid <= 0;
                busy   <= 0;
                if (start_pulse) begin
                    state <= ST_HDR;
                    busy  <= 1'b1;
                end
            end

            // ------------------------------------------------
            ST_HDR: begin
                if (!tvalid || fire) begin
                    tvalid <= 1'b1;
                    tdata  <= {full_hdr, {HDR_REMAIN{payload_byte}}};

                    if (payload_len <= HDR_REMAIN) begin
                        tlast <= 1'b1;
                        tkeep <= ~((1'b1 << (BYTES_PER_BEAT -
                                   (TOTAL_HDR_LEN + payload_len))) - 1'b1);
                        remain_bytes <= 0;
                        state <= ST_GAP;
                    end else begin
                        tlast <= 1'b0;
                        tkeep <= {BYTES_PER_BEAT{1'b1}};
                        remain_bytes <= payload_len - HDR_REMAIN;
                        state <= ST_PAYLOAD;
                    end
                end
            end

            // ------------------------------------------------
            ST_PAYLOAD: begin
                if (fire) begin
                    tdata <= {pkt_count, {BYTES_PER_BEAT-4{payload_byte}}};

                    if (remain_bytes <= BYTES_PER_BEAT) begin
                        tlast <= 1'b1;
                        tkeep <= ~((1'b1 << (BYTES_PER_BEAT - remain_bytes)) - 1'b1);
                        remain_bytes <= 0;
                        state <= ST_GAP;
                    end else begin
                        tlast <= 1'b0;
                        tkeep <= {BYTES_PER_BEAT{1'b1}};
                        remain_bytes <= remain_bytes - BYTES_PER_BEAT;
                    end
                end
            end

            // ------------------------------------------------
            ST_GAP: begin
                if (fire) begin
                    // Packet just finished sending
                    tvalid <= 0;
                    tlast  <= 0;
                    
                    pkt_count <= pkt_count + 1;
                    
                    // Increment logic for 100 users x 100 packets
                    if (pkt_idx == PKTS_PER_USER - 1) begin
                        pkt_idx <= 0;
                        if (user_idx == NUM_USERS - 1) begin
                            user_idx <= 0;
                        end else begin
                            user_idx <= user_idx + 1;
                        end
                    end else begin
                        pkt_idx <= pkt_idx + 1;
                    end
                    
                    done_gen  <= 1'b1;
                    
                    // Check if we've just sent the last packet (pkt_count will be 10000)
                    if (pkt_count == (NUM_USERS * PKTS_PER_USER - 1)) begin
                        // This is the last packet, don't set gap, go directly to IDLE
                        gap_cnt <= 0;
                        state <= ST_IDLE;
                    end else begin
                        gap_cnt <= gap_cycles;
                        state <= ST_GAP;
                    end
                    
                end else if (gap_cnt != 0) begin
                    // Decrement gap counter
                    gap_cnt <= gap_cnt - 1;
                    
                end else if (gap_cnt == 0 && state == ST_GAP) begin
                    // Gap finished, send next packet
                    state <= ST_HDR;
                end
            end

            endcase
        end
    end

endmodule
