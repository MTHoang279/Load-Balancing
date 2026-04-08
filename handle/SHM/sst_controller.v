module sst_controller #(
    parameter NUM_SERVERS       = 4,
    parameter SERVER_ID_WIDTH   = 2,
    parameter SCN_WIDTH         = 8,
    parameter FIFO_DEPTH        = 16,
    parameter FIFO_PTR_WIDTH    = $clog2(FIFO_DEPTH)
)(
    input  wire clk,
    input  wire rst_n,

    // SST
    input  wire sst_scn_dec_en,
    input  wire [SERVER_ID_WIDTH-1:0] sst_server_idx,

    input  wire sst_health_update_valid,
    input  wire [NUM_SERVERS-1:0] sst_health_update_bitmap,

    // CSLB
    input  wire cslb_scn_inc_en,
    input  wire [SERVER_ID_WIDTH-1:0] cslb_server_idx,
    input  wire cslb_rd_en,

    output reg  [NUM_SERVERS*32-1:0] cslb_rd_ip,
    output reg  [NUM_SERVERS*SCN_WIDTH-1:0] cslb_rd_scn,
    output reg  cslb_rd_valid,
    output wire [NUM_SERVERS-1:0] cslb_health_bitmap,

    // memory write
    output reg sst_wr_en,
    output reg [SERVER_ID_WIDTH-1:0] sst_wr_addr,
    output reg [31:0] sst_wr_ip,
    output reg sst_wr_health,
    output reg [SCN_WIDTH-1:0] sst_wr_scn,

    // memory read
    output reg [SERVER_ID_WIDTH-1:0] sst_rd_addr,
    input  wire [31:0] sst_rd_ip,
    input  wire [SCN_WIDTH-1:0] sst_rd_scn,

    // CSLB read
    input wire [NUM_SERVERS*32-1:0] sst_cslb_rd_ip,
    input wire [NUM_SERVERS*SCN_WIDTH-1:0] sst_cslb_rd_scn,
    input wire [NUM_SERVERS-1:0] sst_health_bitmap
);

//////////////////////////////////////////////////////////
// FIFO (event queue)
//////////////////////////////////////////////////////////

localparam ENTRY_WIDTH = SERVER_ID_WIDTH + 1;

reg [ENTRY_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];

reg [FIFO_PTR_WIDTH-1:0] wr_ptr, rd_ptr;
reg [FIFO_PTR_WIDTH:0] fifo_count;

wire fifo_empty = (fifo_count == 0);
wire fifo_full  = (fifo_count >= FIFO_DEPTH-2);

wire push_dec = sst_scn_dec_en && !fifo_full;
wire push_inc = cslb_scn_inc_en && !fifo_full;

wire [1:0] push_count = push_dec + push_inc;

wire [FIFO_PTR_WIDTH-1:0] wr_ptr_p1 = (wr_ptr == FIFO_DEPTH-1) ? 0 : wr_ptr + 1;

