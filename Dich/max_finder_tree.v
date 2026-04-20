////module max_finder_tree #(
////    parameter N      = 16,
////    parameter DATA_W = 12,
////    parameter IDX_W  = $clog2(N)
////)(
////    input  [N*DATA_W-1:0] data_in,
////    input  [N-1:0]        valid_in,
    
////    output [DATA_W-1:0]   max_value,
////    output [IDX_W-1:0]    max_index
////);

////generate
////    if (N == 1) begin : BASE_CASE
////        assign max_value = valid_in[0] ? data_in[DATA_W-1:0] : {DATA_W{1'b0}};
////        assign max_index = {IDX_W{1'b0}};
////    end
    
////    else if (N == 2) begin : TWO_WAY
////        wire [DATA_W-1:0] d0 = data_in[0*DATA_W +: DATA_W];
////        wire [DATA_W-1:0] d1 = data_in[1*DATA_W +: DATA_W];
////        wire sel = valid_in[1] && (d1 >= d0 || !valid_in[0]);
        
////        assign max_value = sel ? d1 : d0;
////        assign max_index = sel ? 1'b1 : 1'b0;
////    end
    
////    else begin : RECURSIVE_TREE
////        localparam N_LEFT  = (N + 1) / 2;
////        localparam N_RIGHT = N - N_LEFT;
        
////        wire [DATA_W-1:0] max_left, max_right;
////        wire [IDX_W-1:0]  idx_left, idx_right;
        
////        max_finder_tree #(
////            .N(N_LEFT),
////            .DATA_W(DATA_W),
////            .IDX_W(IDX_W)
////        ) left_tree (
////            .data_in   (data_in[N_LEFT*DATA_W-1:0]),
////            .valid_in  (valid_in[N_LEFT-1:0]),
////            .max_value (max_left),
////            .max_index (idx_left)
////        );
        
////        max_finder_tree #(
////            .N(N_RIGHT),
////            .DATA_W(DATA_W),
////            .IDX_W(IDX_W)
////        ) right_tree (
////            .data_in   (data_in[N*DATA_W-1:N_LEFT*DATA_W]),
////            .valid_in  (valid_in[N-1:N_LEFT]),
////            .max_value (max_right),
////            .max_index (idx_right)
////        );
        
////        wire valid_left  = |valid_in[N_LEFT-1:0];
////        wire valid_right = |valid_in[N-1:N_LEFT];
        
////        wire sel_right = valid_right && (max_right >= max_left || !valid_left);
        
////        assign max_value = sel_right ? max_right : max_left;
////        assign max_index = sel_right ? (N_LEFT + idx_right) : idx_left;
////    end
////endgenerate

////endmodule 


//module max_finder_tree #(
//    parameter N      = 16,
//    parameter DATA_W = 12,
//    parameter IDX_W  = $clog2(N)
//)(
//    input  [N*DATA_W-1:0] data_in,
//    input  [N-1:0]        valid_in,
    
//    output [DATA_W-1:0]   max_value,
//    output [IDX_W-1:0]    max_index
//);

//generate
//    if (N == 1) begin : BASE_CASE
//        assign max_value = valid_in[0] ? data_in[DATA_W-1:0] : {DATA_W{1'b0}};
//        assign max_index = {IDX_W{1'b0}};
//    end
    
//    else if (N == 2) begin : TWO_WAY
//        wire [DATA_W-1:0] d0 = data_in[0*DATA_W +: DATA_W];
//        wire [DATA_W-1:0] d1 = data_in[1*DATA_W +: DATA_W];
//        wire sel = valid_in[1] && (d1 >= d0 || !valid_in[0]);
        
//        assign max_value = sel ? d1 : d0;
//        assign max_index = sel ? 1'b1 : 1'b0;
////        assign max_index = sel ? {{(IDX_W-1){1'b0}}, 1'b1} : {IDX_W{1'b0}};
//    end
    
//    else begin : RECURSIVE_TREE
//        localparam N_LEFT  = (N + 1) / 2;
//        localparam N_RIGHT = N - N_LEFT;
        
//        wire [DATA_W-1:0] max_left, max_right;
//        wire [IDX_W-1:0]  idx_left, idx_right;
        
//        max_finder_tree #(
//            .N(N_LEFT),
//            .DATA_W(DATA_W),
//            .IDX_W(IDX_W)
//        ) left_tree (
//            .data_in   (data_in[N_LEFT*DATA_W-1:0]),
//            .valid_in  (valid_in[N_LEFT-1:0]),
//            .max_value (max_left),
//            .max_index (idx_left)
//        );
        
//        max_finder_tree #(
//            .N(N_RIGHT),
//            .DATA_W(DATA_W),
//            .IDX_W(IDX_W)
//        ) right_tree (
//            .data_in   (data_in[N*DATA_W-1:N_LEFT*DATA_W]),
//            .valid_in  (valid_in[N-1:N_LEFT]),
//            .max_value (max_right),
//            .max_index (idx_right)
//        );
        
//        wire valid_left  = |valid_in[N_LEFT-1:0];
//        wire valid_right = |valid_in[N-1:N_LEFT];
        
//        wire sel_right = valid_right && (max_right >= max_left || !valid_left);
        
//        assign max_value = sel_right ? max_right : max_left;
//        assign max_index = sel_right ? (N_LEFT + idx_right) : idx_left;
//    end
//endgenerate

//endmodule

module max_finder_tree #(
    parameter N       = 16,
    parameter SCORE_W = $clog2(N),
    parameter IDX_W   = $clog2(N)
)(
    input  [N*SCORE_W-1:0] data_in,
    input  [N-1:0]        valid_in,
    output [IDX_W-1:0]    max_index,
    output                found_any
);

    // ??m s? server s?ng
    reg [$clog2(N):0] alive_count;
    integer k;
    always @(*) begin
        alive_count = 0;
        for (k = 0; k < N; k = k + 1)
            alive_count = alive_count + valid_in[k];
    end

    // Target = s? server s?ng - 1 (th?ng t?t c? server s?ng còn l?i)
    wire [SCORE_W-1:0] target = (alive_count > 0) ? alive_count - 1 : 0;

    wire [N-1:0] is_max;
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : COMP_BLOCK
            // Ch? nh?ng server Valid v? c? ?i?m == N-1 m?i ???c ch?n
            assign is_max[i] = valid_in[i] && (data_in[i*SCORE_W +: SCORE_W] == target);
        end
    endgenerate

    // Priority Encoder logic
    reg [IDX_W-1:0] first_idx;
    reg found;
    integer j;

    always @(*) begin
        first_idx = {IDX_W{1'b0}};
        found = 1'b0;
        for (j = 0; j < N; j = j + 1) begin
            if (!found && is_max[j]) begin
                first_idx = j[IDX_W-1:0];
                found = 1'b1;
            end
        end
    end

    assign max_index = first_idx;
    assign found_any = found;

endmodule