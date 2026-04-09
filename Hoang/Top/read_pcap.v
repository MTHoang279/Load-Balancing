//`timescale 1ns / 1ps

//`define MD_MARKER 8'h4d
//`define NULL 0

//module net2axis_master #(
//    parameter INPUTFILE   = "",
//    parameter START_EN    = 0,
//    parameter TDATA_WIDTH = 512
//)(
//    input  wire                         ACLK,
//    input  wire                         ARESETN,
//    input  wire                         START,

//    output reg                          done_packet,
//    output wire                         DONE,

//    output reg                          M_AXIS_TVALID,
//    output reg  [TDATA_WIDTH-1:0]       M_AXIS_TDATA,
//    output reg  [(TDATA_WIDTH/8)-1:0]   M_AXIS_TKEEP,
//    output reg                          M_AXIS_TLAST,
//    input  wire                         M_AXIS_TREADY
//);

//    /* ---------------- FSM ---------------- */
//    localparam IDLE        = 3'd0;
//    localparam READ_HEADER = 3'd1;
//    localparam DELAY       = 3'd2;
//    localparam LOAD_BEAT   = 3'd3;
//    localparam SEND_BEAT   = 3'd4;
//    localparam LAST        = 3'd5;

//    reg [2:0] state;

//    /* ---------------- Control ---------------- */
//    reg [15:0] delay_counter;
//    reg [15:0] delay_val;
//    reg        eof;

//    /* ---------------- File ---------------- */
//    integer fd, ld;
//    reg [7:0]  md_flag_file;
//    reg [15:0] pkt_id;

//    /* ---------------- AXI ---------------- */
//    wire start_sig = (START_EN == 0) ? 1'b1 : START;
//    wire handshake = M_AXIS_TVALID && M_AXIS_TREADY;
    
//    // =====================================================
//    // DEBUG: Packet counter
//    // =====================================================
//    (* mark_debug = "true", keep = "true" *)
//    reg [31:0] packet_sent_count;

//    assign DONE = (state == LAST);

//    /* =========================================================
//       FSM
//       ========================================================= */
//    always @(posedge ACLK) begin
//        if (!ARESETN) begin
//            state         <= IDLE;
//            M_AXIS_TVALID <= 1'b0;
//            M_AXIS_TLAST  <= 1'b0;
//            delay_counter <= 0;
//            done_packet   <= 1'b0;
//            eof           <= 1'b0;
//            packet_sent_count <= 32'd0;
//        end else begin
//            case (state)

//            /* ---------------- IDLE ---------------- */
//            IDLE: begin
                
//                if (start_sig && !eof)
//                    state <= READ_HEADER;
//            end

//            /* ---------------- READ HEADER ---------------- */
//            READ_HEADER: begin
//                if ($feof(fd)) begin
//                    eof   <= 1'b1;
//                    state <= LAST;
//                end else begin
//                    ld = $fscanf(fd,
//                        "%c: pkt=%d, delay=%d\n",
//                        md_flag_file, pkt_id, delay_val);

//                    if (ld == 3 && md_flag_file == `MD_MARKER) begin
//                        done_packet <= 1'b0;
//                        delay_counter <= delay_val;
//                        state <= (delay_val == 0) ? LOAD_BEAT : DELAY;
//                    end
//                end
//            end

//            /* ---------------- DELAY ---------------- */
//            DELAY: begin
//                if (delay_counter == 0)
//                    state <= LOAD_BEAT;
//                else
//                    delay_counter <= delay_counter - 1;
//            end

//            /* ---------------- LOAD BEAT ---------------- */
//            LOAD_BEAT: begin
//                if (!M_AXIS_TVALID) begin
//                    ld = $fscanf(fd, "%x,%x,%d\n",
//                        M_AXIS_TDATA,
//                        M_AXIS_TKEEP,
//                        M_AXIS_TLAST);

//                    if (ld != 3) begin
//                        $display("[%0t] AXIS: Data parse error", $time);
//                        $finish;
//                    end

//                    M_AXIS_TVALID <= 1'b1;
//                    state <= SEND_BEAT;
//                end
//            end

//            /* ---------------- SEND BEAT ---------------- */
//            SEND_BEAT: begin
//                if (handshake) begin
//                    if (M_AXIS_TLAST) begin
//                        M_AXIS_TVALID <= 1'b0;
//                        M_AXIS_TLAST  <= 1'b0;
//                        done_packet   <= 1'b1;
                        
//                        packet_sent_count <= packet_sent_count + 1;
                        
