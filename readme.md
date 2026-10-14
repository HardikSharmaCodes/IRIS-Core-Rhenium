# Rhenium — Custom 32-bit CPU (SystemVerilog RTL)

Rhenium is a 32-bit pipelined CPU core designed from scratch in SystemVerilog, featuring a custom 48-bit instruction set (IISC ISA), hardware floating-point support, cache, and superscalar execution units.

---

## Quick Start / Running Testbenches

### Prerequisites
- [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` & `vvp`)
  ```bash
  brew install icarus-verilog
  ```

### ALU Testbench
To test:
```bash
iverilog -g2012 -I src -o sim_alu tests/tb_alu.sv
```
Run this:
```bash
vvp sim_alu
```

### FPU Testbench
```bash
iverilog -g2012 -I src -o sim_fpu tests/tb_fpu.sv
vvp sim_fpu
```

### CPU Testbench
```bash
iverilog -g2012 -I src -o sim_cpu tests/tb_cpu.sv
vvp sim_cpu
```

---

## Architectural Highlights

- **Data Path:** 32-bit architecture
- **Instruction Width:** 48-bit custom encoding:
  - `[47:42]`: Opcode (6 bits)
  - `[41:38]`: Destination Register `rd` (4 bits)
  - `[37:34]`: Source Register 1 `rs1` (4 bits)
  - `[33:30]`: Source Register 2 `rs2` (4 bits)
  - `[29:0]`: Immediate / Target Address (30 bits)
- **Pipeline:** 4 stages — Fetch, Decode, Execute, Writeback
- **Hazard Handling:**
  - EX-to-ID data forwarding
  - Load-use hazard detection and stalling
  - Pipeline flushing on branch resolution
- **Branch Prediction:** 2-bit saturating counter
- **Register Files:**
  - Integer: 16 general-purpose 32-bit registers (3 write ports, 6 read ports)
  - Floating-Point: 16 IEEE 754 32-bit registers
- **Execution Units:**
  - ALU: 3x Adders, 3x Subtractors, 3x Multipliers, 3x Dividers, 3x Bitwise Logic units (ready for superscalar dispatch)
  - FPU: Multi-cycle IEEE 754 single-precision (FADD/FSUB: 2 cycles, FMUL: 4 cycles, FDIV: 8 cycles, FNEG/FABS/FCMP: 1 cycle)
- **Memory & Cache:**
  - Instruction ROM: 2 KB (`rom.hex`)
  - Direct-Mapped Cache: 128-bit lines
  - RAM: Synchronous data memory
