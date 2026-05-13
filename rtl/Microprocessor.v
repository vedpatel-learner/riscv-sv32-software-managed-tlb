module microprocessor #(
    parameter INSTR_FILE = "C:/Users/vedpa/project_COA _base/project_COA.srcs/sim_1/new/instr.mem",
    parameter DATA_FILE = "data.mem"
)(
    input wire clk,
    input wire rst,
    output wire [3:0] led
);

    wire rst_n;

    wire [31:0] instruction_data;
    wire [31:0] pc_address;
    wire [31:0] load_data_out;
    wire [31:0] alu_out_address;
    wire [31:0] store_data;
    wire [3:0]  mask;
    wire instruc_mem_valid;
    wire data_mem_valid;
    wire data_mem_we_re;
    wire data_mem_request;
    wire load_signal;
    wire cpu_halted;
    wire cpu_trap;
    wire [31:0] total_cycles_dbg;
    wire [31:0] stall_cycles_dbg;
    wire [31:0] instr_count_dbg;
    wire [31:0] tlb_access_count_dbg;
    wire [31:0] tlb_hit_count_dbg;
    wire [31:0] tlb_miss_count_dbg;
    // ILA debug wires — pipeline valid bits
    wire if_id_valid_dbg;
    wire id_ex_valid_dbg;
    wire ex_mem_valid_dbg;
    wire mem_wb_valid_dbg;
    // ILA debug wires — real-time TLB signals
    wire tlb_hit_rt_dbg;
    wire tlb_lookup_valid_rt_dbg;
    // ILA debug wires — hazard stall
    wire load_use_stall_dbg;

    assign rst_n = ~rst;

    instruc_mem_top #(
        .INIT_MEM(1),
        .INIT_FILE(INSTR_FILE)
    ) u_instruction_memory (
        .clk(clk),
        .rst(rst_n),
        .we_re(1'b0),
        .request(1'b1),
        .mask(4'b1111),
        .address(pc_address[13:2]),
        .data_in(32'b0),
        .valid(instruc_mem_valid),
        .data_out(instruction_data)
    );

    core u_core (
        .clk(clk),
        .rst(rst_n),
        .instruction(instruction_data),
        .load_data_in(load_data_out),
        .mask_singal(mask),
        .load_signal(load_signal),
        .data_mem_we_re(data_mem_we_re),
        .data_mem_request(data_mem_request),
        .instruc_mem_valid(instruc_mem_valid),
        .data_mem_valid(data_mem_valid),
        .store_data_out(store_data),
        .pc_address(pc_address),
        .alu_out_address(alu_out_address),
        .halted_debug(cpu_halted),
        .trap_debug(cpu_trap),
        .total_cycles_debug(total_cycles_dbg),
        .stall_cycles_debug(stall_cycles_dbg),
        .instr_count_debug(instr_count_dbg),
        .tlb_access_count_debug(tlb_access_count_dbg),
        .tlb_hit_count_debug(tlb_hit_count_dbg),
        .tlb_miss_count_debug(tlb_miss_count_dbg),
        // ILA debug connections
        .if_id_valid_debug(if_id_valid_dbg),
        .id_ex_valid_debug(id_ex_valid_dbg),
        .ex_mem_valid_debug(ex_mem_valid_dbg),
        .mem_wb_valid_debug(mem_wb_valid_dbg),
        .tlb_hit_rt_debug(tlb_hit_rt_dbg),
        .tlb_lookup_valid_rt_debug(tlb_lookup_valid_rt_dbg),
        .load_use_stall_debug(load_use_stall_dbg)
    );

    data_mem_top #(
        .INIT_MEM(1),
        .INIT_FILE(DATA_FILE)
    ) u_data_memory (
        .clk(clk),
        .rst(rst_n),
        .we_re(data_mem_we_re),
        .request(data_mem_request),
        .address(alu_out_address[13:2]),
        .data_in(store_data),
        .mask(mask),
        .load(load_signal),
        .valid(data_mem_valid),
        .data_out(load_data_out)
    );

    // =========================================================================
    //  ILA Debug Core — replaces UART-based perf_reporter
    //  Probes all performance counters, pipeline status, TLB real-time signals,
    //  PC, data-memory address, and CPU status.
    //
    //  Trigger: probe8 (cpu_halted) rising edge
    //  Set trigger position to 512 for pre/post capture around halt event.
    //
    //  Generate the ILA IP first by running in Vivado Tcl console:
    //    source C:/Users/vedpa/project_COA\ _base/create_ila.tcl
    //
    //  The ILA is wrapped in `ifndef SIMULATION so that behavioral simulation
    //  works without needing the ILA IP generated first.
    // =========================================================================
    `ifndef SIMULATION
    ila_perf u_ila (
        .clk    (clk),
        .probe0 (total_cycles_dbg),          // [31:0] total cycles
        .probe1 (stall_cycles_dbg),          // [31:0] stall cycles
        .probe2 (instr_count_dbg),           // [31:0] instruction count
        .probe3 (tlb_access_count_dbg),      // [31:0] TLB access count
        .probe4 (tlb_hit_count_dbg),         // [31:0] TLB hit count
        .probe5 (tlb_miss_count_dbg),        // [31:0] TLB miss count
        .probe6 (pc_address),                // [31:0] program counter
        .probe7 (alu_out_address),           // [31:0] data memory address
        .probe8 (cpu_halted),                // [0:0]  CPU halted (trigger)
        .probe9 (cpu_trap),                  // [0:0]  trap occurred
        .probe10(load_use_stall_dbg),        // [0:0]  load-use stall
        .probe11(tlb_hit_rt_dbg),            // [0:0]  real-time TLB hit
        .probe12(tlb_lookup_valid_rt_dbg),   // [0:0]  real-time TLB lookup
        .probe13({if_id_valid_dbg, id_ex_valid_dbg,
                  ex_mem_valid_dbg, mem_wb_valid_dbg}),  // [3:0] pipeline valid
        .probe14(led)                        // [3:0]  LED status
    );
    `endif

    // =========================================================================
    //  LED assignments
    // =========================================================================
    assign led[0] = cpu_halted;                    // CPU halted
    assign led[1] = cpu_trap;                      // Trap occurred
    assign led[2] = tlb_miss_count_dbg[0];         // TLB miss pulse
    assign led[3] = total_cycles_dbg[23];          // Heartbeat

endmodule
