`timescale 1ns/1ps
`include "cpu.sv"

// Minimal ROM hex stub so the CPU can boot
// Tests: NOP, LDI, ADD, SUB, HALT sequence

module tb_cpu;

logic clk, rst;

cpu dut (.clk(clk), .rst(rst));

always #5 clk = ~clk;

initial begin
    // Preload instruction memory with a simple program
    // LDI R1, 10      => opc=000001 rd=0001 rs1=0000 rs2=0000 imm=10
    // LDI R2, 20      => opc=000001 rd=0010 rs1=0000 rs2=0000 imm=20
    // ADD R3, R1, R2  => opc=000101 rd=0011 rs1=0001 rs2=0010 imm=0
    // HALT            => opc=011010 rd=0000 rs1=0000 rs2=0000 imm=0
    dut.rom_inst.memory[0] = 48'b000001_0001_0000_0000_000000000000000000000000001010; // LDI R1,10
    dut.rom_inst.memory[1] = 48'b000001_0010_0000_0000_000000000000000000000000010100; // LDI R2,20
    dut.rom_inst.memory[2] = 48'b000101_0011_0001_0010_000000000000000000000000000000; // ADD R3,R1,R2
    dut.rom_inst.memory[3] = 48'b011010_0000_0000_0000_000000000000000000000000000000; // HALT
    // rest NOP
    for (int i = 4; i < 2048; i++)
        dut.rom_inst.memory[i] = 48'b0;
end

initial begin
    clk = 0; rst = 1;
    repeat(2) @(posedge clk);
    rst = 0;

    // Run for enough cycles
    repeat(20) @(posedge clk);

    $display("R1 = %0d (expect 10)",  dut.regfile.regs[1]);
    $display("R2 = %0d (expect 20)",  dut.regfile.regs[2]);
    $display("R3 = %0d (expect 30)",  dut.regfile.regs[3]);

    if (dut.regfile.regs[1] == 10 &&
        dut.regfile.regs[2] == 20 &&
        dut.regfile.regs[3] == 30)
        $display("PASS  CPU integration test");
    else
        $display("FAIL  CPU integration test");

    $finish;
end

endmodule
