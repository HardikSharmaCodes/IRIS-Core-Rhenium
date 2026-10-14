// Instruction Memory (ROM)
module rom (
    input  logic        clk,
    input  logic [31:0] pc,
    output logic [47:0] instr_out
);

reg [47:0] memory [0:2047]; // 2KB instruction mem

initial
    $readmemh("rom.hex", memory);

always_ff @(posedge clk)
    instr_out <= memory[pc[10:0]];

endmodule
