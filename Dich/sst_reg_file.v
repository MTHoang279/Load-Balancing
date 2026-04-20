
//module sst_reg_file #(
//    parameter NUM_SERVERS     = 16,
//    parameter SERVER_ID_WIDTH = 4,
//    parameter SCN_WIDTH       = 12
//)(
//    input  wire clk,
//    input  wire rst_n,

//    input  wire                        wr_en,
//    input  wire [SERVER_ID_WIDTH-1:0]  wr_addr,
//    input  wire [31:0]                 wr_ip,
//    input  wire                        wr_health,
//    input  wire [SCN_WIDTH-1:0]        wr_scn,

//    input  wire [SERVER_ID_WIDTH-1:0]  rd_addr,
//    output wire [31:0]                 rd_ip,
//    output wire [SCN_WIDTH-1:0]        rd_scn,

//    // CSLB broadcast read: returns ALL servers in one cycle (no address needed)
//    output wire [NUM_SERVERS*32-1:0]      cslb_rd_ip,
//    output wire [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,

//    output wire [NUM_SERVERS-1:0]      health_bitmap
//);

//    (* ram_style = "distributed" *) reg [31:0]          ip_ram    [0:NUM_SERVERS-1];
//    (* ram_style = "distributed" *) reg                 health_ram[0:NUM_SERVERS-1];
//    (* ram_style = "distributed" *) reg [SCN_WIDTH-1:0] scn_ram   [0:NUM_SERVERS-1];

//    integer i;

//    initial begin
//        for (i = 0; i < NUM_SERVERS; i = i + 1) begin
//            ip_ram[i]     = 32'h0A000064 + i;
//            health_ram[i] = 1'b1;
//            scn_ram[i]    = {SCN_WIDTH{1'b0}};
//        end
//    end

//    always @(posedge clk) begin
//        if (!rst_n) begin
//            ip_ram[0]     <= 32'h0A000064;
//            ip_ram[1]     <= 32'h0A000065;
//            ip_ram[2]     <= 32'h0A000066;
//            ip_ram[3]     <= 32'h0A000067;
//            health_ram[0] <= 1'b1;
//            health_ram[1] <= 1'b1;
//            health_ram[2] <= 1'b1;
//            health_ram[3] <= 1'b1;
//            scn_ram[0]    <= {SCN_WIDTH{1'b0}};
//            scn_ram[1]    <= {SCN_WIDTH{1'b0}};
//            scn_ram[2]    <= {SCN_WIDTH{1'b0}};
//            scn_ram[3]    <= {SCN_WIDTH{1'b0}};
//        end else if (wr_en) begin
//            ip_ram[wr_addr]     <= wr_ip;
//            health_ram[wr_addr] <= wr_health;
//            scn_ram[wr_addr]    <= wr_scn;
//        end
//    end

//    assign rd_ip  = ip_ram[rd_addr];
//    assign rd_scn = scn_ram[rd_addr];

//    // Pack all servers into flat buses: server i at [i*W +: W]
//    genvar gi;
//    generate
//        for (gi = 0; gi < NUM_SERVERS; gi = gi + 1) begin : GEN_CSLB_RD
//            assign cslb_rd_ip [gi*32       +: 32      ] = ip_ram [gi];
//            assign cslb_rd_scn[gi*SCN_WIDTH +: SCN_WIDTH] = scn_ram[gi];
//        end
//    endgenerate

//    assign health_bitmap[0] = health_ram[0];
//    assign health_bitmap[1] = health_ram[1];
//    assign health_bitmap[2] = health_ram[2];
//    assign health_bitmap[3] = health_ram[3];

//endmodule



module sst_reg_file #(
    parameter NUM_SERVERS     = 16,
    parameter SERVER_ID_WIDTH = 4,
    parameter SCN_WIDTH       = 12
)(
    input  wire clk,
    input  wire rst_n,

    input  wire                        wr_en,
    input  wire [SERVER_ID_WIDTH-1:0]  wr_addr,
    input  wire [31:0]                 wr_ip,
    input  wire                        wr_health,
    input  wire [SCN_WIDTH-1:0]        wr_scn,

    input  wire [NUM_SERVERS*32-1:0]   boot_ip_list,
    input  wire                        boot_ip_list_valid,

    input  wire [SERVER_ID_WIDTH-1:0]  rd_addr,
    output wire [31:0]                 rd_ip,
    output wire [SCN_WIDTH-1:0]        rd_scn,

    // CSLB broadcast read: returns ALL servers in one cycle (no address needed)
    output wire [NUM_SERVERS*32-1:0]      cslb_rd_ip,
    output wire [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,

    output wire [NUM_SERVERS-1:0]      health_bitmap
);

    (* ram_style = "distributed" *) reg [31:0]          ip_ram    [0:NUM_SERVERS-1];
    (* ram_style = "distributed" *) reg                 health_ram[0:NUM_SERVERS-1];
    (* ram_style = "distributed" *) reg [SCN_WIDTH-1:0] scn_ram   [0:NUM_SERVERS-1];
    reg boot_loaded;

    integer i;

    initial begin
        for (i = 0; i < NUM_SERVERS; i = i + 1) begin
//            ip_ram[i]     = 32'h0A000064 + i;
            ip_ram[i] = boot_ip_list[i*32 +:32];
//            ip_ram[i] = 32'h00000000;
            health_ram[i] = 1'b1;
            scn_ram[i]    = {SCN_WIDTH{1'b0}};
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_SERVERS; i = i + 1) begin
                ip_ram[i]     <= 32'd0;
                health_ram[i] <= 1'b1;
                scn_ram[i]    <= {SCN_WIDTH{1'b0}};
            end
            boot_loaded <= 1'b0;
        end else if (!boot_loaded && boot_ip_list_valid) begin
            for (i = 0; i < NUM_SERVERS; i = i + 1) begin
                ip_ram[i] <= boot_ip_list[i*32 +: 32];
            end
            boot_loaded <= 1'b1;
        end else if (wr_en) begin
            ip_ram[wr_addr]     <= wr_ip;
            health_ram[wr_addr] <= wr_health;
            scn_ram[wr_addr]    <= wr_scn;
        end
    end

    assign rd_ip  = ip_ram[rd_addr];
    assign rd_scn = scn_ram[rd_addr];

    // Pack all servers into flat buses: server i at [i*W +: W]
    genvar gi;
    generate
        for (gi = 0; gi < NUM_SERVERS; gi = gi + 1) begin : GEN_CSLB_RD
            assign cslb_rd_ip [gi*32       +: 32      ] = ip_ram [gi];
            assign cslb_rd_scn[gi*SCN_WIDTH +: SCN_WIDTH] = scn_ram[gi];
            assign health_bitmap[gi] = health_ram[gi];
        end
    endgenerate

endmodule


