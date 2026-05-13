`timescale 1ns/1ps
module baseline_tb;
    reg clk = 0, rst = 0;
    integer cycle_count = 0;

    // Instantiate your BASE CPU (no TLB version)
    microprocessor #(
        .INSTR_FILE("baseline_test.mem"),
        .DATA_FILE("t3_data.mem")  // same data as TLB test
    ) uut (
        .clk(clk), .rst(rst)
    );

    always #5 clk = ~clk;  // 100 MHz

    initial begin
        rst = 0; #20;
        rst = 1;
        // Wait for EBREAK
        wait(uut.halted == 1);  // adjust signal path
        $display("Baseline T3: %0d cycles", cycle_count);
        $finish;
    end

    always @(posedge clk) begin
        if (rst) cycle_count <= cycle_count + 1;
    end
endmodule