//                        state <= READ_HEADER;
//                    end else begin
//                        M_AXIS_TVALID <= 1'b0;
//                        state <= LOAD_BEAT;
//                    end
//                end
//            end

//            /* ---------------- LAST ---------------- */
//            LAST: begin
//                M_AXIS_TVALID <= 1'b0;
//                $display("[%0t] Net2Axis: Finished all packets", $time);
//            end

//            endcase
//        end
//    end

//    /* =========================================================
//       File open
//       ========================================================= */
//    initial begin
//        if (INPUTFILE == "") begin
//            $display("ERROR: INPUTFILE empty");
//            $finish;
//        end

//        fd = $fopen(INPUTFILE, "r");
//        if (fd == `NULL) begin
//            $display("ERROR: Cannot open %s", INPUTFILE);
//            $finish;
//        end
//    end

//endmodule

`timescale 1ns / 1ps

module net2axis_master #(
    parameter INPUTFILE   = "E:/10G_Ethernet/UDP_sample_10K.mem",
    parameter ROM_DEPTH   = 1097,
    //ok      
    // parameter ROM_DEPTH   = 65536,             
    parameter TDATA_WIDTH = 512
)(
    input  wire                   ACLK,
    input  wire                   ARESETN,
    input  wire                   START,

    output reg                    done_packet, 
    output reg                    DONE,        

    output reg                    M_AXIS_TVALID,
    output wire [TDATA_WIDTH-1:0] M_AXIS_TDATA,
    output wire [(TDATA_WIDTH/8)-1:0] M_AXIS_TKEEP,
    output wire                   M_AXIS_TLAST,
    input  wire                   M_AXIS_TREADY
);
    (* mark_debug = "true" *) reg [31:0] packet_sent_count;
    
    localparam ROM_WIDTH = 1 + (TDATA_WIDTH/8) + TDATA_WIDTH;

    (* rom_style = "block" *) reg [ROM_WIDTH-1:0] rom_memory [0:ROM_DEPTH-1];

    initial begin
        $readmemh(INPUTFILE, rom_memory);
    end

    reg [$clog2(ROM_DEPTH)-1:0] read_ptr;
    reg                         active;

    reg [ROM_WIDTH-1:0] raw_data;
    
    always @(posedge ACLK) begin
        if (active) begin
            raw_data <= rom_memory[read_ptr];
        end else if (START && !active) begin
            raw_data <= rom_memory[0]; 
        end
    end 
    
//    always @(posedge ACLK) begin
//        if (!ARESETN) begin
//            raw_data <= 0;
//        end else begin
//            if (START && !active) begin
//                raw_data <= rom_memory[0];
//            end
//            else if (active && handshake) begin
//                raw_data <= rom_memory[read_ptr];
//            end
//        end 
//    end 

//    reg [ROM_WIDTH-1:0] raw_data_r;
//    reg [ROM_WIDTH-1:0] raw_data;
    
//    always @(posedge ACLK) begin
//        if (!ARESETN) begin
//            raw_data_r <= 0;
//            raw_data   <= 0;
//        end else begin
//            if (active) begin
//                raw_data_r <= rom_memory[read_ptr]; // read BRAM
//            end
            
//            raw_data <= raw_data_r; // pipeline thêm 1 stage
//        end
//    end

    assign M_AXIS_TLAST = raw_data[576];
    assign M_AXIS_TKEEP = raw_data[575:512];
    assign M_AXIS_TDATA = raw_data[511:0];

    wire handshake = M_AXIS_TVALID && M_AXIS_TREADY;

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            read_ptr          <= 0;
            active            <= 0;
            M_AXIS_TVALID     <= 0;
            done_packet       <= 0;
            DONE              <= 0;
            packet_sent_count <= 0;
        end else begin
            done_packet <= 0;

            if (START && !active && !DONE) begin
                active        <= 1'b1;
                M_AXIS_TVALID <= 1'b1;
                read_ptr      <= 1;
            end

            if (active) begin
                if (handshake) begin
                    if (M_AXIS_TLAST) begin
                        done_packet <= 1'b1;
                        packet_sent_count <= packet_sent_count + 1;
                    end

                    if (read_ptr == ROM_DEPTH -1) begin
                        active        <= 1'b0;
                        M_AXIS_TVALID <= 1'b0;
                        DONE          <= 1'b1;
                    end else begin
                        read_ptr <= read_ptr + 1;
                    end
                end
            end
            
            if (DONE && !START) begin
                DONE     <= 0;
                read_ptr <= 0;
            end
        end
    end

endmodule