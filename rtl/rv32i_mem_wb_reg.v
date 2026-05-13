module rv32i_mem_wb_reg (
    input wire clk,
    input wire rst,
    input wire enable,                  // !halted

    // Data inputs from memory stage
    input wire        valid_in,
    input wire [31:0] pc4_in,
    input wire [31:0] alu_result_in,
    input wire [31:0] load_data_in,
    input wire [4:0]  rd_in,
    input wire [1:0]  wb_sel_in,
    input wire        reg_write_in,
    input wire        trap_valid_in,
    input wire [31:0] trap_cause_in,
    input wire [31:0] trap_pc_in,
    input wire [31:0] trap_val_in,
    input wire [31:0] csr_read_data_in,

    // Outputs to writeback stage
    output reg        valid,
    output reg [31:0] pc4,
    output reg [31:0] alu_result,
    output reg [31:0] load_data,
    output reg [4:0]  rd,
    output reg [1:0]  wb_sel,
    output reg        reg_write,
    output reg        trap_valid,
    output reg [31:0] trap_cause,
    output reg [31:0] trap_pc,
    output reg [31:0] trap_val,
    output reg [31:0] csr_read_data
);

    localparam [1:0]  WB_ALU    = 2'b00;
    localparam [31:0] TRAP_NONE = 32'd0;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid      <= 1'b0;      pc4        <= 32'd0;
            alu_result <= 32'd0;     load_data  <= 32'd0;
            rd         <= 5'd0;      wb_sel     <= WB_ALU;
            reg_write  <= 1'b0;      trap_valid <= 1'b0;
            trap_cause <= TRAP_NONE; trap_pc    <= 32'd0;
            trap_val   <= 32'd0;
            csr_read_data <= 32'd0;
        end else if (enable) begin
            valid      <= valid_in;      pc4        <= pc4_in;
            alu_result <= alu_result_in; load_data  <= load_data_in;
            rd         <= rd_in;         wb_sel     <= wb_sel_in;
            reg_write  <= reg_write_in;  trap_valid <= trap_valid_in;
            trap_cause <= trap_cause_in; trap_pc    <= trap_pc_in;
            trap_val   <= trap_val_in;
            csr_read_data <= csr_read_data_in;
        end
    end

endmodule
