# Single-Cycle RISC-V Processor (RV32I Subset) in Verilog

A 32-bit single-cycle RISC-V CPU written in Verilog-2005. Every instruction is fetched, decoded, executed, and written back in one clock cycle. The design is verified with a self-checking testbench in Icarus Verilog that runs an assembly test program and checks registers, memory, and the final PC.

## Features

- 32-bit single-cycle datapath implementing a subset of **RV32I**
- Modular design: PC, instruction memory, register file, immediate generator, control unit, ALU control, ALU, data memory
- 32 × 32-bit register file with 2 read ports / 1 write port; `x0` hardwired to zero
- Immediate generator for **I, S, and B** formats with sign extension
- Two-level decoding: main control (opcode → `alu_op`) + ALU control (`alu_op`, `funct3`, `funct7[5]` → ALU operation)
- 256-word instruction memory (loaded from `program.hex`) and 256-word data memory
- Self-checking testbench with cycle-by-cycle trace and PASS/FAIL summary

## Supported Instructions

| Type | Instructions |
|---|---|
| R-type | `add`, `sub`, `and`, `or`, `xor`, `sll`, `srl`, `sra`, `slt`, `sltu` |
| I-type ALU | `addi`, `andi`, `ori`, `xori`, `slli`, `srli`, `srai`, `slti`, `sltiu` |
| Load / Store | `lw`, `sw` (32-bit word access) |
| Branch | `beq`, `bne` |

**Not supported:** `jal`, `jalr`, `lui`, `auipc`, byte/halfword loads and stores (`lb`, `lh`, `lbu`, `lhu`, `sb`, `sh`), `blt`/`bge`/`bltu`/`bgeu`, and system instructions (`ecall`, `ebreak`, `fence`, CSRs).

## Datapath

```
 FETCH          DECODE                            EXECUTE              MEMORY

 +----+ pc  +-------------+       +----------+ rs1_data        +-----+
 | PC |---->| INSTRUCTION |-+-rs1>|          |---------------->|  A  | alu_result  +---------+
 +----+     |   MEMORY    | +-rs2>| REGISTER | rs2_data  +---+ | ALU |------------>| addr    |
   ^        +-------------+ +-rd->|   FILE   |---+------>|0  | |     |             |  DATA   |
   |                        |     |          |   |       |MUX|>|  B  |         +-->| wd      |
   |                        |  +->| wd       |   |  imm->|1  | +-----+         |   | MEMORY  |
   |                        |  |  +----------+   |       +---+    |            |   |      rd |--> mem_rdata
   |                        |  |                 |      alu_src   v zero       |   +---------+
   |                        |  |                 |           (to next-PC)      |
   |                        |  |                 +-----------------------------+
   |                        |  |  +---------+
   |                        +--|->| IMM GEN |--> imm (to ALU mux and branch adder)
   |                        |  |  +---------+
   |                        |  |   write_data    +-----+
   |                        |  +-----------------| MUX |<-- 0: alu_result
   |                        |                    |     |<-- 1: mem_rdata
   |                        |                    +-----+
   |                        |                   mem_to_reg
   |                        |  opcode  +---------+ alu_op  +-------------+
   |                        +--------->| CONTROL |-------->| ALU CONTROL |--> alu_ctrl (to ALU)
   |                                   |  UNIT   |         +-------------+
   |                                   +---------+                ^
   |                      reg_write, alu_src, mem_read,   funct3, funct7[5]
   |                      mem_write, mem_to_reg, branch
   |
   |           +--------+ pc + 4
   |    pc --->| ADD +4 |------------->|0  |
   |           +--------+              |   |
   |           +--------+ pc + imm     |MUX|--- pc_next ---+
   |    pc --->|  ADD   |------------->|1  |               |
   |   imm --->|        |              +---+               |
   |           +--------+                ^                 |
   |                              branch_taken             |
   |                     = branch AND zero   (beq)         |
   |                     = branch AND !zero  (bne)         |
   +-------------- loaded into PC on the clock edge -------+
```

### Control Signals

