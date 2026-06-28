`timescale 1ns / 1ps

module packet_filter #(
    parameter BUS_WIDTH = 512
)(
    input  wire                     clk,
    input  wire                     rst_n,

    /* ------------ AXI-Stream IN (from Generator) ------------ */
    input  wire [BUS_WIDTH-1:0]     s_tdata,
    input  wire                     s_tvalid,
    input  wire                     s_tlast,
    input  wire [BUS_WIDTH/8-1:0]   s_tkeep,
    output wire                     s_tready,

    /* ------------ AXI-Stream OUT (out for message FIFO) ----------- */
    output wire [BUS_WIDTH-1:0]     m_tdata,
    output wire                     m_tvalid,
    output wire                     m_tlast,
    output wire [BUS_WIDTH/8-1:0]   m_tkeep,
    input  wire                     m_tready,

    /* ------------ keydata ----------------- */
    output reg                      meta_tvalid,
    output reg  [31:0]              src_ip,
    output reg  [31:0]              dst_ip,
    output reg  [15:0]              src_port,
    output reg  [15:0]              dst_port,
    output reg  [7:0]               protocol,
    output reg                      done_fil
);

    localparam [15:0] ETH_TYPE_IPV4 = 16'h0800;
    localparam [7:0]  IP_PROTO_UDP  = 8'h11;

    localparam ST_IDLE = 2'd0, ST_PASS = 2'd1, ST_DROP = 2'd2;
    reg [1:0] state;

    reg [BUS_WIDTH-1:0]   buf_data;
    reg [BUS_WIDTH/8-1:0] buf_keep;
    reg                   buf_last;
    reg                   buf_valid;

    assign s_tready = (state == ST_DROP) || (!buf_valid) || (m_tready);
    
    wire in_fire  = s_tvalid && s_tready;
    wire out_fire = buf_valid && m_tready;

    assign m_tdata  = buf_data;
    assign m_tkeep  = buf_keep;
    assign m_tlast  = buf_last;
    assign m_tvalid = buf_valid;

    /* ---------------- MAIN LOGIC -------------------- */
    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            buf_valid   <= 1'b0;
            meta_tvalid <= 1'b0;
            done_fil    <= 1'b0;
        end else begin
            // Delete pulse signal each period
            meta_tvalid <= 1'b0;
            done_fil    <= 1'b0;

            // When data get out, it notify buf is emty
            if (out_fire) begin
                buf_valid <= 1'b0;
            end

            // Process input
            if (in_fire) begin
                case (state)
                    ST_IDLE: begin

                        if (s_tdata[415:400] == ETH_TYPE_IPV4 &&
                            s_tdata[327:320] == IP_PROTO_UDP) begin
//                        if (s_tdata[111:96] == ETH_TYPE_IPV4 &&
//                            s_tdata[191:184] == IP_PROTO_UDP) begin

                            state <= s_tlast ? ST_IDLE : ST_PASS;

                            // Assign Metadata */
                            protocol <= s_tdata[327:320];
                            src_ip   <= s_tdata[303:272];
                            dst_ip   <= s_tdata[271:240];
                            src_port <= s_tdata[239:224];
                            dst_port <= s_tdata[223:208]; 
                            
                            // Assign Metadata
//                            src_ip   <= s_tdata[239:208];
//                            dst_ip   <= s_tdata[271:240];
//                            src_port <= s_tdata[287:272];
//                            dst_port <= s_tdata[303:288];
//                            protocol <= s_tdata[191:184];
                            meta_tvalid <= 1'b1;

                            buf_data  <= s_tdata;
                            buf_keep  <= s_tkeep;
                            buf_last  <= s_tlast;
                            buf_valid <= 1'b1;
                        end else begin
                            state <= s_tlast ? ST_IDLE : ST_DROP;
                        end
                        
                        if (s_tlast) done_fil <= 1'b1;
                    end

                    ST_PASS: begin
                        buf_data  <= s_tdata;
                        buf_keep  <= s_tkeep;
                        buf_last  <= s_tlast;
                        buf_valid <= 1'b1;
                        if (s_tlast) begin
                            state <= ST_IDLE;
                            done_fil <= 1'b1;
                        end
                    end

                    ST_DROP: begin
                        if (s_tlast) begin
                            state <= ST_IDLE;
                            done_fil <= 1'b1;
                        end
                    end
                endcase
            end
        end
    end
endmodule