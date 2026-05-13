module rv32i_forwarding_unit (
    input wire id_ex_rs1_used,
    input wire id_ex_rs2_used,
    input wire [4:0] id_ex_rs1,
    input wire [4:0] id_ex_rs2,
    input wire [31:0] id_ex_rs1_value,
    input wire [31:0] id_ex_rs2_value,
    input wire ex_mem_valid,
    input wire ex_mem_reg_write,
    input wire ex_mem_mem_read,
    input wire [4:0] ex_mem_rd,
    input wire [31:0] ex_mem_forward_data,
    input wire mem_wb_valid,
    input wire mem_wb_reg_write,
    input wire [4:0] mem_wb_rd,
    input wire [31:0] wb_write_data,

    output wire [31:0] forward_rs1_value,
    output wire [31:0] forward_rs2_value
);

    assign forward_rs1_value =
        (id_ex_rs1_used && ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read &&
         (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) ? ex_mem_forward_data :
        (id_ex_rs1_used && mem_wb_valid && mem_wb_reg_write &&
         (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) ? wb_write_data :
        id_ex_rs1_value;

    assign forward_rs2_value =
        (id_ex_rs2_used && ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read &&
         (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) ? ex_mem_forward_data :
        (id_ex_rs2_used && mem_wb_valid && mem_wb_reg_write &&
         (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) ? wb_write_data :
        id_ex_rs2_value;

endmodule
