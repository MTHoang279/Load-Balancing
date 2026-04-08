module heartbeat_generator #(
    parameter SRC_MAC      = 48'h00_11_22_33_44_55,
    parameter SRC_IP       = 32'h0A_00_00_0A,
    parameter DST_MAC      = 48'hFF_FF_FF_FF_FF_FF,
    parameter DST_IP       = 32'h0A_00_00_FF,
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
    input  wire [63:0] timestamp
);

    localparam ETHERTYPE_IPV4  = 16'h0800;
    localparam IP_VERSION_IHL  = 8'h45;
    localparam IP_DSCP_ECN     = 8'h00;
    localparam IP_TOTAL_LEN    = 16'd42;
    localparam IP_FLAGS_FRAG   = 16'h4000;
    localparam IP_TTL          = 8'h40;
    localparam IP_PROTOCOL_UDP = 8'h11;
    localparam UDP_LENGTH      = 16'd22;

    reg [15:0] seq_number;
    reg [15:0] ip_id;
    reg [511:0] pkt_data_reg;
    reg [31:0] timestamp_snapshot;
    reg trigger_pending;

    function [15:0] calc_ip_checksum;
        input [15:0] ip_id_in;
        reg [31:0] sum_v;
        begin
            sum_v = 32'd0;
            sum_v = sum_v + {IP_VERSION_IHL, IP_DSCP_ECN};
            sum_v = sum_v + IP_TOTAL_LEN;
            sum_v = sum_v + ip_id_in;
            sum_v = sum_v + IP_FLAGS_FRAG;
            sum_v = sum_v + {IP_TTL, IP_PROTOCOL_UDP};
            sum_v = sum_v + SRC_IP[31:16];
            sum_v = sum_v + SRC_IP[15:0];
            sum_v = sum_v + DST_IP[31:16];
            sum_v = sum_v + DST_IP[15:0];
            sum_v = (sum_v[15:0] + sum_v[31:16]);
            sum_v = (sum_v[15:0] + sum_v[31:16]);
            calc_ip_checksum = ~sum_v[15:0];
        end
    endfunction

    assign pkt_data = pkt_data_reg;

    initial begin
        seq_number       = 16'h0;
        ip_id            = 16'h0;
        pkt_valid        = 1'b0;
        pkt_data_reg     = 512'h0;
        timestamp_snapshot = 32'h0;
        trigger_pending  = 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_number      <= 16'h0;
            ip_id           <= 16'h0;
            pkt_valid       <= 1'b0;
            pkt_data_reg    <= 512'h0;
            timestamp_snapshot <= 32'h0;
            trigger_pending <= 1'b0;
        end else begin
            if (trigger && pkt_valid)
                trigger_pending <= 1'b1;

            if (!pkt_valid) begin
                if (trigger || trigger_pending) begin
                    timestamp_snapshot <= timestamp[31:0];
                    ip_id              <= ip_id + 1'b1;

                    pkt_data_reg[511:464] <= DST_MAC;
                    pkt_data_reg[463:416] <= SRC_MAC;
                    pkt_data_reg[415:400] <= ETHERTYPE_IPV4;
                    pkt_data_reg[399:392] <= IP_VERSION_IHL;
                    pkt_data_reg[391:384] <= IP_DSCP_ECN;
                    pkt_data_reg[383:368] <= IP_TOTAL_LEN;
                    pkt_data_reg[367:352] <= ip_id + 1'b1;
                    pkt_data_reg[351:336] <= IP_FLAGS_FRAG;
                    pkt_data_reg[335:328] <= IP_TTL;
                    pkt_data_reg[327:320] <= IP_PROTOCOL_UDP;
                    pkt_data_reg[319:304] <= calc_ip_checksum(ip_id + 1'b1);
                    pkt_data_reg[303:272] <= SRC_IP;
                    pkt_data_reg[271:240] <= DST_IP;
                    pkt_data_reg[239:224] <= SRC_PORT;
                    pkt_data_reg[223:208] <= DST_PORT;
                    pkt_data_reg[207:192] <= UDP_LENGTH;
                    pkt_data_reg[191:176] <= 16'h0000;
                    pkt_data_reg[175:160] <= HB_TYPE;
                    pkt_data_reg[159:144] <= seq_number;
                    pkt_data_reg[143:112] <= timestamp[31:0];
                    pkt_data_reg[111:0]   <= 112'h0;

                    trigger_pending    <= 1'b0;
                    pkt_valid          <= 1'b1;
                end
            end else begin
                if (pkt_ready) begin
                    pkt_valid  <= 1'b0;
                    seq_number <= seq_number + 1;
                end
            end
        end
    end

endmodule
