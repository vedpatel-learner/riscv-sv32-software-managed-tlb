# Architecture Guide

> Detailed technical reference for the RISC-V RV32I + Sv32 TLB processor architecture.

---

## 1. System Overview

The system is a 5-stage in-order pipelined processor implementing the RISC-V RV32I base integer ISA with Zicsr extension, augmented with a software-managed 4-entry TLB for Sv32-style virtual memory translation.

### Block Diagram

```
                    ┌──────────────────────────────────────────────────┐
                    │              fpga_top.v                          │
                    │  ┌──────────┐  ┌─────────────────────────────┐  │
    125 MHz ──────▶ │  │clk_divider│─▶│    Microprocessor.v        │  │──▶ LED[3:0]
    btn0 ─────────▶ │  │125→62.5MHz│  │  ┌───────────────────────┐ │  │
                    │  └──────────┘  │  │    core.v               │ │  │
                    │                │  │  ┌────┬────┬─────┬────┐ │ │  │
                    │                │  │  │ IF │ ID │ EX  │ MEM│ │ │  │
                    │                │  │  │    │    │     │+TLB│ │ │  │
                    │                │  │  │    │    │     │    │ │ │  │
                    │                │  │  └────┴────┴─────┴────┘ │ │  │
                    │                │  │  ┌─────────┐ ┌────────┐ │ │  │
                    │                │  │  │  CSR    │ │Perf Ctr│ │ │  │
                    │                │  │  └─────────┘ └────────┘ │ │  │
                    │                │  └───────────────────────┘ │  │
                    │                │  ┌──────────┐┌──────────┐  │  │
                    │                │  │Instr BRAM││Data BRAM │  │  │
                    │                │  │  16 KB   ││  16 KB   │  │  │
                    │                │  └──────────┘└──────────┘  │  │
                    │                │  ┌──────────────────────┐  │  │
                    │                │  │  ILA Debug Core      │  │  │
                    │                │  │  (15 probes, 1K buf) │  │  │
                    │                │  └──────────────────────┘  │  │
                    │                └─────────────────────────────┘  │
                    └──────────────────────────────────────────────────┘
```

---

## 2. Pipeline Stages

### 2.1 Instruction Fetch (IF)

**Module**: `rv32i_fetch_stage.v` (49 lines, combinational)

PC selection priority (highest to lowest):
1. **Trap flush** → `mtvec` (trap vector base)
2. **MRET flush** → `mepc` (exception PC)
3. **Branch taken** → `branch_target` (from EX)
4. **Stall** → `current_pc` (hold)
5. **Sequential** → `current_pc + 4`

The IF/ID register captures `{valid, pc, instruction}` on each clock edge.

### 2.2 Instruction Decode (ID)

**Module**: `rv32i_decode_stage.v` (320 lines, combinational)

Decodes all 47 instructions:
- **RV32I base**: 40 instructions (R/I/S/B/U/J types)
- **Zicsr**: CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
- **Privileged**: ECALL, EBREAK, MRET

Generates:
- Register addresses (rs1, rs2, rd)
- Immediate values (5 format types)
- ALU operation code
- Writeback source selection
- Memory access signals
- CSR operation fields
- Hazard detection inputs

### 2.3 Execute (EX)

**Module**: `rv32i_execute_stage.v` (99 lines, combinational)

Contains:
- **ALU** (`alu.v`, 22 lines): ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND, PASS
- **Branch comparator**: BEQ, BNE, BLT, BGE, BLTU, BGEU
- **Address calculation**: Branch targets, JAL/JALR targets
- **Trap detection**: Misaligned load/store (causes 4/5/6), illegal instruction (2), ECALL (11), EBREAK (3)

**Forwarding**: The forwarding unit (`rv32i_forwarding_unit.v`, 32 lines) selects:
1. EX/MEM bypass (priority, excludes loads in EX/MEM)
2. MEM/WB bypass (includes load data)
3. Register file value (no hazard)

### 2.4 Memory (MEM)

**Module**: `rv32i_memory_stage.v` (158 lines, combinational)

This is where TLB integration happens:

