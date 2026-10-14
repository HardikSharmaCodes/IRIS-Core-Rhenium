// Program Counter
module pc (
    input  logic        clk,
    input  logic        rst,
    input  logic        count_enable,
    input  logic        jump_enable,
    input  logic [31:0] jump_data,
    input  logic        halt,
    output logic [31:0] pc_out
);

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        pc_out <= 32'b0;
    else if (!halt) begin
        if (jump_enable)
            pc_out <= jump_data;
        else if (count_enable)
            pc_out <= pc_out + 32'd1;
    end
end

endmodule
