////module adder_tree #(
////    parameter N = 16
////)(
////    input  [N-1:0] bits_in,
////    output [N-1:0]   sum_out
////);

////generate
////    if (N == 1) begin : BASE_CASE
////        assign sum_out = {3'b0, bits_in[0]};
////    end
    
////    else if (N == 2) begin : TWO_WAY
////        assign sum_out = {2'b0, bits_in[0]} + {2'b0, bits_in[1]};
////    end
    
////    else begin : RECURSIVE_TREE
////        localparam N_LEFT  = (N + 1) / 2;
////        localparam N_RIGHT = N - N_LEFT;
        
////        wire [N-1:0] sum_left, sum_right;
        
////        adder_tree #(.N(N_LEFT)) left_tree (
////            .bits_in (bits_in[N_LEFT-1:0]),
////            .sum_out (sum_left)
////        );
        
////        adder_tree #(.N(N_RIGHT)) right_tree (
////            .bits_in (bits_in[N-1:N_LEFT]),
////            .sum_out (sum_right)
////        );
        
////        assign sum_out = sum_left + sum_right;
////    end
////endgenerate

////endmodule 

//module adder_tree #(
//    parameter N = 16
//)(
//    input  [N-1:0] bits_in,
//    output [N-1:0]         sum_out
//);

//generate
//    if (N == 1) begin : BASE_CASE
//        assign sum_out = {{(N-1){1'b0}}, bits_in[0]};
//    end
    
//    else if (N == 2) begin : TWO_WAY
//        assign sum_out = {2'b0, bits_in[0]} + {2'b0, bits_in[1]};
//    end
    
//    else begin : RECURSIVE_TREE
//        localparam N_LEFT  = (N + 1) / 2;
//        localparam N_RIGHT = N - N_LEFT;
        
//        wire [N-1:0] sum_left, sum_right;
        
//        adder_tree #(
//            .N(N_LEFT)
//        ) left_tree (
//            .bits_in (bits_in[N_LEFT-1:0]),
//            .sum_out (sum_left)
//        );
        
//        adder_tree #(
//            .N(N_RIGHT)
//        ) right_tree (
//            .bits_in (bits_in[N-1:N_LEFT]),
//            .sum_out (sum_right)
//        );
        
//        assign sum_out = sum_left + sum_right;
//    end
//endgenerate

//endmodule 

module adder_tree #(
    parameter N = 16,
    parameter OUT_W = $clog2(N)
)(
    input  [N-1:0] bits_in,
    output [OUT_W-1:0] sum_out
);

generate
    if (N == 1) begin : BASE_CASE
//        assign sum_out = {3'b0, bits_in[0]};
        assign sum_out = bits_in[0];
    end
    
    else if (N == 2) begin : TWO_WAY
//        assign sum_out = {2'b0, bits_in[0]} + {2'b0, bits_in[1]};
        assign sum_out = bits_in[0] + bits_in[1];
    end
    
    else begin : RECURSIVE_TREE
        localparam N_LEFT  = (N + 1) / 2;
        localparam N_RIGHT = N - N_LEFT;
        
        wire [OUT_W-1:0] sum_left, sum_right;
        
        adder_tree #(
            .N(N_LEFT),
            .OUT_W(OUT_W)
        ) left_tree (
            .bits_in (bits_in[N_LEFT-1:0]),
            .sum_out (sum_left)
        );
        
        adder_tree #(
            .N(N_RIGHT),
            .OUT_W(OUT_W)
        ) right_tree (
            .bits_in (bits_in[N-1:N_LEFT]),
            .sum_out (sum_right)
        );
        
        assign sum_out = sum_left + sum_right;
    end
endgenerate

endmodule