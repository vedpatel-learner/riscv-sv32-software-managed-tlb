`define SIMULATION
`timescale 1ns/1ps

// ============================================================================
//  Phase 5: TLB Performance Data Collection Testbench
//  Runs 4 test configurations (1/4/8/16 page working sets) sequentially,
//  collects performance counters, computes metrics, and prints a summary table.
// ============================================================================
module perf_tb();

    reg clk;
    reg rst;
    wire [3:0] led;

    microprocessor #(
        .INSTR_FILE("C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/t_perf_instr.mem"),
        .DATA_FILE("C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/t1_data.mem")
    ) uut (
        .clk(clk),
        .rst(rst),
        .led(led)
    );

    always #5 clk = ~clk;

    // Results storage
    integer t_cycles  [0:3];
    integer t_stalls  [0:3];
    integer t_instrs  [0:3];
    integer t_access  [0:3];
    integer t_hits    [0:3];
    integer t_misses  [0:3];
    integer test_idx;
    integer i;

    // =========================================================================
    //  Run a single test: reset, reload data memory, wait for halt, record
    // =========================================================================
    task run_test;
        input integer idx;
        input [8*128-1:0] data_file;
        input [8*32-1:0]  test_name;
        input integer expected_access;
        input integer expected_miss;
        input integer expected_hit;
        integer errors;
        begin
            errors = 0;

            // Assert reset
            rst = 1;
            #50;

            // Clear and reload data memory
            for (i = 0; i < 4096; i = i + 1)
                uut.u_data_memory.u_memory.mem[i] = 32'b0;
            $readmemh(data_file, uut.u_data_memory.u_memory.mem);

            // Also reload instruction memory (in case it got corrupted)
            $readmemh("C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/t_perf_instr.mem",
                       uut.u_instruction_memory.u_memory.mem);

            // Release reset
            #27;
            rst = 0;

            // Wait for halt
            wait (uut.u_core.halted);
            #30;

            // Record results
            t_cycles[idx] = uut.u_core.total_cycles;
            t_stalls[idx] = uut.u_core.stall_cycles;
            t_instrs[idx] = uut.u_core.instr_count;
            t_access[idx] = uut.u_core.u_tlb.access_count;
            t_hits[idx]   = uut.u_core.u_tlb.hit_count;
            t_misses[idx] = uut.u_core.u_tlb.miss_count;

            // Per-test report
            $display("");
            $display("  --- %0s ---", test_name);
            $display("  Cycles=%0d  Instrs=%0d  Stalls=%0d",
                t_cycles[idx], t_instrs[idx], t_stalls[idx]);
            $display("  TLB: access=%0d  hit=%0d  miss=%0d",
                t_access[idx], t_hits[idx], t_misses[idx]);

            // Verify expected counts
            if (t_access[idx] !== expected_access) begin
                $display("  [FAIL] access=%0d (expected %0d)", t_access[idx], expected_access);
                errors = errors + 1;
            end
            if (t_misses[idx] !== expected_miss) begin
                $display("  [FAIL] miss=%0d (expected %0d)", t_misses[idx], expected_miss);
                errors = errors + 1;
            end
            if (t_hits[idx] !== expected_hit) begin
                $display("  [FAIL] hit=%0d (expected %0d)", t_hits[idx], expected_hit);
                errors = errors + 1;
            end

            if (errors == 0)
                $display("  [PASS] All counters match expected values");
        end
    endtask

    // =========================================================================
    //  Main test sequence
    // =========================================================================
    initial begin
        clk = 0;

        $display("");
        $display("================================================================");
        $display("     PHASE 5: TLB PERFORMANCE DATA COLLECTION");
        $display("================================================================");

        // NOTE: Each TLB miss causes an instruction replay, so the replayed LW
        // generates an additional TLB access (hit). Thus:
        //   actual_accesses = logical_accesses + miss_count
        //   actual_hits = logical_hits + miss_count (replays always hit)

        // T1: 1 page — 10+1=11 accesses, 1 cold miss, 9+1=10 hits
        run_test(0,
            "C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/t1_data.mem",
            "T1: 1 page (4KB)", 11, 1, 10);

        // T2: 4 pages — 40+4=44 accesses, 4 cold misses, 36+4=40 hits
        run_test(1,
            "C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/t2_data.mem",
            "T2: 4 pages (16KB)", 44, 4, 40);

        // T3: 8 pages — 80+80=160 accesses, 80 misses, 0+80=80 hits (replays)
        run_test(2,
            "C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/t3_data.mem",
            "T3: 8 pages (32KB)", 160, 80, 80);

        // T4: 16 pages — 160+160=320 accesses, 160 misses, 0+160=160 hits (replays)
        run_test(3,
            "C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/t4_data.mem",
            "T4: 16 pages (64KB)", 320, 160, 160);

        // =====================================================================
        //  Summary Table
        // =====================================================================
        $display("");
        $display("================================================================");
        $display("     PERFORMANCE SUMMARY TABLE");
        $display("================================================================");
        $display("  Test    | Pages | Cycles | Instrs | Access | Hits | Miss | Hit%%");
        $display("  --------|-------|--------|--------|--------|------|------|------");

        for (i = 0; i < 4; i = i + 1) begin
            if (t_access[i] > 0) begin
                $display("  T%0d      | %5d | %6d | %6d | %6d | %4d | %4d | %3d%%",
                    i+1,
                    (i == 0) ? 1 : (i == 1) ? 4 : (i == 2) ? 8 : 16,
                    t_cycles[i], t_instrs[i],
                    t_access[i], t_hits[i], t_misses[i],
                    (t_hits[i] * 100) / t_access[i]);
            end
        end

        $display("================================================================");
        $display("");

        // EMAT calculation
        $display("  --- Effective Memory Access Time (EMAT) ---");
        $display("  Assumptions: hit_time = 1 cycle, miss_penalty = estimated from data");
        $display("");
        for (i = 0; i < 4; i = i + 1) begin
            if (t_misses[i] > 0 && t_access[i] > 0) begin
                $display("  T%0d: EMAT = %0d%% × 1 + %0d%% × (%0d cycles/miss) = ~%0d cycles",
                    i+1,
                    (t_hits[i] * 100) / t_access[i],
                    (t_misses[i] * 100) / t_access[i],
                    (t_cycles[i] - t_instrs[i]) / t_misses[i],
                    (t_hits[i] + t_misses[i] * ((t_cycles[i] - t_instrs[i]) / t_misses[i])) / t_access[i]);
            end
        end

        $display("");
        $display("  --- CPI (Cycles Per Instruction) ---");
        for (i = 0; i < 4; i = i + 1) begin
            if (t_instrs[i] > 0) begin
                $display("  T%0d: CPI = %0d / %0d = %0d.%02d",
                    i+1, t_cycles[i], t_instrs[i],
                    t_cycles[i] / t_instrs[i],
                    ((t_cycles[i] * 100) / t_instrs[i]) % 100);
            end
        end

        $display("");
        $display("================================================================");
        $display("     PHASE 5 DATA COLLECTION COMPLETE");
        $display("================================================================");
        $display("");

        $finish;
    end

    // Timeout
    initial begin
        #50000000;
        $display("!!! TIMEOUT !!!");
        $finish;
    end

endmodule
