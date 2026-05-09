//module heartbeat_checker #(
//    parameter NUM_SERVERS = 16,
//    parameter SERVER_ID_WIDTH = 4
//)(
//    input  wire clk,
//    input  wire rst_n,

//    input  wire trigger,

//    input  wire                        parser_response_valid,
//    input  wire [SERVER_ID_WIDTH-1:0]  parser_server_id,
//    output wire                        parser_response_ready,

//    output reg                         sst_health_update_valid,
//    output reg  [NUM_SERVERS-1:0]      sst_health_update_bitmap
//);

//    reg [NUM_SERVERS-1:0] response_table;

//    localparam IDLE        = 2'b00;
//    localparam UPDATE_SST  = 2'b01;
//    localparam CLEAR       = 2'b10;
    
//    reg [1:0] state, next_state;

//    reg trigger_prev;
//    wire trigger_edge;
    
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n)
//            trigger_prev <= 1'b0;
//        else
//            trigger_prev <= trigger;
//    end
    
//    assign trigger_edge = trigger & ~trigger_prev;

//    assign parser_response_ready = (state == IDLE);

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n)
//            state <= IDLE;
//        else
//            state <= next_state;
//    end

//    always @(*) begin
//        next_state = state;
        
//        case (state)
//            IDLE: begin
//                if (trigger_edge)
//                    next_state = UPDATE_SST;
//            end

//            UPDATE_SST: begin
//                next_state = CLEAR;
//            end

//            CLEAR: begin
//                next_state = IDLE;
//            end
            
//            default: next_state = IDLE;
//        endcase
//    end

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            response_table              <= {NUM_SERVERS{1'b0}};
//            sst_health_update_valid     <= 1'b0;
//            sst_health_update_bitmap    <= {NUM_SERVERS{1'b0}};
//        end
//        else begin
//            sst_health_update_valid <= 1'b0;
            
//            case (state)
//                IDLE: begin
//                    if (parser_response_valid && parser_response_ready) begin
//                        response_table[parser_server_id] <= 1'b1;
//                    end
//                end

//                UPDATE_SST: begin
//                    sst_health_update_valid  <= 1'b1;
//                    sst_health_update_bitmap <= response_table;
//                end

//                CLEAR: begin
//                    response_table           <= {NUM_SERVERS{1'b0}};
//                    sst_health_update_valid  <= 1'b0;
//                    sst_health_update_bitmap <= {NUM_SERVERS{1'b0}};
//                end
                
//                default: begin
//                end
//            endcase
//        end
//    end

//endmodule
module heartbeat_checker #(
    parameter NUM_SERVERS = 16,
    parameter SERVER_ID_WIDTH = 4,
    parameter HEARTBEATS_REQUIRED = 5
)(
    input  wire clk,
    input  wire rst_n,

    input  wire heartbeat_tick,
    input  wire trigger,

    input  wire                        parser_response_valid,
    input  wire [SERVER_ID_WIDTH-1:0]  parser_server_id,
    output wire                        parser_response_ready,

    output reg                         sst_health_update_valid,
    output reg  [NUM_SERVERS-1:0]      sst_health_update_bitmap
);

    localparam STREAK_WIDTH = $clog2(HEARTBEATS_REQUIRED + 1);

    reg [STREAK_WIDTH-1:0] heartbeat_streak [0:NUM_SERVERS-1];
    reg                    heartbeat_seen   [0:NUM_SERVERS-1];
    reg [NUM_SERVERS-1:0]   response_table;
    integer i;

    localparam IDLE        = 2'b00;
    localparam UPDATE_SST  = 2'b01;
    localparam CLEAR       = 2'b10;
    
    reg [1:0] state, next_state;

    reg trigger_prev;
    wire trigger_edge;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            trigger_prev <= 1'b0;
        else
            trigger_prev <= trigger;
    end
    
    assign trigger_edge = trigger & ~trigger_prev;

    assign parser_response_ready = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (trigger_edge)
                    next_state = UPDATE_SST;
            end

            UPDATE_SST: begin
                next_state = CLEAR;
            end

            CLEAR: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_SERVERS; i = i + 1) begin
                heartbeat_streak[i] <= {STREAK_WIDTH{1'b0}};
                heartbeat_seen[i]   <= 1'b0;
            end
            response_table          <= {NUM_SERVERS{1'b0}};
            sst_health_update_valid     <= 1'b0;
            sst_health_update_bitmap    <= {NUM_SERVERS{1'b0}};
        end
        else begin
            sst_health_update_valid <= 1'b0;

            if (parser_response_valid && parser_response_ready) begin
                heartbeat_seen[parser_server_id] <= 1'b1;
            end

            if (heartbeat_tick) begin
                for (i = 0; i < NUM_SERVERS; i = i + 1) begin
                    if (heartbeat_seen[i] || (parser_response_valid && parser_response_ready && (parser_server_id == i[SERVER_ID_WIDTH-1:0]))) begin
                        if (heartbeat_streak[i] < HEARTBEATS_REQUIRED[STREAK_WIDTH-1:0])
                            heartbeat_streak[i] <= heartbeat_streak[i] + 1'b1;
                        if (heartbeat_streak[i] + 1'b1 >= HEARTBEATS_REQUIRED[STREAK_WIDTH-1:0])
                            response_table[i] <= 1'b1;
                    end else begin
                        heartbeat_streak[i] <= {STREAK_WIDTH{1'b0}};
                    end
                    heartbeat_seen[i] <= 1'b0;
                end
            end
            
            case (state)
                IDLE: begin
                end

                UPDATE_SST: begin
                    sst_health_update_valid  <= 1'b1;
                    sst_health_update_bitmap <= response_table;
                end

                CLEAR: begin
                    for (i = 0; i < NUM_SERVERS; i = i + 1) begin
                        heartbeat_streak[i] <= {STREAK_WIDTH{1'b0}};
                        heartbeat_seen[i]   <= 1'b0;
                    end
                    response_table           <= {NUM_SERVERS{1'b0}};
                    sst_health_update_valid  <= 1'b0;
                    sst_health_update_bitmap <= {NUM_SERVERS{1'b0}};
                end
                
                default: begin
                end
            endcase
        end
    end

endmodule
