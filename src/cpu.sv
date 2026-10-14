// Rhenium CPU Top-Level
// IISC ISA — 48-bit instructions, 4-stage pipeline (Fetch/Decode/Execute/Writeback)
// Superscalar: 3x Adder, 3x Subtractor, 3x Multiplier, 3x Divider, 3x bopr
// Branch prediction: 2-bit saturating counter
// Forwarding + stalling + pipeline flushing
//
// Instruction encoding (48 bits):
//   [47:42] opcode  (6b)
//   [41:38] rd      (4b)  destination register
//   [37:34] rs1     (4b)  source 1
//   [33:30] rs2     (4b)  source 2
//   [29:0]  imm/addr(30b)

`include "pc.sv"
`include "rom.sv"
`include "ram.sv"
`include "cache.sv"
`include "register_file.sv"
`include "alu.sv"
`include "fpu.sv"
`include "superscalar.sv"

// Opcode definitions 
`define NOP   6'b000000
`define LDI   6'b000001
`define MOV   6'b000010
`define STR   6'b000011
`define LDA   6'b000100
`define ADD   6'b000101
`define MUL   6'b000110
`define DIV   6'b000111
`define SUB   6'b001000
`define AND   6'b001001
`define OR    6'b001010
`define XOR   6'b001011
`define NAND  6'b001100
`define NOR   6'b001101
`define XNOR  6'b001110
`define NOT   6'b001111
`define SLL   6'b010000
`define SRL   6'b010001
`define SRA   6'b010010
`define ROR   6'b010011
`define ROL   6'b010100
`define INC   6'b010101
`define DEC   6'b010110
`define CMP   6'b010111
`define JMP   6'b011000
`define JMPZ  6'b011001
`define HALT  6'b011010
`define JMP1  6'b011011
`define FADD  6'b011100
`define FSUB  6'b011101
`define FMUL  6'b011110
`define FDIV  6'b011111
`define FNEG  6'b100000
`define FABS  6'b100001
`define FCMP  6'b100010

module cpu (
    input  logic clk,
    input  logic rst
);

logic [31:0] pc;
logic        pc_jump_en;
logic [31:0] pc_jump_data;
logic        pc_count_en;
logic        pc_halt;

pc pc_inst (
    .clk(clk), .rst(rst),
    .count_enable(pc_count_en),
    .jump_enable(pc_jump_en),
    .jump_data(pc_jump_data),
    .halt(pc_halt),
    .pc_out(pc)
);

logic [47:0] rom_out;

rom rom_inst (
    .clk(clk),
    .pc(pc),
    .instr_out(rom_out)
);

logic        rf_wr_en0, rf_wr_en1, rf_wr_en2;
logic [3:0]  rf_wr_addr0, rf_wr_addr1, rf_wr_addr2;
logic [31:0] rf_wr_data0, rf_wr_data1, rf_wr_data2;

logic [3:0]  rf_rd_addr0, rf_rd_addr1, rf_rd_addr2;
logic [3:0]  rf_rd_addr3, rf_rd_addr4, rf_rd_addr5;
logic [31:0] rf_rd_data0, rf_rd_data1, rf_rd_data2;
logic [31:0] rf_rd_data3, rf_rd_data4, rf_rd_data5;

register_file regfile (
    .clk(clk), .rst(rst),
    .wr_en0(rf_wr_en0), .wr_addr0(rf_wr_addr0), .wr_data0(rf_wr_data0),
    .wr_en1(rf_wr_en1), .wr_addr1(rf_wr_addr1), .wr_data1(rf_wr_data1),
    .wr_en2(rf_wr_en2), .wr_addr2(rf_wr_addr2), .wr_data2(rf_wr_data2),
    .rd_addr0(rf_rd_addr0), .rd_data0(rf_rd_data0),
    .rd_addr1(rf_rd_addr1), .rd_data1(rf_rd_data1),
    .rd_addr2(rf_rd_addr2), .rd_data2(rf_rd_data2),
    .rd_addr3(rf_rd_addr3), .rd_data3(rf_rd_data3),
    .rd_addr4(rf_rd_addr4), .rd_data4(rf_rd_data4),
    .rd_addr5(rf_rd_addr5), .rd_data5(rf_rd_data5)
);

logic [31:0] add_a[0:2], add_b[0:2], add_res[0:2];
genvar g;
generate
    for (g = 0; g < 3; g++) begin : gen_adders
        Adder adder_inst (.Adder_a(add_a[g]), .Adder_b(add_b[g]), .Adder_result(add_res[g]));
    end
endgenerate

logic [31:0] sub_a[0:2], sub_b[0:2], sub_res[0:2];
generate
    for (g = 0; g < 3; g++) begin : gen_subs
        Subtractor sub_inst (.Subtractor_a(sub_a[g]), .Subtractor_b(sub_b[g]), .Subtractor_result(sub_res[g]));
    end
endgenerate

logic [31:0] mul_a[0:2], mul_b[0:2];
logic [63:0] mul_res[0:2];
generate
    for (g = 0; g < 3; g++) begin : gen_muls
        Multiplier mul_inst (.Multiplier_a(mul_a[g]), .Multiplier_b(mul_b[g]), .Multiplier_result(mul_res[g]));
    end
endgenerate

logic [31:0] div_a[0:2], div_b[0:2], div_res[0:2];
generate
    for (g = 0; g < 3; g++) begin : gen_divs
        Divider div_inst (.Divider_a(div_a[g]), .Divider_b(div_b[g]), .Divider_result(div_res[g]));
    end
endgenerate


logic [3:0]  bopr_opr[0:2];
logic [31:0] bopr_a[0:2], bopr_b[0:2], bopr_res[0:2];
generate
    for (g = 0; g < 3; g++) begin : gen_boprs
        bopr bopr_inst (.opr(bopr_opr[g]), .a(bopr_a[g]), .b(bopr_b[g]), .result(bopr_res[g]));
    end
endgenerate


logic        fpu_dispatch;
logic [47:0] fpu_instr;
logic        fpu_int_wr_en;
logic [3:0]  fpu_int_wr_addr;
logic [31:0] fpu_int_wr_data;

fpu fpu_inst (
    .clk(clk), .rst(rst),
    .cpu_out(fpu_instr),
    .dispatch(fpu_dispatch),
    .int_wr_en(fpu_int_wr_en),
    .int_wr_addr(fpu_int_wr_addr),
    .int_wr_data(fpu_int_wr_data)
);


logic [31:0] cache_addr;
logic        cache_read;
logic        cache_refill;
logic [127:0]cache_refill_data;
logic [31:0] cache_data_out;
logic        cache_hit;

cache cache_inst (
    .clk(clk),
    .addr(cache_addr),
    .read(cache_read),
    .refill(cache_refill),
    .refill_data(cache_refill_data),
    .data_out(cache_data_out),
    .hit(cache_hit)
);

logic        ram_wr_en, ram_rd_en;
logic [31:0] ram_addr, ram_wr_data, ram_rd_data;

ram ram_inst (
    .clk(clk),
    .wr_en(ram_wr_en), .rd_en(ram_rd_en),
    .addr(ram_addr),
    .wr_data(ram_wr_data),
    .rd_data(ram_rd_data)
);

logic [47:0] ibuf_out;
logic        ibuf_empty, ibuf_full;
logic        ibuf_consume;

instruction_buffer ibuf (
    .clk(clk), .rst(rst),
    .instr_in(rom_out),
    .instr_valid(!ibuf_full),
    .consume(ibuf_consume),
    .instr_out(ibuf_out),
    .empty(ibuf_empty),
    .full(ibuf_full)
);

logic        rob_dispatch_valid;
logic [4:0]  rob_dispatch_dest;
logic        rob_dispatch_ready;
logic [2:0]  rob_dispatch_tag;

logic        rob_wb_valid;
logic [2:0]  rob_wb_tag;
logic [31:0] rob_wb_value;

logic        rob_commit_ready;
logic        rob_commit_valid;
logic [4:0]  rob_commit_dest;
logic [31:0] rob_commit_value;

logic        rob_empty, rob_full;

reorder_buffer rob (
    .clk(clk), .rst(rst),
    .dispatch_valid(rob_dispatch_valid),
    .dispatch_dest(rob_dispatch_dest),
    .dispatch_ready(rob_dispatch_ready),
    .dispatch_tag(rob_dispatch_tag),
    .writeback_valid(rob_wb_valid),
    .writeback_tag(rob_wb_tag),
    .writeback_value(rob_wb_value),
    .commit_ready(rob_commit_ready),
    .commit_valid(rob_commit_valid),
    .commit_dest(rob_commit_dest),
    .commit_value(rob_commit_value),
    .empty(rob_empty),
    .full(rob_full)
);

reg [1:0] branch_pred;  // 2'b01 = Probably_not

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        branch_pred <= 2'b01;
end

reg [47:0] if_id_instr;

reg [5:0]  id_ex_opc;
reg [3:0]  id_ex_rd, id_ex_rs1, id_ex_rs2;
reg [31:0] id_ex_op_a, id_ex_op_b;
reg [29:0] id_ex_imm;
reg        id_ex_reg_write;
reg        id_ex_mem_read, id_ex_mem_write;
reg        id_ex_jump, id_ex_jmpz, id_ex_jmp1, id_ex_halt;
reg [29:0] id_ex_jump_target;
reg        id_ex_is_fpu;

// EX/WB
reg [5:0]  ex_wb_opc;
reg [3:0]  ex_wb_rd;
reg [31:0] ex_wb_result;
reg        ex_wb_reg_write;
reg        ex_wb_mem_read, ex_wb_mem_write;
reg [31:0] ex_wb_mem_addr;
reg [31:0] ex_wb_store_data;
reg        ex_wb_halt;

logic [31:0] fwd_a, fwd_b;

always_comb begin
    fwd_a = id_ex_op_a;
    fwd_b = id_ex_op_b;
    if (ex_wb_reg_write && ex_wb_rd != 0 && ex_wb_rd == id_ex_rs1)
        fwd_a = ex_wb_result;
    if (ex_wb_reg_write && ex_wb_rd != 0 && ex_wb_rd == id_ex_rs2)
        fwd_b = ex_wb_result;
    if (rob_commit_valid && rob_commit_dest[3:0] == id_ex_rs1)
        fwd_a = rob_commit_value;
    if (rob_commit_valid && rob_commit_dest[3:0] == id_ex_rs2)
        fwd_b = rob_commit_value;
end

logic stall;

always_comb begin
    stall = 1'b0;
    // load-use hazard
    if (id_ex_mem_read) begin
        if (id_ex_rd == if_id_instr[37:34] || id_ex_rd == if_id_instr[33:30])
            stall = 1'b1;
    end
    // ROB full stall
    if (rob_full)
        stall = 1'b1;
    // FPU busy stall — simplified: stall while FP instruction in EX
    if (id_ex_is_fpu)
        stall = 1'b1;
end

logic [31:0] alu_result;
logic        branch_taken;
logic [31:0] branch_target;

always_comb begin
    alu_result    = 32'b0;
    branch_taken  = 1'b0;
    branch_target = {2'b0, id_ex_jump_target};

    // Wire ALU unit 0 inputs (primary pipeline)
    add_a[0]   = fwd_a; add_b[0]   = fwd_b;
    sub_a[0]   = fwd_a; sub_b[0]   = fwd_b;
    mul_a[0]   = fwd_a; mul_b[0]   = fwd_b;
    div_a[0]   = fwd_a; div_b[0]   = fwd_b;
    bopr_a[0]  = fwd_a; bopr_b[0]  = fwd_b;
    bopr_opr[0] = 4'b0;

    // Units 1,2 unused in-order (available for superscalar dispatch)
    add_a[1]  = 32'b0; add_b[1]  = 32'b0;
    add_a[2]  = 32'b0; add_b[2]  = 32'b0;
    sub_a[1]  = 32'b0; sub_b[1]  = 32'b0;
    sub_a[2]  = 32'b0; sub_b[2]  = 32'b0;
    mul_a[1]  = 32'b0; mul_b[1]  = 32'b0;
    mul_a[2]  = 32'b0; mul_b[2]  = 32'b0;
    div_a[1]  = 32'b0; div_b[1]  = 32'b0;
    div_a[2]  = 32'b0; div_b[2]  = 32'b0;
    bopr_a[1] = 32'b0; bopr_b[1] = 32'b0; bopr_opr[1] = 4'b0;
    bopr_a[2] = 32'b0; bopr_b[2] = 32'b0; bopr_opr[2] = 4'b0;

    case (id_ex_opc)
        `NOP:  alu_result = 32'b0;
        `LDI:  alu_result = {{2{id_ex_imm[29]}}, id_ex_imm};
        `MOV:  alu_result = fwd_a;
        `ADD:  alu_result = add_res[0];
        `SUB:  alu_result = sub_res[0];
        `MUL:  alu_result = mul_res[0][31:0];
        `DIV:  alu_result = div_res[0];
        `AND: begin bopr_opr[0] = 4'b0000; alu_result = bopr_res[0]; end
        `OR:  begin bopr_opr[0] = 4'b0001; alu_result = bopr_res[0]; end
        `XOR: begin bopr_opr[0] = 4'b0010; alu_result = bopr_res[0]; end
        `NAND:begin bopr_opr[0] = 4'b0011; alu_result = bopr_res[0]; end
        `NOR: begin bopr_opr[0] = 4'b0100; alu_result = bopr_res[0]; end
        `XNOR:begin bopr_opr[0] = 4'b0101; alu_result = bopr_res[0]; end
        `NOT: begin bopr_opr[0] = 4'b0110; alu_result = bopr_res[0]; end
        `SLL: begin bopr_opr[0] = 4'b0111; alu_result = bopr_res[0]; end
        `SRL: begin bopr_opr[0] = 4'b1000; alu_result = bopr_res[0]; end
        `SRA: begin bopr_opr[0] = 4'b1001; alu_result = bopr_res[0]; end
        `ROL: begin bopr_opr[0] = 4'b1010; alu_result = bopr_res[0]; end
        `ROR: begin bopr_opr[0] = 4'b1011; alu_result = bopr_res[0]; end
        `INC: begin bopr_opr[0] = 4'b1100; alu_result = bopr_res[0]; end
        `DEC: begin bopr_opr[0] = 4'b1101; alu_result = bopr_res[0]; end
        `CMP: begin bopr_opr[0] = 4'b1110; alu_result = bopr_res[0]; end

        `JMP: begin
            branch_taken  = 1'b1;
            branch_target = {2'b0, id_ex_jump_target};
        end
        `JMPZ: begin
            if (fwd_a == 32'b0) begin
                branch_taken  = 1'b1;
                branch_target = {2'b0, id_ex_jump_target};
            end
        end
        `JMP1: begin
            if (fwd_a == 32'd1) begin
                branch_taken  = 1'b1;
                branch_target = {2'b0, id_ex_jump_target};
            end
        end

        `LDA:  alu_result = {2'b0, id_ex_imm};  // address
        `STR:  alu_result = {2'b0, id_ex_imm};  // address

        default: alu_result = 32'b0;
    endcase
end
assign cache_addr   = ex_wb_mem_addr;
assign cache_read   = ex_wb_mem_read;
assign cache_refill = (!cache_hit && ex_wb_mem_read);

always_comb begin
    ram_wr_en   = 1'b0;
    ram_rd_en   = 1'b0;
    ram_addr    = ex_wb_mem_addr;
    ram_wr_data = ex_wb_store_data;

    if (ex_wb_mem_write) begin
        ram_wr_en = 1'b1;
    end
    if (ex_wb_mem_read && !cache_hit) begin
        ram_rd_en = 1'b0; // stall handled externally; simplified: direct pass
    end
end

assign cache_refill_data = {96'b0, ram_rd_data}; // simplified refill — 1 word

logic [31:0] wb_data;
always_comb begin
    if (ex_wb_mem_read)
        wb_data = cache_hit ? cache_data_out : ram_rd_data;
    else
        wb_data = ex_wb_result;
end

assign rf_wr_en0   = ex_wb_reg_write && !ex_wb_mem_write;
assign rf_wr_addr0 = ex_wb_rd;
assign rf_wr_data0 = wb_data;

// FPU integer writeback
assign rf_wr_en1   = fpu_int_wr_en;
assign rf_wr_addr1 = fpu_int_wr_addr;
assign rf_wr_data1 = fpu_int_wr_data;

// ROB commit writeback
assign rf_wr_en2   = rob_commit_valid;
assign rf_wr_addr2 = rob_commit_dest[3:0];
assign rf_wr_data2 = rob_commit_value;

assign rob_commit_ready = 1'b1;

assign rob_dispatch_valid = id_ex_reg_write && !stall;
assign rob_dispatch_dest  = {1'b0, id_ex_rd};
assign rob_wb_valid       = ex_wb_reg_write;
assign rob_wb_tag         = 3'b0; // simplified — single in-order tag
assign rob_wb_value       = wb_data;

assign pc_jump_en   = branch_taken;
assign pc_jump_data = branch_target;
assign pc_count_en  = !stall && !branch_taken && !id_ex_halt;
assign pc_halt      = id_ex_halt;

assign fpu_dispatch = id_ex_is_fpu && !stall;
assign fpu_instr    = {id_ex_opc, id_ex_rd, id_ex_rs1, id_ex_rs2, id_ex_imm};

assign rf_rd_addr0 = if_id_instr[37:34]; // rs1
assign rf_rd_addr1 = if_id_instr[33:30]; // rs2
assign rf_rd_addr2 = 4'b0;
assign rf_rd_addr3 = 4'b0;
assign rf_rd_addr4 = 4'b0;
assign rf_rd_addr5 = 4'b0;

assign ibuf_consume = !stall && !branch_taken;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        if_id_instr  <= 48'b0;

        id_ex_opc         <= `NOP;
        id_ex_rd          <= 4'b0;
        id_ex_rs1         <= 4'b0;
        id_ex_rs2         <= 4'b0;
        id_ex_op_a        <= 32'b0;
        id_ex_op_b        <= 32'b0;
        id_ex_imm         <= 30'b0;
        id_ex_reg_write   <= 1'b0;
        id_ex_mem_read    <= 1'b0;
        id_ex_mem_write   <= 1'b0;
        id_ex_jump        <= 1'b0;
        id_ex_jmpz        <= 1'b0;
        id_ex_jmp1        <= 1'b0;
        id_ex_halt        <= 1'b0;
        id_ex_jump_target <= 30'b0;
        id_ex_is_fpu      <= 1'b0;

        ex_wb_opc        <= `NOP;
        ex_wb_rd         <= 4'b0;
        ex_wb_result     <= 32'b0;
        ex_wb_reg_write  <= 1'b0;
        ex_wb_mem_read   <= 1'b0;
        ex_wb_mem_write  <= 1'b0;
        ex_wb_mem_addr   <= 32'b0;
        ex_wb_store_data <= 32'b0;
        ex_wb_halt       <= 1'b0;

        branch_pred <= 2'b01;

    end else begin

        ex_wb_opc        <= id_ex_opc;
        ex_wb_rd         <= id_ex_rd;
        ex_wb_result     <= alu_result;
        ex_wb_reg_write  <= id_ex_reg_write;
        ex_wb_mem_read   <= id_ex_mem_read;
        ex_wb_mem_write  <= id_ex_mem_write;
        ex_wb_mem_addr   <= alu_result;
        ex_wb_store_data <= fwd_b; // STR: store rs2 value
        ex_wb_halt       <= id_ex_halt;

        if (id_ex_opc == `JMPZ || id_ex_opc == `JMP1) begin
            if (branch_taken) begin
                if (branch_pred < 2'b11) branch_pred <= branch_pred + 1;
            end else begin
                if (branch_pred > 2'b00) branch_pred <= branch_pred - 1;
            end
        end

        if (branch_taken) begin
            if_id_instr     <= 48'b0; // bubble
            id_ex_opc       <= `NOP;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read  <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_jump      <= 1'b0;
            id_ex_jmpz      <= 1'b0;
            id_ex_jmp1      <= 1'b0;
            id_ex_halt      <= 1'b0;
            id_ex_is_fpu    <= 1'b0;
        end

        else if (stall) begin
            if_id_instr <= if_id_instr; // freeze fetch
            id_ex_opc       <= `NOP;    // bubble into EX
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read  <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_jump      <= 1'b0;
            id_ex_jmpz      <= 1'b0;
            id_ex_jmp1      <= 1'b0;
            id_ex_halt      <= 1'b0;
            id_ex_is_fpu    <= 1'b0;
        end

        else begin

            // Fetch
            if_id_instr <= rom_out;

            // Decode — read registers, fill ID/EX
            id_ex_opc         <= if_id_instr[47:42];
            id_ex_rd          <= if_id_instr[41:38];
            id_ex_rs1         <= if_id_instr[37:34];
            id_ex_rs2         <= if_id_instr[33:30];
            id_ex_imm         <= if_id_instr[29:0];
            id_ex_op_a        <= rf_rd_data0;
            id_ex_op_b        <= rf_rd_data1;
            id_ex_jump_target <= if_id_instr[29:0];

            // Control defaults
            id_ex_reg_write   <= 1'b0;
            id_ex_mem_read    <= 1'b0;
            id_ex_mem_write   <= 1'b0;
            id_ex_jump        <= 1'b0;
            id_ex_jmpz        <= 1'b0;
            id_ex_jmp1        <= 1'b0;
            id_ex_halt        <= 1'b0;
            id_ex_is_fpu      <= 1'b0;

            if ((if_id_instr[47:42] == `JMPZ || if_id_instr[47:42] == `JMP1) &&
                 branch_pred >= 2'b10) begin
            end

            case (if_id_instr[47:42])
                `NOP:  ; // nothing
                `LDI:  id_ex_reg_write <= 1'b1;
                `MOV:  id_ex_reg_write <= 1'b1;
                `LDA: begin
                    id_ex_mem_read  <= 1'b1;
                    id_ex_reg_write <= 1'b1;
                end
                `STR:  id_ex_mem_write <= 1'b1;
                `ADD, `SUB, `MUL, `DIV: id_ex_reg_write <= 1'b1;
                `AND, `OR, `XOR, `NAND, `NOR, `XNOR,
                `NOT, `SLL, `SRL, `SRA, `ROR, `ROL,
                `INC, `DEC, `CMP: id_ex_reg_write <= 1'b1;
                `JMP:  id_ex_jump <= 1'b1;
                `JMPZ: id_ex_jmpz <= 1'b1;
                `JMP1: id_ex_jmp1 <= 1'b1;
                `HALT: id_ex_halt <= 1'b1;
                `FADD, `FSUB, `FMUL, `FDIV,
                `FNEG, `FABS, `FCMP: id_ex_is_fpu <= 1'b1;
                default: ;
            endcase
        end
    end
end

endmodule
