# Single-Cycle RISC-V Processor — Beginner's Guide

This project is a tiny 32-bit RISC-V CPU written in Verilog. It is **single-cycle**:
every instruction is fetched, decoded, executed and finished in **one clock cycle**.

## Quick start

Double-click **`run.bat`**. It will:

1. Compile all `.v` files with `iverilog`.
2. Run the simulation with `vvp` (you will see a cycle-by-cycle trace and a PASS/FAIL list).
3. Open the waveform `riscv.vcd` in GTKWave with the layout from `wave.gtkw`.

> A warning like `$readmemh(program.hex): Not enough words in the file` is normal.
> The program has 24 instructions but the instruction memory has room for 256.

## Files

| File | What it is |
|---|---|
| `pc.v` | Program Counter |
| `instr_mem.v` | Instruction memory (loads `program.hex`) |
| `reg_file.v` | 32 registers, x0 is always 0 |
| `alu.v` | Arithmetic Logic Unit |
| `alu_control.v` | Picks the exact ALU operation |
| `control_unit.v` | Main control unit (decodes the opcode) |
| `imm_gen.v` | Immediate generator (builds the constant) |
| `data_mem.v` | Data memory (for `lw` / `sw`) |
| `riscv_top.v` | Top module: wires everything together |
| `tb_riscv.v` | Self-checking testbench |
| `program.s` | Test program in assembly (with comments) |
| `program.hex` | Same program as machine code |
| `wave.gtkw` | GTKWave layout file |
| `run.bat` | One-click compile + simulate + view |

## Which instructions are supported?

A subset of RV32I:

- **R-type:** `add, sub, and, or, xor, sll, srl, sra, slt, sltu`
- **I-type ALU:** `addi, andi, ori, xori, slli, srli, srai, slti, sltiu`
- **Memory:** `lw, sw` (32-bit words only)
- **Branch:** `beq, bne`

Not supported (to keep it simple): `jal, jalr, lui, auipc`, byte/half loads and stores
(`lb, lh, sb, sh, ...`), `blt/bge`-style branches, and system instructions (`ecall`, ...).

---

## 1. The datapath (text diagram)

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
   |                        |  |                    (rs2_data = data that sw stores)
   |                        |  |  +---------+
   |                        +--|->| IMM GEN |--> imm (to ALU mux and branch adder)
   |                        |  |  +---------+
   |                        |  |
   |                        |  |   write_data    +-----+
   |                        |  +-----------------| MUX |<-- 0: alu_result
   |                        |                    |     |<-- 1: mem_rdata
   |                        |                    +-----+
   |                        |                   mem_to_reg
   |                        |
   |                        |  opcode  +---------+ alu_op  +-------------+
   |                        +--------->| CONTROL |-------->| ALU CONTROL |--> alu_ctrl (to ALU)
   |                                   |  UNIT   |         +-------------+
   |                                   +---------+                ^
   |                      reg_write, alu_src, mem_read,   funct3, funct7[5]
   |                      mem_write, mem_to_reg, branch
   |
   |  NEXT-PC LOGIC (runs at the same time as everything above)
   |
   |           +--------+ pc + 4
   |    pc --->| ADD +4 |------------->|0  |
   |           +--------+              |   |
   |           +--------+ pc + imm     |MUX|--- pc_next ---+
   |    pc --->|  ADD   |------------->|1  |               |
   |   imm --->|        | (branch      +---+               |
   |           +--------+  target)       ^                 |
   |                              branch_taken             |
   |                     = branch AND zero   (beq)         |
   |                     = branch AND !zero  (bne)         |
   |                                                       |
   +-------------- loaded into PC on the clock edge -------+
```

In words, every clock cycle the data flows like this:

```
PC --> Instruction Memory --> Control + Register File + Imm Gen
   --> ALU --> Data Memory --> back into the Register File
   --> and at the same time the next PC is chosen (pc+4 or branch target)
