//module tlcm_stage2 #(
//    parameter N = 16
//)(
//    input  [N*N-1:0]  score_part,
//    input             pipe_valid_in,
//    input  [N-1:0]    server_valid_in,

//    output [N*4-1:0]  total_score,
//    output            pipe_valid_out,
//    output [N-1:0]    server_valid_out
//);

//genvar i;

//generate
//    for (i = 0; i < N; i = i + 1) begin : ROW_SUM
//        adder_tree #(.N(N)) u_adder_tree (
//            .bits_in (score_part[i*N +: N]),
//            .sum_out (total_score[i*4 +: 4])
//        );
//    end
//endgenerate

//assign pipe_valid_out   = pipe_valid_in;
//assign server_valid_out = server_valid_in;

//endmodule 

//module tlcm_stage2 #(
//    parameter N = 16,
//    parameter SCORE_W = $clog2(N)
//)(
//    input  [N*N-1:0]  score_part,
//    input             pipe_valid_in,
//    input  [N-1:0]    server_valid_in,

//    output [N*SCORE_W-1:0]  total_score,
//    output            pipe_valid_out,
//    output [N-1:0]    server_valid_out
//);

//genvar i;

//generate
//    for (i = 0; i < N; i = i + 1) begin : ROW_SUM
//        adder_tree #(.N(N)) u_adder_tree (
//            .bits_in (score_part[i*N +: N]),
//            .sum_out (total_score[i*SCORE_W +: SCORE_W])
//        );
//    end
//endgenerate

//assign pipe_valid_out   = pipe_valid_in;
//assign server_valid_out = server_valid_in;

//endmodule 

module tlcm_stage2 #(
    parameter N = 16,
    parameter SCORE_W = $clog2(N)
)(
    input  [N*N-1:0]  score_part,
    input             pipe_valid_in,
    input  [N-1:0]    server_valid_in,

    output [N*SCORE_W-1:0]  total_score,
    output            pipe_valid_out,
    output [N-1:0]    server_valid_out
);

genvar i;

generate
    for (i = 0; i < N; i = i + 1) begin : ROW_SUM
        adder_tree #(
            .N(N),
            .OUT_W(SCORE_W)
        ) u_adder_tree (
            .bits_in (score_part[i*N +: N]),
            .sum_out (total_score[i*SCORE_W +: SCORE_W])
        );
    end
endgenerate

assign pipe_valid_out   = pipe_valid_in;
assign server_valid_out = server_valid_in;

endmodule