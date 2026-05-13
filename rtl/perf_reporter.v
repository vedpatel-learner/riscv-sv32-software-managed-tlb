// ============================================================================
//  perf_reporter.v — Sends performance counters over UART as ASCII hex
//  Format per counter: "XX=HHHHHHHH\r\n" (13 chars × 6 counters = 78 chars)
//  Labels: TC (total cycles), SC (stall), IC (instr), TA (tlb access),
//          TH (tlb hit), TM (tlb miss)
// ============================================================================
module perf_reporter #(
    parameter CLK_FREQ  = 125_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire        clk,
    input  wire        rst,           // active-low
    input  wire        trigger,       // rising edge starts report
    input  wire [31:0] counter_0,     // total_cycles
    input  wire [31:0] counter_1,     // stall_cycles
    input  wire [31:0] counter_2,     // instr_count
    input  wire [31:0] counter_3,     // tlb_access
    input  wire [31:0] counter_4,     // tlb_hit
    input  wire [31:0] counter_5,     // tlb_miss
    output wire        uart_tx_line,
    output wire        busy
);

    // ---- UART TX instance ----
    reg        uart_start;
    reg  [7:0] uart_data;
    wire       uart_busy;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart (
        .clk(clk),
        .rst(rst),
        .tx_start(uart_start),
        .tx_data(uart_data),
        .tx(uart_tx_line),
        .tx_busy(uart_busy)
    );

    // ---- State machine ----
    localparam [2:0] S_IDLE      = 3'd0,
                     S_LOAD_CHAR = 3'd1,
                     S_SEND      = 3'd2,
                     S_WAIT_BUSY = 3'd3,
                     S_WAIT_DONE = 3'd4,
                     S_NEXT      = 3'd5,
                     S_DONE      = 3'd6;

    reg [2:0]  state;
    reg [2:0]  ctr_idx;   // 0-5: which counter
    reg [3:0]  step;      // 0-12: position within one counter line
    reg        triggered;

    // Latched counter values (individual registers, no array)
    reg [31:0] lat0, lat1, lat2, lat3, lat4, lat5;

    assign busy = (state != S_IDLE) && (state != S_DONE);

    // ---- Current counter value mux ----
    reg [31:0] cur_val;
    always @(*) begin
        case (ctr_idx)
            3'd0: cur_val = lat0;
            3'd1: cur_val = lat1;
            3'd2: cur_val = lat2;
            3'd3: cur_val = lat3;
            3'd4: cur_val = lat4;
            3'd5: cur_val = lat5;
            default: cur_val = 32'd0;
        endcase
    end

    // ---- Nibble to ASCII hex ----
    function [7:0] nib2hex;
        input [3:0] nib;
        begin
            nib2hex = (nib < 4'd10) ? (8'h30 + {4'd0, nib})
                                    : (8'h37 + {4'd0, nib});
        end
    endfunction

    // ---- Label lookup ----
    reg [7:0] label_char;
    always @(*) begin
        case ({ctr_idx, step[0]})
            4'b000_0: label_char = "T";  4'b000_1: label_char = "C";
            4'b001_0: label_char = "S";  4'b001_1: label_char = "C";
            4'b010_0: label_char = "I";  4'b010_1: label_char = "C";
            4'b011_0: label_char = "T";  4'b011_1: label_char = "A";
            4'b100_0: label_char = "T";  4'b100_1: label_char = "H";
            4'b101_0: label_char = "T";  4'b101_1: label_char = "M";
            default:  label_char = " ";
        endcase
    end

    // ---- Current character mux ----
    reg [7:0] out_char;
    always @(*) begin
        case (step)
            4'd0:  out_char = label_char;
            4'd1:  out_char = label_char;
            4'd2:  out_char = "=";
            4'd3:  out_char = nib2hex(cur_val[31:28]);
            4'd4:  out_char = nib2hex(cur_val[27:24]);
            4'd5:  out_char = nib2hex(cur_val[23:20]);
            4'd6:  out_char = nib2hex(cur_val[19:16]);
            4'd7:  out_char = nib2hex(cur_val[15:12]);
            4'd8:  out_char = nib2hex(cur_val[11:8]);
            4'd9:  out_char = nib2hex(cur_val[7:4]);
            4'd10: out_char = nib2hex(cur_val[3:0]);
            4'd11: out_char = 8'h0D;  // CR
            4'd12: out_char = 8'h0A;  // LF
            default: out_char = " ";
        endcase
    end

    // ---- Main state machine ----
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state      <= S_IDLE;
            ctr_idx    <= 3'd0;
            step       <= 4'd0;
            uart_start <= 1'b0;
            uart_data  <= 8'd0;
            triggered  <= 1'b0;
            lat0 <= 32'd0; lat1 <= 32'd0; lat2 <= 32'd0;
            lat3 <= 32'd0; lat4 <= 32'd0; lat5 <= 32'd0;
        end else begin
            uart_start <= 1'b0;  // default: no pulse

            case (state)
                S_IDLE: begin
                    if (trigger && !triggered) begin
                        lat0 <= counter_0;  lat1 <= counter_1;
                        lat2 <= counter_2;  lat3 <= counter_3;
                        lat4 <= counter_4;  lat5 <= counter_5;
                        ctr_idx   <= 3'd0;
                        step      <= 4'd0;
                        triggered <= 1'b1;
                        state     <= S_LOAD_CHAR;
                    end
                end

                S_LOAD_CHAR: begin
                    uart_data <= out_char;
                    state     <= S_SEND;
                end

                S_SEND: begin
                    if (!uart_busy) begin
                        uart_start <= 1'b1;
                        state      <= S_WAIT_BUSY;
                    end
                end

                S_WAIT_BUSY: begin
                    // Wait for UART to assert busy
                    if (uart_busy) begin
                        state <= S_WAIT_DONE;
                    end
                end

                S_WAIT_DONE: begin
                    // Wait for UART to finish byte
                    if (!uart_busy) begin
                        state <= S_NEXT;
                    end
                end

                S_NEXT: begin
                    if (step == 4'd12) begin
                        step <= 4'd0;
                        if (ctr_idx == 3'd5) begin
                            state <= S_DONE;
                        end else begin
                            ctr_idx <= ctr_idx + 3'd1;
                            state   <= S_LOAD_CHAR;
                        end
                    end else begin
                        step  <= step + 4'd1;
                        state <= S_LOAD_CHAR;
                    end
                end

                S_DONE: begin
                    // Stay done until reset
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