```
Virtual Address (from ALU)
        │
   ┌────▼────┐
   │  TLB    │  translation_enable = (satp ≠ 0) && !handler_mode
   │ Lookup  │
   └────┬────┘
        │
   ┌────▼────┐        ┌───────────────┐
   │ Hit?    │──NO──▶ │ Page Fault    │ cause 13 (load) / 15 (store)
   │         │        │ → Trap flow   │
   └────┬────┘        └───────────────┘
        │ YES
   ┌────▼────────────┐
   │ Physical Addr   │ = {TLB_PPN[21:0], VA[11:0]}
   │ → Data Memory   │
   └─────────────────┘
```

Also handles:
- Store data alignment with byte-enable masks (SB/SH/SW)
- Load data formatting with sign/zero extension (LB/LH/LW/LBU/LHU)

### 2.5 Writeback (WB)

**Module**: `rv32i_writeback_stage.v` (27 lines, combinational)

4-way result multiplexer:
- `WB_ALU (00)`: ALU result
- `WB_MEM (01)`: Memory load data
- `WB_PC4 (10)`: PC+4 (for JAL/JALR)
- `WB_CSR (11)`: CSR read data

---

## 3. CSR Infrastructure

**Module**: `rv32i_csr.v` (205 lines)

### Register Map

| Address | Name | Purpose |
|---------|------|---------|
| `0x300` | MSTATUS | Machine status (MIE bit) |
| `0x305` | MTVEC | Trap vector base address |
| `0x340` | MSCRATCH | Scratch register for handler |
| `0x341` | MEPC | Exception PC (saved on trap) |
| `0x342` | MCAUSE | Trap cause code |
| `0x343` | MTVAL | Faulting address |
| `0x180` | SATP | Page table base address |
| `0xFC0` | TLB_VPN | Custom: VPN for TLB fill |
| `0xFC1` | TLB_PPN | Custom: PPN for TLB fill |
| `0xFC2` | TLB_CMD | Custom: TLB command trigger |

### Write Priority

```
trap_enter > normal CSR write
```

When `trap_enter` is asserted: MEPC ← trap_pc, MCAUSE ← cause, MTVAL ← faulting_address.

### TLB Commands (via TLB_CMD)

| Value | Action |
|-------|--------|
| `1` | Commit entry: write `{TLB_VPN, TLB_PPN}` to TLB at FIFO position |
| `2` | Flush all: invalidate all 4 TLB entries |

---

## 4. TLB Design

**Module**: `rv32i_tlb.v` (84 lines)

### Entry Format

```
┌───────┬──────────────────┬────────────────────────┐
│ valid │    vpn[19:0]     │      ppn[21:0]         │
│  1b   │     20 bits      │       22 bits          │
└───────┴──────────────────┴────────────────────────┘
                    43 bits per entry × 4 entries = 172 bits total
```

### Lookup (Combinational)

All 4 entries are compared in parallel against the requested VPN. If any entry matches with `valid=1`, `tlb_hit` is asserted and the corresponding PPN is output.

### FIFO Replacement

```
next_write_index: 0 → 1 → 2 → 3 → 0 → 1 → ...
```

A 2-bit counter (`next_write_index`) determines where the next entry is written. This is the simplest possible replacement policy — just 2 flip-flops.

### Performance Counters

The TLB maintains three 32-bit counters:
- `access_count`: incremented on every valid lookup
- `hit_count`: incremented on lookup with match
- `miss_count`: incremented on lookup without match

---

## 5. Trap & Page Fault Handling

### Trap Entry Flow

```
1. Trap detected (EX or MEM stage)
2. trap_inflight flag set → fetch stage redirects to MTVEC
3. Pipeline bubbles propagate (4 cycles to drain)
4. When trap reaches WB: CSR saves MEPC, MCAUSE, MTVAL
5. handler_mode set → translation disabled (identity mapping)
6. Handler executes at MTVEC
```

### Page Fault Handler (36 instructions at PC 0x200–0x28C)

