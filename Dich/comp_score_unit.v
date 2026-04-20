//module comp_score_unit #(
//    parameter N = 16,
//    parameter DATA_W = 12,
//    parameter IDX_W  = $clog2(N)
//)(
//    input  [DATA_W-1:0] A,     // SCN[i]
//    input  [DATA_W-1:0] B,     // SCN[j]
//    input  [IDX_W-1:0]  i,     // index i
//    input  [IDX_W-1:0]  j,     // index j
//    input  [IDX_W-1:0]  tie_bias, // rotating tie-break origin
//    input  [N-1:0]      ena,   // valid[j]
//    output reg          score
//);

//wire [IDX_W-1:0] rank_i = i - tie_bias;
//wire [IDX_W-1:0] rank_j = j - tie_bias;

//always @(*) begin
//    if (!(ena[i] && ena[j])) begin
//        score = 1'b0;
//    end
//    else if (A < B) begin
//        score = 1'b1;
//    end
//    else if (A > B) begin
//        score = 1'b0;
//    end
//    else begin
//        // Tie-break with rotating priority so equal SCN does not starve fixed indices.
//        if (rank_i > rank_j)
////        if (i > j)            
//            score = 1'b1;
//        else
//            score = 1'b0;
//    end
//end

//endmodule


module comp_score_unit #(
    parameter N = 16,
    parameter DATA_W = 12,
    parameter IDX_W  = $clog2(N)
)(
    input  [DATA_W-1:0] A,     // SCN[i]
    input  [DATA_W-1:0] B,     // SCN[j]
    input  [IDX_W-1:0]  i,     // index i
    input  [IDX_W-1:0]  j,     // index j
//    input  [IDX_W-1:0]  tie_bias, // rotating tie-break origin
    input  [N-1:0]      ena,   // valid[j]
    output reg          score
);

//wire [IDX_W-1:0] rank_i = i - tie_bias;
//wire [IDX_W-1:0] rank_j = j - tie_bias;

always @(*) begin
    if (!(ena[i] && ena[j])) begin
        score = 1'b0;
    end
    else if (A < B) begin
        score = 1'b1;
    end
    else if (A > B) begin
        score = 1'b0;
    end
    else begin
        // Tie-break with rotating priority so equal SCN does not starve fixed indices.
//        if (rank_i > rank_j)
        if (i > j)
            score = 1'b1;
        else
            score = 1'b0;
    end
end

endmodule