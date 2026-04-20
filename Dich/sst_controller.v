
//module sst_controller #(
//    parameter NUM_SERVERS     = 16,
//    parameter SERVER_ID_WIDTH = 4,
//    parameter SCN_WIDTH       = 12
//)(
//    input  wire clk,
//    input  wire rst_n,

//    input  wire                        sst_scn_dec_en,
//    input  wire [SERVER_ID_WIDTH-1:0]  sst_server_idx,

//    input  wire                        sst_health_update_valid,
//    input  wire [NUM_SERVERS-1:0]      sst_health_update_bitmap,

//    input  wire                        cslb_scn_inc_en,
//    input  wire [SERVER_ID_WIDTH-1:0]  cslb_server_idx,

//    input  wire                        cslb_rd_en,
//    output reg  [NUM_SERVERS*32-1:0]       cslb_rd_ip,
//    output reg  [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,
//    output reg                         cslb_rd_valid,

//    output wire [NUM_SERVERS-1:0]      cslb_health_bitmap,
//    output reg                         cslb_health_update_valid,

//    output reg                         sst_wr_en,
//    output reg  [SERVER_ID_WIDTH-1:0]  sst_wr_addr,
//    output reg  [31:0]                 sst_wr_ip,
//    output reg                         sst_wr_health,
//    output reg  [SCN_WIDTH-1:0]        sst_wr_scn,

//    output reg  [SERVER_ID_WIDTH-1:0]  sst_rd_addr,
//    input  wire [31:0]                 sst_rd_ip,
//    input  wire [SCN_WIDTH-1:0]        sst_rd_scn,

//    input  wire [NUM_SERVERS*32-1:0]       sst_cslb_rd_ip,
//    input  wire [NUM_SERVERS*SCN_WIDTH-1:0] sst_cslb_rd_scn,
    
//    input  wire [NUM_SERVERS*32-1:0]   boot_ip_list,
//    input  wire                        boot_ip_list_valid,

//    input  wire [NUM_SERVERS-1:0]      sst_health_bitmap
//);

//    localparam FIFO_DEPTH     = 8;
//    localparam FIFO_PTR_WIDTH = 3;  // log2(8)
//    localparam ENTRY_WIDTH    = 2 + SERVER_ID_WIDTH;

//    reg [ENTRY_WIDTH-1:0]    fifo_mem [0:FIFO_DEPTH-1];
//    reg [FIFO_PTR_WIDTH-1:0] fifo_wr_ptr;
//    reg [FIFO_PTR_WIDTH-1:0] fifo_rd_ptr;
//    reg [FIFO_PTR_WIDTH:0]   fifo_count;

//    wire fifo_empty = (fifo_count == 0);

//    reg [31:0]          wr_ip_temp;
//    reg                 wr_health_temp;
//    reg [SCN_WIDTH-1:0] wr_scn_temp;

//    reg [NUM_SERVERS-1:0]      health_bitmap_snapshot;
//    reg [NUM_SERVERS-1:0]      fifo_health_bitmap;
//    reg [SERVER_ID_WIDTH-1:0]  health_server_counter;
//    reg                        health_batch_active;

//    reg [NUM_SERVERS-1:0]      cslb_health_bitmap_reg;
    
//    reg boot_ip_ready;

//    reg cslb_rd_en_lat;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) cslb_rd_en_lat <= 1'b0;
//        else        cslb_rd_en_lat <= cslb_rd_en;
//    end

//    assign cslb_health_bitmap = cslb_health_bitmap_reg;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
////            cslb_rd_ip    <= {(NUM_SERVERS*32){1'b0}};
//            cslb_rd_ip    <= boot_ip_list;
//            cslb_rd_scn   <= {(NUM_SERVERS*SCN_WIDTH){1'b0}};
//            cslb_rd_valid <= 1'b0;
//            boot_ip_ready <= 1'b0;
//        end else begin
//            if (boot_ip_list_valid) boot_ip_ready <= 1'b1;
        
