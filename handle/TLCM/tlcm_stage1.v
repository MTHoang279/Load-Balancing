//module tlcm_stage1 #(
//    parameter N      = 16,
//    parameter DATA_W = 12,
//    parameter IDX_W  = $clog2(N)
//)(
//    input  [N*DATA_W-1:0] scn,
//    input  [N-1:0]        server_valid,
//    input  [IDX_W-1:0]    tie_bias,

//    output [N*N-1:0]      score_part,
//    output [N-1:0]        server_valid_out
//);

//genvar i, j;

//generate
//    for (i = 0; i < N; i = i + 1) begin : GEN_I
//        for (j = 0; j < N; j = j + 1) begin : GEN_J
//            comp_score_unit #(
//                .N     (N),
//                .DATA_W(DATA_W),
//                .IDX_W (IDX_W)
//            ) u_cmp (
//                .A     (scn[i*DATA_W +: DATA_W]),
//                .B     (scn[j*DATA_W +: DATA_W]),
//                .i     (i[IDX_W-1:0]),
//                .j     (j[IDX_W-1:0]),
//                .tie_bias(tie_bias),
//                .ena   (server_valid),
//                .score (score_part[i*N + j])
//            );
//        end
//    end
//endgenerate

//assign server_valid_out = server_valid;

//endmodule


module tlcm_stage1 #(
    parameter N      = 16,
    parameter DATA_W = 12,
    parameter IDX_W  = $clog2(N)
)(
    input  [N*DATA_W-1:0] scn,
    input  [N-1:0]        server_valid,
    input  [IDX_W-1:0]    tie_bias,

    output [N*N-1:0]      score_part,
    output [N-1:0]        server_valid_out
);

genvar i, j;

generate
    for (i = 0; i < N; i = i + 1) begin : GEN_I
        for (j = 0; j < N; j = j + 1) begin : GEN_J
            comp_score_unit #(
                .N     (N),
                .DATA_W(DATA_W),
                .IDX_W (IDX_W)
            ) u_cmp (
                .A     (scn[i*DATA_W +: DATA_W]),
                .B     (scn[j*DATA_W +: DATA_W]),
                .i     (i[IDX_W-1:0]),
                .j     (j[IDX_W-1:0]),
                .tie_bias(tie_bias),
                .ena   (server_valid),
                .score (score_part[i*N + j])
            );
        end
    end
endgenerate

assign server_valid_out = server_valid;

endmodule
