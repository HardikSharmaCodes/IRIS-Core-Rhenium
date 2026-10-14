// Adder — ripple carry
module Adder (
    input  logic [31:0] Adder_a,
    input  logic [31:0] Adder_b,
    output logic [31:0] Adder_result
);
    assign Adder_result = Adder_a + Adder_b;
endmodule

// Subtractor
module Subtractor (
    input  logic [31:0] Subtractor_a,
    input  logic [31:0] Subtractor_b,
    output logic [31:0] Subtractor_result
);
    assign Subtractor_result = Subtractor_a - Subtractor_b;
endmodule

// Multiplier — 32x32 -> 64
module Multiplier (
    input  logic [31:0] Multiplier_a,
    input  logic [31:0] Multiplier_b,
    output logic [63:0] Multiplier_result
);
    assign Multiplier_result = Multiplier_a * Multiplier_b;
endmodule

// Divider
module Divider (
    input  logic [31:0] Divider_a,
    input  logic [31:0] Divider_b,
    output logic [31:0] Divider_result
);
    assign Divider_result = (Divider_b == 0) ? 32'b0 : Divider_a / Divider_b;
endmodule

// Basic Operations (AND, OR, XOR, NAND, NOR, XNOR, NOT, shifts, rotate, INC, DEC, CMP)
module bopr (
    input  logic [3:0]  opr,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
always_comb begin
    case (opr)
        4'b0000: result = a & b;           // AND
        4'b0001: result = a | b;           // OR
        4'b0010: result = a ^ b;           // XOR
        4'b0011: result = ~(a & b);        // NAND
        4'b0100: result = ~(a | b);        // NOR
        4'b0101: result = ~(a ^ b);        // XNOR
        4'b0110: result = ~a;              // NOT
        4'b0111: result = a << 1;          // SLL
        4'b1000: result = a >> 1;          // SRL
        4'b1001: result = $signed(a) >>> 1;// SRA
        4'b1010: result = {a[30:0], a[31]};// ROL
        4'b1011: result = {a[0], a[31:1]}; // ROR
        4'b1100: result = a + 32'd1;       // INC
        4'b1101: result = a - 32'd1;       // DEC
        4'b1110: result = (a == b) ? 32'd1 : 32'd0; // CMP
        default: result = 32'b0;
    endcase
end
endmodule
