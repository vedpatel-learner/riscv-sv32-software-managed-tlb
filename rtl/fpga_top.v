// ============================================================================
//  fpga_top.v — FPGA top-level for Zybo Z7-10
//  Uses divide-by-2 clock: 125 MHz → 62.5 MHz CPU clock.
//  Debug via Xilinx ILA — no external UART cable required.
// ============================================================================
module fpga_top (
    input  wire       clk,        // 125 MHz system clock (K17)
    input  wire       btn0,       // Reset button, active-high (K18)
    output wire [3:0] led         // LEDs (M14, M15, G14, D18)
);

    wire rst_n = ~btn0;           // Active-low reset for clk_divider
    wire cpu_clk;
    wire clk_locked;

    // =========================================================================
    //  Clock divider: 125 MHz → 62.5 MHz
    // =========================================================================
    clk_divider u_clk_div (
        .clk_in (clk),
        .rst    (rst_n),
        .clk_out(cpu_clk),
        .locked (clk_locked)
    );

    // =========================================================================
    //  CPU — runs at 62.5 MHz
    //  ILA debug core is instantiated inside microprocessor module.
    // =========================================================================
    microprocessor #(
        .INSTR_FILE("C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/t_perf_instr.mem"),
        .DATA_FILE("C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/t3_data.mem")
    ) u_cpu (
        .clk(cpu_clk),
        .rst(btn0),
        .led(led)
    );

endmodule
