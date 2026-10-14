// Data Memory (RAM) — ~6MB
module ram (
    input  logic        clk,
    input  logic        wr_en,
    input  logic        rd_en,
    input  logic [31:0] addr,
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data
);

`ifdef SYNTHESIS
localparam WORDS = 1572864; // 6MB
`else
localparam WORDS = 65536;   // simulation
`endif

reg [31:0] memory [0:WORDS-1];

always_ff @(posedge clk) begin
    if (wr_en)
        memory[addr[21:0]] <= wr_data;
end

assign rd_data = rd_en ? memory[addr[21:0]] : 32'b0;

endmodule
