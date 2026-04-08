`timescale 1ns / 1ps

module hash_ring #(
    parameter NUM_SERVERS = 16,
    parameter VNODES_PER  = 16,
    parameter HASH_WIDTH  = 32
)(
    input  wire clk,
    input  wire rst_n,

    output reg  done,

    /* Flattened ring table */
    output wire [HASH_WIDTH*NUM_SERVERS*VNODES_PER-1:0] ring_hash,
    output wire [$clog2(NUM_SERVERS)*NUM_SERVERS*VNODES_PER-1:0] ring_sid
);

    /* =========================================================
     * Parameters
     * ========================================================= */

    localparam TOTAL_VNODES = NUM_SERVERS * VNODES_PER;
    localparam SID_WIDTH    = $clog2(NUM_SERVERS);

    /* =========================================================
     * CRC32 function
     * polynomial = 0x04C11DB7
     * ========================================================= */

    function [31:0] crc32;
        input [31:0] data;

        reg [31:0] crc;
        integer i;

        begin

            crc = 32'hFFFFFFFF;

            for(i = 0; i < 32; i = i + 1) begin
                if ((crc[31] ^ data[i]) == 1'b1)
                    crc = (crc << 1) ^ 32'h04C11DB7;
                else
                    crc = (crc << 1);
            end

            crc32 = crc;

        end
    endfunction


    /* =========================================================
     * Virtual node hash
     * ========================================================= */

    function [HASH_WIDTH-1:0] vnode_hash;
        input integer sid;
        input integer vid;

        reg [31:0] seed;

        begin

            /* combine sid and vid */
            seed = {sid[15:0], vid[15:0]};

            vnode_hash = crc32(seed);

        end
    endfunction


    /* =========================================================
     * Generate ring table
     * ========================================================= */

    genvar s,v;

    generate
        for (s = 0; s < NUM_SERVERS; s = s + 1) begin : SERVER_LOOP
            for (v = 0; v < VNODES_PER; v = v + 1) begin : VNODE_LOOP

                localparam integer IDX = s*VNODES_PER + v;

                assign ring_hash[IDX*HASH_WIDTH +: HASH_WIDTH]
                       = vnode_hash(s,v);

                assign ring_sid[IDX*SID_WIDTH +: SID_WIDTH]
                       = s;

            end
        end
    endgenerate


    /* =========================================================
     * Done flag
     * ========================================================= */

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            done <= 1'b0;
        else
            done <= 1'b1;
    end

endmodule