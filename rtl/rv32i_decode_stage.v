module rv32i_decode_stage (
    input wire [31:0] instruction,

    output wire [4:0] rs1_addr,
    output wire [4:0] rs2_addr,
    output wire [4:0] rd_addr,
    output wire [2:0] funct3,
    output reg [31:0] imm,
    output reg [3:0] alu_op,
    output reg [1:0] wb_sel,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg use_pc,
    output reg use_imm,
    output reg branch,
    output reg jal,
    output reg jalr,
    output reg rs1_used,
    output reg rs2_used,
    output reg illegal,
    output reg ecall,
    output reg ebreak,

    // CSR outputs
    output reg        csr_read,      // Instruction reads a CSR
    output reg [1:0]  csr_op,        // 01=CSRRW, 10=CSRRS, 11=CSRRC
    output wire [11:0] csr_addr,      // CSR address (instruction[31:20])
    output reg        csr_imm_sel,   // 1 = use zimm (CSRRWI/CSRRSI/CSRRCI)
    output reg        mret           // MRET instruction
);

    localparam [3:0] ALU_ADD  = 4'd0;
    localparam [3:0] ALU_SUB  = 4'd1;
    localparam [3:0] ALU_SLL  = 4'd2;
    localparam [3:0] ALU_SLT  = 4'd3;
    localparam [3:0] ALU_SLTU = 4'd4;
    localparam [3:0] ALU_XOR  = 4'd5;
    localparam [3:0] ALU_SRL  = 4'd6;
    localparam [3:0] ALU_SRA  = 4'd7;
    localparam [3:0] ALU_OR   = 4'd8;
    localparam [3:0] ALU_AND  = 4'd9;
    localparam [3:0] ALU_PASS = 4'd15;

    localparam [1:0] WB_ALU = 2'b00;
    localparam [1:0] WB_MEM = 2'b01;
    localparam [1:0] WB_PC4 = 2'b10;
    localparam [1:0] WB_CSR = 2'b11;

    wire [6:0] opcode;
    wire [6:0] funct7;
    wire [11:0] system_imm;
    wire [31:0] funct32;  // Full 32-bit instruction for MRET matching

    function [31:0] imm_i;
        input [31:0] instr;
        begin
            imm_i = {{20{instr[31]}}, instr[31:20]};
        end
    endfunction

    function [31:0] imm_s;
        input [31:0] instr;
        begin
            imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        end
    endfunction

    function [31:0] imm_b;
        input [31:0] instr;
        begin
            imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        end
    endfunction

    function [31:0] imm_u;
        input [31:0] instr;
        begin
            imm_u = {instr[31:12], 12'b0};
        end
    endfunction

    function [31:0] imm_j;
        input [31:0] instr;
        begin
            imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
        end
    endfunction

    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];
    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign rd_addr = instruction[11:7];
    assign system_imm = instruction[31:20];
    assign csr_addr = instruction[31:20];
    assign funct32 = instruction;

    always @(*) begin
        imm = 32'b0;
        alu_op = ALU_ADD;
        wb_sel = WB_ALU;
        reg_write = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        use_pc = 1'b0;
        use_imm = 1'b0;
        branch = 1'b0;
        jal = 1'b0;
        jalr = 1'b0;
        rs1_used = 1'b0;
        rs2_used = 1'b0;
        illegal = 1'b0;
        ecall = 1'b0;
        ebreak = 1'b0;
        csr_read = 1'b0;
        csr_op = 2'b00;
        csr_imm_sel = 1'b0;
        mret = 1'b0;

        case (opcode)
            7'b0110011: begin
                reg_write = 1'b1;
                rs1_used = 1'b1;
                rs2_used = 1'b1;
                case ({funct7, funct3})
                    10'b0000000_000: alu_op = ALU_ADD;
                    10'b0100000_000: alu_op = ALU_SUB;
                    10'b0000000_001: alu_op = ALU_SLL;
                    10'b0000000_010: alu_op = ALU_SLT;
                    10'b0000000_011: alu_op = ALU_SLTU;
                    10'b0000000_100: alu_op = ALU_XOR;
                    10'b0000000_101: alu_op = ALU_SRL;
                    10'b0100000_101: alu_op = ALU_SRA;
                    10'b0000000_110: alu_op = ALU_OR;
                    10'b0000000_111: alu_op = ALU_AND;
                    default: illegal = 1'b1;
                endcase
            end

            7'b0010011: begin
                reg_write = 1'b1;
                rs1_used = 1'b1;
                use_imm = 1'b1;
                imm = imm_i(instruction);
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b001: begin
                        imm = {27'b0, instruction[24:20]};
                        if (funct7 == 7'b0000000) begin
                            alu_op = ALU_SLL;
                        end else begin
                            illegal = 1'b1;
                        end
                    end
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: begin
                        imm = {27'b0, instruction[24:20]};
                        if (funct7 == 7'b0000000) begin
                            alu_op = ALU_SRL;
                        end else if (funct7 == 7'b0100000) begin
                            alu_op = ALU_SRA;
                        end else begin
                            illegal = 1'b1;
                        end
                    end
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: illegal = 1'b1;
                endcase
            end

            7'b0000011: begin
                reg_write = 1'b1;
                mem_read = 1'b1;
                rs1_used = 1'b1;
                use_imm = 1'b1;
                wb_sel = WB_MEM;
                imm = imm_i(instruction);
                case (funct3)
                    3'b000,
                    3'b001,
                    3'b010,
                    3'b100,
                    3'b101: alu_op = ALU_ADD;
                    default: illegal = 1'b1;
                endcase
            end

            7'b0100011: begin
                mem_write = 1'b1;
                rs1_used = 1'b1;
                rs2_used = 1'b1;
                use_imm = 1'b1;
                imm = imm_s(instruction);
                case (funct3)
                    3'b000,
                    3'b001,
                    3'b010: alu_op = ALU_ADD;
                    default: illegal = 1'b1;
                endcase
            end

            7'b1100011: begin
                branch = 1'b1;
                rs1_used = 1'b1;
                rs2_used = 1'b1;
                use_pc = 1'b1;
                use_imm = 1'b1;
                imm = imm_b(instruction);
                case (funct3)
                    3'b000,
                    3'b001,
                    3'b100,
                    3'b101,
                    3'b110,
                    3'b111: alu_op = ALU_ADD;
                    default: illegal = 1'b1;
                endcase
            end

            7'b1101111: begin
                reg_write = 1'b1;
                use_pc = 1'b1;
                use_imm = 1'b1;
                wb_sel = WB_PC4;
                jal = 1'b1;
                imm = imm_j(instruction);
                alu_op = ALU_ADD;
            end

            7'b1100111: begin
                reg_write = 1'b1;
                rs1_used = 1'b1;
                use_imm = 1'b1;
                wb_sel = WB_PC4;
                jalr = 1'b1;
                imm = imm_i(instruction);
                if (funct3 == 3'b000) begin
                    alu_op = ALU_ADD;
                end else begin
                    illegal = 1'b1;
                end
            end

            7'b0110111: begin
                reg_write = 1'b1;
                use_imm = 1'b1;
                imm = imm_u(instruction);
                alu_op = ALU_PASS;
            end

            7'b0010111: begin
                reg_write = 1'b1;
                use_pc = 1'b1;
                use_imm = 1'b1;
                imm = imm_u(instruction);
                alu_op = ALU_ADD;
            end

            7'b0001111: begin
                if ((funct3 != 3'b000) && (funct3 != 3'b001)) begin
                    illegal = 1'b1;
                end
            end

            7'b1110011: begin
                if (funct3 == 3'b000) begin
                    // ECALL, EBREAK, MRET (funct3 = 000)
                    if (funct32 == 32'h30200073) begin
                        // MRET
                        mret = 1'b1;
                    end else if ((rs1_addr == 5'd0) && (rd_addr == 5'd0)) begin
                        if (system_imm == 12'h000) begin
                            ecall = 1'b1;
                        end else if (system_imm == 12'h001) begin
                            ebreak = 1'b1;
                        end else begin
                            illegal = 1'b1;
                        end
                    end else begin
                        illegal = 1'b1;
                    end
                end else begin
                    // CSR instructions (funct3 = 001, 010, 011, 101, 110, 111)
                    case (funct3)
                        3'b001: begin  // CSRRW
                            csr_read = 1'b1;
                            csr_op = 2'b01;
                            rs1_used = 1'b1;
                            reg_write = 1'b1;
                            wb_sel = WB_CSR;
                        end
                        3'b010: begin  // CSRRS
                            csr_read = 1'b1;
                            csr_op = 2'b10;
                            rs1_used = 1'b1;
                            reg_write = 1'b1;
                            wb_sel = WB_CSR;
                        end
                        3'b011: begin  // CSRRC
                            csr_read = 1'b1;
                            csr_op = 2'b11;
                            rs1_used = 1'b1;
                            reg_write = 1'b1;
                            wb_sel = WB_CSR;
                        end
                        3'b101: begin  // CSRRWI
                            csr_read = 1'b1;
                            csr_op = 2'b01;
                            csr_imm_sel = 1'b1;
                            reg_write = 1'b1;
                            wb_sel = WB_CSR;
                        end
                        3'b110: begin  // CSRRSI
                            csr_read = 1'b1;
                            csr_op = 2'b10;
                            csr_imm_sel = 1'b1;
                            reg_write = 1'b1;
                            wb_sel = WB_CSR;
                        end
                        3'b111: begin  // CSRRCI
                            csr_read = 1'b1;
                            csr_op = 2'b11;
                            csr_imm_sel = 1'b1;
                            reg_write = 1'b1;
                            wb_sel = WB_CSR;
                        end
                        default: begin
                            illegal = 1'b1;
                        end
                    endcase
                end
            end

            default: begin
                illegal = 1'b1;
            end
        endcase
    end

endmodule
