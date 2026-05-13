// ============================================================================
//  clk_divider.v — Simple divide-by-2 clock divider
//  125 MHz → 62.5 MHz (toggle flip-flop)
//
//  NOTE: For exact 50 MHz, replace this with Vivado Clocking Wizard IP
//        (MMCM: 125 × 8 / 20 = 50 MHz). This simple divider is provided
//        for designs where 62.5 MHz is acceptable and no IP is desired.
// ============================================================================
module clk_divider (
    input  wire clk_in,     // 125 MHz
    input  wire rst,        // active-low
    output reg  clk_out,    // 62.5 MHz
    output wire locked      // always ready after reset
);

    assign locked = rst;  // locked when not in reset

    always @(posedge clk_in or negedge rst) begin
        if (!rst)
            clk_out <= 1'b0;
        else
            clk_out <= ~clk_out;
    end

endmodule
