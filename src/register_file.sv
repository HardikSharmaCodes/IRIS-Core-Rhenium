// Integer Register File — 16 GP regs, 6 ports
module register_file (
    input  logic        clk,
    input  logic        rst,

    // Write ports (3 for superscalar)
    input  logic        wr_en0,
    input  logic [3:0]  wr_addr0,
    input  logic [31:0] wr_data0,

    input  logic        wr_en1,
    input  logic [3:0]  wr_addr1,
    input  logic [31:0] wr_data1,

    input  logic        wr_en2,
    input  logic [3:0]  wr_addr2,
    input  logic [31:0] wr_data2,

    // Read ports (6 for superscalar, 3 ops each reading 2 regs)
    input  logic [3:0]  rd_addr0,
    output logic [31:0] rd_data0,

    input  logic [3:0]  rd_addr1,
    output logic [31:0] rd_data1,

    input  logic [3:0]  rd_addr2,
    output logic [31:0] rd_data2,

    input  logic [3:0]  rd_addr3,
    output logic [31:0] rd_data3,

    input  logic [3:0]  rd_addr4,
    output logic [31:0] rd_data4,

    input  logic [3:0]  rd_addr5,
    output logic [31:0] rd_data5
);

reg [31:0] regs [0:15];
integer i;

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        for (i = 0; i < 16; i = i + 1)
            regs[i] <= 32'b0;
    else begin
        if (wr_en0) regs[wr_addr0] <= wr_data0;
        if (wr_en1) regs[wr_addr1] <= wr_data1;
        if (wr_en2) regs[wr_addr2] <= wr_data2;
    end
end

assign rd_data0 = regs[rd_addr0];
assign rd_data1 = regs[rd_addr1];
assign rd_data2 = regs[rd_addr2];
assign rd_data3 = regs[rd_addr3];
assign rd_data4 = regs[rd_addr4];
assign rd_data5 = regs[rd_addr5];

endmodule
