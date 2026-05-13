## ============================================================================
##  zybo_z7_10.xdc — Pin constraints for Zybo Z7-10 (xc7z010clg400-1)
##  Board: Digilent Zybo Z7-10
##  CPU runs at 62.5 MHz (125 MHz / 2 via clk_divider)
## ============================================================================

## --- System Clock: 125 MHz input ---
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4} [get_ports { clk }]

## --- Reset Button (BTN0, active-high momentary) ---
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { btn0 }]

## --- LEDs ---
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]

## --- UART TX removed — performance reporting now uses ILA debug core ---
## (previously: V12 on JE Pmod header pin 1)

## --- Configuration ---
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
