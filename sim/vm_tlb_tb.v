`timescale 1ns/1ps

module vm_tlb_tb();

    reg clk;
    reg rst;
    wire [3:0] led;

    integer errors;
    integer load_page_faults;
    integer store_page_faults;

    microprocessor #(
        .INSTR_FILE("C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/vm_tlb_instr.mem"),
        .DATA_FILE("C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/vm_tlb_data.mem")
    ) uut (
        .clk(clk),
        .rst(rst),
        .led(led)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!rst && uut.u_core.mem_wb_valid && uut.u_core.mem_wb_trap_valid) begin
            if (uut.u_core.mem_wb_trap_cause == 32'd13) begin
                load_page_faults <= load_page_faults + 1;
            end else if (uut.u_core.mem_wb_trap_cause == 32'd15) begin
                store_page_faults <= store_page_faults + 1;
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        errors = 0;
        load_page_faults = 0;
        store_page_faults = 0;

        #27;
        rst = 1'b0;

        wait (uut.u_core.halted);
        #30;

        $display("");
        $display("================================================================");
        $display("        VM / TLB FULL-FLOW REGRESSION REPORT");
        $display("================================================================");
        $display("  Total Cycles      : %0d", uut.u_core.total_cycles);
        $display("  Retired Instrs    : %0d", uut.u_core.instr_count);
        $display("  TLB Accesses      : %0d", uut.u_core.u_tlb.access_count);
        $display("  TLB Hits          : %0d", uut.u_core.u_tlb.hit_count);
        $display("  TLB Misses        : %0d", uut.u_core.u_tlb.miss_count);
        $display("  Load PFs          : %0d", load_page_faults);
        $display("  Store PFs         : %0d", store_page_faults);
        $display("  Last Trap Cause   : %0d", uut.u_core.u_csr.mcause);
        $display("");

        if (uut.u_core.u_regfile.register[12] !== 32'd1) begin
            $display("  [FAIL] x12 pass marker = 0x%08h (expected 0x00000001)", uut.u_core.u_regfile.register[12]);
            errors = errors + 1;
        end else begin
            $display("  [PASS] x12 pass marker set");
        end

        if (uut.u_core.u_regfile.register[10] !== 32'd17) begin
            $display("  [FAIL] a0 = %0d (expected 17)", uut.u_core.u_regfile.register[10]);
            errors = errors + 1;
        end

        if (uut.u_core.u_regfile.register[11] !== 32'd17) begin
            $display("  [FAIL] a1 = %0d (expected 17)", uut.u_core.u_regfile.register[11]);
            errors = errors + 1;
        end

        if (uut.u_core.u_regfile.register[13] !== 32'd34) begin
            $display("  [FAIL] a3 = %0d (expected 34)", uut.u_core.u_regfile.register[13]);
            errors = errors + 1;
        end

        if (uut.u_core.u_regfile.register[14] !== 32'd68) begin
            $display("  [FAIL] a4 = %0d (expected 68)", uut.u_core.u_regfile.register[14]);
            errors = errors + 1;
        end

        if (uut.u_core.u_regfile.register[15] !== 32'd51) begin
            $display("  [FAIL] a5 = %0d (expected 51)", uut.u_core.u_regfile.register[15]);
            errors = errors + 1;
        end

        if (uut.u_core.u_regfile.register[16] !== 32'd17) begin
            $display("  [FAIL] a6 = %0d (expected 17)", uut.u_core.u_regfile.register[16]);
            errors = errors + 1;
        end

        if (uut.u_core.u_regfile.register[17] !== 32'd1234) begin
            $display("  [FAIL] a7 = %0d (expected 1234)", uut.u_core.u_regfile.register[17]);
            errors = errors + 1;
        end

        if (uut.u_data_memory.u_memory.mem[12'h400] !== 32'd1234) begin
            $display("  [FAIL] physical page-1 word-0 = %0d (expected 1234)", uut.u_data_memory.u_memory.mem[12'h400]);
            errors = errors + 1;
        end else begin
            $display("  [PASS] store replay updated physical memory");
        end

        if (uut.u_core.u_tlb.access_count !== 32'd16) begin
            $display("  [FAIL] tlb_access_count = %0d (expected 16)", uut.u_core.u_tlb.access_count);
            errors = errors + 1;
        end

        if (uut.u_core.u_tlb.hit_count !== 32'd9) begin
            $display("  [FAIL] tlb_hit_count = %0d (expected 9)", uut.u_core.u_tlb.hit_count);
            errors = errors + 1;
        end

        if (uut.u_core.u_tlb.miss_count !== 32'd7) begin
            $display("  [FAIL] tlb_miss_count = %0d (expected 7)", uut.u_core.u_tlb.miss_count);
            errors = errors + 1;
        end

        if (load_page_faults !== 6) begin
            $display("  [FAIL] load page fault count = %0d (expected 6)", load_page_faults);
            errors = errors + 1;
        end

        if (store_page_faults !== 1) begin
            $display("  [FAIL] store page fault count = %0d (expected 1)", store_page_faults);
            errors = errors + 1;
        end

        if (uut.u_core.u_tlb.next_write_index !== 2'd1) begin
            $display("  [FAIL] next_write_index = %0d (expected 1 after flush + refill)", uut.u_core.u_tlb.next_write_index);
            errors = errors + 1;
        end else begin
            $display("  [PASS] FIFO pointer reset after flush and refilled once");
        end

        if (uut.u_core.u_csr.mepc !== 32'h000000AC) begin
            $display("  [FAIL] final MEPC = 0x%08h (expected 0x000000AC for final EBREAK)", uut.u_core.u_csr.mepc);
            errors = errors + 1;
        end

        $display("");
        $display("================================================================");
        if (errors == 0) begin
            $display("          *** VM / TLB REGRESSION PASSED ***");
        end else begin
            $display("          *** %0d VM / TLB CHECK(S) FAILED ***", errors);
        end
        $display("================================================================");
        $display("");

        $finish;
    end

    initial begin
        #200000;
        $display("!!! TIMEOUT !!!");
        $finish;
    end

    initial begin
        $dumpfile("vm_tlb.vcd");
        $dumpvars(0, vm_tlb_tb);
    end

endmodule
