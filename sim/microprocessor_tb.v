`timescale 1ns/1ps

module microprocessor_tb();

    reg clk;
    reg rst;
    wire [3:0] led;

    microprocessor uut (
        .clk(clk),
        .rst(rst),
        .led(led)
    );

    // 10ns clock period
    always #5 clk = ~clk;

    integer i;
    integer errors;
    reg [31:0] expected [0:31];
    integer cycle_count;

    initial begin
        expected[0]  = 32'h00000000;
        expected[1]  = 32'h00000005;
        expected[2]  = 32'h0000000A;
        expected[3]  = 32'h0000000F;
        expected[4]  = 32'h00000005;
        expected[5]  = 32'hFFFFFFFD;
        expected[6]  = 32'h00000000;
        expected[7]  = 32'h0000000F;
        expected[8]  = 32'h0000000F;
        expected[9]  = 32'h00000014;
        expected[10] = 32'h00000005;
        expected[11] = 32'hFFFFFFFE;
        expected[12] = 32'h00000001;
        expected[13] = 32'h00000001;
        expected[14] = 32'h12345000;
        expected[15] = 32'h00000038;
        expected[16] = 32'h00000005;
        expected[17] = 32'h0000000A;
        expected[18] = 32'h000000FF;
        expected[19] = 32'h000000FF;
        expected[20] = 32'hFFFFFFFF;
        expected[21] = 32'hFFFFFFFD;
        expected[22] = 32'h0000FFFD;
        expected[23] = 32'h0000002A;
        expected[24] = 32'h00000007;
        expected[25] = 32'h00000008;
        expected[26] = 32'h00000009;
        expected[27] = 32'h0000009C;
        expected[28] = 32'h0000000B;
        expected[29] = 32'h000000B8;
        expected[30] = 32'h000000B0;
        expected[31] = 32'h00000037;
    end

    // Cycle-by-cycle trace for debugging the first 10 cycles
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count <= 12) begin
                $display("=== Cycle %0d ===", cycle_count);
                $display("  PC=%0h  IF/ID_valid=%b  IF/ID_instr=%08h  IF/ID_pc=%0h",
                    uut.u_core.pc_reg,
                    uut.u_core.if_id_valid,
                    uut.u_core.if_id_instruction,
                    uut.u_core.if_id_pc);
                $display("  ID/EX_valid=%b  ID/EX_rd=%0d  ID/EX_reg_write=%b  ID/EX_imm=%0h  ID/EX_use_imm=%b",
                    uut.u_core.id_ex_valid,
                    uut.u_core.id_ex_rd,
                    uut.u_core.id_ex_reg_write,
                    uut.u_core.id_ex_imm,
                    uut.u_core.id_ex_use_imm);
                $display("  EX/MEM_valid=%b  EX/MEM_rd=%0d  EX/MEM_reg_write=%b  EX/MEM_alu=%0h",
                    uut.u_core.ex_mem_valid,
                    uut.u_core.ex_mem_rd,
                    uut.u_core.ex_mem_reg_write,
                    uut.u_core.ex_mem_alu_result);
                $display("  MEM/WB_valid=%b  MEM/WB_rd=%0d  MEM/WB_reg_write=%b  MEM/WB_alu=%0h",
                    uut.u_core.mem_wb_valid,
                    uut.u_core.mem_wb_rd,
                    uut.u_core.mem_wb_reg_write,
                    uut.u_core.mem_wb_alu_result);
                $display("  WB: en=%b  rd=%0d  data=%0h",
                    uut.u_core.u_regfile.en,
                    uut.u_core.u_regfile.rd,
                    uut.u_core.u_regfile.data);
                $display("  Reg[1]=%0h  Reg[2]=%0h  Reg[5]=%0h",
                    uut.u_core.u_regfile.register[1],
                    uut.u_core.u_regfile.register[2],
                    uut.u_core.u_regfile.register[5]);
                $display("  fwd_rs1=%0h  fwd_rs2=%0h  alu_result=%0h",
                    uut.u_core.forward_rs1_value,
                    uut.u_core.forward_rs2_value,
                    uut.u_core.ex_alu_result);
            end
        end
    end

    initial begin
        clk = 0;
        rst = 1;
        errors = 0;
        cycle_count = 0;

        #27;       // release between clock edges to avoid race
        rst = 0;

        wait(uut.u_core.halted || uut.u_core.trap_flag);
        #30;

        // Performance
        $display("");
        $display("================================================================");
        $display("     RV32I 5-STAGE PIPELINE VERIFICATION REPORT");
        $display("================================================================");
        $display("");
        $display("--- Performance Counters ---");
        $display("  Total Cycles      : %0d", uut.u_core.total_cycles);
        $display("  Stall Cycles      : %0d", uut.u_core.stall_cycles);
        $display("  Retired Instrs    : %0d", uut.u_core.instr_count);
        $display("  Halted            : %b", uut.u_core.halted);
        $display("  Trap Flag         : %b", uut.u_core.trap_flag);
        $display("  Trap Cause        : %0d", uut.u_core.u_csr.mcause);
        $display("  Trap PC           : 0x%08h", uut.u_core.u_csr.mepc);

        // Register verification
        $display("");
        $display("--- Register File Verification (x0 - x31) ---");
        for (i = 0; i < 32; i = i + 1) begin
            if (uut.u_core.u_regfile.register[i] !== expected[i]) begin
                $display("  [FAIL] x%0d = 0x%08h  (expected 0x%08h)",
                    i, uut.u_core.u_regfile.register[i], expected[i]);
                errors = errors + 1;
            end else begin
                $display("  [PASS] x%0d = 0x%08h", i, uut.u_core.u_regfile.register[i]);
            end
        end

        // Summary
        $display("");
        $display("================================================================");
        if (errors == 0)
            $display("          *** ALL TESTS PASSED ***");
        else
            $display("          *** %0d TEST(S) FAILED ***", errors);
        $display("================================================================");
        $display("");

        $finish;
    end

    // Timeout
    initial begin
        #50000;
        $display("\n!!! TIMEOUT !!!");
        $finish;
    end

    initial begin
        $dumpfile("microprocessor.vcd");
        $dumpvars(0, microprocessor_tb);
    end

endmodule
