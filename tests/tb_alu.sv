`timescale 1ns/1ps
`include "alu.sv"

module tb_alu;

logic [31:0] a_add, b_add, res_add;
Adder dut_add (.Adder_a(a_add), .Adder_b(b_add), .Adder_result(res_add));

// Subtractor
logic [31:0] a_sub, b_sub, res_sub;
Subtractor dut_sub (.Subtractor_a(a_sub), .Subtractor_b(b_sub), .Subtractor_result(res_sub));

// Multiplier
logic [31:0] a_mul, b_mul;
logic [63:0] res_mul;
Multiplier dut_mul (.Multiplier_a(a_mul), .Multiplier_b(b_mul), .Multiplier_result(res_mul));

// Divider
logic [31:0] a_div, b_div, res_div;
Divider dut_div (.Divider_a(a_div), .Divider_b(b_div), .Divider_result(res_div));

// bopr
logic [3:0]  opr;
logic [31:0] a_b, b_b, res_b;
bopr dut_bopr (.opr(opr), .a(a_b), .b(b_b), .result(res_b));

integer pass, fail;

task check(input string name, input logic [63:0] got, input logic [63:0] exp);
    if (got === exp) begin
        $display("PASS  %s: %0d", name, got);
        pass++;
    end else begin
        $display("FAIL  %s: got %0d expected %0d", name, got, exp);
        fail++;
    end
endtask

initial begin
    pass = 0; fail = 0;

    // Adder
    a_add = 10; b_add = 20; #1;
    check("ADD 10+20",    res_add, 30);
    a_add = 32'hFFFFFFFF; b_add = 1; #1;
    check("ADD overflow", res_add, 0);

    // Subtractor
    a_sub = 50; b_sub = 30; #1;
    check("SUB 50-30",    res_sub, 20);
    a_sub = 0; b_sub = 1; #1;
    check("SUB underflow",res_sub, 32'hFFFFFFFF);

    // Multiplier
    a_mul = 6; b_mul = 7; #1;
    check("MUL 6*7",      res_mul, 42);
    a_mul = 32'hFFFF; b_mul = 32'hFFFF; #1;
    check("MUL large",    res_mul, 64'hFFFE0001);

    // Divider
    a_div = 100; b_div = 5; #1;
    check("DIV 100/5",    res_div, 20);
    a_div = 7; b_div = 0; #1;
    check("DIV by zero",  res_div, 0);

    // bopr — AND
    opr = 4'b0000; a_b = 32'hFF00; b_b = 32'h0FF0; #1;
    check("AND",          res_b, 32'h0F00);
    // OR
    opr = 4'b0001; a_b = 32'hF0; b_b = 32'h0F; #1;
    check("OR",           res_b, 32'hFF);
    // XOR
    opr = 4'b0010; a_b = 32'hFF; b_b = 32'hFF; #1;
    check("XOR",          res_b, 0);
    // NOT
    opr = 4'b0110; a_b = 32'h0; #1;
    check("NOT 0",        res_b, 32'hFFFFFFFF);
    // SLL
    opr = 4'b0111; a_b = 32'h1; #1;
    check("SLL",          res_b, 32'h2);
    // SRL
    opr = 4'b1000; a_b = 32'h8; #1;
    check("SRL",          res_b, 32'h4);
    // INC
    opr = 4'b1100; a_b = 41; #1;
    check("INC",          res_b, 42);
    // DEC
    opr = 4'b1101; a_b = 43; #1;
    check("DEC",          res_b, 42);
    // CMP equal
    opr = 4'b1110; a_b = 5; b_b = 5; #1;
    check("CMP eq",       res_b, 1);
    // CMP not equal
    opr = 4'b1110; a_b = 5; b_b = 6; #1;
    check("CMP ne",       res_b, 0);

    $display("\n=== ALU TB: %0d passed, %0d failed ===", pass, fail);
    $finish;
end

endmodule
