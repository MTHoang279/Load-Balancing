module heartbeat_generator #(
    parameter SRC_MAC      = 48'h00_11_22_33_44_55,
    parameter SRC_IP       = 32'h0A_00_00_0A,
    parameter DST_MAC      = 48'hFF_FF_FF_FF_FF_FF,  // Broadcast MAC
    parameter DST_IP       = 32'h0A_00_00_FF,        // Broadcast IP
    parameter SRC_PORT     = 16'd9999,
    parameter DST_PORT     = 16'd8888,
    parameter HB_TYPE      = 16'h0001
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        trigger,

    output reg         pkt_valid,
    output wire [511:0] pkt_data,
    input  wire        pkt_ready,
    
    // Timestamp input (optional)
    input  wire [63:0] timestamp
);

    // =========================================================================
    // Packet Structure (512 bits = 64 bytes)
    // =========================================================================
    // [511:464] - MAC Destination (48 bits)
    // [463:416] - MAC Source (48 bits)
    // [415:400] - Ethertype (16 bits)
    // [399:392] - IP Version & IHL (8 bits)
    // [391:384] - DSCP & ECN (8 bits)
    // [383:368] - IP Total Length (16 bits)
    // [367:352] - Identification (16 bits)
    // [351:336] - Flags + Fragment Offset (16 bits)
    // [335:328] - Time to Live (8 bits)
    // [327:320] - Protocol (8 bits)
    // [319:304] - IP Header Checksum (16 bits)
    // [303:272] - IP Source (32 bits)
    // [271:240] - IP Destination (32 bits)
    // [239:224] - UDP Source Port (16 bits)
    // [223:208] - UDP Destination Port (16 bits)
    // [207:192] - UDP Length (16 bits)
    // [191:176] - UDP Checksum (16 bits)
    // [175:0]   - Data (176 bits = 22 bytes)

    localparam ETHERTYPE_IPV4    = 16'h0800;
    localparam IP_VERSION_IHL    = 8'h45;       // IPv4, 20-byte header
    localparam IP_DSCP_ECN       = 8'h00;       // Default DSCP/ECN
    localparam IP_TOTAL_LEN      = 16'd42;      // IP header(20) + UDP header(8) + Data(14)
    localparam IP_FLAGS_FRAG     = 16'h4000;    // Don't fragment, offset 0
    localparam IP_TTL            = 8'h40;       // TTL = 64
    localparam IP_PROTOCOL_UDP   = 8'h11;       // UDP protocol
    localparam UDP_LENGTH        = 16'd22;      // UDP header(8) + Data(14)
    
    // Heartbeat data payload: Type(2) + Timestamp(8) + Sequence(4) = 14 bytes
    localparam HB_PAYLOAD_SIZE   = 14;
    
    reg [15:0] seq_number;           // Sequence number (16-bit ??, gi?m t? 32)
    reg [15:0] ip_id;                // IP identification field
    reg [31:0] sum;                  // Temporary for checksum calculation
    reg [15:0] ip_checksum;          // Calculated IP checksum
    reg [511:0] pkt_data_reg;        // Packet data register
    reg [31:0] timestamp_snapshot;   // Captured timestamp when trigger arrives
    reg trigger_pending;             // Flag for trigger received while busy

    function [15:0] calc_ip_checksum;
        input dummy;
        reg [31:0] sum;
        begin
            sum = 0;
            
            // Add all 16-bit words in IP header (except checksum field)
            sum = sum + {IP_VERSION_IHL, IP_DSCP_ECN};     // Bytes 0-1
            sum = sum + IP_TOTAL_LEN;                      // Bytes 2-3
            sum = sum + ip_id;                             // Bytes 4-5 (using current ID)
            sum = sum + IP_FLAGS_FRAG;                     // Bytes 6-7
            sum = sum + {IP_TTL, IP_PROTOCOL_UDP};         // Bytes 8-9
            // Skip bytes 10-11 (checksum field itself)
            sum = sum + SRC_IP[31:16];                     // Bytes 12-13
            sum = sum + SRC_IP[15:0];                      // Bytes 14-15
            sum = sum + DST_IP[31:16];                     // Bytes 16-17
            sum = sum + DST_IP[15:0];                      // Bytes 18-19
            
            // Fold 32-bit sum to 16 bits (add carry)
            sum = (sum[15:0] + sum[31:16]);
            sum = (sum[15:0] + sum[31:16]);  // Second fold in case of carry from first
            
            // One's complement
            calc_ip_checksum = ~sum[15:0];
        end
    endfunction
    
    always @(*) begin
        pkt_data_reg = 512'h0;

        sum = 0;
        sum = sum + {IP_VERSION_IHL, IP_DSCP_ECN};
        sum = sum + IP_TOTAL_LEN;
        sum = sum + ip_id;
        sum = sum + IP_FLAGS_FRAG;
        sum = sum + {IP_TTL, IP_PROTOCOL_UDP};
        sum = sum + SRC_IP[31:16];
        sum = sum + SRC_IP[15:0];
        sum = sum + DST_IP[31:16];
        sum = sum + DST_IP[15:0];
        sum = (sum[15:0] + sum[31:16]);
        sum = (sum[15:0] + sum[31:16]);
        ip_checksum = ~sum[15:0];

        if (pkt_valid) begin
            pkt_data_reg[511:464] = DST_MAC;
            pkt_data_reg[463:416] = SRC_MAC;
            pkt_data_reg[415:400] = ETHERTYPE_IPV4;
            pkt_data_reg[399:392] = IP_VERSION_IHL;
            pkt_data_reg[391:384] = IP_DSCP_ECN;
            pkt_data_reg[383:368] = IP_TOTAL_LEN;
            pkt_data_reg[367:352] = ip_id;
            pkt_data_reg[351:336] = IP_FLAGS_FRAG;
            pkt_data_reg[335:328] = IP_TTL;
            pkt_data_reg[327:320] = IP_PROTOCOL_UDP;
            pkt_data_reg[319:304] = ip_checksum;
            pkt_data_reg[303:272] = SRC_IP;
            pkt_data_reg[271:240] = DST_IP;
            pkt_data_reg[239:224] = SRC_PORT;
            pkt_data_reg[223:208] = DST_PORT;
            pkt_data_reg[207:192] = UDP_LENGTH;
            pkt_data_reg[191:176] = 16'h0000;
            pkt_data_reg[175:160] = HB_TYPE;
            pkt_data_reg[159:144] = seq_number;
            pkt_data_reg[143:112] = timestamp_snapshot;
            pkt_data_reg[111:0]   = 112'h0;
        end
    end
    
    assign pkt_data = pkt_data_reg;

    initial begin
        seq_number = 16'h0;
        ip_id = 16'h0;
        pkt_valid = 1'b0;
        sum = 32'h0;
        ip_checksum = 16'h0;
        pkt_data_reg = 512'h0;
        timestamp_snapshot = 32'h0;
        trigger_pending = 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_number <= 16'h0;
            ip_id <= 16'h0;
            pkt_valid <= 1'b0;
            trigger_pending <= 1'b0;
        end
        else begin
            if (trigger && pkt_valid) begin
                trigger_pending <= 1'b1;
            end

            if (!pkt_valid) begin
                if (trigger || trigger_pending) begin
                    timestamp_snapshot <= timestamp[31:0];
                    ip_id <= ip_id + 1;
                    trigger_pending <= 1'b0;
                    pkt_valid <= 1'b1;
                end
            end
            else begin
                if (pkt_ready) begin
                    pkt_valid <= 1'b0;
                    seq_number <= seq_number + 1;
                end
            end
        end
    end

endmodule
