module registerfile (
    input wire clk,
    input wire rst,
    input wire en,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] data,

    output wire [31:0] op_a,
    output wire [31:0] op_b
);

    reg [31:0] register [31:0];   // same name preserved
    integer i;

    always @(posedge clk) begin
        if (!rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                register[i] <= 32'b0;
            end
        end
        else begin
            if (en && rd != 0) begin
                register[rd] <= data;
            end
        end
    end

    assign op_a = (rs1 != 0) ? 
                  ((rs1 == rd && en) ? data : register[rs1]) 
                  : 32'b0;

    assign op_b = (rs2 != 0) ? 
                  ((rs2 == rd && en) ? data : register[rs2]) 
                  : 32'b0;

endmodule