| Instruction type | reg_write | alu_src | mem_read | mem_write | mem_to_reg | branch | alu_op |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| R-type | 1 | 0 | 0 | 0 | 0 | 0 | `10` |
| I-type ALU | 1 | 1 | 0 | 0 | 0 | 0 | `11` |
| Load (`lw`) | 1 | 1 | 1 | 0 | 1 | 0 | `00` |
| Store (`sw`) | 0 | 1 | 0 | 1 | 0 | 0 | `00` |
| Branch | 0 | 0 | 0 | 0 | 0 | 1 | `01` |

## File Structure

```
riscv-single-cycle-verilog/
├── riscv_top.v      # Top level: datapath wiring, muxes, PC adders, branch logic
├── pc.v             # Program counter
├── instr_mem.v      # Instruction memory (loads program.hex)
├── reg_file.v       # 32 x 32-bit register file
├── imm_gen.v        # Immediate generator (I/S/B formats)
├── control_unit.v   # Main control unit (opcode decode)
├── alu_control.v    # ALU control (funct3/funct7 decode)
├── alu.v            # ALU with zero flag
├── data_mem.v       # Data memory
├── tb_riscv.v       # Self-checking testbench
├── program.s        # Test program (assembly, commented)
├── program.hex      # Test program (machine code)
├── wave.gtkw        # GTKWave signal layout
├── run.bat          # One-click compile + simulate + view (Windows)
└── README.md
```

## Running the Simulation

Requires [Icarus Verilog](https://steveicarus.github.io/iverilog/) and optionally [GTKWave](https://gtkwave.sourceforge.net/).

**Windows:** double-click `run.bat`.

**Any platform:**

```bash
iverilog -g2005 -Wall -o riscv_sim.vvp \
    tb_riscv.v riscv_top.v pc.v instr_mem.v reg_file.v \
    alu.v alu_control.v control_unit.v imm_gen.v data_mem.v
vvp riscv_sim.vvp
gtkwave riscv.vcd wave.gtkw      # optional: view waveform
```

> A `$readmemh(program.hex): Not enough words in the file` warning is expected: the 24-instruction program is smaller than the 256-word instruction memory.

### Test Program

`program.s` exercises `add`, `sub`, `and`, `or`, `addi`, `lw`, `sw`, and `beq`, covering:

- negative ALU results and negative memory offsets
- taken and not-taken branches
- a backward-branch loop that runs 3 times
- an attempted write to `x0` (must be ignored)
- a `beq x0, x0, 0` halt loop

After 40 cycles, the testbench checks 16 registers, 3 memory words, and the final PC.

## Test Results

```
PASS: x0  (always zero)        = 0x00000000 (0)
PASS: x1  (addi 5)             = 0x00000005 (5)
PASS: x2  (addi 3)             = 0x00000003 (3)
PASS: x3  (add 5+3)            = 0x00000008 (8)
PASS: x4  (sub 5-3)            = 0x00000002 (2)
PASS: x5  (and 5&3)            = 0x00000001 (1)
PASS: x6  (or 5|3)             = 0x00000007 (7)
PASS: x7  (sub 3-5)            = 0xfffffffe (-2)
PASS: x8  (base addr)          = 0x00000010 (16)
PASS: x9  (lw mem[16])         = 0x00000008 (8)
PASS: x10 (lw mem[20])         = 0xfffffffe (-2)
PASS: x11 (skipped by beq)     = 0x00000000 (0)
PASS: x12 (beq not taken)      = 0x0000002a (42)
PASS: x13 (add 42+-2)          = 0x00000028 (40)
PASS: x14 (loop counter)       = 0x00000003 (3)
PASS: x15 (loop limit)         = 0x00000003 (3)
PASS: mem[8]  (sw -8(x8))      = 0x00000028 (40)
PASS: mem[16] (sw 0(x8))       = 0x00000008 (8)
PASS: mem[20] (sw 4(x8))       = 0xfffffffe (-2)
PASS: pc  (halt loop)          = 0x0000005c (92)
SUMMARY: 20 passed, 0 failed, 20 total
*** ALL TESTS PASSED ***
```

## Author

Protik Dey
