// Instruction Buffer — 8-entry FIFO
module instruction_buffer (
    input  logic        clk,
    input  logic        rst,
    input  logic [47:0] instr_in,
    input  logic        instr_valid,
    input  logic        consume,
    output logic [47:0] instr_out,
    output logic        empty,
    output logic        full
);

reg [47:0] buffer [0:7];
reg [2:0]  head, tail;
reg [3:0]  count;

assign empty     = (count == 0);
assign full      = (count == 8);
assign instr_out = empty ? 48'b0 : buffer[head];

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        head  <= 0;
        tail  <= 0;
        count <= 0;
    end else begin
        case ({instr_valid && !full, consume && !empty})
            2'b10: begin
                buffer[tail] <= instr_in;
                tail  <= tail + 1'b1;
                count <= count + 1'b1;
            end
            2'b01: begin
                head  <= head + 1'b1;
                count <= count - 1'b1;
            end
            2'b11: begin
                buffer[tail] <= instr_in;
                tail  <= tail + 1'b1;
                head  <= head + 1'b1;
            end
            default: ;
        endcase
    end
end

endmodule

// Reorder Buffer — 8-entry
module reorder_buffer (
    input  logic        clk,
    input  logic        rst,

    // Dispatch
    input  logic        dispatch_valid,
    input  logic [4:0]  dispatch_dest,
    output logic        dispatch_ready,
    output logic [2:0]  dispatch_tag,

    // Writeback
    input  logic        writeback_valid,
    input  logic [2:0]  writeback_tag,
    input  logic [31:0] writeback_value,

    // Commit
    input  logic        commit_ready,
    output logic        commit_valid,
    output logic [4:0]  commit_dest,
    output logic [31:0] commit_value,

    output logic        empty,
    output logic        full
);

reg [4:0]  rob_dest  [0:7];
reg [31:0] rob_value [0:7];
reg        rob_ready [0:7];
reg        rob_valid [0:7];

reg [2:0] head, tail;
reg [3:0] count;
integer   i;

assign empty          = (count == 0);
assign full           = (count == 8);
assign dispatch_ready = !full;
assign dispatch_tag   = tail;
assign commit_valid   = !empty && rob_valid[head] && rob_ready[head];
assign commit_dest    = rob_dest[head];
assign commit_value   = rob_value[head];

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        head  <= 0;
        tail  <= 0;
        count <= 0;
        for (i = 0; i < 8; i = i + 1) begin
            rob_dest[i]  <= 0;
            rob_value[i] <= 0;
            rob_ready[i] <= 0;
            rob_valid[i] <= 0;
        end
    end else begin
        if (dispatch_valid && dispatch_ready) begin
            rob_dest[tail]  <= dispatch_dest;
            rob_value[tail] <= 0;
            rob_ready[tail] <= 0;
            rob_valid[tail] <= 1;
            tail            <= tail + 1'b1;
        end

        if (writeback_valid) begin
            rob_value[writeback_tag] <= writeback_value;
            rob_ready[writeback_tag] <= 1;
        end

        if (commit_valid && commit_ready) begin
            rob_valid[head] <= 0;
            rob_ready[head] <= 0;
            head            <= head + 1'b1;
        end

        case ({dispatch_valid && dispatch_ready, commit_valid && commit_ready})
            2'b10:   count <= count + 1'b1;
            2'b01:   count <= count - 1'b1;
            default: count <= count;
        endcase
    end
end

endmodule

// Register Rename Table — maps arch regs (0-15) to physical (0-31)
module rename_table (
    input  logic        clk,
    input  logic        rst,

    // Rename (allocate new physical for arch reg)
    input  logic        rename_en,
    input  logic [3:0]  arch_reg,
    input  logic [4:0]  phys_reg,

    // Lookup
    input  logic [3:0]  lookup_addr0,
    output logic [4:0]  phys_out0,
    input  logic [3:0]  lookup_addr1,
    output logic [4:0]  phys_out1,
    input  logic [3:0]  lookup_addr2,
    output logic [4:0]  phys_out2
);

reg [4:0] map [0:15];
integer i;

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        for (i = 0; i < 16; i = i + 1)
            map[i] <= i[4:0];
    else if (rename_en)
        map[arch_reg] <= phys_reg;
end

assign phys_out0 = map[lookup_addr0];
assign phys_out1 = map[lookup_addr1];
assign phys_out2 = map[lookup_addr2];

endmodule
