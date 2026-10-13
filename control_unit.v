// ============================================================
// control_unit.v - Main Control Unit
// Looks at the 7-bit opcode and sets the control signals that
// steer data through the datapath.
// ============================================================
`timescale 1ns/1ps          // time unit / precision for simulation

module control_unit (
    input  wire [6:0] opcode,      // instruction bits [6:0]
    output reg        reg_write,   // 1 = write result into register rd
    output reg        alu_src,     // 0 = ALU input B is rs2, 1 = immediate
    output reg        mem_read,    // 1 = read data memory (lw)
    output reg        mem_write,   // 1 = write data memory (sw)
    output reg        mem_to_reg,  // 0 = write ALU result to rd, 1 = write memory data
    output reg        branch,      // 1 = this is a branch instruction (beq/bne)
    output reg  [1:0] alu_op       // tells ALU control which kind of operation
);
    // RISC-V opcodes we support
    localparam OP_R      = 7'b0110011;  // add, sub, and, or, ...
    localparam OP_I_ALU  = 7'b0010011;  // addi, andi, ori, ...
    localparam OP_LOAD   = 7'b0000011;  // lw
    localparam OP_STORE  = 7'b0100011;  // sw
    localparam OP_BRANCH = 7'b1100011;  // beq, bne

    always @(*) begin
        // Default: everything off (acts like a NOP for unknown opcodes)
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        branch     = 1'b0;
        alu_op     = 2'b00;

        case (opcode)
            OP_R: begin                 // R-type: rd = rs1 OP rs2
                reg_write = 1'b1;       // result goes to rd
                alu_op    = 2'b10;      // ALU control looks at funct3/funct7
            end
            OP_I_ALU: begin             // I-type: rd = rs1 OP imm
                reg_write = 1'b1;       // result goes to rd
                alu_src   = 1'b1;       // second operand is the immediate
                alu_op    = 2'b11;      // ALU control looks at funct3
            end
            OP_LOAD: begin              // lw: rd = mem[rs1 + imm]
                reg_write  = 1'b1;      // loaded value goes to rd
                alu_src    = 1'b1;      // address = rs1 + immediate
                mem_read   = 1'b1;      // read data memory
                mem_to_reg = 1'b1;      // write memory data (not ALU result) to rd
                alu_op     = 2'b00;     // ALU adds
            end
            OP_STORE: begin             // sw: mem[rs1 + imm] = rs2
                alu_src   = 1'b1;       // address = rs1 + immediate
                mem_write = 1'b1;       // write data memory
                alu_op    = 2'b00;      // ALU adds
            end
            OP_BRANCH: begin            // beq: if (rs1 == rs2) PC = PC + imm
                branch = 1'b1;          // this is a branch
                alu_op = 2'b01;         // ALU subtracts; zero flag means "equal"
            end
            default: ;                  // unknown opcode: keep all signals 0
        endcase
    end
endmodule
