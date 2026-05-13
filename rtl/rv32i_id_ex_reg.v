module rv32i_id_ex_reg (
    input wire clk,
    input wire rst,
    input wire enable,                  // !halted
    input wire flush,                   // trap_flush || branch_taken || load_use_stall

    // Data inputs from decode / register file
    input wire        valid_in,
    input wire [31:0] pc_in,
    input wire [31:0] pc4_in,
    input wire [31:0] imm_in,
    input wire [31:0] rs1_value_in,
    input wire [31:0] rs2_value_in,
    input wire [4:0]  rs1_in,
    input wire [4:0]  rs2_in,
    input wire [4:0]  rd_in,
    input wire [2:0]  funct3_in,
    input wire [3:0]  alu_op_in,
    input wire [1:0]  wb_sel_in,
    input wire        reg_write_in,
    input wire        mem_read_in,
    input wire        mem_write_in,
    input wire        use_pc_in,
    input wire        use_imm_in,
    input wire        branch_in,
    input wire        jal_in,
    input wire        jalr_in,
    input wire        rs1_used_in,
    input wire        rs2_used_in,
    input wire        illegal_in,
    input wire        ecall_in,
    input wire        ebreak_in,
    // CSR fields
    input wire        csr_read_in,
    input wire [1:0]  csr_op_in,
    input wire [11:0] csr_addr_in,
    input wire        csr_imm_sel_in,
    input wire        mret_in,

    // Outputs to execute stage
    output reg        valid,
    output reg [31:0] pc,
    output reg [31:0] pc4,
    output reg [31:0] imm,
    output reg [31:0] rs1_value,
    output reg [31:0] rs2_value,
    output reg [4:0]  rs1,
    output reg [4:0]  rs2,
    output reg [4:0]  rd,
    output reg [2:0]  funct3,
    output reg [3:0]  alu_op,
    output reg [1:0]  wb_sel,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        use_pc,
    output reg        use_imm,
    output reg        branch,
    output reg        jal,
    output reg        jalr,
    output reg        rs1_used,
    output reg        rs2_used,
    output reg        illegal,
    output reg        ecall,
    output reg        ebreak,
    // CSR outputs
    output reg        csr_read,
    output reg [1:0]  csr_op,
    output reg [11:0] csr_addr,
    output reg        csr_imm_sel,
    output reg        mret
);

    localparam [3:0] ALU_ADD = 4'd0;
    localparam [1:0] WB_ALU  = 2'b00;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid     <= 1'b0;   pc        <= 32'd0;  pc4       <= 32'd0;
            imm       <= 32'd0;  rs1_value <= 32'd0;  rs2_value <= 32'd0;
            rs1       <= 5'd0;   rs2       <= 5'd0;   rd        <= 5'd0;
            funct3    <= 3'd0;   alu_op    <= ALU_ADD; wb_sel    <= WB_ALU;
            reg_write <= 1'b0;   mem_read  <= 1'b0;   mem_write <= 1'b0;
            use_pc    <= 1'b0;   use_imm   <= 1'b0;   branch    <= 1'b0;
            jal       <= 1'b0;   jalr      <= 1'b0;
            rs1_used  <= 1'b0;   rs2_used  <= 1'b0;
            illegal   <= 1'b0;   ecall     <= 1'b0;   ebreak    <= 1'b0;
            csr_read  <= 1'b0;   csr_op    <= 2'b00;   csr_addr  <= 12'd0;
            csr_imm_sel <= 1'b0; mret      <= 1'b0;
        end else if (enable) begin
            if (flush) begin
                // Insert pipeline bubble — zero everything
                valid     <= 1'b0;   pc        <= 32'd0;  pc4       <= 32'd0;
                imm       <= 32'd0;  rs1_value <= 32'd0;  rs2_value <= 32'd0;
                rs1       <= 5'd0;   rs2       <= 5'd0;   rd        <= 5'd0;
                funct3    <= 3'd0;   alu_op    <= ALU_ADD; wb_sel    <= WB_ALU;
                reg_write <= 1'b0;   mem_read  <= 1'b0;   mem_write <= 1'b0;
                use_pc    <= 1'b0;   use_imm   <= 1'b0;   branch    <= 1'b0;
                jal       <= 1'b0;   jalr      <= 1'b0;
                rs1_used  <= 1'b0;   rs2_used  <= 1'b0;
                illegal   <= 1'b0;   ecall     <= 1'b0;   ebreak    <= 1'b0;
                csr_read  <= 1'b0;   csr_op    <= 2'b00;   csr_addr  <= 12'd0;
                csr_imm_sel <= 1'b0; mret      <= 1'b0;
            end else begin
                // Latch new values from decode stage
                valid     <= valid_in;     pc        <= pc_in;
                pc4       <= pc4_in;       imm       <= imm_in;
                rs1_value <= rs1_value_in; rs2_value <= rs2_value_in;
                rs1       <= rs1_in;       rs2       <= rs2_in;
                rd        <= rd_in;        funct3    <= funct3_in;
                alu_op    <= alu_op_in;    wb_sel    <= wb_sel_in;
                reg_write <= reg_write_in; mem_read  <= mem_read_in;
                mem_write <= mem_write_in; use_pc    <= use_pc_in;
                use_imm   <= use_imm_in;   branch    <= branch_in;
                jal       <= jal_in;       jalr      <= jalr_in;
                rs1_used  <= rs1_used_in;  rs2_used  <= rs2_used_in;
                illegal   <= illegal_in;   ecall     <= ecall_in;
                ebreak    <= ebreak_in;
                csr_read  <= csr_read_in;   csr_op    <= csr_op_in;
                csr_addr  <= csr_addr_in;   csr_imm_sel <= csr_imm_sel_in;
                mret      <= mret_in;
            end
        end
    end

endmodule
