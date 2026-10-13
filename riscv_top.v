// ============================================================
// riscv_top.v - Single-Cycle RV32I Processor (top level)
// Connects all the blocks into a datapath. Every instruction
// finishes in exactly one clock cycle.
//
// Supported: R-type ALU ops (add, sub, and, or, xor, sll, srl,
// sra, slt, sltu), I-type ALU ops (addi, andi, ori, ...),
// lw, sw, beq, bne.
// ============================================================
`timescale 1ns/1ps          // time unit / precision for simulation

module riscv_top (
    input wire clk,     // clock
    input wire reset    // active-high reset
);
    // ---------------- Wires between the blocks ----------------
    wire [31:0] pc;            // current instruction address
    wire [31:0] pc_next;       // address of the next instruction
    wire [31:0] pc_plus4;      // pc + 4 (next sequential instruction)
    wire [31:0] branch_target; // pc + immediate (where a branch jumps to)
    wire [31:0] instr;         // current instruction

    // Instruction fields (same bit positions in every RISC-V instruction)
    wire [6:0] opcode   = instr[6:0];    // what kind of instruction
    wire [4:0] rd       = instr[11:7];   // destination register
    wire [2:0] funct3   = instr[14:12];  // sub-operation
    wire [4:0] rs1      = instr[19:15];  // source register 1
    wire [4:0] rs2      = instr[24:20];  // source register 2
    wire       funct7_5 = instr[30];     // distinguishes add/sub and srl/sra

    // Control signals (from the control units)
    wire       reg_write, alu_src, mem_read, mem_write, mem_to_reg, branch;
    wire [1:0] alu_op;
    wire [3:0] alu_ctrl;

    // Data values
    wire [31:0] rs1_data;      // value read from register rs1
    wire [31:0] rs2_data;      // value read from register rs2
    wire [31:0] imm;           // sign-extended immediate
    wire [31:0] alu_b;         // second ALU operand (after the mux)
    wire [31:0] alu_result;    // ALU output
    wire        alu_zero;      // 1 when ALU output is zero
    wire [31:0] mem_rdata;     // data read from data memory
    wire [31:0] write_data;    // data written back into rd

    // ---------------- 1. FETCH ----------------
    pc u_pc (
        .clk(clk), .reset(reset),
        .pc_next(pc_next), .pc(pc)
    );

    instr_mem u_imem (
        .addr(pc), .instr(instr)
    );

    // ---------------- 2. DECODE ----------------
    control_unit u_ctrl (
        .opcode(opcode),
        .reg_write(reg_write),   .alu_src(alu_src),
        .mem_read(mem_read),     .mem_write(mem_write),
        .mem_to_reg(mem_to_reg), .branch(branch),
        .alu_op(alu_op)
    );

    reg_file u_regfile (
        .clk(clk), .reg_write(reg_write),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .wd(write_data),
        .rd1(rs1_data), .rd2(rs2_data)
    );

    imm_gen u_immgen (
        .instr(instr), .imm(imm)
    );

    // ---------------- 3. EXECUTE ----------------
    alu_control u_aluctrl (
        .alu_op(alu_op), .funct3(funct3), .funct7_5(funct7_5),
        .alu_ctrl(alu_ctrl)
    );

    assign alu_b = alu_src ? imm : rs2_data;     // MUX: immediate or rs2?

    alu u_alu (
        .a(rs1_data), .b(alu_b), .alu_ctrl(alu_ctrl),
        .result(alu_result), .zero(alu_zero)
    );

    // ---------------- 4. MEMORY ----------------
    data_mem u_dmem (
        .clk(clk), .mem_read(mem_read), .mem_write(mem_write),
        .addr(alu_result), .wd(rs2_data), .rd(mem_rdata)
    );

    // ---------------- 5. WRITE BACK ----------------
    assign write_data = mem_to_reg ? mem_rdata : alu_result;  // MUX: memory or ALU?

    // ---------------- NEXT PC ----------------
    assign pc_plus4      = pc + 32'd4;           // normal case: next instruction
    assign branch_target = pc + imm;             // branch: jump by the immediate

    // Branch is taken when it's a branch AND the condition holds:
    //   beq (funct3=000): rs1 - rs2 == 0  -> zero = 1
    //   bne (funct3=001): rs1 - rs2 != 0  -> zero = 0
    wire branch_cond  = (funct3 == 3'b001) ? ~alu_zero : alu_zero;
    wire branch_taken = branch & branch_cond;

    assign pc_next = branch_taken ? branch_target : pc_plus4;  // MUX: branch or +4?
endmodule
