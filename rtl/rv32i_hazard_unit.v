module rv32i_hazard_unit (
    input wire if_id_valid,
    input wire id_ex_valid,
    input wire id_ex_mem_read,
    input wire [4:0] id_ex_rd,
    input wire decode_rs1_used,
    input wire decode_rs2_used,
    input wire [4:0] decode_rs1_addr,
    input wire [4:0] decode_rs2_addr,

    output wire load_use_stall
);

    assign load_use_stall =
        if_id_valid &&
        id_ex_valid &&
        id_ex_mem_read &&
        (id_ex_rd != 5'd0) &&
        ((decode_rs1_used && (decode_rs1_addr == id_ex_rd)) ||
         (decode_rs2_used && (decode_rs2_addr == id_ex_rd)));

endmodule
