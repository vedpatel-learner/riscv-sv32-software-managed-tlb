module rv32i_execute_stage (
    input wire valid,
    input wire [31:0] pc,
    input wire [31:0] pc4,
    input wire [31:0] imm,
    input wire [31:0] rs1_value,
    input wire [31:0] rs2_value,
    input wire use_pc,
    input wire use_imm,
    input wire [2:0] funct3,
    input wire [3:0] alu_op,
    input wire mem_read,
    input wire mem_write,
    input wire branch,
    input wire jal,
    input wire jalr,
    input wire illegal,
    input wire ecall,
    input wire ebreak,

    output wire [31:0] alu_result,
    output wire [31:0] pc_plus4,
    output wire [31:0] store_data,
    output wire branch_taken,
    output wire [31:0] branch_target,
    output wire trap_valid,
    output wire [31:0] trap_cause
);

    localparam [31:0] TRAP_INST_MISALIGNED  = 32'd0;
    localparam [31:0] TRAP_ILLEGAL_INSTR    = 32'd2;
    localparam [31:0] TRAP_BREAKPOINT       = 32'd3;
    localparam [31:0] TRAP_LOAD_MISALIGNED  = 32'd4;
    localparam [31:0] TRAP_STORE_MISALIGNED = 32'd6;
    localparam [31:0] TRAP_ECALL_MMODE      = 32'd11;

    wire [31:0] operand_a;
    wire [31:0] operand_b;
    wire control_taken_raw;
    wire pc_misaligned;
    wire mem_misaligned;

    function branch_compare;
        input [2:0] cmp_funct3;
        input [31:0] op_a;
        input [31:0] op_b;
        begin
            case (cmp_funct3)
                3'b000: branch_compare = (op_a == op_b);
                3'b001: branch_compare = (op_a != op_b);
                3'b100: branch_compare = ($signed(op_a) < $signed(op_b));
                3'b101: branch_compare = ($signed(op_a) >= $signed(op_b));
                3'b110: branch_compare = (op_a < op_b);
                3'b111: branch_compare = (op_a >= op_b);
                default: branch_compare = 1'b0;
            endcase
        end
    endfunction

    function misaligned_access;
        input cmp_mem_read;
        input cmp_mem_write;
        input [2:0] cmp_funct3;
        input [1:0] addr_low;
        begin
            misaligned_access = 1'b0;
            if (cmp_mem_read || cmp_mem_write) begin
                case (cmp_funct3)
                    3'b001,
                    3'b101: misaligned_access = addr_low[0];
                    3'b010: misaligned_access = (addr_low != 2'b00);
                    default: misaligned_access = 1'b0;
                endcase
            end
        end
    endfunction

    assign operand_a = use_pc ? pc : rs1_value;
    assign operand_b = use_imm ? imm : rs2_value;
    assign pc_plus4 = pc4;
    assign store_data = rs2_value;

    alu u_alu (
        .a_i(operand_a),
        .b_i(operand_b),
        .op_i(alu_op),
        .res_o(alu_result)
    );

    assign control_taken_raw =
        valid &&
        (jal || jalr || (branch && branch_compare(funct3, rs1_value, rs2_value)));

    assign branch_target = jalr ? {alu_result[31:1], 1'b0} : alu_result;
    assign pc_misaligned = control_taken_raw && (branch_target[1:0] != 2'b00);
    assign branch_taken = control_taken_raw && !pc_misaligned;
    assign mem_misaligned = misaligned_access(mem_read, mem_write, funct3, alu_result[1:0]);

    assign trap_valid =
        valid &&
        (illegal || ecall || ebreak || pc_misaligned || mem_misaligned);

    assign trap_cause =
        illegal ? TRAP_ILLEGAL_INSTR :
        ecall ? TRAP_ECALL_MMODE :
        ebreak ? TRAP_BREAKPOINT :
        pc_misaligned ? TRAP_INST_MISALIGNED :
        mem_read ? TRAP_LOAD_MISALIGNED :
        TRAP_STORE_MISALIGNED;

endmodule
