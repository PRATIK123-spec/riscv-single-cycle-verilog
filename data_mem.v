// ============================================================
// data_mem.v - Data Memory
// Used by lw (read) and sw (write). Word-addressed internally.
// Read is combinational; write happens on the rising clock edge.
// ============================================================
`timescale 1ns/1ps          // time unit / precision for simulation

module data_mem #(
    parameter DEPTH = 256                  // number of 32-bit words (1 KB)
) (
    input  wire        clk,                // clock
    input  wire        mem_read,           // 1 = lw is reading
    input  wire        mem_write,          // 1 = sw is writing
    input  wire [31:0] addr,               // byte address (from the ALU)
    input  wire [31:0] wd,                 // data to write (from rs2)
    output wire [31:0] rd                  // data read out
);
    reg [31:0] mem [0:DEPTH-1];            // the memory array

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'b0;                // start with all memory = 0
    end

    // Read: give the word at addr/4 (only when mem_read, else 0)
    assign rd = mem_read ? mem[addr[9:2]] : 32'b0;

    // Write: store wd at addr/4 on the clock edge
    always @(posedge clk) begin
        if (mem_write)
            mem[addr[9:2]] <= wd;
    end
endmodule
