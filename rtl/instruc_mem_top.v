module instruc_mem_top #(
    parameter INIT_MEM = 1,
    parameter INIT_FILE = "instr.mem"
)(
    input wire clk,
    input wire rst,
    input wire we_re,
    input wire request,
    input wire [3:0]  mask,
    input wire [11:0] address,
    input wire [31:0] data_in,

    output wire valid,
    output wire [31:0] data_out
    );

    assign valid = rst && request;

    memory #(
      .INIT_MEM(INIT_MEM),
      .INIT_FILE(INIT_FILE)
    )u_memory(
        .clk(clk),
        .we_re(we_re),
        .request(request),
        .mask(mask),
        .address(address),
        .data_in(data_in),
        .data_out(data_out)
    );
endmodule
