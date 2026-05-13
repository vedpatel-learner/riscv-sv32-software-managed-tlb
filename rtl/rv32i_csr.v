// ============================================================================
//  rv32i_csr.v — CSR Register File for RV32I with TLB Support
//  Implements: MSTATUS, MTVEC, MSCRATCH, MEPC, MCAUSE, MTVAL, SATP
//  Custom:     TLB_VPN (0xFC0), TLB_PPN (0xFC1), TLB_CMD (0xFC2)
// ============================================================================
module rv32i_csr (
    input  wire        clk,
    input  wire        rst,

    // --- CSR Read Port (combinational, used in EX stage) ---
    input  wire [11:0] csr_addr_read,
    output reg  [31:0] csr_read_data,

    // --- CSR Write Port (from WB stage via Core control) ---
    input  wire        csr_write_enable,
    input  wire [11:0] csr_addr_write,
    input  wire [31:0] csr_write_data,
    input  wire [1:0]  csr_op,           // 2'b01=CSRRW, 2'b10=CSRRS, 2'b11=CSRRC

    // --- Trap Entry Interface (from Core trap logic) ---
    input  wire        trap_enter,        // Pulse: entering a trap
    input  wire [31:0] trap_pc,           // PC of faulting instruction -> MEPC
    input  wire [31:0] trap_cause,        // Cause code -> MCAUSE
    input  wire [31:0] trap_val,          // Faulting address -> MTVAL

    // --- MRET Interface ---
    input  wire        mret_execute,      // Pulse: executing MRET
    output wire [31:0] mepc_out,          // MEPC value for PC restoration

    // --- Output to Core (always available) ---
    output wire [31:0] mtvec_out,         // Trap vector address
    output wire [31:0] satp_out,          // Page table base address

    // --- TLB Write Interface (directly wired to TLB module) ---
    output reg         tlb_write_trigger, // Pulse: commit TLB entry
    output wire [19:0] tlb_write_vpn,     // VPN from TLB_VPN register
    output wire [21:0] tlb_write_ppn,     // PPN from TLB_PPN register
    output reg         tlb_flush_trigger  // Pulse: flush all TLB entries
);

    // =========================================================================
    //  CSR Address Map
    // =========================================================================
    localparam [11:0] ADDR_MSTATUS  = 12'h300;
    localparam [11:0] ADDR_MTVEC    = 12'h305;
    localparam [11:0] ADDR_MSCRATCH = 12'h340;
    localparam [11:0] ADDR_MEPC     = 12'h341;
    localparam [11:0] ADDR_MCAUSE   = 12'h342;
    localparam [11:0] ADDR_MTVAL    = 12'h343;
    localparam [11:0] ADDR_SATP     = 12'h180;
    localparam [11:0] ADDR_TLB_VPN  = 12'hFC0;
    localparam [11:0] ADDR_TLB_PPN  = 12'hFC1;
    localparam [11:0] ADDR_TLB_CMD  = 12'hFC2;

    // =========================================================================
    //  CSR Registers
    // =========================================================================
    reg [31:0] mstatus;
    reg [31:0] mtvec;
    reg [31:0] mscratch;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mtval;
    reg [31:0] satp;
    reg [31:0] tlb_vpn_reg;
    reg [31:0] tlb_ppn_reg;

    // =========================================================================
    //  Continuous Outputs
    // =========================================================================
    assign mepc_out      = mepc;
    assign mtvec_out     = mtvec;
    assign satp_out      = satp;
    assign tlb_write_vpn = tlb_vpn_reg[19:0];
    assign tlb_write_ppn = tlb_ppn_reg[21:0];

    // =========================================================================
    //  CSR Read (combinational)
    // =========================================================================
    always @(*) begin
        case (csr_addr_read)
            ADDR_MSTATUS:  csr_read_data = mstatus;
            ADDR_MTVEC:    csr_read_data = mtvec;
            ADDR_MSCRATCH: csr_read_data = mscratch;
            ADDR_MEPC:     csr_read_data = mepc;
            ADDR_MCAUSE:   csr_read_data = mcause;
            ADDR_MTVAL:    csr_read_data = mtval;
            ADDR_SATP:     csr_read_data = satp;
            ADDR_TLB_VPN:  csr_read_data = tlb_vpn_reg;
            ADDR_TLB_PPN:  csr_read_data = tlb_ppn_reg;
            default:       csr_read_data = 32'd0;
        endcase
    end

    // =========================================================================
    //  CSR Write Logic (sequential)
    //  Priority: trap_enter > mret > normal CSR write
    // =========================================================================
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            mstatus     <= 32'd0;
            mtvec       <= 32'd0;
            mscratch    <= 32'd0;
            mepc        <= 32'd0;
            mcause      <= 32'd0;
            mtval       <= 32'd0;
            satp        <= 32'd0;
            tlb_vpn_reg <= 32'd0;
            tlb_ppn_reg <= 32'd0;
            tlb_write_trigger <= 1'b0;
            tlb_flush_trigger <= 1'b0;
        end else begin
            // Default: clear single-cycle pulses
            tlb_write_trigger <= 1'b0;
            tlb_flush_trigger <= 1'b0;

            if (trap_enter) begin
                // ---- Trap Entry: Hardware saves state ----
                mepc   <= trap_pc;
                mcause <= trap_cause;
                mtval  <= trap_val;
                // Disable interrupts (simplified: clear MIE bit)
                mstatus[3] <= 1'b0;

            end else if (csr_write_enable) begin
                // ---- Normal CSR Write (from CSRRW/CSRRS/CSRRC instructions) ----
                case (csr_addr_write)
                    ADDR_MSTATUS: begin
                        case (csr_op)
                            2'b01: mstatus <= csr_write_data;                  // CSRRW
                            2'b10: mstatus <= mstatus | csr_write_data;        // CSRRS
                            2'b11: mstatus <= mstatus & ~csr_write_data;       // CSRRC
                            default: ;
                        endcase
                    end
                    ADDR_MTVEC: begin
                        case (csr_op)
                            2'b01: mtvec <= csr_write_data;
                            2'b10: mtvec <= mtvec | csr_write_data;
                            2'b11: mtvec <= mtvec & ~csr_write_data;
                            default: ;
                        endcase
                    end
                    ADDR_MSCRATCH: begin
                        case (csr_op)
                            2'b01: mscratch <= csr_write_data;
                            2'b10: mscratch <= mscratch | csr_write_data;
                            2'b11: mscratch <= mscratch & ~csr_write_data;
                            default: ;
                        endcase
                    end
                    ADDR_MEPC: begin
                        case (csr_op)
                            2'b01: mepc <= csr_write_data;
                            2'b10: mepc <= mepc | csr_write_data;
                            2'b11: mepc <= mepc & ~csr_write_data;
                            default: ;
                        endcase
                    end
                    ADDR_MCAUSE: begin
                        case (csr_op)
                            2'b01: mcause <= csr_write_data;
                            2'b10: mcause <= mcause | csr_write_data;
                            2'b11: mcause <= mcause & ~csr_write_data;
                            default: ;
                        endcase
                    end
                    ADDR_MTVAL: begin
                        case (csr_op)
                            2'b01: mtval <= csr_write_data;
                            2'b10: mtval <= mtval | csr_write_data;
                            2'b11: mtval <= mtval & ~csr_write_data;
                            default: ;
                        endcase
                    end
                    ADDR_SATP: begin
                        case (csr_op)
                            2'b01: satp <= csr_write_data;
                            2'b10: satp <= satp | csr_write_data;
                            2'b11: satp <= satp & ~csr_write_data;
                            default: ;
                        endcase
                    end
                    ADDR_TLB_VPN: begin
                        // Only CSRRW makes sense for TLB registers
                        tlb_vpn_reg <= csr_write_data;
                    end
                    ADDR_TLB_PPN: begin
                        tlb_ppn_reg <= csr_write_data;
                    end
                    ADDR_TLB_CMD: begin
                        if (csr_write_data == 32'd1) begin
                            tlb_write_trigger <= 1'b1;
                        end else if (csr_write_data == 32'd2) begin
                            tlb_flush_trigger <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule
