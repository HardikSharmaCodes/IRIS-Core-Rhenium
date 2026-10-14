`timescale 1ns/1ps
`include "fpu.sv"

module tb_fpu;

logic        clk, rst;
logic        start_add, start_mul, start_div, sub_flag;
logic [31:0] a, b;
logic [31:0] res_add, res_mul, res_div;
logic        busy_add, ready_add, idle_add;
logic        busy_mul, ready_mul, idle_mul;
logic        busy_div, ready_div, idle_div;

fpuAddSub  dut_add (.clk(clk), .rst(rst), .start(start_add), .sub(sub_flag),
                    .a(a), .b(b), .result(res_add),
                    .busy(busy_add), .ready(ready_add), .idle(idle_add));

fpuMultiplier dut_mul (.clk(clk), .rst(rst), .start(start_mul),
                       .a(a), .b(b), .result(res_mul),
                       .busy(busy_mul), .ready(ready_mul), .idle(idle_mul));

fpuDivider dut_div (.clk(clk), .rst(rst), .start(start_div),
                    .a(a), .b(b), .result(res_div),
                    .busy(busy_div), .ready(ready_div), .idle(idle_div));

always #5 clk = ~clk;

integer pass, fail;

// IEEE 754: 1.0 = 32'h3F800000, 2.0 = 32'h40000000, 0.5 = 32'h3F000000
// -1.0 = 32'hBF800000

task check_fp(input string name, input logic [31:0] got, input logic [31:0] exp);
    if (got === exp) begin
        $display("PASS  %s: %h", name, got);
        pass++;
    end else begin
        $display("FAIL  %s: got %h expected %h", name, got, exp);
        fail++;
    end
endtask

initial begin
    #100000 begin $display("TIMEOUT!"); $finish; end
end

initial begin
    clk = 0; rst = 1; pass = 0; fail = 0;
    start_add = 0; start_mul = 0; start_div = 0; sub_flag = 0;
    a = 0; b = 0;

    repeat(2) @(posedge clk);
    rst = 0;
    repeat(2) @(posedge clk);

    // ADD: 1.0 + 1.0 = 2.0
    a = 32'h3F800000; b = 32'h3F800000; sub_flag = 0;
    start_add = 1; @(posedge clk); start_add = 0;
    wait(ready_add); @(posedge clk);
    check_fp("1.0+1.0=2.0", res_add, 32'h40000000);

    // SUB: 2.0 - 1.0 = 1.0
    a = 32'h40000000; b = 32'h3F800000; sub_flag = 1;
    start_add = 1; @(posedge clk); start_add = 0;
    wait(ready_add); @(posedge clk);
    check_fp("2.0-1.0=1.0", res_add, 32'h3F800000);

    // MUL: 2.0 * 2.0 = 4.0
    a = 32'h40000000; b = 32'h40000000;
    start_mul = 1; @(posedge clk); start_mul = 0;
    wait(ready_mul); @(posedge clk);
    check_fp("2.0*2.0=4.0", res_mul, 32'h40800000);

    // DIV: 1.0 / 2.0 = 0.5
    a = 32'h3F800000; b = 32'h40000000;
    start_div = 1; @(posedge clk); start_div = 0;
    wait(ready_div); @(posedge clk);
    check_fp("1.0/2.0=0.5", res_div, 32'h3F000000);

    $display("\n=== FPU TB: %0d passed, %0d failed ===", pass, fail);
    $finish;
end

endmodule
