# ============================================================
# program.s - Test program for the single-cycle RV32I CPU
# The machine code for this file is in program.hex (one
# instruction per line, address 0x00 first).
# Uses: add, sub, and, or, addi, lw, sw, beq
# ============================================================

        addi x1,  x0, 5        # 0x00: x1 = 0 + 5 = 5
        addi x2,  x0, 3        # 0x04: x2 = 0 + 3 = 3
        add  x3,  x1, x2       # 0x08: x3 = 5 + 3 = 8
        sub  x4,  x1, x2       # 0x0C: x4 = 5 - 3 = 2
        and  x5,  x1, x2       # 0x10: x5 = 0101 & 0011 = 0001 = 1
        or   x6,  x1, x2       # 0x14: x6 = 0101 | 0011 = 0111 = 7
        sub  x7,  x2, x1       # 0x18: x7 = 3 - 5 = -2 (0xFFFFFFFE), tests negative results
        addi x8,  x0, 16       # 0x1C: x8 = 16, used as a base address for memory
        sw   x3,  0(x8)        # 0x20: mem[16] = x3 = 8
        sw   x7,  4(x8)        # 0x24: mem[20] = x7 = -2
        lw   x9,  0(x8)        # 0x28: x9 = mem[16] = 8
        lw   x10, 4(x8)        # 0x2C: x10 = mem[20] = -2
        beq  x9,  x3, skip     # 0x30: 8 == 8, so branch IS taken -> jump to 0x38
        addi x11, x0, 99       # 0x34: SKIPPED by the branch, so x11 must stay 0
skip:
        beq  x1,  x2, wrong    # 0x38: 5 != 3, so branch NOT taken -> fall through
        addi x12, x0, 42       # 0x3C: x12 = 42 (runs only if beq above was not taken)
wrong:
        addi x0,  x0, 55       # 0x40: try to write x0 -> ignored, x0 stays 0
        add  x13, x12, x7      # 0x44: x13 = 42 + (-2) = 40
        sw   x13, -8(x8)       # 0x48: mem[16 - 8] = mem[8] = 40 (negative offset)
        addi x15, x0, 3        # 0x4C: x15 = 3, loop limit
loop:
        addi x14, x14, 1       # 0x50: x14 = x14 + 1 (loop counter)
        beq  x14, x15, done    # 0x54: if counter == 3, leave the loop (forward branch)
        beq  x0,  x0, loop     # 0x58: always taken -> jump back to 0x50 (backward branch)
done:
        beq  x0,  x0, done     # 0x5C: infinite loop = "halt" (PC stays at 0x5C)
