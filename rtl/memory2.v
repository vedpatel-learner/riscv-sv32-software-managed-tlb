module memory#(
    parameter INIT_MEM = 0,
    parameter INIT_FILE = "instr.mem"
)(
    input wire clk,
    input wire we_re,
    input wire request,
    input wire [11:0]address,
    input wire [31:0]data_in,
    input wire [3:0]mask,

    output wire [31:0]data_out
);

    (* ram_style = "block" *) reg [31:0] mem [0:4095];
    integer i;

    initial begin
        for (i = 0; i < 4096; i = i + 1) begin
            mem[i] = 32'b0;
        end
        if (INIT_MEM) begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always @(posedge clk) begin
        if (request && we_re) begin
            if(mask[0]) begin
                mem[address][7:0] <= data_in[7:0];
            end
            if(mask[1]) begin
                mem[address][15:8] <= data_in[15:8];
            end
            if(mask[2]) begin
                mem[address][23:16] <= data_in[23:16];
            end
            if(mask[3]) begin
                mem[address][31:24] <= data_in[31:24];
            end
        end
    end

    assign data_out = mem[address];
endmodule
