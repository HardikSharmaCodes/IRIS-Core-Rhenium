// Direct-mapped Cache — 2MB
// 21-bit tag | 15-bit index | 4-bit offset -> 2^15 * 16B = 512KB lines... 
// 2MB = 2097152 bytes. Line = 16 bytes. Lines = 131072 = 2^17.
// addr[31:17] = tag (15 bits), addr[16:4] = index (13 bits), addr[3:0] = offset
module cache (
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic        read,

    // Refill
    input  logic         refill,
    input  logic [127:0] refill_data,

    output logic [31:0] data_out,
    output logic        hit
);

`ifdef SYNTHESIS
localparam LINES = 131072; // 2MB
`else
localparam LINES = 1024;   // simulation
`endif

reg [127:0] data_array [0:LINES-1];
reg [14:0]  tag_array  [0:LINES-1];
reg         valid      [0:LINES-1];

wire [14:0] tag    = addr[31:17];
wire [12:0] index  = addr[16:4];
wire [3:0]  offset = addr[3:0];

integer i;
initial begin
    for (i = 0; i < LINES; i = i + 1)
        valid[i] = 1'b0;
end

always_ff @(posedge clk) begin
    if (refill) begin
        data_array[index] <= refill_data;
        tag_array[index]  <= tag;
        valid[index]      <= 1'b1;
    end
end

always_comb begin
    hit      = 1'b0;
    data_out = 32'b0;
    if (read && valid[index] && tag_array[index] == tag) begin
        hit = 1'b1;
        case (offset[3:2])
            2'b00: data_out = data_array[index][31:0];
            2'b01: data_out = data_array[index][63:32];
            2'b10: data_out = data_array[index][95:64];
            2'b11: data_out = data_array[index][127:96];
        endcase
    end
end

endmodule