```assembly
# === Context Save ===
csrrw   x1, mscratch, x1       # Save x1 to MSCRATCH
sw      x5, 0(x0)              # Save x5-x7, x28 to memory
sw      x6, 4(x0)
sw      x7, 8(x0)
sw      x28, 16(x0)

# === Address Parsing ===
csrr    x5, mtval              # Get faulting virtual address
srli    x6, x5, 22             # VPN[1] = VA[31:22]
srli    x7, x5, 12             # VPN[0] = VA[21:12]
andi    x7, x7, 0x3FF          # Mask to 10 bits

# === L1 Page Table Walk ===
csrr    x28, satp              # Get page table base
slli    x6, x6, 2              # VPN[1] × 4 = byte offset
add     x6, x6, x28            # L1 PTE address
lw      x6, 0(x6)              # Load L1 PTE (1 load-use stall)
andi    x28, x6, 1             # Check valid bit
beq     x28, x0, invalid       # Branch if invalid

# === L2 Page Table Walk ===
srli    x6, x6, 10             # Extract L2 table base PPN
slli    x6, x6, 12             # Convert to physical address
slli    x7, x7, 2              # VPN[0] × 4 = byte offset
add     x7, x7, x6             # L2 PTE address
lw      x7, 0(x7)              # Load L2 PTE (1 load-use stall)
andi    x28, x7, 1             # Check valid bit
beq     x28, x0, invalid       # Branch if invalid

# === TLB Fill ===
srli    x6, x5, 12             # VPN from faulting VA
csrrw   x0, 0xFC0, x6          # TLB_VPN ← VPN
csrrw   x0, 0xFC1, x7          # TLB_PPN ← PPN (from L2 PTE)
li      x7, 1
csrrw   x0, 0xFC2, x7          # TLB_CMD ← 1 (commit)

# === Context Restore ===
lw      x28, 16(x0)
lw      x7, 8(x0)
lw      x6, 4(x0)
lw      x5, 0(x0)
csrrw   x1, mscratch, x1       # Restore x1 from MSCRATCH

# === Return ===
mret                            # PC ← MEPC, handler_mode ← 0
```

**Total**: 36 instructions + 2 load-use stalls + 8 flush cycles = **46 cycles per miss**

---

## 6. Performance Counter Infrastructure

### Counter Definitions

| Counter | Width | Incremented When |
|---------|:-----:|-----------------|
| `total_cycles` | 32 | Every cycle (while not halted) |
| `stall_cycles` | 32 | Load-use stall active |
| `instr_count` | 32 | Valid instruction retires at WB (non-trap) |
| `tlb_access_count` | 32 | Valid TLB lookup |
| `tlb_hit_count` | 32 | TLB lookup with match |
| `tlb_miss_count` | 32 | TLB lookup without match |

### CPI Note

CPI values (1.25–1.33) appear similar across all tests because the instruction counter includes handler instructions. The meaningful metric is **overhead percentage**, which compares against the baseline CPU.

---

## 7. Memory Architecture

### Instruction Memory
- 4096 × 32-bit synchronous BRAM (16 KB)
- Word-addressed: `pc_address[13:2]`
- Read-only during execution
- Initialized from `.mem` file at synthesis

### Data Memory
- 4096 × 32-bit synchronous BRAM (16 KB)
- Word-addressed: `alu_out_address[13:2]`
- Supports byte/halfword/word access via masks
- Initialized from `.mem` file at synthesis

### Page Table Layout (in Data Memory)

```
Address 0x000–0x0FF:  Context save area + scratch
Address 0x100–0x1FF:  L1 page table (up to 1024 PTEs)
Address 0x200+:       L2 page tables (linked from L1)
Address 0x1000+:      Data pages (4 KB each)
```

---

## 8. Design Scope — Pedagogical Simplifications

This implementation makes three deliberate simplifications relative to the full RISC-V Sv32 specification:

1. **No instruction-side TLB** — only data memory accesses (LW/SW) are translated
2. **No R/W/X permission enforcement** — all valid TLB entries permit read and write
3. **Simplified SATP** — used as a 32-bit base address register only (no MODE/ASID)

These reduce hardware complexity while preserving the phenomena under study (TLB capacity effects and software page-walk overhead).
