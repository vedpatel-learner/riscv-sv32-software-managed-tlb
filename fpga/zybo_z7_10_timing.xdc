## ============================================================================
##  zybo_z7_10_timing.xdc — Implementation-only timing constraints
##  This file is marked USED_IN_SYNTHESIS = FALSE in Vivado project settings.
##  It defines the generated 62.5 MHz clock for the CPU domain.
## ============================================================================

## --- Generated Clock: 62.5 MHz CPU clock ---
## The clk_divider toggles clk_out_reg every 125 MHz rising edge.
## This constrains all CPU logic paths at 16ns period (62.5 MHz).
create_generated_clock -name cpu_clk -source [get_ports clk] -divide_by 2 \
    [get_pins u_clk_div/clk_out_reg/Q]