//            cslb_rd_valid <= 1'b0;
////            if (cslb_rd_en_lat) begin
//            if (!boot_ip_ready) begin
//                cslb_rd_ip <= boot_ip_list;
//                cslb_rd_scn <= {(NUM_SERVERS*SCN_WIDTH){1'b0}};
//            end else if (cslb_rd_en_lat) begin
//                cslb_rd_ip    <= sst_cslb_rd_ip;
//                cslb_rd_scn   <= sst_cslb_rd_scn;
//                cslb_rd_valid <= 1'b1;
//            end
//        end
//    end

//    localparam IDLE        = 2'b00;
//    localparam READ_MODIFY = 2'b01;
//    localparam WRITE_BACK  = 2'b10;

//    reg [1:0] state;
//    reg [SERVER_ID_WIDTH-1:0] target_server;
//    reg [1:0] operation_type;
//    reg health_value;

//    wire current_server_health;
//    assign current_server_health = sst_health_bitmap[sst_rd_addr];

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n)
//            sst_rd_addr <= {SERVER_ID_WIDTH{1'b0}};
//        else if (state == IDLE && !fifo_empty && !health_batch_active)
//            sst_rd_addr <= fifo_mem[fifo_rd_ptr][SERVER_ID_WIDTH-1:0];
//        else if (state == IDLE && health_batch_active)
//            sst_rd_addr <= health_server_counter;
//    end

//    always @(posedge clk or negedge rst_n) begin : main_fsm
//        integer i;
//        reg [FIFO_PTR_WIDTH-1:0] wp;
//        reg [FIFO_PTR_WIDTH:0]   enq_count;
//        reg                       deq_this_cycle;
//        if (!rst_n) begin
//            state                  <= IDLE;
//            sst_wr_en              <= 1'b0;
//            sst_wr_addr            <= {SERVER_ID_WIDTH{1'b0}};
//            sst_wr_ip              <= 32'd0;
//            sst_wr_health          <= 1'b0;
//            sst_wr_scn             <= {SCN_WIDTH{1'b0}};
//            target_server          <= {SERVER_ID_WIDTH{1'b0}};
//            operation_type         <= 2'd0;
//            health_value           <= 1'b0;
//            wr_ip_temp             <= 32'd0;
//            wr_health_temp         <= 1'b0;
//            wr_scn_temp            <= {SCN_WIDTH{1'b0}};
//            health_bitmap_snapshot <= {NUM_SERVERS{1'b0}};
//            fifo_health_bitmap     <= {NUM_SERVERS{1'b0}};
//            health_server_counter  <= {SERVER_ID_WIDTH{1'b0}};
//            health_batch_active         <= 1'b0;
//            cslb_health_bitmap_reg        <= {NUM_SERVERS{1'b1}};
//            cslb_health_update_valid      <= 1'b0;
//            fifo_rd_ptr            <= {FIFO_PTR_WIDTH{1'b0}};
//            fifo_wr_ptr            <= {FIFO_PTR_WIDTH{1'b0}};
//            fifo_count             <= {(FIFO_PTR_WIDTH+1){1'b0}};
//            for (i = 0; i < FIFO_DEPTH; i = i + 1)
//                fifo_mem[i]        <= {ENTRY_WIDTH{1'b0}};
//        end else begin
//            cslb_health_update_valid <= 1'b0;

//            wp        = fifo_wr_ptr;
//            enq_count = 0;

