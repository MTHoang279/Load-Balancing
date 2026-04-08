module sst_reg_file #(
    parameter NUM_SERVERS     = 4,
    parameter SERVER_ID_WIDTH = 2,
    parameter SCN_WIDTH       = 8
)(
    input  wire clk,
    input  wire rst_n,

    // Controller write
    input  wire                        wr_en,
    input  wire [SERVER_ID_WIDTH-1:0]  wr_addr,
    input  wire [31:0]                 wr_ip,
    input  wire                        wr_health,
    input  wire [SCN_WIDTH-1:0]        wr_scn,

    // Heartbeat write (NEW)
    input  wire                        hb_wr_en,
    input  wire [SERVER_ID_WIDTH-1:0]  hb_wr_addr,
    input  wire [31:0]                 hb_wr_ip,

    // Read
    input  wire [SERVER_ID_WIDTH-1:0]  rd_addr,
    output wire [31:0]                 rd_ip,
    output wire [SCN_WIDTH-1:0]        rd_scn,

    // CSLB broadcast read
    output wire [NUM_SERVERS*32-1:0]      cslb_rd_ip,
    output wire [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,

    output wire [NUM_SERVERS-1:0]      health_bitmap
);

    (* ram_style = "distributed" *) reg [31:0]          ip_ram    [0:NUM_SERVERS-1];
    (* ram_style = "distributed" *) reg                 health_ram[0:NUM_SERVERS-1];
    (* ram_style = "distributed" *) reg [SCN_WIDTH-1:0] scn_ram   [0:NUM_SERVERS-1];

    integer i;

//////////////////////////////////////////////////////////
// WRITE LOGIC (UPDATED)
//////////////////////////////////////////////////////////

    always @(posedge clk) begin
        if (!rst_n) begin
            // Initialize default server IP addresses to 10.0.0.100 + idx
            // and health=1, SCN=0, scalable for NUM_SERVERS.
            for (i = 0; i < NUM_SERVERS; i = i + 1) begin
                ip_ram[i]     <= 32'h0A000064 + i;  // 10.0.0.100 + i
                health_ram[i] <= 1'b1;
                scn_ram[i]    <= {SCN_WIDTH{1'b0}};
            end
        end 
        else begin

            // 1. Controller write (SCN + health + IP)
            if (wr_en) begin
                ip_ram[wr_addr]     <= wr_ip;
                health_ram[wr_addr] <= wr_health;
                scn_ram[wr_addr]    <= wr_scn;
            end

            // 2. Heartbeat write (IP only, overwrite if same addr)
            if (hb_wr_en) begin
                ip_ram[hb_wr_addr] <= hb_wr_ip;
            end

        end
    end

//////////////////////////////////////////////////////////
// READ
//////////////////////////////////////////////////////////

    assign rd_ip  = ip_ram[rd_addr];
    assign rd_scn = scn_ram[rd_addr];

//////////////////////////////////////////////////////////
// CSLB BROADCAST
//////////////////////////////////////////////////////////

    genvar gi;
    generate
        for (gi = 0; gi < NUM_SERVERS; gi = gi + 1) begin : GEN_CSLB_RD
            assign cslb_rd_ip [gi*32        +: 32       ] = ip_ram [gi];
            assign cslb_rd_scn[gi*SCN_WIDTH +: SCN_WIDTH] = scn_ram[gi];
        end
    endgenerate

//////////////////////////////////////////////////////////
// HEALTH BITMAP
//////////////////////////////////////////////////////////

    generate
        for (gi = 0; gi < NUM_SERVERS; gi = gi + 1) begin : GEN_HEALTH
            assign health_bitmap[gi] = health_ram[gi];
        end
    endgenerate

endmodule