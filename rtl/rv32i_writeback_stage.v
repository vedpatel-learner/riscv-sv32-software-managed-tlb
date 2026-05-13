module rv32i_writeback_stage (
    input wire mem_wb_valid,
    input wire [1:0] mem_wb_wb_sel,
    input wire [31:0] mem_wb_pc4,
    input wire [31:0] mem_wb_alu_result,
    input wire [31:0] mem_wb_load_data,
    input wire mem_wb_reg_write,
    input wire mem_wb_trap_valid,
    input wire [31:0] mem_wb_csr_read_data,
    input wire halted,

    output wire [31:0] wb_write_data,
    output wire wb_write_enable
);

    localparam [1:0] WB_MEM = 2'b01;
    localparam [1:0] WB_PC4 = 2'b10;
    localparam [1:0] WB_CSR = 2'b11;

    assign wb_write_data =
        (mem_wb_wb_sel == WB_MEM) ? mem_wb_load_data :
        (mem_wb_wb_sel == WB_PC4) ? mem_wb_pc4 :
        (mem_wb_wb_sel == WB_CSR) ? mem_wb_csr_read_data :
        mem_wb_alu_result;

    assign wb_write_enable =
        mem_wb_valid &&
        mem_wb_reg_write &&
        !mem_wb_trap_valid &&
        !halted;

endmodule
