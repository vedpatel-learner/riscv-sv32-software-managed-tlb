module rv32i_if_id_reg (
    input wire clk,
    input wire rst,
    input wire enable,                  // !halted

    // Inputs from fetch stage
    input wire valid_in,
    input wire [31:0] pc_in,
    input wire [31:0] instruction_in,

    // Outputs to decode stage
    output reg valid,
    output reg [31:0] pc,
    output reg [31:0] instruction
);

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid       <= 1'b0;
            pc          <= 32'd0;
            instruction <= 32'd0;
        end else if (enable) begin
            valid       <= valid_in;
            pc          <= pc_in;
            instruction <= instruction_in;
        end
    end

endmodule
