////module tlcm_stage3 #(
////    parameter N = 16,
////    parameter IDX_W = $clog2(N),
////    parameter DATA_W = 12
////)(
////    input  [N*N-1:0]   total_score,
////    input              pipe_valid_in,
////    input  [N-1:0]     server_valid_in,

////    output [IDX_W-1:0] best_index,
////    output             pipe_valid_out,
////    output [N-1:0]     server_valid_out
////);

////wire [N-1:0] max_score;

////max_finder_tree #(
////    .N(N),
////    .DATA_W(DATA_W),
////    .IDX_W(IDX_W)
////) u_max_tree (
////    .data_in   (total_score),
////    .valid_in  (server_valid_in),
////    .max_value (max_score),
////    .max_index (best_index)
////);

////assign pipe_valid_out   = pipe_valid_in;
////assign server_valid_out = server_valid_in;

////endmodule


//module tlcm_stage3 #(
//    parameter N = 16,
//    parameter IDX_W = $clog2(N)
//)(
//    input  [N*$clog2(N)-1:0]   total_score,
//    input              pipe_valid_in,
//    input  [N-1:0]     server_valid_in,

//    output [IDX_W-1:0] best_index,
//    output             pipe_valid_out,
//    output [N-1:0]     server_valid_out
//);

//wire [$clog2(N):0] max_score;

//max_finder_tree #(
//    .N(N),
//    .DATA_W(12),
//    .IDX_W(IDX_W)
//) u_max_tree (
//    .data_in   (total_score),
//    .valid_in  (server_valid_in),
//    .max_value (max_score),
//    .max_index (best_index)
//);

//assign pipe_valid_out   = pipe_valid_in;
//assign server_valid_out = server_valid_in;

//endmodule 

module tlcm_stage3 #(
    parameter N = 16,
    parameter IDX_W = $clog2(N),
    parameter SCORE_W = $clog2(N)
)(
    input  [N*SCORE_W-1:0] total_score,
    input                  pipe_valid_in,
    input  [N-1:0]         server_valid_in,

    output [IDX_W-1:0]     best_index,
    output                 pipe_valid_out,
    output [N-1:0]         server_valid_out
);

    wire found_winner;

    // Thay th? max_finder_tree (?? quy) b?ng parallel_max_finder (song song)
    max_finder_tree #(
        .N(N),
        .SCORE_W(SCORE_W),
        .IDX_W(IDX_W)
    ) u_parallel_max (
        .data_in   (total_score),
        .valid_in  (server_valid_in),
        .max_index (best_index),
        .found_any (found_winner)
    );

    // ???ng valid gi? nguy?n (Combinational)
    // N?u Timing v?n ??, h?y ch?n th?m 1 t?ng Reg ? ??y
    assign pipe_valid_out   = pipe_valid_in && found_winner;
    assign server_valid_out = server_valid_in;

endmodule 
