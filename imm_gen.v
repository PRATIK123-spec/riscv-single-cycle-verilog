// ============================================================
// imm_gen.v - Immediate Generator
// RISC-V scatters the constant ("immediate") across different bits
// depending on the instruction format. This module collects those
// bits and sign-extends them to 32 bits.
// ============================================================
`timescale 1ns/1ps          // time unit / precision for simulation

module imm_gen (
    input  wire [31:0] instr,   // the full instruction
    output reg  [31:0] imm      // the 32-bit sign-extended immediate
);
    wire [6:0] opcode = instr[6:0];   // opcode tells us the format

    always @(*) begin
        case (opcode)
            // I-type (addi, lw, ...): imm[11:0] = instr[31:20]
            7'b0010011,
            7'b0000011: imm = {{20{instr[31]}}, instr[31:20]};

            // S-type (sw): imm[11:5] = instr[31:25], imm[4:0] = instr[11:7]
            7'b0100011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type (beq): imm[12|10:5|4:1|11], lowest bit is always 0
            7'b1100011: imm = {{19{instr[31]}}, instr[31], instr[7],
                               instr[30:25], instr[11:8], 1'b0};

            // R-type and anything else: no immediate
            default:    imm = 32'b0;
        endcase
    end
endmodule