```

The three **multiplexers (MUX)** are the "switches" the control unit flips:

| MUX | Select signal | 0 chooses | 1 chooses |
|---|---|---|---|
| ALU input B | `alu_src` | `rs2_data` (register) | `imm` (constant) |
| Write-back data | `mem_to_reg` | `alu_result` | `mem_rdata` (from memory) |
| Next PC | `branch_taken` | `pc + 4` | `pc + imm` (branch target) |

---

## 2. What each module does

### `pc.v` — Program Counter
A 32-bit register that holds the address of the current instruction. On every rising
clock edge it loads `pc_next`. On reset it goes to `0`.

### `instr_mem.v` — Instruction Memory
A read-only array of 256 words loaded from `program.hex`. You give it the PC, it gives
back the 32-bit instruction. Since each instruction is 4 bytes, it uses `addr[9:2]`
(i.e. address ÷ 4) as the word index.

### `reg_file.v` — Register File
32 registers (`x0`…`x31`), each 32 bits.
- **Two read ports**: it reads `rs1` and `rs2` at the same time (combinational, instant).
- **One write port**: on the rising clock edge, if `reg_write = 1`, it writes `wd` into `rd`.
- **x0 is always 0**: writes to x0 are ignored and reading x0 always returns 0.

### `imm_gen.v` — Immediate Generator
Many instructions contain a constant ("immediate"), e.g. the `5` in `addi x1, x0, 5`.
RISC-V spreads these bits around the instruction differently per format (I, S, B).
This module collects the bits and **sign-extends** them to 32 bits (copies the top bit
into all the upper bits so negative numbers stay negative).

| Format | Used by | Immediate bits |
|---|---|---|
| I | `addi`, `lw` | `instr[31:20]` |
| S | `sw` | `instr[31:25]`, `instr[11:7]` |
| B | `beq` | `instr[31]`, `instr[7]`, `instr[30:25]`, `instr[11:8]`, then a `0` |

### `control_unit.v` — Main Control Unit
Looks only at the **opcode** (`instr[6:0]`) and produces the control signals
(`reg_write`, `alu_src`, `mem_read`, `mem_write`, `mem_to_reg`, `branch`, `alu_op`).
Think of it as the "brain" that decides which switches to flip.

### `alu_control.v` — ALU Control
The main control only says the *kind* of operation (`alu_op`). The ALU control looks
at `alu_op` **plus** `funct3` and `funct7[5]` to pick the exact ALU operation:

| `alu_op` | Meaning | ALU does |
|---|---|---|
| `00` | load/store | ADD (address = rs1 + imm) |
| `01` | branch | SUB (rs1 − rs2, check if zero) |
| `10` | R-type | depends on funct3/funct7 (add, sub, and, or, ...) |
| `11` | I-type ALU | depends on funct3 (addi, andi, ori, ...) |

ALU codes used: `0010`=ADD, `0110`=SUB, `0000`=AND, `0001`=OR, `0011`=XOR,
`0100`=SLL, `0101`=SRL, `1000`=SRA, `0111`=SLT, `1001`=SLTU.

### `alu.v` — ALU
Does the math: add, subtract, AND, OR, XOR, shifts and compares. It also outputs a
**zero flag** (`zero = 1` when the result is 0), which `beq` uses to check equality.

### `data_mem.v` — Data Memory
A read/write array of 256 words. `lw` reads from it (combinational), `sw` writes to it
on the rising clock edge. The address comes from the ALU (`rs1 + imm`).

### `riscv_top.v` — Top Module
Contains no "logic blocks" of its own — it **connects** all the modules above, has the
three multiplexers, the `pc + 4` adder, the `pc + imm` branch adder, and the small
branch decision: `branch_taken = branch AND (zero for beq / NOT zero for bne)`.

---

## 3. Control signals for each instruction type

| Instruction type | Example | reg_write | alu_src | mem_read | mem_write | mem_to_reg | branch | alu_op |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| R-type | `add x3, x1, x2` | **1** | 0 | 0 | 0 | 0 | 0 | `10` |
| I-type ALU | `addi x1, x0, 5` | **1** | **1** | 0 | 0 | 0 | 0 | `11` |
| Load | `lw x9, 0(x8)` | **1** | **1** | **1** | 0 | **1** | 0 | `00` |
| Store | `sw x3, 0(x8)` | 0 | **1** | 0 | **1** | 0 (don't care) | 0 | `00` |
| Branch | `beq x9, x3, skip` | 0 | 0 | 0 | 0 | 0 (don't care) | **1** | `01` |

Things to notice:
- Only `sw` and `beq` have `reg_write = 0` — they don't produce a register result.
- `alu_src = 1` whenever the second operand is a constant (`addi`, `lw`, `sw`).
- `mem_to_reg = 1` only for `lw` — it's the only instruction whose result comes from memory.
- "Don't care" means the value doesn't matter because nothing is written to a register.
  Our design sets it to 0 anyway.

---

## 4. Step-by-step walkthroughs

All examples use real values from `program.s`. Before each instruction runs,
`x1 = 5`, `x2 = 3`, `x3 = 8`, `x8 = 16`, and memory address 16 holds `8`.

### 4.1 `add x3, x1, x2` (at PC = 0x08, machine code `0x002081B3`)

**Goal:** `x3 = x1 + x2 = 5 + 3 = 8`

The instruction bits split into fields:

```
 funct7   rs2   rs1  funct3  rd    opcode
0000000  00010 00001  000  00011  0110011
           x2    x1   add    x3   R-type
```

| Step | What happens |
|---|---|
| 1. Fetch | PC = `0x08` goes into instruction memory, which outputs `0x002081B3`. |
| 2. Decode | Opcode `0110011` = R-type. Control sets: **reg_write=1, alu_src=0, mem_read=0, mem_write=0, mem_to_reg=0, branch=0, alu_op=10**. Register file reads `x1 = 5` and `x2 = 3`. |
| 3. Execute | ALU control sees `alu_op=10`, `funct3=000`, `funct7[5]=0` → ADD (`0010`). `alu_src=0` so ALU input B = `rs2_data = 3`. ALU computes `5 + 3 = 8`. |
| 4. Memory | `mem_read=0`, `mem_write=0` → data memory does nothing. |
| 5. Write back | `mem_to_reg=0` → write_data = ALU result = `8`. On the clock edge, since `reg_write=1`, `x3 ← 8`. |
| Next PC | `branch=0` → `branch_taken=0` → PC = `0x08 + 4 = 0x0C`. |

### 4.2 `lw x9, 0(x8)` (at PC = 0x28, machine code `0x00042483`)

**Goal:** `x9 = memory[x8 + 0] = memory[16] = 8`

```
   imm[11:0]     rs1  funct3  rd    opcode