//            if (sst_health_update_valid && (fifo_count + enq_count) < FIFO_DEPTH) begin
//                fifo_mem[wp]       <= {2'd2, {SERVER_ID_WIDTH{1'b0}}};
//                fifo_health_bitmap <= sst_health_update_bitmap;
//                wp        = wp + 1'b1;
//                enq_count = enq_count + 1'b1;
//            end
//            if (cslb_scn_inc_en && (fifo_count + enq_count) < FIFO_DEPTH) begin
//                fifo_mem[wp] <= {2'd0, cslb_server_idx};
//                wp        = wp + 1'b1;
//                enq_count = enq_count + 1'b1;
//            end
//            if (sst_scn_dec_en && (fifo_count + enq_count) < FIFO_DEPTH) begin
//                fifo_mem[wp] <= {2'd1, sst_server_idx};
//                wp        = wp + 1'b1;
//                enq_count = enq_count + 1'b1;
//            end
//            fifo_wr_ptr <= wp;

//            deq_this_cycle = 1'b0;

//            if (state == WRITE_BACK && operation_type == 2'd2 && health_batch_active) begin
//                if (health_server_counter < NUM_SERVERS - 1)
//                    health_server_counter <= health_server_counter + 1'b1;
//                else begin
//                    health_batch_active   <= 1'b0;
//                    health_server_counter <= {SERVER_ID_WIDTH{1'b0}};
//                end
//            end

//            case (state)
//                IDLE: begin
//                    sst_wr_en <= 1'b0;
//                    if (health_batch_active) begin
//                        target_server  <= health_server_counter;
//                        operation_type <= 2'd2;
//                        health_value   <= health_bitmap_snapshot[health_server_counter];
//                        state          <= READ_MODIFY;
//                    end else if (fifo_count > 0) begin
//                        if (fifo_mem[fifo_rd_ptr][ENTRY_WIDTH-1:SERVER_ID_WIDTH] == 2'd2) begin
//                            cslb_health_bitmap_reg   <= fifo_health_bitmap;
//                            health_bitmap_snapshot   <= fifo_health_bitmap;
//                            health_server_counter    <= {SERVER_ID_WIDTH{1'b0}};
//                            health_batch_active      <= 1'b1;
//                            cslb_health_update_valid <= 1'b1;
//                            fifo_rd_ptr              <= fifo_rd_ptr + 1'b1;
//                            deq_this_cycle            = 1'b1;
//                        end else begin
//                            target_server  <= fifo_mem[fifo_rd_ptr][SERVER_ID_WIDTH-1:0];
//                            operation_type <= fifo_mem[fifo_rd_ptr][ENTRY_WIDTH-1:SERVER_ID_WIDTH];
//                            fifo_rd_ptr    <= fifo_rd_ptr + 1'b1;
//                            deq_this_cycle  = 1'b1;
//                            state          <= READ_MODIFY;
//                        end
//                    end
//                end

//                READ_MODIFY: begin
//                    wr_ip_temp <= sst_rd_ip;
//                    case (operation_type)
//                        2'd0: begin
//                            wr_scn_temp    <= current_server_health ? sst_rd_scn + 1 : {SCN_WIDTH{1'b0}};
//                            wr_health_temp <= current_server_health;
//                        end
//                        2'd1: begin
//                            wr_scn_temp    <= (current_server_health && sst_rd_scn > 0) ?
//                                              sst_rd_scn - 1 : {SCN_WIDTH{1'b0}};
//                            wr_health_temp <= current_server_health;
//                        end
//                        2'd2: begin
//                            wr_health_temp <= health_value;
//                            wr_scn_temp    <= (!health_value) ? {SCN_WIDTH{1'b0}} :
//                                             (!current_server_health && health_value) ? {SCN_WIDTH{1'b0}} :
//                                             sst_rd_scn;
//                        end
//                        default: begin
//                            wr_scn_temp    <= sst_rd_scn;
//                            wr_health_temp <= current_server_health;
//                        end
//                    endcase
//                    state <= WRITE_BACK;
//                end

//                WRITE_BACK: begin
//                    sst_wr_addr   <= target_server;
//                    sst_wr_ip     <= wr_ip_temp;
//                    sst_wr_health <= wr_health_temp;
//                    sst_wr_scn    <= wr_scn_temp;
//                    sst_wr_en     <= 1'b1;
//                    state         <= IDLE;
//                end

