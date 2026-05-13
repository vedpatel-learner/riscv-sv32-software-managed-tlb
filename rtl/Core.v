module core (
    input wire clk,
    input wire rst,
    input wire data_mem_valid,
    input wire instruc_mem_valid,
    input wire [31:0] instruction,
    input wire [31:0] load_data_in,

    output wire load_signal,
    output wire data_mem_we_re,
    output wire data_mem_request,
    output wire [3:0] mask_singal,
    output wire [31:0] store_data_out,
    output wire [31:0] alu_out_address,
    output wire [31:0] pc_address,
    output wire halted_debug,
    output wire trap_debug,
    output wire [31:0] total_cycles_debug,
    output wire [31:0] stall_cycles_debug,
    output wire [31:0] instr_count_debug,
    output wire [31:0] tlb_access_count_debug,
    output wire [31:0] tlb_hit_count_debug,
    output wire [31:0] tlb_miss_count_debug,
    // ILA debug: pipeline valid bits
    output wire if_id_valid_debug,
    output wire id_ex_valid_debug,
    output wire ex_mem_valid_debug,
    output wire mem_wb_valid_debug,
    // ILA debug: real-time TLB signals
    output wire tlb_hit_rt_debug,
    output wire tlb_lookup_valid_rt_debug,
    // ILA debug: hazard stall
    output wire load_use_stall_debug
);

    // =========================================================================
    //  Constants
    // =========================================================================
    localparam [3:0]  ALU_ADD   = 4'd0;
    localparam [1:0]  WB_ALU   = 2'b00;
    localparam [1:0]  WB_PC4   = 2'b10;
    localparam [1:0]  WB_CSR   = 2'b11;
    localparam [31:0] TRAP_NONE = 32'd0;

    // =========================================================================
    //  Core control registers (PC, performance counters, trap handling)
    // =========================================================================
    reg [31:0] total_cycles;
    reg [31:0] stall_cycles;
    reg [31:0] instr_count;
    reg halted;
    reg trap_flag;
    reg trap_inflight;
    reg handler_mode;
    reg [31:0] pc_reg;

    // =========================================================================
    //  IF/ID pipeline register signals (wires driven by module)
    // =========================================================================
    wire        if_id_valid;
    wire [31:0] if_id_pc;
    wire [31:0] if_id_instruction;

    // =========================================================================
    //  ID/EX pipeline register signals (wires driven by module)
    // =========================================================================
    wire        id_ex_valid;
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_pc4;
    wire [31:0] id_ex_imm;
    wire [31:0] id_ex_rs1_value;
    wire [31:0] id_ex_rs2_value;
    wire [4:0]  id_ex_rs1;
    wire [4:0]  id_ex_rs2;
    wire [4:0]  id_ex_rd;
    wire [2:0]  id_ex_funct3;
    wire [3:0]  id_ex_alu_op;
    wire [1:0]  id_ex_wb_sel;
    wire        id_ex_reg_write;
    wire        id_ex_mem_read;
    wire        id_ex_mem_write;
    wire        id_ex_use_pc;
    wire        id_ex_use_imm;
    wire        id_ex_branch;
    wire        id_ex_jal;
    wire        id_ex_jalr;
    wire        id_ex_rs1_used;
    wire        id_ex_rs2_used;
    wire        id_ex_illegal;
    wire        id_ex_ecall;
    wire        id_ex_ebreak;
    // CSR fields from ID/EX
    wire        id_ex_csr_read;
    wire [1:0]  id_ex_csr_op;
    wire [11:0] id_ex_csr_addr;
    wire        id_ex_csr_imm_sel;
    wire        id_ex_mret;

    // =========================================================================
    //  EX/MEM pipeline register signals (wires driven by module)
    // =========================================================================
    wire        ex_mem_valid;
    wire [31:0] ex_mem_pc;
    wire [31:0] ex_mem_pc4;
    wire [31:0] ex_mem_alu_result;
    wire [31:0] ex_mem_store_data;
    wire [4:0]  ex_mem_rd;
    wire [2:0]  ex_mem_funct3;
    wire [1:0]  ex_mem_wb_sel;
    wire        ex_mem_reg_write;
    wire        ex_mem_mem_read;
    wire        ex_mem_mem_write;
    wire        ex_mem_trap_valid;
    wire [31:0] ex_mem_trap_cause;
    wire [31:0] ex_mem_trap_pc;
    // CSR fields from EX/MEM
    wire [11:0] ex_mem_csr_addr;
    wire [1:0]  ex_mem_csr_op;
    wire [31:0] ex_mem_csr_write_data;
    wire [31:0] ex_mem_csr_read_data;
    wire        ex_mem_csr_write_en;

    // =========================================================================
    //  MEM/WB pipeline register signals (wires driven by module)
    // =========================================================================
    wire        mem_wb_valid;
    wire [31:0] mem_wb_pc4;
    wire [31:0] mem_wb_alu_result;
    wire [31:0] mem_wb_load_data;
    wire [4:0]  mem_wb_rd;
    wire [1:0]  mem_wb_wb_sel;
    wire        mem_wb_reg_write;
    wire        mem_wb_trap_valid;
    wire [31:0] mem_wb_trap_cause;
    wire [31:0] mem_wb_trap_pc;
    wire [31:0] mem_wb_trap_val;
    wire [31:0] mem_wb_csr_read_data;

    // =========================================================================
    //  Decode stage output wires
    // =========================================================================
    wire [4:0]  dec_rs1_addr;
    wire [4:0]  dec_rs2_addr;
    wire [4:0]  dec_rd;
    wire [2:0]  dec_funct3;
    wire [31:0] dec_imm;
    wire [3:0]  dec_alu_op;
    wire [1:0]  dec_wb_sel;
    wire        dec_reg_write;
    wire        dec_mem_read;
    wire        dec_mem_write;
    wire        dec_use_pc;
    wire        dec_use_imm;
    wire        dec_branch;
    wire        dec_jal;
    wire        dec_jalr;
    wire        dec_rs1_used;
    wire        dec_rs2_used;
    wire        dec_illegal;
    wire        dec_ecall;
    wire        dec_ebreak;
    // CSR decode outputs
    wire        dec_csr_read;
    wire [1:0]  dec_csr_op;
    wire [11:0] dec_csr_addr;
    wire        dec_csr_imm_sel;
    wire        dec_mret;

    // =========================================================================
    //  Register File wires
    // =========================================================================
    wire [31:0] rf_rs1_data;
    wire [31:0] rf_rs2_data;

    // =========================================================================
    //  Hazard / Forwarding wires
    // =========================================================================
    wire        load_use_stall;
    wire [31:0] ex_mem_forward_data;
    wire [31:0] forward_rs1_value;
    wire [31:0] forward_rs2_value;

    // =========================================================================
    //  Fetch stage wires
    // =========================================================================
    wire [31:0] fetch_next_pc;
    wire        fetch_if_id_valid_next;
    wire [31:0] fetch_if_id_pc_next;
    wire [31:0] fetch_if_id_instruction_next;

    // =========================================================================
    //  Execute stage wires
    // =========================================================================
    wire [31:0] ex_alu_result;
    wire [31:0] ex_pc_plus4;
    wire [31:0] ex_store_data;
    wire        ex_branch_taken;
    wire [31:0] ex_branch_target;
    wire        ex_trap_valid;
    wire [31:0] ex_trap_cause;

    // =========================================================================
    //  Memory stage wires
    // =========================================================================
    wire [31:0] mem_load_value;
    wire [3:0]  mem_store_mask;
    wire [31:0] mem_store_word;
    wire [31:0] mem_access_address;
    wire        mem_trap_valid;
    wire [31:0] mem_trap_cause;
    wire [31:0] mem_trap_val;

    // =========================================================================
    //  Writeback stage wires
    // =========================================================================
    wire [31:0] wb_write_data;
    wire        wb_write_enable;

    // =========================================================================
    //  CSR Module wires
    // =========================================================================
    wire [31:0] csr_read_data;    // CSR read output (combinational)
    wire [31:0] mepc_out;         // MEPC value for MRET
    wire [31:0] mtvec_out;        // Trap vector address
    wire [31:0] satp_out;         // Page table base (for Phase 2)
    wire        tlb_write_trigger;
    wire [19:0] tlb_write_vpn;
    wire [21:0] tlb_write_ppn;
    wire        tlb_flush_trigger;
    wire        tlb_lookup_valid;
    wire        tlb_hit;
    wire [21:0] tlb_ppn;
    wire [31:0] tlb_access_count;
    wire [31:0] tlb_hit_count;
    wire [31:0] tlb_miss_count;
    wire        translation_enable;

    // =========================================================================
    //  CSR write data computation (EX stage, combinational)
    //  For CSRRWI/CSRRSI/CSRRCI: write data = zero-extended zimm (rs1 field)
    //  For CSRRW/CSRRS/CSRRC:    write data = rs1 value (forwarded)
    // =========================================================================
    wire [31:0] csr_write_value;
    assign csr_write_value = id_ex_csr_imm_sel ? {27'd0, id_ex_rs1} : forward_rs1_value;

    // =========================================================================
    //  Control wires
    // =========================================================================
    wire trap_flush;
    wire mret_flush;
    wire id_ex_flush;

    assign translation_enable = (satp_out != 32'd0) && !handler_mode;
    assign tlb_lookup_valid =
        ex_mem_valid &&
        !ex_mem_trap_valid &&
        (ex_mem_mem_read || ex_mem_mem_write) &&
        translation_enable;

    // Trap detection now includes MEM-stage TLB/page-fault traps.
    assign trap_flush = trap_inflight || ex_trap_valid || mem_trap_valid;

    // MRET detected in EX stage — flush pipeline, PC = MEPC
    assign mret_flush = id_ex_mret && id_ex_valid;

    // Combined flush for ID/EX register
    assign id_ex_flush = trap_flush || mret_flush || ex_branch_taken || load_use_stall;

    // EX/MEM forwarding data (for forwarding unit)
    assign ex_mem_forward_data = (ex_mem_wb_sel == WB_PC4) ? ex_mem_pc4 :
                                 (ex_mem_wb_sel == WB_CSR) ? ex_mem_csr_read_data :
                                 ex_mem_alu_result;

    // =========================================================================
    //  TLB Module Instance
    // =========================================================================
    rv32i_tlb u_tlb (
        .clk(clk),
        .rst(rst),
        .lookup_valid(tlb_lookup_valid),
        .lookup_vpn(ex_mem_alu_result[31:12]),
        .tlb_hit(tlb_hit),
        .tlb_ppn(tlb_ppn),
        .write_enable(tlb_write_trigger),
        .write_vpn(tlb_write_vpn),
        .write_ppn(tlb_write_ppn),
        .flush_all(tlb_flush_trigger),
        .tlb_hit_count(tlb_hit_count),
        .tlb_miss_count(tlb_miss_count),
        .tlb_access_count(tlb_access_count)
    );

    // =========================================================================
    //  CSR Module Instance
    // =========================================================================
    rv32i_csr u_csr (
        .clk(clk),
        .rst(rst),

        // Read port — used in EX stage for CSR read
        .csr_addr_read(id_ex_csr_addr),
        .csr_read_data(csr_read_data),

        // Write port — CSR write happens in MEM stage (ex_mem register has data)
        .csr_write_enable(ex_mem_csr_write_en && ex_mem_valid && !ex_mem_trap_valid),
        .csr_addr_write(ex_mem_csr_addr),
        .csr_write_data(ex_mem_csr_write_data),
        .csr_op(ex_mem_csr_op),

        // Trap entry — from WB stage trap detection
        .trap_enter(mem_wb_valid && mem_wb_trap_valid && !halted),
        .trap_pc(mem_wb_trap_pc),
        .trap_cause(mem_wb_trap_cause),
        .trap_val(mem_wb_trap_val),

        // MRET — executed when MRET is in EX stage
        .mret_execute(mret_flush),
        .mepc_out(mepc_out),

        // Outputs
        .mtvec_out(mtvec_out),
        .satp_out(satp_out),
        .tlb_write_trigger(tlb_write_trigger),
        .tlb_write_vpn(tlb_write_vpn),
        .tlb_write_ppn(tlb_write_ppn),
        .tlb_flush_trigger(tlb_flush_trigger)
    );

    // =========================================================================
    //  IF/ID Pipeline Register
    // =========================================================================
    rv32i_if_id_reg u_if_id_reg (
        .clk(clk),
        .rst(rst),
        .enable(!halted),
        .valid_in(fetch_if_id_valid_next),
        .pc_in(fetch_if_id_pc_next),
        .instruction_in(fetch_if_id_instruction_next),
        .valid(if_id_valid),
        .pc(if_id_pc),
        .instruction(if_id_instruction)
    );

    // =========================================================================
    //  ID/EX Pipeline Register
    // =========================================================================
    rv32i_id_ex_reg u_id_ex_reg (
        .clk(clk),
        .rst(rst),
        .enable(!halted),
        .flush(id_ex_flush),
        .valid_in(if_id_valid),
        .pc_in(if_id_pc),
        .pc4_in(if_id_pc + 32'd4),
        .imm_in(dec_imm),
        .rs1_value_in(rf_rs1_data),
        .rs2_value_in(rf_rs2_data),
        .rs1_in(dec_rs1_addr),
        .rs2_in(dec_rs2_addr),
        .rd_in(dec_rd),
        .funct3_in(dec_funct3),
        .alu_op_in(dec_alu_op),
        .wb_sel_in(dec_wb_sel),
        .reg_write_in(dec_reg_write),
        .mem_read_in(dec_mem_read),
        .mem_write_in(dec_mem_write),
        .use_pc_in(dec_use_pc),
        .use_imm_in(dec_use_imm),
        .branch_in(dec_branch),
        .jal_in(dec_jal),
        .jalr_in(dec_jalr),
        .rs1_used_in(dec_rs1_used),
        .rs2_used_in(dec_rs2_used),
        .illegal_in(dec_illegal),
        .ecall_in(dec_ecall),
        .ebreak_in(dec_ebreak),
        // CSR fields
        .csr_read_in(dec_csr_read),
        .csr_op_in(dec_csr_op),
        .csr_addr_in(dec_csr_addr),
        .csr_imm_sel_in(dec_csr_imm_sel),
        .mret_in(dec_mret),
        // Outputs
        .valid(id_ex_valid),
        .pc(id_ex_pc),
        .pc4(id_ex_pc4),
        .imm(id_ex_imm),
        .rs1_value(id_ex_rs1_value),
        .rs2_value(id_ex_rs2_value),
        .rs1(id_ex_rs1),
        .rs2(id_ex_rs2),
        .rd(id_ex_rd),
        .funct3(id_ex_funct3),
        .alu_op(id_ex_alu_op),
        .wb_sel(id_ex_wb_sel),
        .reg_write(id_ex_reg_write),
        .mem_read(id_ex_mem_read),
        .mem_write(id_ex_mem_write),
        .use_pc(id_ex_use_pc),
        .use_imm(id_ex_use_imm),
        .branch(id_ex_branch),
        .jal(id_ex_jal),
        .jalr(id_ex_jalr),
        .rs1_used(id_ex_rs1_used),
        .rs2_used(id_ex_rs2_used),
        .illegal(id_ex_illegal),
        .ecall(id_ex_ecall),
        .ebreak(id_ex_ebreak),
        // CSR outputs
        .csr_read(id_ex_csr_read),
        .csr_op(id_ex_csr_op),
        .csr_addr(id_ex_csr_addr),
        .csr_imm_sel(id_ex_csr_imm_sel),
        .mret(id_ex_mret)
    );

    // =========================================================================
    //  EX/MEM Pipeline Register
    //  Note: reg_write, mem_read, mem_write gated by !ex_trap_valid
    // =========================================================================
    rv32i_ex_mem_reg u_ex_mem_reg (
        .clk(clk),
        .rst(rst),
        .enable(!halted),
        .flush(mem_trap_valid),
        .valid_in(id_ex_valid),
        .pc_in(id_ex_pc),
        .pc4_in(ex_pc_plus4),
        .alu_result_in(ex_alu_result),
        .store_data_in(ex_store_data),
        .rd_in(id_ex_rd),
        .funct3_in(id_ex_funct3),
        .wb_sel_in(id_ex_wb_sel),
        .reg_write_in(id_ex_reg_write && !ex_trap_valid),
        .mem_read_in(id_ex_mem_read && !ex_trap_valid),
        .mem_write_in(id_ex_mem_write && !ex_trap_valid),
        .trap_valid_in(ex_trap_valid),
        .trap_cause_in(ex_trap_cause),
        .trap_pc_in(id_ex_pc),
        // CSR fields: pass through to MEM stage
        .csr_addr_in(id_ex_csr_addr),
        .csr_op_in(id_ex_csr_op),
        .csr_write_data_in(csr_write_value),
        .csr_read_data_in(csr_read_data),
        .csr_write_en_in(id_ex_csr_read && !ex_trap_valid),
        // Outputs
        .valid(ex_mem_valid),
        .pc(ex_mem_pc),
        .pc4(ex_mem_pc4),
        .alu_result(ex_mem_alu_result),
        .store_data(ex_mem_store_data),
        .rd(ex_mem_rd),
        .funct3(ex_mem_funct3),
        .wb_sel(ex_mem_wb_sel),
        .reg_write(ex_mem_reg_write),
        .mem_read(ex_mem_mem_read),
        .mem_write(ex_mem_mem_write),
        .trap_valid(ex_mem_trap_valid),
        .trap_cause(ex_mem_trap_cause),
        .trap_pc(ex_mem_trap_pc),
        // CSR outputs
        .csr_addr(ex_mem_csr_addr),
        .csr_op(ex_mem_csr_op),
        .csr_write_data(ex_mem_csr_write_data),
        .csr_read_data(ex_mem_csr_read_data),
        .csr_write_en(ex_mem_csr_write_en)
    );

    // =========================================================================
    //  MEM/WB Pipeline Register
    // =========================================================================
    rv32i_mem_wb_reg u_mem_wb_reg (
        .clk(clk),
        .rst(rst),
        .enable(!halted),
        .valid_in(ex_mem_valid),
        .pc4_in(ex_mem_pc4),
        .alu_result_in(ex_mem_alu_result),
        .load_data_in(mem_load_value),
        .rd_in(ex_mem_rd),
        .wb_sel_in(ex_mem_wb_sel),
        .reg_write_in(ex_mem_reg_write),
        .trap_valid_in(mem_trap_valid),
        .trap_cause_in(mem_trap_cause),
        .trap_pc_in(ex_mem_pc),
        .trap_val_in(mem_trap_val),
        .csr_read_data_in(ex_mem_csr_read_data),
        .valid(mem_wb_valid),
        .pc4(mem_wb_pc4),
        .alu_result(mem_wb_alu_result),
        .load_data(mem_wb_load_data),
        .rd(mem_wb_rd),
        .wb_sel(mem_wb_wb_sel),
        .reg_write(mem_wb_reg_write),
        .trap_valid(mem_wb_trap_valid),
        .trap_cause(mem_wb_trap_cause),
        .trap_pc(mem_wb_trap_pc),
        .trap_val(mem_wb_trap_val),
        .csr_read_data(mem_wb_csr_read_data)
    );

    // =========================================================================
    //  Decode Stage (combinational)
    // =========================================================================
    rv32i_decode_stage u_decode_stage (
        .instruction(if_id_instruction),
        .rs1_addr(dec_rs1_addr),
        .rs2_addr(dec_rs2_addr),
        .rd_addr(dec_rd),
        .funct3(dec_funct3),
        .imm(dec_imm),
        .alu_op(dec_alu_op),
        .wb_sel(dec_wb_sel),
        .reg_write(dec_reg_write),
        .mem_read(dec_mem_read),
        .mem_write(dec_mem_write),
        .use_pc(dec_use_pc),
        .use_imm(dec_use_imm),
        .branch(dec_branch),
        .jal(dec_jal),
        .jalr(dec_jalr),
        .rs1_used(dec_rs1_used),
        .rs2_used(dec_rs2_used),
        .illegal(dec_illegal),
        .ecall(dec_ecall),
        .ebreak(dec_ebreak),
        // CSR outputs
        .csr_read(dec_csr_read),
        .csr_op(dec_csr_op),
        .csr_addr(dec_csr_addr),
        .csr_imm_sel(dec_csr_imm_sel),
        .mret(dec_mret)
    );

    // =========================================================================
    //  Register File
    // =========================================================================
    registerfile u_regfile (
        .clk(clk),
        .rst(rst),
        .en(wb_write_enable),
        .rs1(dec_rs1_addr),
        .rs2(dec_rs2_addr),
        .rd(mem_wb_rd),
        .data(wb_write_data),
        .op_a(rf_rs1_data),
        .op_b(rf_rs2_data)
    );

    // =========================================================================
    //  Hazard Detection Unit
    // =========================================================================
    rv32i_hazard_unit u_hazard_unit (
        .if_id_valid(if_id_valid),
        .id_ex_valid(id_ex_valid),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_rd(id_ex_rd),
        .decode_rs1_used(dec_rs1_used),
        .decode_rs2_used(dec_rs2_used),
        .decode_rs1_addr(dec_rs1_addr),
        .decode_rs2_addr(dec_rs2_addr),
        .load_use_stall(load_use_stall)
    );

    // =========================================================================
    //  Forwarding Unit
    // =========================================================================
    rv32i_forwarding_unit u_forwarding_unit (
        .id_ex_rs1_used(id_ex_rs1_used),
        .id_ex_rs2_used(id_ex_rs2_used),
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .id_ex_rs1_value(id_ex_rs1_value),
        .id_ex_rs2_value(id_ex_rs2_value),
        .ex_mem_valid(ex_mem_valid),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_forward_data(ex_mem_forward_data),
        .mem_wb_valid(mem_wb_valid),
        .mem_wb_reg_write(mem_wb_reg_write),
        .mem_wb_rd(mem_wb_rd),
        .wb_write_data(wb_write_data),
        .forward_rs1_value(forward_rs1_value),
        .forward_rs2_value(forward_rs2_value)
    );

    // =========================================================================
    //  Fetch Stage (combinational)
    //  Updated: trap_flush now jumps to MTVEC, mret_flush jumps to MEPC
    // =========================================================================
    rv32i_fetch_stage u_fetch_stage (
        .current_pc(pc_reg),
        .instr_valid(instruc_mem_valid),
        .instruction(instruction),
        .if_id_valid_current(if_id_valid),
        .if_id_pc_current(if_id_pc),
        .if_id_instruction_current(if_id_instruction),
        .trap_flush(trap_flush),
        .mret_flush(mret_flush),
        .mtvec(mtvec_out),
        .mepc(mepc_out),
        .branch_taken(ex_branch_taken),
        .branch_target(ex_branch_target),
        .stall(load_use_stall),
        .next_pc(fetch_next_pc),
        .if_id_valid_next(fetch_if_id_valid_next),
        .if_id_pc_next(fetch_if_id_pc_next),
        .if_id_instruction_next(fetch_if_id_instruction_next)
    );

    // =========================================================================
    //  Execute Stage (combinational)
    // =========================================================================
    rv32i_execute_stage u_execute_stage (
        .valid(id_ex_valid),
        .pc(id_ex_pc),
        .pc4(id_ex_pc4),
        .imm(id_ex_imm),
        .rs1_value(forward_rs1_value),
        .rs2_value(forward_rs2_value),
        .use_pc(id_ex_use_pc),
        .use_imm(id_ex_use_imm),
        .funct3(id_ex_funct3),
        .alu_op(id_ex_alu_op),
        .mem_read(id_ex_mem_read),
        .mem_write(id_ex_mem_write),
        .branch(id_ex_branch),
        .jal(id_ex_jal),
        .jalr(id_ex_jalr),
        .illegal(id_ex_illegal),
        .ecall(id_ex_ecall),
        .ebreak(id_ex_ebreak),
        .alu_result(ex_alu_result),
        .pc_plus4(ex_pc_plus4),
        .store_data(ex_store_data),
        .branch_taken(ex_branch_taken),
        .branch_target(ex_branch_target),
        .trap_valid(ex_trap_valid),
        .trap_cause(ex_trap_cause)
    );

    // =========================================================================
    //  Memory Stage (combinational)
    // =========================================================================
    rv32i_memory_stage u_memory_stage (
        .ex_mem_valid(ex_mem_valid),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_mem_write(ex_mem_mem_write),
        .ex_mem_trap_valid(ex_mem_trap_valid),
        .ex_mem_trap_cause(ex_mem_trap_cause),
        .ex_mem_funct3(ex_mem_funct3),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_store_data(ex_mem_store_data),
        .load_data_in(load_data_in),
        .halted(halted),
        .translation_enable(translation_enable),
        .tlb_hit(tlb_hit),
        .tlb_ppn(tlb_ppn),
        .load_value(mem_load_value),
        .store_mask(mem_store_mask),
        .store_word(mem_store_word),
        .physical_address(mem_access_address),
        .mem_trap_valid(mem_trap_valid),
        .mem_trap_cause(mem_trap_cause),
        .mem_trap_val(mem_trap_val),
        .load_signal(load_signal),
        .data_mem_we_re(data_mem_we_re),
        .data_mem_request(data_mem_request)
    );

    // =========================================================================
    //  Writeback Stage (combinational)
    // =========================================================================
    rv32i_writeback_stage u_writeback_stage (
        .mem_wb_valid(mem_wb_valid),
        .mem_wb_wb_sel(mem_wb_wb_sel),
        .mem_wb_pc4(mem_wb_pc4),
        .mem_wb_alu_result(mem_wb_alu_result),
        .mem_wb_load_data(mem_wb_load_data),
        .mem_wb_reg_write(mem_wb_reg_write),
        .mem_wb_trap_valid(mem_wb_trap_valid),
        .mem_wb_csr_read_data(mem_wb_csr_read_data),
        .halted(halted),
        .wb_write_data(wb_write_data),
        .wb_write_enable(wb_write_enable)
    );

    // =========================================================================
    //  Output assignments
    // =========================================================================
    assign mask_singal = data_mem_we_re ? mem_store_mask : 4'b1111;
    assign store_data_out = data_mem_we_re ? mem_store_word : 32'b0;
    assign alu_out_address = mem_access_address;
    assign pc_address = pc_reg;

    assign halted_debug = halted;
    assign trap_debug = trap_flag;
    assign total_cycles_debug = total_cycles;
    assign stall_cycles_debug = stall_cycles;
    assign instr_count_debug = instr_count;
    assign tlb_access_count_debug = tlb_access_count;
    assign tlb_hit_count_debug = tlb_hit_count;
    assign tlb_miss_count_debug = tlb_miss_count;
    // ILA debug: pipeline valid bits
    assign if_id_valid_debug       = if_id_valid;
    assign id_ex_valid_debug       = id_ex_valid;
    assign ex_mem_valid_debug      = ex_mem_valid;
    assign mem_wb_valid_debug      = mem_wb_valid;
    // ILA debug: real-time TLB signals
    assign tlb_hit_rt_debug        = tlb_hit;
    assign tlb_lookup_valid_rt_debug = tlb_lookup_valid;
    // ILA debug: hazard stall
    assign load_use_stall_debug    = load_use_stall;

    // =========================================================================
    //  PC register, performance counters, and trap handling
    //  KEY CHANGE: Traps now jump to MTVEC instead of halting.
    //              MRET returns from trap handler.
    //              Only EBREAK halts the CPU.
    // =========================================================================
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            total_cycles  <= 32'd0;
            stall_cycles  <= 32'd0;
            instr_count   <= 32'd0;
            halted        <= 1'b0;
            trap_flag     <= 1'b0;
            trap_inflight <= 1'b0;
            handler_mode  <= 1'b0;
            pc_reg        <= 32'd0;
        end else begin
            if (!halted) begin
                // --- Performance counters ---
                total_cycles <= total_cycles + 32'd1;

                if (load_use_stall) begin
                    stall_cycles <= stall_cycles + 32'd1;
                end

                if (mem_wb_valid && !mem_wb_trap_valid) begin
                    instr_count <= instr_count + 32'd1;
                end

                // --- Trap handling ---
                // When a trap reaches WB stage: CSR module saves MEPC/MCAUSE,
                // PC will be redirected to MTVEC via fetch stage.
                // EBREAK is special: it still halts the CPU (for debugger/simulation end)
                if (mem_wb_valid && mem_wb_trap_valid) begin
                    if (mem_wb_trap_cause == 32'd3) begin
                        // EBREAK: halt the CPU
                        halted    <= 1'b1;
                        trap_flag <= 1'b1;
                    end
                end

                if (mem_wb_valid && mem_wb_trap_valid) begin
                    trap_inflight <= 1'b0;
                end else if (ex_trap_valid || mem_trap_valid) begin
                    trap_inflight <= 1'b1;
                end

                if (mret_flush) begin
                    handler_mode <= 1'b0;
                end else if (mem_wb_valid && mem_wb_trap_valid && (mem_wb_trap_cause != 32'd3)) begin
                    handler_mode <= 1'b1;
                end

                // --- PC update ---
                pc_reg <= fetch_next_pc;
            end
        end
    end

endmodule
