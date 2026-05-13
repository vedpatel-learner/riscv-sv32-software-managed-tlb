module alu (a_i,b_i,op_i,res_o);

    input wire [31:0] a_i;
    input wire [31:0] b_i;
    input wire [3:0] op_i;

    output reg [31:0] res_o;

    always @(*) begin
        case (op_i)
            4'b0000: res_o = a_i + b_i;
            4'b0001: res_o = a_i - b_i;
            4'b0010: res_o = a_i << b_i[4:0];
            4'b0011: res_o = ($signed(a_i) < $signed(b_i)) ? 32'd1 : 32'd0;
            4'b0100: res_o = (a_i < b_i) ? 32'd1 : 32'd0;
            4'b0101: res_o = a_i ^ b_i;
            4'b0110: res_o = a_i >> b_i[4:0];
            4'b0111: res_o = $signed(a_i) >>> b_i[4:0];
            4'b1000: res_o = a_i | b_i;
            4'b1001: res_o = a_i & b_i;
            4'b1111: res_o = b_i;
            default: res_o = 32'd0;
        endcase
    end
endmodule
