`timescale 1ns / 1ps

`define MD_MARKER 8'h4d
`define NULL 0

module net2axis_master #(
    parameter INPUTFILE   = "",
    parameter START_EN    = 0,
    parameter TDATA_WIDTH = 512
)(
    input  wire                         ACLK,
    input  wire                         ARESETN,
    input  wire                         START,

    output wire                         DONE,

    output reg                          M_AXIS_TVALID,
    output reg  [TDATA_WIDTH-1:0]       M_AXIS_TDATA,
    output reg  [(TDATA_WIDTH/8)-1:0]   M_AXIS_TKEEP,
    output reg                          M_AXIS_TLAST,
    input  wire                         M_AXIS_TREADY
);

    /* ---------------- FSM ---------------- */
    localparam IDLE        = 3'd0;
    localparam READ_HEADER = 3'd1;
    localparam DELAY       = 3'd2;
    localparam LOAD_BEAT   = 3'd3;
    localparam SEND_BEAT   = 3'd4;
    localparam LAST        = 3'd5;

    reg [2:0] state;

    /* ---------------- Control ---------------- */
    reg [15:0] delay_counter;
    reg [15:0] delay_val;
    reg        eof;

    /* ---------------- File ---------------- */
    integer fd, ld;
    reg [7:0]  md_flag_file;
    reg [15:0] pkt_id;

    /* ---------------- AXI ---------------- */
    wire start_sig = (START_EN == 0) ? 1'b1 : START;
    wire handshake = M_AXIS_TVALID && M_AXIS_TREADY;

    assign DONE = (state == LAST);

    /* =========================================================
       FSM
       ========================================================= */
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            state         <= IDLE;
            M_AXIS_TVALID <= 1'b0;
            M_AXIS_TLAST  <= 1'b0;
            delay_counter <= 0;
            eof           <= 1'b0;
        end else begin
            case (state)

            /* ---------------- IDLE ---------------- */
            IDLE: begin
                
                if (start_sig && !eof)
                    state <= READ_HEADER;
            end

            /* ---------------- READ HEADER ---------------- */
            READ_HEADER: begin
                if ($feof(fd)) begin
                    eof   <= 1'b1;
                    state <= LAST;
                end else begin
                    ld = $fscanf(fd,
                        "%c: pkt=%d, delay=%d\n",
                        md_flag_file, pkt_id, delay_val);

                    if (ld == 3 && md_flag_file == `MD_MARKER) begin
                        delay_counter <= delay_val;
                        state <= (delay_val == 0) ? LOAD_BEAT : DELAY;
                    end
                end
            end

            /* ---------------- DELAY ---------------- */
            DELAY: begin
                if (delay_counter == 0)
                    state <= LOAD_BEAT;
                else
                    delay_counter <= delay_counter - 1;
            end

            /* ---------------- LOAD BEAT ---------------- */
            LOAD_BEAT: begin
                if (!M_AXIS_TVALID) begin
                    ld = $fscanf(fd, "%x,%x,%d\n",
                        M_AXIS_TDATA,
                        M_AXIS_TKEEP,
                        M_AXIS_TLAST);

                    if (ld != 3) begin
                        $display("[%0t] AXIS: Data parse error", $time);
                        $finish;
                    end

                    M_AXIS_TVALID <= 1'b1;
                    state <= SEND_BEAT;
                end
            end

            /* ---------------- SEND BEAT ---------------- */
            SEND_BEAT: begin
                if (handshake) begin
                    if (M_AXIS_TLAST) begin
                        M_AXIS_TVALID <= 1'b0;
                        M_AXIS_TLAST  <= 1'b0;
                        state <= READ_HEADER;
                    end else begin
                        M_AXIS_TVALID <= 1'b0;
                        state <= LOAD_BEAT;
                    end
                end
            end

            /* ---------------- LAST ---------------- */
            LAST: begin
                M_AXIS_TVALID <= 1'b0;
                $display("[%0t] Net2Axis: Finished all packets", $time);
            end

            endcase
        end
    end

    /* =========================================================
       File open
       ========================================================= */
    initial begin
        if (INPUTFILE == "") begin
            $display("ERROR: INPUTFILE empty");
            $finish;
        end

        fd = $fopen(INPUTFILE, "r");
        if (fd == `NULL) begin
            $display("ERROR: Cannot open %s", INPUTFILE);
            $finish;
        end
    end

endmodule
