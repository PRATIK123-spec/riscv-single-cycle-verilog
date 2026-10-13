// ============================================================
// reg_file.v - Register File (32 registers x 32 bits)
// Two read ports (rs1, rs2) and one write port (rd).
// Reads are combinational; the write happens on the rising clock edge.
// Register x0 is hard-wired to zero.
// ============================================================
`timescale 1ns/1ps          // time unit / precision for simulation

module reg_file (
    input  wire        clk,         // clock
    input  wire        reg_write,   // 1 = write wd into register rd this cycle
    input  wire [4:0]  rs1,         // number of first source register
    input  wire [4:0]  rs2,         // number of second source register
    input  wire [4:0]  rd,          // number of destination register
    input  wire [31:0] wd,          // data to write into rd
    output wire [31:0] rd1,         // value of register rs1
    output wire [31:0] rd2          // value of register rs2
);
    reg [31:0] regs [0:31];         // the 32 registers

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'b0;        // start with all registers = 0
    end

    // Read ports: reading x0 always gives 0
    assign rd1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];

    // Write port: only write when enabled AND destination is not x0
    always @(posedge clk) begin
        if (reg_write && (rd != 5'd0))
            regs[rd] <= wd;
    end
endmodule
