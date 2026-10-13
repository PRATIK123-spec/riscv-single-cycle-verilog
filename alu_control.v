// ============================================================
// alu_control.v - ALU Control Unit
// Turns the 2-bit alu_op from the main control unit plus the
// instruction's funct3/funct7 fields into the 4-bit ALU operation.
//
//   alu_op = 00 -> ADD            (lw, sw: address = rs1 + imm)
//   alu_op = 01 -> SUB            (beq/bne: compare by subtracting)
//   alu_op = 10 -> R-type         (look at funct3 and funct7)
//   alu_op = 11 -> I-type ALU     (look at funct3, e.g. addi)
// ============================================================
`timescale 1ns/1ps          // time unit / precision for simulation

module alu_control (
    input  wire [1:0] alu_op,     // from main control unit
    input  wire [2:0] funct3,     // instruction bits [14:12]
    input  wire       funct7_5,   // instruction bit 30 (bit 5 of funct7): picks sub/sra
    output reg  [3:0] alu_ctrl    // operation code sent to the ALU
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0010;                     // ADD for load/store address
            2'b01: alu_ctrl = 4'b0110;                     // SUB for branch compare
            2'b10: begin                                   // R-type: add/sub/and/or/...
                case (funct3)
                    3'b000: alu_ctrl = funct7_5 ? 4'b0110  // sub (funct7 = 0100000)
                                                : 4'b0010; // add (funct7 = 0000000)
                    3'b001: alu_ctrl = 4'b0100;            // sll
                    3'b010: alu_ctrl = 4'b0111;            // slt
                    3'b011: alu_ctrl = 4'b1001;            // sltu
                    3'b100: alu_ctrl = 4'b0011;            // xor
                    3'b101: alu_ctrl = funct7_5 ? 4'b1000  // sra
                                                : 4'b0101; // srl
                    3'b110: alu_ctrl = 4'b0001;            // or
                    3'b111: alu_ctrl = 4'b0000;            // and
                    default: alu_ctrl = 4'b0010;
                endcase
            end
            2'b11: begin                                   // I-type ALU: addi/andi/ori/...
                case (funct3)
                    3'b000: alu_ctrl = 4'b0010;            // addi (there is no "subi", so never sub)
                    3'b001: alu_ctrl = 4'b0100;            // slli
                    3'b010: alu_ctrl = 4'b0111;            // slti
                    3'b011: alu_ctrl = 4'b1001;            // sltiu
                    3'b100: alu_ctrl = 4'b0011;            // xori
                    3'b101: alu_ctrl = funct7_5 ? 4'b1000  // srai
                                                : 4'b0101; // srli
                    3'b110: alu_ctrl = 4'b0001;            // ori
                    3'b111: alu_ctrl = 4'b0000;            // andi
                    default: alu_ctrl = 4'b0010;
                endcase
            end
            default: alu_ctrl = 4'b0010;
        endcase
    end
endmodule
