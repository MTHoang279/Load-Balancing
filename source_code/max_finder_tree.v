
module max_finder_tree #(
    parameter N       = 16,
    parameter SCORE_W = $clog2(N),
    parameter IDX_W   = $clog2(N)
)(
    input  [N*SCORE_W-1:0] data_in,
    input  [N-1:0]         valid_in,
    output reg [IDX_W-1:0] max_index,
    output reg             found_any
);

    localparam COUNT_W = $clog2(N + 1);
    localparam GROUP_SIZE = 8;
    localparam NUM_GROUPS = (N + GROUP_SIZE - 1) / GROUP_SIZE;
    localparam GROUP_IDX_W = (GROUP_SIZE > 1) ? $clog2(GROUP_SIZE) : 1;

    integer i;
    integer idx;
    integer j;
    
    reg [COUNT_W-1:0] alive_count;
    reg [SCORE_W-1:0] target_score;

    reg [NUM_GROUPS-1:0] group_match;
    reg [NUM_GROUPS*IDX_W-1:0] group_idx;

    reg [NUM_GROUPS-1:0] group_valid;
    reg [NUM_GROUPS*IDX_W-1:0] group_valid_idx;

    always @(*) begin
        alive_count = {COUNT_W{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
            if (valid_in[i])
                alive_count = alive_count + 1'b1;
        end

        if (alive_count == 0)
            target_score = {SCORE_W{1'b0}};
        else
            target_score = alive_count - 1'b1;

        for (i = 0; i < NUM_GROUPS; i = i + 1) begin
            group_match[i] = 1'b0;
            group_idx[i*IDX_W +: IDX_W] = {IDX_W{1'b0}};
            group_valid[i] = 1'b0;
            group_valid_idx[i*IDX_W +: IDX_W] = {IDX_W{1'b0}};
        end
        

        // Grouped priority encoder for matches
        for (i = 0; i < NUM_GROUPS; i = i + 1) begin
//            integer j;
            for (j = 0; j < GROUP_SIZE; j = j + 1) begin
//                integer idx;
                idx = i*GROUP_SIZE + j;
                if (idx < N) begin
                    if (!group_match[i] && valid_in[idx] &&
                        (data_in[idx*SCORE_W +: SCORE_W] == target_score)) begin
                        group_match[i] = 1'b1;
                        group_idx[i*IDX_W +: IDX_W] = idx[IDX_W-1:0];
                    end
                    if (!group_valid[i] && valid_in[idx]) begin
                        group_valid[i] = 1'b1;
                        group_valid_idx[i*IDX_W +: IDX_W] = idx[IDX_W-1:0];
                    end
                end
            end
        end

        found_any = 1'b0;
        max_index = {IDX_W{1'b0}};

        for (i = 0; i < NUM_GROUPS; i = i + 1) begin
            if (!found_any && group_match[i]) begin
                max_index = group_idx[i*IDX_W +: IDX_W];
                found_any = 1'b1;
            end
        end

        if (!found_any) begin
            for (i = 0; i < NUM_GROUPS; i = i + 1) begin
                if (!found_any && group_valid[i]) begin
                    max_index = group_valid_idx[i*IDX_W +: IDX_W];
                    found_any = 1'b1;
                end
            end
        end
    end

endmodule
