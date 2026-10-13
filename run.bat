@echo off
REM ============================================================
REM run.bat - Compile, simulate, and view the single-cycle RISC-V CPU
REM Double-click this file, or run it from a command prompt.
REM Needs iverilog, vvp and gtkwave on PATH.
REM ============================================================

REM Work in the folder this .bat file lives in (so program.hex is found)
cd /d "%~dp0"

echo === Step 1: Compiling with iverilog ===
iverilog -g2005 -Wall -o riscv_sim.vvp ^
    tb_riscv.v riscv_top.v pc.v instr_mem.v reg_file.v ^
    alu.v alu_control.v control_unit.v imm_gen.v data_mem.v
if errorlevel 1 (
    echo.
    echo *** COMPILE FAILED - see errors above ***
    pause
    exit /b 1
)

echo.
echo === Step 2: Simulating with vvp ===
REM Note: a "$readmemh ... Not enough words" warning is normal - the
REM program is shorter than the 256-word instruction memory.
vvp riscv_sim.vvp
if errorlevel 1 (
    echo.
    echo *** SIMULATION FAILED ***
    pause
    exit /b 1
)

echo.
echo === Step 3: Opening the waveform in GTKWave ===
start "" gtkwave riscv.vcd wave.gtkw

pause
