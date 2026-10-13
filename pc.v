// ============================================================
// pc.v - Program Counter
// Holds the address of the instruction being executed.
// On every rising clock edge it loads the "next PC" value.
// ============================================================
`timescale 1ns/1ps          // time unit / precision for simulation

module pc (
    input  wire        clk,      // clock
    input  wire        reset,    // active-high reset
    input  wire [31:0] pc_next,  // address of the next instruction
    output reg  [31:0] pc        // address of the current instruction
);
    always @(posedge clk) begin
        if (reset)
            pc <= 32'h0000_0000;  // after reset, start at address 0
        else
            pc <= pc_next;        // otherwise move to the next instruction
    end
endmodule
