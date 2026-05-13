`timescale 1ns/1ps

// ============================================================================
//  Phase 1 CSR Verification Testbench
//  Tests: CSR read/write (CSRRW/CSRRS/CSRRC/CSRRWI),
//         ECALL → MTVEC → handler → MRET → continue
// ============================================================================
module csr_test_tb();

    reg clk;
    reg rst;
    wire [3:0] led;

    microprocessor #(
        .INSTR_FILE("C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/test_csr_instr.mem")
    ) uut (
        .clk(clk),
        .rst(rst),
        .led(led)
    );

    // 10ns clock period (100 MHz)
    always #5 clk = ~clk;

    integer cycle_count;
    integer errors;
    integer i;

    // =========================================================================
    //  Detailed pipeline trace (first N cycles after reset)
    // =========================================================================
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count <= cycle_count + 1;

            // Trace first 30 cycles for debugging
            if (cycle_count <= 30) begin
                $display("=== Cycle %0d ===", cycle_count);
                $display("  PC=0x%03h  halted=%b  trap_inflight=%b  trap_flag=%b",
                    uut.u_core.pc_reg,
                    uut.u_core.halted,
                    uut.u_core.trap_inflight,
                    uut.u_core.trap_flag);
                $display("  trap_flush=%b  mret_flush=%b  ex_branch_taken=%b  load_use_stall=%b",
                    uut.u_core.trap_flush,
                    uut.u_core.mret_flush,
                    uut.u_core.ex_branch_taken,
                    uut.u_core.load_use_stall);
                $display("  IF/ID: valid=%b  pc=0x%03h  instr=%08h",
                    uut.u_core.if_id_valid,
                    uut.u_core.if_id_pc,
                    uut.u_core.if_id_instruction);
                $display("  ID/EX: valid=%b  pc=0x%03h  rd=%0d  mret=%b  csr_read=%b  csr_addr=0x%03h",
                    uut.u_core.id_ex_valid,
                    uut.u_core.id_ex_pc,
                    uut.u_core.id_ex_rd,
                    uut.u_core.id_ex_mret,
                    uut.u_core.id_ex_csr_read,
                    uut.u_core.id_ex_csr_addr);
                $display("  EX/MEM: valid=%b  pc=0x%03h  rd=%0d  trap=%b  csr_we=%b",
                    uut.u_core.ex_mem_valid,
                    uut.u_core.ex_mem_pc,
                    uut.u_core.ex_mem_rd,
                    uut.u_core.ex_mem_trap_valid,
                    uut.u_core.ex_mem_csr_write_en);
                $display("  MEM/WB: valid=%b  rd=%0d  trap=%b",
                    uut.u_core.mem_wb_valid,
                    uut.u_core.mem_wb_rd,
                    uut.u_core.mem_wb_trap_valid);
                $display("  CSR: mtvec=0x%08h  mepc=0x%08h  mcause=%0d  mstatus=0x%08h",
                    uut.u_core.u_csr.mtvec,
                    uut.u_core.u_csr.mepc,
                    uut.u_core.u_csr.mcause,
                    uut.u_core.u_csr.mstatus);
                $display("  csr_read_data=0x%08h  fwd_rs1=0x%08h",
                    uut.u_core.csr_read_data,
                    uut.u_core.forward_rs1_value);
            end
        end
    end

    // =========================================================================
    //  Main test sequence
    // =========================================================================
    initial begin
        clk = 0;
        rst = 1;
        errors = 0;
        cycle_count = 0;

        #27;  // Release reset between clock edges
        rst = 0;

        // Wait for CPU to halt (via EBREAK)
        wait(uut.u_core.halted || uut.u_core.trap_flag);
        #30;

        // =====================================================================
        //  Verification
        // =====================================================================
        $display("");
        $display("================================================================");
        $display("     PHASE 1: CSR INFRASTRUCTURE VERIFICATION REPORT");
        $display("================================================================");
        $display("");

        // --- Performance ---
        $display("--- Performance Counters ---");
        $display("  Total Cycles      : %0d", uut.u_core.total_cycles);
        $display("  Stall Cycles      : %0d", uut.u_core.stall_cycles);
        $display("  Retired Instrs    : %0d", uut.u_core.instr_count);
        $display("  Halted            : %b",  uut.u_core.halted);
        $display("  Trap Flag         : %b",  uut.u_core.trap_flag);
        $display("");

        // --- CSR Final State ---
        // NOTE: EBREAK at end triggers cause=3 trap, overwriting MEPC/MCAUSE
        //       and clearing MSTATUS[3] (MIE bit)
        $display("--- CSR Register State ---");
        $display("  MTVEC    = 0x%08h  (expected: 0x00000100)", uut.u_core.u_csr.mtvec);
        $display("  MEPC     = 0x%08h  (expected: 0x0000008C)", uut.u_core.u_csr.mepc);
        $display("  MCAUSE   = 0x%08h  (expected: 0x00000003)", uut.u_core.u_csr.mcause);
        $display("  MSTATUS  = 0x%08h  (expected: 0x00000017)", uut.u_core.u_csr.mstatus);
        $display("  MSCRATCH = 0x%08h  (expected: 0x00001000)", uut.u_core.u_csr.mscratch);
        $display("");

        // --- Test 1: PASS/FAIL marker ---
        $display("--- Test Results ---");
        if (uut.u_core.u_regfile.register[12] == 32'h00000001) begin
            $display("  [PASS] a2 (x12) = 1  — All inline checks passed");
        end else if (uut.u_core.u_regfile.register[12] == 32'hFFFFFFFF) begin
            $display("  [FAIL] a2 (x12) = -1  — An inline BNE check failed!");
            errors = errors + 1;
        end else begin
            $display("  [FAIL] a2 (x12) = 0x%08h — Unexpected value!", 
                uut.u_core.u_regfile.register[12]);
            errors = errors + 1;
        end

        // --- Test 2: ECALL marker (a0 = 42 before ECALL) ---
        if (uut.u_core.u_regfile.register[10] == 32'd42) begin
            $display("  [PASS] a0 (x10) = 42  — ECALL marker set correctly");
        end else begin
            $display("  [FAIL] a0 (x10) = %0d  (expected 42)", 
                uut.u_core.u_regfile.register[10]);
            errors = errors + 1;
        end

        // --- Test 3: MRET return marker (a1 = 99 after MRET) ---
        if (uut.u_core.u_regfile.register[11] == 32'd99) begin
            $display("  [PASS] a1 (x11) = 99  — MRET returned correctly");
        end else begin
            $display("  [FAIL] a1 (x11) = %0d  (expected 99)", 
                uut.u_core.u_regfile.register[11]);
            errors = errors + 1;
        end

        // --- Test 4: MTVEC register value ---
        if (uut.u_core.u_csr.mtvec == 32'h00000100) begin
            $display("  [PASS] MTVEC = 0x100  — CSR write (CSRRW) working");
        end else begin
            $display("  [FAIL] MTVEC = 0x%08h  (expected 0x00000100)", 
                uut.u_core.u_csr.mtvec);
            errors = errors + 1;
        end

        // --- Test 5: MEPC value (EBREAK at 0x8C overwrites ECALL's MEPC) ---
        if (uut.u_core.u_csr.mepc == 32'h0000008C) begin
            $display("  [PASS] MEPC = 0x8C  — Final trap (EBREAK) set MEPC correctly");
        end else begin
            $display("  [FAIL] MEPC = 0x%08h  (expected 0x0000008C)", 
                uut.u_core.u_csr.mepc);
            errors = errors + 1;
        end

        // --- Test 6: MCAUSE = 3 (EBREAK overwrites ECALL's cause=11) ---
        if (uut.u_core.u_csr.mcause == 32'd3) begin
            $display("  [PASS] MCAUSE = 3  — Final trap (EBREAK) set cause correctly");
        end else begin
            $display("  [FAIL] MCAUSE = %0d  (expected 3)", 
                uut.u_core.u_csr.mcause);
            errors = errors + 1;
        end

        // --- Test 7: MSTATUS = 0x17 (CSRRWI set 0x1F, then EBREAK clears bit 3) ---
        if (uut.u_core.u_csr.mstatus == 32'h00000017) begin
            $display("  [PASS] MSTATUS = 0x17  — CSRRWI + EBREAK MIE clear correct");
        end else begin
            $display("  [FAIL] MSTATUS = 0x%08h  (expected 0x00000017)", 
                uut.u_core.u_csr.mstatus);
            errors = errors + 1;
        end

        // --- Test 8: MSCRATCH = 0x1000 ---
        if (uut.u_core.u_csr.mscratch == 32'h00001000) begin
            $display("  [PASS] MSCRATCH = 0x1000  — CSR write working");
        end else begin
            $display("  [FAIL] MSCRATCH = 0x%08h  (expected 0x00001000)", 
                uut.u_core.u_csr.mscratch);
            errors = errors + 1;
        end

        // --- Test 9: CPU halted via EBREAK (cause=3, not ECALL cause=11) ---
        if (uut.u_core.halted == 1'b1) begin
            $display("  [PASS] CPU halted  — EBREAK reached");
        end else begin
            $display("  [FAIL] CPU not halted!");
            errors = errors + 1;
        end

        // --- Summary ---
        $display("");
        $display("================================================================");
        if (errors == 0) begin
            $display("          *** ALL %0d TESTS PASSED ***", 9);
            $display("  CSR read/write: CSRRW, CSRRS, CSRRC, CSRRWI verified");
            $display("  Trap flow: ECALL -> MTVEC -> handler -> MRET -> continue");
        end else begin
            $display("          *** %0d TEST(S) FAILED ***", errors);
        end
        $display("================================================================");
        $display("");

        // Dump all registers for reference
        $display("--- Register File Dump ---");
        for (i = 0; i < 32; i = i + 1) begin
            $display("  x%0d = 0x%08h", i, uut.u_core.u_regfile.register[i]);
        end

        $finish;
    end

    // Timeout
    initial begin
        #100000;
        $display("\n!!! TIMEOUT !!! — CPU did not halt within 10000 cycles");
        $display("  PC = 0x%08h", uut.u_core.pc_reg);
        $display("  halted = %b, trap_inflight = %b", 
            uut.u_core.halted, uut.u_core.trap_inflight);
        $finish;
    end

    initial begin
        $dumpfile("csr_test.vcd");
        $dumpvars(0, csr_test_tb);
    end

endmodule
