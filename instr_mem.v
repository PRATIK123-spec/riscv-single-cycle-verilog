// ============================================================
// instr_mem.v - Instruction Memory (read-only)
// Holds the program. Loaded from a hex file at start of simulation.
// Reading is combinational: the instruction appears as soon as
// the address changes (no clock needed).
// ============================================================
`timescale 1ns/1ps          // time unit / precision for simulation

module instr_mem #(
    parameter DEPTH    = 256,             // number of 32-bit words (1 KB)
    parameter MEM_FILE = "program.hex"    // file with the program
) (
    input  wire [31:0] addr,              // byte address (comes from the PC)
    output wire [31:0] instr              // instruction stored at that address
);
    reg [31:0] mem [0:DEPTH-1];           // the memory array: DEPTH words of 32 bits

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0013;       // fill with NOP (addi x0, x0, 0) first
        $readmemh(MEM_FILE, mem);         // then load the program from the hex file
    end

    // Instructions are 4 bytes long, so drop the low 2 address bits
    // to turn a byte address into a word index (addr / 4).
    assign instr = mem[addr[9:2]];
endmodule