000000000000   01000   010  01001  0000011
     0           x8     lw    x9    load
```

| Step | What happens |
|---|---|
| 1. Fetch | PC = `0x28` → instruction `0x00042483`. |
| 2. Decode | Opcode `0000011` = load. Control sets: **reg_write=1, alu_src=1, mem_read=1, mem_write=0, mem_to_reg=1, branch=0, alu_op=00**. Register file reads `x8 = 16`. Immediate generator outputs `imm = 0`. |
| 3. Execute | `alu_op=00` → ALU does ADD. `alu_src=1` → B = `imm = 0`. ALU computes the **address** `16 + 0 = 16`. |
| 4. Memory | `mem_read=1` → data memory reads address 16 (word index 16/4 = 4) and outputs `8`. |
| 5. Write back | `mem_to_reg=1` → write_data = memory data = `8` (not the ALU result 16!). On the clock edge `x9 ← 8`. |
| Next PC | `branch=0` → PC = `0x28 + 4 = 0x2C`. |

### 4.3 `beq x9, x3, skip` (at PC = 0x30, machine code `0x00348463`)

**Goal:** if `x9 == x3` then jump to `skip` (address `0x38`), else go to `0x34`.
Here `x9 = 8` and `x3 = 8`, so the branch **is taken**.

```
imm[12] imm[10:5]  rs2   rs1  funct3 imm[4:1] imm[11] opcode
   0     000000   00011 01001  000    0100      0     1100011
                    x3    x9   beq                    branch
```

The immediate generator reassembles the scattered bits:
`imm = {imm[12], imm[11], imm[10:5], imm[4:1], 0} = 0 0 000000 0100 0 = 8`.
So the branch offset is **+8 bytes** (2 instructions ahead).

| Step | What happens |
|---|---|
| 1. Fetch | PC = `0x30` → instruction `0x00348463`. |
| 2. Decode | Opcode `1100011` = branch. Control sets: **reg_write=0, alu_src=0, mem_read=0, mem_write=0, mem_to_reg=0, branch=1, alu_op=01**. Register file reads `x9 = 8` and `x3 = 8`. Imm gen outputs `8`. |
| 3. Execute | `alu_op=01` → ALU does SUB. `alu_src=0` → B = `x3`. ALU computes `8 − 8 = 0`, so **zero = 1**. At the same time the branch adder computes `branch_target = PC + imm = 0x30 + 8 = 0x38`. |
| 4. Memory | Nothing (`mem_read=0`, `mem_write=0`). |
| 5. Write back | Nothing (`reg_write=0`). |
| Next PC | `branch=1` AND `zero=1` → `branch_taken=1` → PC mux picks `branch_target` → **PC = 0x38**. The instruction at `0x34` (`addi x11, x0, 99`) is skipped, which is why the test checks `x11 == 0`. |

If the registers were *not* equal, the ALU result would be non-zero, `zero = 0`,
`branch_taken = 0`, and the PC would simply become `0x30 + 4 = 0x34`.

---

## 5. The test program and the testbench

`program.s` (machine code in `program.hex`) exercises every required instruction:
`add, sub, and, or, addi, lw, sw, beq` — including a negative result, a negative
memory offset, a taken branch, a not-taken branch, a backward branch (a loop that runs
3 times), and an attempt to write `x0`. It ends with `beq x0, x0, 0`, an infinite loop
that acts as "halt".

`tb_riscv.v`:
1. Generates a 10 ns clock and holds reset for 2 cycles.
2. Prints a trace each cycle (`pc`, `instr`, ALU result).
3. After 40 cycles, checks 20 values (16 registers, 3 memory words, and the final PC),
   printing **PASS** or **FAIL** for each and a summary.
4. Writes `riscv.vcd` for GTKWave.

## 6. Reading the waveform

`wave.gtkw` groups the signals:

- **Clock / Reset** – `clk`, `reset`
- **Fetch** – `pc`, `instr`, `pc_next`
- **Decode** – `opcode`, `rs1`, `rs2`, `rd`, `imm`
- **Control signals** – `reg_write`, `alu_src`, `mem_read`, `mem_write`, `mem_to_reg`, `branch`, `alu_op`, `alu_ctrl`
- **ALU** – `rs1_data` (input A), `rs2_data`, `alu_b` (input B after the mux), `alu_result`, `alu_zero`
- **Memory / Write-back** – `mem_rdata`, `write_data`
- **Branch** – `branch_taken`, `branch_target`

Tips: values before the first clock edge show as red `x` (unknown) because the PC has
not been reset yet — that's expected. Use **Zoom Fit** (or Ctrl+Alt+F) and the zoom
buttons to change the view; click in the wave area to place a cursor and read values.
