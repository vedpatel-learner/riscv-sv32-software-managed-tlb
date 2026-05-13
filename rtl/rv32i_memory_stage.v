module rv32i_memory_stage (
    input wire ex_mem_valid,
    input wire ex_mem_mem_read,
    input wire ex_mem_mem_write,
    input wire ex_mem_trap_valid,
    input wire [31:0] ex_mem_trap_cause,
    input wire [2:0] ex_mem_funct3,
    input wire [31:0] ex_mem_alu_result,
    input wire [31:0] ex_mem_store_data,
    input wire [31:0] load_data_in,
    input wire halted,
    input wire translation_enable,
    input wire tlb_hit,
    input wire [21:0] tlb_ppn,

    output wire [31:0] load_value,
    output wire [3:0] store_mask,
    output wire [31:0] store_word,
    output wire [31:0] physical_address,
    output wire mem_trap_valid,
    output wire [31:0] mem_trap_cause,
    output wire [31:0] mem_trap_val,
    output wire load_signal,
    output wire data_mem_we_re,
    output wire data_mem_request
);

    function [3:0] store_mask_fn;
        input [2:0] funct3;
        input [1:0] addr_low;
        begin
            case (funct3)
                3'b000: begin
                    case (addr_low)
                        2'b00: store_mask_fn = 4'b0001;
                        2'b01: store_mask_fn = 4'b0010;
                        2'b10: store_mask_fn = 4'b0100;
                        default: store_mask_fn = 4'b1000;
                    endcase
                end
                3'b001: begin
                    case (addr_low)
                        2'b00: store_mask_fn = 4'b0011;
                        2'b01: store_mask_fn = 4'b0110;
                        default: store_mask_fn = 4'b1100;
                    endcase
                end
                default: store_mask_fn = 4'b1111;
            endcase
        end
    endfunction

    function [31:0] store_align_fn;
        input [2:0] funct3;
        input [1:0] addr_low;
        input [31:0] rs2_value;
        begin
            case (funct3)
                3'b000: begin
                    case (addr_low)
                        2'b00: store_align_fn = {24'b0, rs2_value[7:0]};
                        2'b01: store_align_fn = {16'b0, rs2_value[7:0], 8'b0};
                        2'b10: store_align_fn = {8'b0, rs2_value[7:0], 16'b0};
                        default: store_align_fn = {rs2_value[7:0], 24'b0};
                    endcase
                end
                3'b001: begin
                    case (addr_low)
                        2'b00: store_align_fn = {16'b0, rs2_value[15:0]};
                        2'b01: store_align_fn = {8'b0, rs2_value[15:0], 8'b0};
                        default: store_align_fn = {rs2_value[15:0], 16'b0};
                    endcase
                end
                default: store_align_fn = rs2_value;
            endcase
        end
    endfunction

    function [31:0] load_format_fn;
        input [2:0] funct3;
        input [1:0] addr_low;
        input [31:0] word_value;
        begin
            case (funct3)
                3'b000: begin
                    case (addr_low)
                        2'b00: load_format_fn = {{24{word_value[7]}}, word_value[7:0]};
                        2'b01: load_format_fn = {{24{word_value[15]}}, word_value[15:8]};
                        2'b10: load_format_fn = {{24{word_value[23]}}, word_value[23:16]};
                        default: load_format_fn = {{24{word_value[31]}}, word_value[31:24]};
                    endcase
                end
                3'b001: begin
                    case (addr_low)
                        2'b00: load_format_fn = {{16{word_value[15]}}, word_value[15:0]};
                        2'b01: load_format_fn = {{16{word_value[23]}}, word_value[23:8]};
                        default: load_format_fn = {{16{word_value[31]}}, word_value[31:16]};
                    endcase
                end
                3'b010: load_format_fn = word_value;
                3'b100: begin
                    case (addr_low)
                        2'b00: load_format_fn = {24'b0, word_value[7:0]};
                        2'b01: load_format_fn = {24'b0, word_value[15:8]};
                        2'b10: load_format_fn = {24'b0, word_value[23:16]};
                        default: load_format_fn = {24'b0, word_value[31:24]};
                    endcase
                end
                default: begin
                    case (addr_low)
                        2'b00: load_format_fn = {16'b0, word_value[15:0]};
                        2'b01: load_format_fn = {16'b0, word_value[23:8]};
                        default: load_format_fn = {16'b0, word_value[31:16]};
                    endcase
                end
            endcase
        end
    endfunction

    wire is_memory_access;
    wire tlb_miss;
    wire mem_access_allowed;

    assign is_memory_access = ex_mem_mem_read || ex_mem_mem_write;
    assign tlb_miss =
        ex_mem_valid &&
        is_memory_access &&
        translation_enable &&
        !ex_mem_trap_valid &&
        !tlb_hit;

    assign mem_access_allowed =
        !ex_mem_trap_valid &&
        (!translation_enable || tlb_hit);

    assign physical_address = translation_enable ?
                              {tlb_ppn, ex_mem_alu_result[11:0]} :
                              ex_mem_alu_result;

    assign store_mask = store_mask_fn(ex_mem_funct3, ex_mem_alu_result[1:0]);
    assign store_word = store_align_fn(ex_mem_funct3, ex_mem_alu_result[1:0], ex_mem_store_data);
    assign load_value = load_format_fn(ex_mem_funct3, ex_mem_alu_result[1:0], load_data_in);
    assign mem_trap_valid = ex_mem_valid && (ex_mem_trap_valid || tlb_miss);
    assign mem_trap_cause = ex_mem_trap_valid ? ex_mem_trap_cause :
                            ex_mem_mem_read ? 32'd13 : 32'd15;
    assign mem_trap_val = tlb_miss ? ex_mem_alu_result : 32'd0;

    assign load_signal = ex_mem_valid && ex_mem_mem_read && mem_access_allowed;
    assign data_mem_we_re = ex_mem_valid && ex_mem_mem_write && mem_access_allowed;
    assign data_mem_request =
        ex_mem_valid &&
        is_memory_access &&
        mem_access_allowed &&
        !halted &&
        !mem_trap_valid;

endmodule
