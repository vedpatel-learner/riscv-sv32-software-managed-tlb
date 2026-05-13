module rv32i_ex_mem_reg (
    input wire clk,
    input wire rst,
    input wire enable,                  // !halted
    input wire flush,

    // Data inputs from execute stage
    input wire        valid_in,
    input wire [31:0] pc_in,
    input wire [31:0] pc4_in,
    input wire [31:0] alu_result_in,
    input wire [31:0] store_data_in,
    input wire [4:0]  rd_in,
    input wire [2:0]  funct3_in,
    input wire [1:0]  wb_sel_in,
    input wire        reg_write_in,
    input wire        mem_read_in,
    input wire        mem_write_in,
    input wire        trap_valid_in,
    input wire [31:0] trap_cause_in,
    input wire [31:0] trap_pc_in,
    // CSR fields
    input wire [11:0] csr_addr_in,
    input wire [1:0]  csr_op_in,
    input wire [31:0] csr_write_data_in,
    input wire [31:0] csr_read_data_in,
    input wire        csr_write_en_in,

    // Outputs to memory stage
    output reg        valid,
    output reg [31:0] pc,
    output reg [31:0] pc4,
    output reg [31:0] alu_result,
    output reg [31:0] store_data,
    output reg [4:0]  rd,
    output reg [2:0]  funct3,
    output reg [1:0]  wb_sel,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        trap_valid,
    output reg [31:0] trap_cause,
    output reg [31:0] trap_pc,
    // CSR outputs
    output reg [11:0] csr_addr,
    output reg [1:0]  csr_op,
    output reg [31:0] csr_write_data,
    output reg [31:0] csr_read_data,
    output reg        csr_write_en
);

    localparam [1:0]  WB_ALU    = 2'b00;
    localparam [31:0] TRAP_NONE = 32'd0;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid      <= 1'b0;      pc         <= 32'd0;
            pc4        <= 32'd0;     alu_result <= 32'd0;
            store_data <= 32'd0;     rd         <= 5'd0;
            funct3     <= 3'd0;      wb_sel     <= WB_ALU;
            reg_write  <= 1'b0;      mem_read   <= 1'b0;
            mem_write  <= 1'b0;      trap_valid <= 1'b0;
            trap_cause <= TRAP_NONE; trap_pc    <= 32'd0;
            csr_addr   <= 12'd0;     csr_op     <= 2'b00;
            csr_write_data <= 32'd0; csr_read_data <= 32'd0;
            csr_write_en <= 1'b0;
        end else if (enable) begin
            if (flush) begin
                valid      <= 1'b0;      pc         <= 32'd0;
                pc4        <= 32'd0;     alu_result <= 32'd0;
                store_data <= 32'd0;     rd         <= 5'd0;
                funct3     <= 3'd0;      wb_sel     <= WB_ALU;
                reg_write  <= 1'b0;      mem_read   <= 1'b0;
                mem_write  <= 1'b0;      trap_valid <= 1'b0;
                trap_cause <= TRAP_NONE; trap_pc    <= 32'd0;
                csr_addr   <= 12'd0;     csr_op     <= 2'b00;
                csr_write_data <= 32'd0; csr_read_data <= 32'd0;
                csr_write_en <= 1'b0;
            end else begin
                valid      <= valid_in;      pc         <= pc_in;
                pc4        <= pc4_in;        alu_result <= alu_result_in;
                store_data <= store_data_in; rd         <= rd_in;
                funct3     <= funct3_in;     wb_sel     <= wb_sel_in;
                reg_write  <= reg_write_in;  mem_read   <= mem_read_in;
                mem_write  <= mem_write_in;  trap_valid <= trap_valid_in;
                trap_cause <= trap_cause_in; trap_pc    <= trap_pc_in;
                csr_addr   <= csr_addr_in;    csr_op     <= csr_op_in;
                csr_write_data <= csr_write_data_in; csr_read_data <= csr_read_data_in;
                csr_write_en <= csr_write_en_in;
            end
        end
    end

endmodule