// write
always @(posedge clk) begin
    if(push_dec)
        fifo_mem[wr_ptr] <= {1'b1, sst_server_idx};

    if(push_inc)
        fifo_mem[push_dec ? wr_ptr_p1 : wr_ptr] <= {1'b0, cslb_server_idx};
end

// pointer
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        wr_ptr <= 0;
    else
        wr_ptr <= wr_ptr + push_count;
end

// count
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        fifo_count <= 0;
    else
        fifo_count <= fifo_count + push_count - pop_fifo;
end

//////////////////////////////////////////////////////////
// HEALTH CONTROLLER
//////////////////////////////////////////////////////////

reg health_batch_active;
reg [SERVER_ID_WIDTH-1:0] health_counter;
reg [NUM_SERVERS-1:0] health_bitmap_snapshot;

reg [NUM_SERVERS-1:0] cslb_health_bitmap_reg;
assign cslb_health_bitmap = cslb_health_bitmap_reg;

//////////////////////////////////////////////////////////
// DISPATCHER (select operation source)
//////////////////////////////////////////////////////////

reg op_type;
reg [SERVER_ID_WIDTH-1:0] target_server;

wire pop_fifo = (state==IDLE) && !fifo_empty && !health_batch_active;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rd_ptr <= 0;
        op_type <= 0;
        target_server <= 0;
    end
    else if(state==IDLE) begin

        // ?u tiên health batch
        if(health_batch_active) begin
            op_type <= 1'b0; // dummy
            target_server <= health_counter;
        end
        else if(pop_fifo) begin
            op_type <= fifo_mem[rd_ptr][ENTRY_WIDTH-1];
            target_server <= fifo_mem[rd_ptr][SERVER_ID_WIDTH-1:0];
            rd_ptr <= rd_ptr + 1'b1;
        end

    end
end

//////////////////////////////////////////////////////////
// MEMORY PIPELINE
//////////////////////////////////////////////////////////

reg [31:0] rd_ip_r;
reg [SCN_WIDTH-1:0] rd_scn_r;

always @(posedge clk) begin
    rd_ip_r  <= sst_rd_ip;
    rd_scn_r <= sst_rd_scn;
end

wire current_health = sst_health_bitmap[sst_rd_addr];

//////////////////////////////////////////////////////////
// FSM
//////////////////////////////////////////////////////////

localparam IDLE=0, READ=1, MODIFY=2, WRITE=3;
reg [1:0] state;

reg [SCN_WIDTH-1:0] new_scn;
reg new_health;

always @(posedge clk or negedge rst_n) begin
if(!rst_n) begin

    state <= IDLE;
    sst_wr_en <= 0;
    sst_rd_addr <= 0;

    health_batch_active <= 0;
    health_counter <= 0;

    cslb_health_bitmap_reg <= {NUM_SERVERS{1'b1}};

end
else begin

    sst_wr_en <= 0;

    // trigger health update
    if(sst_health_update_valid && !health_batch_active && state==IDLE) begin
        health_batch_active <= 1;
        health_counter <= 0;
        health_bitmap_snapshot <= sst_health_update_bitmap;
        cslb_health_bitmap_reg <= sst_health_update_bitmap;
    end

    case(state)

    IDLE:
    begin
        if(health_batch_active || pop_fifo) begin
            sst_rd_addr <= target_server;
            state <= READ;
        end
    end

    READ:
        state <= MODIFY;

    MODIFY:
    begin
        new_health <= health_batch_active ? 
                      health_bitmap_snapshot[target_server] :
                      current_health;

        if(health_batch_active) begin
            new_scn <= (!health_bitmap_snapshot[target_server] || !current_health)
                        ? 0 : rd_scn_r;
        end
        else if(op_type==1'b0) begin
            new_scn <= current_health ? rd_scn_r + 1 : 0;
        end
        else begin
            new_scn <= (current_health && rd_scn_r>0) ? rd_scn_r-1 : 0;
        end

        state <= WRITE;
    end

    WRITE:
    begin
        sst_wr_en     <= 1'b1;
        sst_wr_addr   <= target_server;
        sst_wr_ip     <= rd_ip_r;
        sst_wr_scn    <= new_scn;
        sst_wr_health <= new_health;

        if(health_batch_active) begin
            if(health_counter == NUM_SERVERS-1)
                health_batch_active <= 0;
            else
                health_counter <= health_counter + 1;
        end

        state <= IDLE;
    end

    endcase
end
end

//////////////////////////////////////////////////////////
// CSLB READ PIPELINE
//////////////////////////////////////////////////////////

reg cslb_rd_en_d;

always @(posedge clk)
    cslb_rd_en_d <= cslb_rd_en;

always @(posedge clk) begin
    cslb_rd_valid <= 0;
    if(cslb_rd_en_d) begin
        cslb_rd_ip    <= sst_cslb_rd_ip;
        cslb_rd_scn   <= sst_cslb_rd_scn;
        cslb_rd_valid <= 1;
    end
end

endmodule