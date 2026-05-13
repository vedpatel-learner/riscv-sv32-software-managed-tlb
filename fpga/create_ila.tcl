# ==============================================================================
#  create_ila.tcl — Generate ILA debug core for RISC-V performance analysis
#
#  Usage: In Vivado Tcl console (with project open):
#         source C:/Users/vedpa/project_COA\ _base/create_ila.tcl
#
#  This creates an ILA IP named "ila_perf" with 15 probes covering:
#   - 6 performance counters (32-bit each)
#   - PC and data-memory address (32-bit each)
#   - Pipeline valid bits, TLB real-time signals, CPU status, LEDs
#
#  Sample depth: 1024 (uses ~8 BRAMs on Z7-10)
#  Trigger position: middle (512 pre-trigger + 512 post-trigger samples)
# ==============================================================================

# --- Remove stale ILA IP if it exists ---
set ila_name ila_perf
if {[llength [get_ips $ila_name]] > 0} {
    puts "INFO: Removing existing ILA IP '$ila_name' ..."
    export_ip_user_files -of_objects [get_ips $ila_name] -no_script -reset -force -quiet
    remove_files [get_files -quiet ${ila_name}.xci]
    file delete -force [get_property IP_DIR [get_ips -quiet $ila_name]] 2>/dev/null
}

# --- Create ILA IP ---
puts "INFO: Creating ILA IP '$ila_name' ..."
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
          -module_name $ila_name

# --- Configure ILA core ---
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES  {15}         \
    CONFIG.C_DATA_DEPTH     {1024}       \
    CONFIG.C_TRIGIN_EN      {false}      \
    CONFIG.C_TRIGOUT_EN     {false}      \
    CONFIG.C_INPUT_PIPE_STAGES {0}       \
    CONFIG.C_EN_STRG_QUAL   {1}         \
    CONFIG.C_ADV_TRIGGER    {true}       \
    CONFIG.ALL_PROBE_SAME_MU {true}      \
    CONFIG.ALL_PROBE_SAME_MU_CNT {2}    \
    CONFIG.C_PROBE0_WIDTH   {32}         \
    CONFIG.C_PROBE1_WIDTH   {32}         \
    CONFIG.C_PROBE2_WIDTH   {32}         \
    CONFIG.C_PROBE3_WIDTH   {32}         \
    CONFIG.C_PROBE4_WIDTH   {32}         \
    CONFIG.C_PROBE5_WIDTH   {32}         \
    CONFIG.C_PROBE6_WIDTH   {32}         \
    CONFIG.C_PROBE7_WIDTH   {32}         \
    CONFIG.C_PROBE8_WIDTH   {1}          \
    CONFIG.C_PROBE9_WIDTH   {1}          \
    CONFIG.C_PROBE10_WIDTH  {1}          \
    CONFIG.C_PROBE11_WIDTH  {1}          \
    CONFIG.C_PROBE12_WIDTH  {1}          \
    CONFIG.C_PROBE13_WIDTH  {4}          \
    CONFIG.C_PROBE14_WIDTH  {4}          \
] [get_ips $ila_name]

# --- Probe Map (for reference) ---
# probe0  [31:0]  total_cycles        — Total cycle count
# probe1  [31:0]  stall_cycles        — Pipeline stall cycles
# probe2  [31:0]  instr_count         — Retired instruction count
# probe3  [31:0]  tlb_access_count    — TLB access count
# probe4  [31:0]  tlb_hit_count       — TLB hit count
# probe5  [31:0]  tlb_miss_count      — TLB miss count
# probe6  [31:0]  pc_address          — Current program counter
# probe7  [31:0]  alu_out_address     — Data memory effective address
# probe8  [0:0]   cpu_halted          — CPU halt flag (primary trigger)
# probe9  [0:0]   cpu_trap            — Trap occurred flag
# probe10 [0:0]   load_use_stall      — Load-use hazard stall
# probe11 [0:0]   tlb_hit_rt          — Real-time TLB hit signal
# probe12 [0:0]   tlb_lookup_valid_rt — Real-time TLB lookup valid
# probe13 [3:0]   pipeline_valid      — {if_id, id_ex, ex_mem, mem_wb} valid
# probe14 [3:0]   led                 — LED status

# --- Generate output products ---
generate_target all [get_ips $ila_name]

# --- Create synthesis run (optional — will be picked up automatically) ---
catch {create_ip_run [get_ips $ila_name]}

puts "============================================================"
puts "  ILA IP '$ila_name' created successfully."
puts "  Probes: 15 (269 bits total)"
puts "  Depth:  1024 samples"
puts ""
puts "  Next steps:"
puts "  1. Run Synthesis + Implementation"
puts "  2. Program FPGA, open Hardware Manager"
puts "  3. Set trigger: probe8 (cpu_halted) rising edge"
puts "  4. Set trigger position to 512 (mid-buffer)"
puts "  5. Arm ILA, press BTN0 to start CPU"
puts "  6. Read counter values from waveform when triggered"
puts "============================================================"
