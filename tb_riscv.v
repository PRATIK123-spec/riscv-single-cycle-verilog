// ============================================================
// tb_riscv.v - Self-checking testbench for the single-cycle CPU
// 1. Generates a clock and a reset.
// 2. Runs the program in program.hex.
// 3. Checks the final register and memory values.
// 4. Prints PASS/FAIL for each check and a summary.
// 5. Dumps a VCD waveform (riscv.vcd) for GTKWave.
// ============================================================
`timescale 1ns/1ps

module tb_riscv;
    reg clk   = 0;                  // clock signal
    reg reset = 1;                  // start in reset

    integer pass_count = 0;         // number of checks that passed
    integer fail_count = 0;         // number of checks that failed
    integer cycle      = 0;         // cycle counter for the trace

    // The processor under test
    riscv_top dut (
        .clk(clk),
        .reset(reset)
    );

    // 10 ns clock period (100 MHz)
    always #5 clk = ~clk;

    // ---------- Helper task: compare a value and print PASS/FAIL ----------
    task check;
        input [8*24-1:0] name;      // label for the check (up to 24 chars)
        input [31:0]     actual;    // value found in the design
        input [31:0]     expected;  // value we expect
        begin
            if (actual === expected) begin
                $display("PASS: %-24s = 0x%08h (%0d)", name, actual, $signed(actual));
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %-24s = 0x%08h, expected 0x%08h", name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ---------- Instruction trace: print what executes each cycle ----------
    always @(negedge clk) begin
        if (!reset) begin
            cycle = cycle + 1;
            $display("cycle %2d  pc=0x%02h  instr=0x%08h  alu=0x%08h  %s",
                     cycle, dut.pc, dut.instr, dut.alu_result,
                     dut.reg_write && dut.rd != 0 ? "(writes reg)" :
                     dut.mem_write ? "(writes mem)" : "");
        end
    end

    // ---------- Main test sequence ----------
    initial begin
        $dumpfile("riscv.vcd");     // waveform file name
        $dumpvars(0, tb_riscv);     // record every signal in the design

        // Hold reset for 2 clock edges, then release it
        repeat (2) @(posedge clk);
        #1 reset = 0;

        // Run long enough for the program to reach the halt loop
        repeat (40) @(posedge clk);
        #1;

        $display("");
        $display("==================== RESULTS ====================");
        // --- Registers ---
        check("x0  (always zero)",   dut.u_regfile.regs[0],  32'd0);
        check("x1  (addi 5)",        dut.u_regfile.regs[1],  32'd5);
        check("x2  (addi 3)",        dut.u_regfile.regs[2],  32'd3);
        check("x3  (add 5+3)",       dut.u_regfile.regs[3],  32'd8);
        check("x4  (sub 5-3)",       dut.u_regfile.regs[4],  32'd2);
        check("x5  (and 5&3)",       dut.u_regfile.regs[5],  32'd1);
        check("x6  (or 5|3)",        dut.u_regfile.regs[6],  32'd7);
        check("x7  (sub 3-5)",       dut.u_regfile.regs[7],  32'hFFFF_FFFE);
        check("x8  (base addr)",     dut.u_regfile.regs[8],  32'd16);
        check("x9  (lw mem[16])",    dut.u_regfile.regs[9],  32'd8);
        check("x10 (lw mem[20])",    dut.u_regfile.regs[10], 32'hFFFF_FFFE);
        check("x11 (skipped by beq)",dut.u_regfile.regs[11], 32'd0);
        check("x12 (beq not taken)", dut.u_regfile.regs[12], 32'd42);
        check("x13 (add 42+-2)",     dut.u_regfile.regs[13], 32'd40);
        check("x14 (loop counter)",  dut.u_regfile.regs[14], 32'd3);
        check("x15 (loop limit)",    dut.u_regfile.regs[15], 32'd3);
        // --- Data memory (index = byte address / 4) ---
        check("mem[8]  (sw -8(x8))", dut.u_dmem.mem[2],      32'd40);
        check("mem[16] (sw 0(x8))",  dut.u_dmem.mem[4],      32'd8);
        check("mem[20] (sw 4(x8))",  dut.u_dmem.mem[5],      32'hFFFF_FFFE);
        // --- PC should be stuck in the halt loop ---
        check("pc  (halt loop)",     dut.pc,                 32'h0000_005C);

        $display("=================================================");
        $display("SUMMARY: %0d passed, %0d failed, %0d total",
                 pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");
        $display("=================================================");
        $finish;
    end
endmodule