//                default: state <= IDLE;
//            endcase

//            fifo_count <= fifo_count + enq_count - (deq_this_cycle ? 1'b1 : 1'b0);
//        end
//    end

//endmodule



module sst_controller #(
    parameter NUM_SERVERS     = 16,
    parameter SERVER_ID_WIDTH = 4,
    parameter SCN_WIDTH       = 12
)(
    input  wire clk,
    input  wire rst_n,

    input  wire                        sst_scn_dec_en,
    input  wire [SERVER_ID_WIDTH-1:0]  sst_server_idx,

    input  wire                        sst_health_update_valid,
    input  wire [NUM_SERVERS-1:0]      sst_health_update_bitmap,

    input  wire                        cslb_scn_inc_en,
    input  wire [SERVER_ID_WIDTH-1:0]  cslb_server_idx,

    input  wire                        cslb_rd_en,
    output reg  [NUM_SERVERS*32-1:0]       cslb_rd_ip,
    output reg  [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,
    output reg                         cslb_rd_valid,

    output wire [NUM_SERVERS-1:0]      cslb_health_bitmap,
    output reg                         cslb_health_update_valid,

    output reg                         sst_wr_en,
    output reg  [SERVER_ID_WIDTH-1:0]  sst_wr_addr,
    output reg  [31:0]                 sst_wr_ip,
    output reg                         sst_wr_health,
    output reg  [SCN_WIDTH-1:0]        sst_wr_scn,

    output reg  [SERVER_ID_WIDTH-1:0]  sst_rd_addr,
    input  wire [31:0]                 sst_rd_ip,
    input  wire [SCN_WIDTH-1:0]        sst_rd_scn,

    input  wire [NUM_SERVERS*32-1:0]       sst_cslb_rd_ip,
    input  wire [NUM_SERVERS*SCN_WIDTH-1:0] sst_cslb_rd_scn,

    input  wire [NUM_SERVERS*32-1:0]       boot_ip_list,
    input  wire                        boot_ip_valid,

    input  wire [NUM_SERVERS-1:0]      sst_health_bitmap
);

    localparam FIFO_DEPTH     = 8;
    localparam FIFO_PTR_WIDTH = 3;  // log2(8)
    localparam ENTRY_WIDTH    = 2 + SERVER_ID_WIDTH;

    reg [ENTRY_WIDTH-1:0]    fifo_mem [0:FIFO_DEPTH-1];
    reg [FIFO_PTR_WIDTH-1:0] fifo_wr_ptr;
    reg [FIFO_PTR_WIDTH-1:0] fifo_rd_ptr;
    reg [FIFO_PTR_WIDTH:0]   fifo_count;

    wire fifo_empty = (fifo_count == 0);

    reg [31:0]          wr_ip_temp;
    reg                 wr_health_temp;
    reg [SCN_WIDTH-1:0] wr_scn_temp;

    reg [NUM_SERVERS-1:0]      health_bitmap_snapshot;
    reg [NUM_SERVERS-1:0]      fifo_health_bitmap;
    reg [SERVER_ID_WIDTH-1:0]  health_server_counter;
    reg                        health_batch_active;

    reg [NUM_SERVERS-1:0]      cslb_health_bitmap_reg;

    reg cslb_rd_en_lat;
    reg boot_ip_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cslb_rd_en_lat <= 1'b0;
        else        cslb_rd_en_lat <= cslb_rd_en;
    end

    assign cslb_health_bitmap = cslb_health_bitmap_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
//            cslb_rd_ip    <= boot_ip_list;
            cslb_rd_ip <= {(NUM_SERVERS*32){1'b0}};
            cslb_rd_scn   <= {(NUM_SERVERS*SCN_WIDTH){1'b0}};
            cslb_rd_valid <= 1'b0;
            boot_ip_ready <= 1'b0;
        end else begin
            if (boot_ip_valid)
                boot_ip_ready <= 1'b1;

            cslb_rd_valid <= 1'b0;
            if (!boot_ip_ready) begin
//                cslb_rd_ip <= boot_ip_list;
                cslb_rd_ip <= {(NUM_SERVERS*32){1'b0}};
                cslb_rd_scn <= {(NUM_SERVERS*SCN_WIDTH){1'b0}};
            end else if (cslb_rd_en_lat &&
                         (fifo_count == 0) &&
                         !health_batch_active &&
                         !sst_wr_en &&
                         !sst_health_update_valid &&
                         !cslb_scn_inc_en &&
                         !sst_scn_dec_en) begin
                cslb_rd_ip    <= sst_cslb_rd_ip;
                cslb_rd_scn   <= sst_cslb_rd_scn;
                cslb_rd_valid <= 1'b1;
            end
        end
    end

    localparam IDLE        = 2'b00;
    localparam READ_MODIFY = 2'b01;
    localparam WRITE_BACK  = 2'b10;

    reg [1:0] state;
    reg [SERVER_ID_WIDTH-1:0] target_server;
    reg [1:0] operation_type;
    reg health_value;

    wire current_server_health;
    assign current_server_health = sst_health_bitmap[sst_rd_addr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sst_rd_addr <= {SERVER_ID_WIDTH{1'b0}};
        else if (state == IDLE && !fifo_empty && !health_batch_active)
            sst_rd_addr <= fifo_mem[fifo_rd_ptr][SERVER_ID_WIDTH-1:0];
        else if (state == IDLE && health_batch_active)
            sst_rd_addr <= health_server_counter;
    end

    always @(posedge clk or negedge rst_n) begin : main_fsm
        integer i;
        reg [FIFO_PTR_WIDTH-1:0] wp;
        reg [FIFO_PTR_WIDTH:0]   enq_count;
        reg                       deq_this_cycle;
        if (!rst_n) begin
            state                  <= IDLE;
            sst_wr_en              <= 1'b0;
            sst_wr_addr            <= {SERVER_ID_WIDTH{1'b0}};
            sst_wr_ip              <= 32'd0;
            sst_wr_health          <= 1'b0;
            sst_wr_scn             <= {SCN_WIDTH{1'b0}};
            target_server          <= {SERVER_ID_WIDTH{1'b0}};
            operation_type         <= 2'd0;
            health_value           <= 1'b0;
            wr_ip_temp             <= 32'd0;
            wr_health_temp         <= 1'b0;
            wr_scn_temp            <= {SCN_WIDTH{1'b0}};
            health_bitmap_snapshot <= {NUM_SERVERS{1'b0}};
            fifo_health_bitmap     <= {NUM_SERVERS{1'b0}};
            health_server_counter  <= {SERVER_ID_WIDTH{1'b0}};
            health_batch_active         <= 1'b0;
            cslb_health_bitmap_reg        <= {NUM_SERVERS{1'b1}};
            cslb_health_update_valid      <= 1'b0;
            fifo_rd_ptr            <= {FIFO_PTR_WIDTH{1'b0}};
            fifo_wr_ptr            <= {FIFO_PTR_WIDTH{1'b0}};
            fifo_count             <= {(FIFO_PTR_WIDTH+1){1'b0}};
            for (i = 0; i < FIFO_DEPTH; i = i + 1)
                fifo_mem[i]        <= {ENTRY_WIDTH{1'b0}};
        end else begin
            cslb_health_update_valid <= 1'b0;

            wp        = fifo_wr_ptr;
            enq_count = 0;

            if (sst_health_update_valid && (fifo_count + enq_count) < FIFO_DEPTH) begin
                fifo_mem[wp]       <= {2'd2, {SERVER_ID_WIDTH{1'b0}}};
                fifo_health_bitmap <= sst_health_update_bitmap;
                wp        = wp + 1'b1;
                enq_count = enq_count + 1'b1;
            end
            if (cslb_scn_inc_en && (fifo_count + enq_count) < FIFO_DEPTH) begin
                fifo_mem[wp] <= {2'd0, cslb_server_idx};
                wp        = wp + 1'b1;
                enq_count = enq_count + 1'b1;
            end
            if (sst_scn_dec_en && (fifo_count + enq_count) < FIFO_DEPTH) begin
                fifo_mem[wp] <= {2'd1, sst_server_idx};
                wp        = wp + 1'b1;
                enq_count = enq_count + 1'b1;
            end
            fifo_wr_ptr <= wp;

            deq_this_cycle = 1'b0;

            if (state == WRITE_BACK && operation_type == 2'd2 && health_batch_active) begin
                if (health_server_counter < NUM_SERVERS - 1)
                    health_server_counter <= health_server_counter + 1'b1;
                else begin
                    health_batch_active   <= 1'b0;
                    health_server_counter <= {SERVER_ID_WIDTH{1'b0}};
                end
            end

            case (state)
                IDLE: begin
                    sst_wr_en <= 1'b0;
                    if (health_batch_active) begin
                        target_server  <= health_server_counter;
                        operation_type <= 2'd2;
                        health_value   <= health_bitmap_snapshot[health_server_counter];
                        state          <= READ_MODIFY;
                    end else if (fifo_count > 0) begin
                        if (fifo_mem[fifo_rd_ptr][ENTRY_WIDTH-1:SERVER_ID_WIDTH] == 2'd2) begin
                            cslb_health_bitmap_reg   <= fifo_health_bitmap;
                            health_bitmap_snapshot   <= fifo_health_bitmap;
                            health_server_counter    <= {SERVER_ID_WIDTH{1'b0}};
                            health_batch_active      <= 1'b1;
                            cslb_health_update_valid <= 1'b1;
                            fifo_rd_ptr              <= fifo_rd_ptr + 1'b1;
                            deq_this_cycle            = 1'b1;
                        end else begin
                            target_server  <= fifo_mem[fifo_rd_ptr][SERVER_ID_WIDTH-1:0];
                            operation_type <= fifo_mem[fifo_rd_ptr][ENTRY_WIDTH-1:SERVER_ID_WIDTH];
                            fifo_rd_ptr    <= fifo_rd_ptr + 1'b1;
                            deq_this_cycle  = 1'b1;
                            state          <= READ_MODIFY;
                        end
                    end
                end

                READ_MODIFY: begin
                    wr_ip_temp <= sst_rd_ip;
                    case (operation_type)
                        2'd0: begin
                            wr_scn_temp    <= current_server_health ? sst_rd_scn + 1 : {SCN_WIDTH{1'b0}};
                            wr_health_temp <= current_server_health;
                        end
                        2'd1: begin
                            wr_scn_temp    <= (current_server_health && sst_rd_scn > 0) ?
                                              sst_rd_scn - 1 : {SCN_WIDTH{1'b0}};
                            wr_health_temp <= current_server_health;
                        end
                        2'd2: begin
                            wr_health_temp <= health_value;
                            wr_scn_temp    <= (!health_value) ? {SCN_WIDTH{1'b0}} :
                                             (!current_server_health && health_value) ? {SCN_WIDTH{1'b0}} :
                                             sst_rd_scn;
                        end
                        default: begin
                            wr_scn_temp    <= sst_rd_scn;
                            wr_health_temp <= current_server_health;
                        end
                    endcase
                    state <= WRITE_BACK;
                end

                WRITE_BACK: begin
                    sst_wr_addr   <= target_server;
                    sst_wr_ip     <= wr_ip_temp;
                    sst_wr_health <= wr_health_temp;
                    sst_wr_scn    <= wr_scn_temp;
                    sst_wr_en     <= 1'b1;
                    state         <= IDLE;
                end

                default: state <= IDLE;
            endcase

            fifo_count <= fifo_count + enq_count - (deq_this_cycle ? 1'b1 : 1'b0);
        end
    end

endmodule
