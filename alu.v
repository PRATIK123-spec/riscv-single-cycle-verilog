// ============================================================
// alu.v - Arithmetic Logic Unit
// Does the actual math/logic. Which operation it performs is chosen
// by the 4-bit alu_ctrl signal coming from the ALU control unit.
// ============================================================
`timescale 1ns/1ps          // time unit / precision for simulation

module alu (
    input  wire [31:0] a,          // first operand (always the rs1 value)
    input  wire [31:0] b,          // second operand (rs2 value OR immediate)
    input  wire [3:0]  alu_ctrl,   // which operation to do
    output reg  [31:0] result,     // result of the operation
    output wire        zero        // 1 when result == 0 (used by beq)
);
    // ALU operation codes (must match alu_control.v)
    localparam ALU_AND  = 4'b0000;
    localparam ALU_OR   = 4'b0001;
    localparam ALU_ADD  = 4'b0010;
    localparam ALU_XOR  = 4'b0011;
    localparam ALU_SLL  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SUB  = 4'b0110;
    localparam ALU_SLT  = 4'b0111;
    localparam ALU_SRA  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    always @(*) begin
        case (alu_ctrl)
            ALU_AND:  result = a & b;                                     // bitwise AND
            ALU_OR:   result = a | b;                                     // bitwise OR
            ALU_ADD:  result = a + b;                                     // addition
            ALU_XOR:  result = a ^ b;                                     // bitwise XOR
            ALU_SLL:  result = a << b[4:0];                               // shift left (by low 5 bits of b)
            ALU_SRL:  result = a >> b[4:0];                               // logical shift right (fill with 0)
            ALU_SUB:  result = a - b;                                     // subtraction
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // set if less than (signed)
            ALU_SRA:  result = $signed(a) >>> b[4:0];                     // arithmetic shift right (keeps sign)
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;                   // set if less than (unsigned)
            default:  result = 32'b0;                                     // unknown code -> 0
        endcase
    end

    assign zero = (result == 32'b0);   // zero flag: beq subtracts and checks this
endmodule
