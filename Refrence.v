

module program_counter(
    input clk,
    input reset,
    input jump_enable,
    input [7:0] jump_data,
    input count_enable,
    input halt,
    output reg [7:0] pc_count
);

always @(posedge clk or posedge reset) begin
    if (reset)
        pc_count <= 8'd0;

    else if (!halt) begin

        if (jump_enable)
            pc_count <= jump_data;

        else if (count_enable)
            pc_count <= pc_count + 8'd1;

    end
end

endmodule



module read_only_memory(
    input [7:0] rom_addr,
    output [15:0] rom_data
);

reg [15:0] memory [0:255];

initial begin
    $readmemh("rom.hex", memory);
end

assign rom_data = memory[rom_addr];

endmodule



module register_file(
    input clk,

    input wr_en,
    input [1:0] wr_addr,
    input [7:0] wr_data,

    input [1:0] rd_addr_a,
    output [7:0] rd_data_a,

    input [1:0] rd_addr_b,
    output [7:0] rd_data_b
);

reg [7:0] registers [0:3];

always @(posedge clk) begin

    if (wr_en)
        registers[wr_addr] <= wr_data;

end



assign rd_data_a =
    (wr_en && (wr_addr == rd_addr_a))
    ? wr_data
    : registers[rd_addr_a];

assign rd_data_b =
    (wr_en && (wr_addr == rd_addr_b))
    ? wr_data
    : registers[rd_addr_b];

endmodule



module ram(
    input clk,
    input wr_en,
    input rd_en,

    input [7:0] addr,
    input [7:0] wr_data,

    output [7:0] rd_data
);

reg [7:0] memory [0:255];



always @(posedge clk) begin

    if (wr_en)
        memory[addr] <= wr_data;

end


assign rd_data =
    rd_en ? memory[addr] : 8'b0;

endmodule




module arithmetic_logic_unit(
    input [7:0] a,
    input [7:0] b,
    input [2:0] alu_operation,

    output reg [7:0] alu_result
);

always @(*) begin

    case (alu_operation)

        3'b000:
            alu_result = a + b;

        3'b001:
            alu_result = a - b;

        3'b010:
            alu_result = a & b;

        3'b011:
            alu_result = a | b;

        3'b100:
            alu_result = a ^ b;

        3'b101:
            alu_result = ~a;

        3'b110:
            alu_result = a << 1;

        3'b111:
            alu_result = a >> 1;

        default:
            alu_result = 8'b0;

    endcase

end

endmodule



module hazard_detection_unit(

    input        id_ex_mem_read,
    input [1:0]  id_ex_rd,

    input [3:0]  if_id_opcode,
    input [1:0]  if_id_rs,
    input [1:0]  if_id_rt,

    output reg   stall
);

reg uses_rs;
reg uses_rt;

always @(*) begin

    uses_rs = 1'b0;
    uses_rt = 1'b0;

    case (if_id_opcode)

        // LOAD REGISTER
        4'b0010:
            begin
                uses_rs = 1'b1;
            end

        // STORE
        4'b0011:
            begin
                uses_rs = 1'b1;
            end

        // ADD
        4'b0101:
            begin
                uses_rs = 1'b1;
                uses_rt = 1'b1;
            end

        // SUB
        4'b0110:
            begin
                uses_rs = 1'b1;
                uses_rt = 1'b1;
            end

        // AND
        4'b0111:
            begin
                uses_rs = 1'b1;
                uses_rt = 1'b1;
            end

        // OR
        4'b1000:
            begin
                uses_rs = 1'b1;
                uses_rt = 1'b1;
            end

        // XOR
        4'b1001:
            begin
                uses_rs = 1'b1;
                uses_rt = 1'b1;
            end

        // NOT
        4'b1010:
            begin
                uses_rs = 1'b1;
            end

        // SHIFT LEFT
        4'b1011:
            begin
                uses_rs = 1'b1;
            end


        4'b1100:
            begin
                uses_rs = 1'b1;
            end

        4'b1110:
            begin
                uses_rs = 1'b1;
                uses_rt = 1'b1;
            end

        default:
            begin
                uses_rs = 1'b0;
                uses_rt = 1'b0;
            end

    endcase



    stall = 1'b0;

    if (id_ex_mem_read) begin

        if (uses_rs && (id_ex_rd == if_id_rs))
            stall = 1'b1;

        if (uses_rt && (id_ex_rd == if_id_rt))
            stall = 1'b1;

    end

end

endmodule



module forwarding_unit(

    input        ex_mem_reg_write,
    input [1:0]  ex_mem_rd,
    input        ex_mem_mem_read,

    input        mem_wb_reg_write,
    input [1:0]  mem_wb_rd,

    input [1:0]  id_ex_rs,
    input [1:0]  id_ex_rt,

    output reg [1:0] forward_a,
    output reg [1:0] forward_b

);

always @(*) begin



    forward_a = 2'b00;
    forward_b = 2'b00;



    if (ex_mem_reg_write &&
        !ex_mem_mem_read &&
        (ex_mem_rd == id_ex_rs)) begin

        forward_a = 2'b10;

    end

    else if (mem_wb_reg_write &&
             (mem_wb_rd == id_ex_rs)) begin

        forward_a = 2'b01;

    end



    if (ex_mem_reg_write &&
        !ex_mem_mem_read &&
        (ex_mem_rd == id_ex_rt)) begin

        forward_b = 2'b10;

    end

    else if (mem_wb_reg_write &&
             (mem_wb_rd == id_ex_rt)) begin

        forward_b = 2'b01;

    end

end

endmodule




module pipelined_cpu(
    input clk,
    input reset
);




wire [7:0]  program_counter;
wire [15:0] instruction;
wire [15:0] rom_data;

wire pc_jump_enable;
wire [7:0] pc_jump_data;
wire pc_count_enable;
wire pc_halt;




wire [7:0] register_data_a;
wire [7:0] register_data_b;

wire [1:0] rf_read_a;
wire [1:0] rf_read_b;




wire        wb_reg_write;
wire [1:0]  wb_rd;
wire [7:0]  wb_data;




register_file rf(

    .clk(clk),

    .wr_en(wb_reg_write),
    .wr_addr(wb_rd),
    .wr_data(wb_data),

    .rd_addr_a(rf_read_a),
    .rd_data_a(register_data_a),

    .rd_addr_b(rf_read_b),
    .rd_data_b(register_data_b)

);



read_only_memory rom(

    .rom_addr(program_counter),
    .rom_data(rom_data)

);

assign instruction = rom_data;



program_counter pc(

    .clk(clk),
    .reset(reset),

    .jump_enable(pc_jump_enable),
    .jump_data(pc_jump_data),

    .count_enable(pc_count_enable),
    .halt(pc_halt),

    .pc_count(program_counter)

);




reg [15:0] if_id_instruction;




wire [3:0] if_id_opcode;

wire [1:0] if_id_rs;
wire [1:0] if_id_rt;

assign if_id_opcode = if_id_instruction[15:12];

assign if_id_rs = if_id_instruction[11:10];

assign if_id_rt = if_id_instruction[9:8];




reg [3:0] id_ex_opcode;

reg [1:0] id_ex_rs;
reg [1:0] id_ex_rt;
reg [1:0] id_ex_rd;

reg [7:0] id_ex_operand_a;
reg [7:0] id_ex_operand_b;

reg [7:0] id_ex_immediate;

reg [2:0] id_ex_alu_operation;

reg id_ex_reg_write;
reg id_ex_mem_read;
reg id_ex_mem_write;

reg id_ex_jump;
reg id_ex_branch;
reg id_ex_halt;

reg [7:0] id_ex_jump_target;




reg [7:0] ex_mem_result;

reg [7:0] ex_mem_store_data;

reg [7:0] ex_mem_memory_address;

reg [1:0] ex_mem_rd;

reg ex_mem_reg_write;
reg ex_mem_mem_read;
reg ex_mem_mem_write;



reg [7:0] mem_wb_data;

reg [1:0] mem_wb_rd;

reg mem_wb_reg_write;



wire [7:0] memory_read_data;

ram data_ram(

    .clk(clk),

    .wr_en(ex_mem_mem_write),
    .rd_en(ex_mem_mem_read),

    .addr(ex_mem_memory_address),

    .wr_data(ex_mem_store_data),

    .rd_data(memory_read_data)

);




wire load_use_stall;

hazard_detection_unit hdu(

    .id_ex_mem_read(id_ex_mem_mem_read),
    .id_ex_rd(id_ex_rd),

    .if_id_opcode(if_id_opcode),
    .if_id_rs(if_id_rs),
    .if_id_rt(if_id_rt),

    .stall(load_use_stall)

);




wire [1:0] forward_a;
wire [1:0] forward_b;

forwarding_unit fu(

    .ex_mem_reg_write(ex_mem_reg_write),
    .ex_mem_rd(ex_mem_rd),
    .ex_mem_mem_read(ex_mem_mem_read),

    .mem_wb_reg_write(mem_wb_reg_write),
    .mem_wb_rd(mem_wb_rd),

    .id_ex_rs(id_ex_rs),
    .id_ex_rt(id_ex_rt),

    .forward_a(forward_a),
    .forward_b(forward_b)

);




reg [7:0] alu_input_a;
reg [7:0] alu_input_b;

always @(*) begin

    case(forward_a)

        2'b00:
            alu_input_a = id_ex_operand_a;

        2'b01:
            alu_input_a = mem_wb_data;

        2'b10:
            alu_input_a = ex_mem_result;

        default:
            alu_input_a = id_ex_operand_a;

    endcase


    case(forward_b)

        2'b00:
            alu_input_b = id_ex_operand_b;

        2'b01:
            alu_input_b = mem_wb_data;

        2'b10:
            alu_input_b = ex_mem_result;

        default:
            alu_input_b = id_ex_operand_b;

    endcase

end



wire [7:0] alu_result;

arithmetic_logic_unit alu(

    .a(alu_input_a),
    .b(alu_input_b),

    .alu_operation(id_ex_alu_operation),

    .alu_result(alu_result)

);




reg [7:0] ex_result;

always @(*) begin

    case(id_ex_opcode)


        4'b0001:
            ex_result = id_ex_immediate;


        4'b0010:
            ex_result = alu_input_a;


        4'b0100:
            ex_result = id_ex_immediate;

        4'b0101,
        4'b0110,
        4'b0111,
        4'b1000,
        4'b1001,
        4'b1010,
        4'b1011,
        4'b1100:
            ex_result = alu_result;

        default:
            ex_result = alu_result;

    endcase

end




reg ex_taken;
reg [7:0] ex_target;

always @(*) begin

    ex_taken  = 1'b0;
    ex_target = id_ex_jump_target;


    if (id_ex_jump) begin

        ex_taken = 1'b1;

    end


    else if (id_ex_branch) begin

        if (alu_result == 8'b0)
            ex_taken = 1'b1;

    end

end




assign pc_jump_enable = ex_taken;

assign pc_jump_data = ex_target;




assign pc_count_enable =
    !load_use_stall &&
    !id_ex_halt &&
    !ex_taken;




assign pc_halt = id_ex_halt;




assign rf_read_a = if_id_rs;
assign rf_read_b = if_id_rt;




always @(posedge clk or posedge reset) begin

    if (reset) begin



        if_id_instruction <= 16'b0;




        id_ex_opcode <= 4'b0000;

        id_ex_rs <= 2'b0;
        id_ex_rt <= 2'b0;
        id_ex_rd <= 2'b0;

        id_ex_operand_a <= 8'b0;
        id_ex_operand_b <= 8'b0;

        id_ex_immediate <= 8'b0;

        id_ex_alu_operation <= 3'b000;

        id_ex_reg_write <= 1'b0;
        id_ex_mem_read <= 1'b0;
        id_ex_mem_write <= 1'b0;

        id_ex_jump <= 1'b0;
        id_ex_branch <= 1'b0;
        id_ex_halt <= 1'b0;

        id_ex_jump_target <= 8'b0;




        ex_mem_result <= 8'b0;
        ex_mem_store_data <= 8'b0;
        ex_mem_memory_address <= 8'b0;

        ex_mem_rd <= 2'b0;

        ex_mem_reg_write <= 1'b0;
        ex_mem_mem_read <= 1'b0;
        ex_mem_mem_write <= 1'b0;




        mem_wb_data <= 8'b0;
        mem_wb_rd <= 2'b0;
        mem_wb_reg_write <= 1'b0;

    end

    else begin


        mem_wb_rd <= ex_mem_rd;

        mem_wb_reg_write <= ex_mem_reg_write;


        if (ex_mem_mem_read)
            mem_wb_data <= memory_read_data;

        else
            mem_wb_data <= ex_mem_result;



        ex_mem_result <= ex_result;

        ex_mem_rd <= id_ex_rd;

        ex_mem_reg_write <= id_ex_reg_write;

        ex_mem_mem_read <= id_ex_mem_read;

        ex_mem_mem_write <= id_ex_mem_write;


        ex_mem_memory_address <= ex_result;



        ex_mem_store_data <= alu_input_a;




        if (ex_taken) begin


            if_id_instruction <= 16'b0;

            id_ex_opcode <= 4'b0000;

            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;

            id_ex_jump <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_halt <= 1'b0;

        end



        else if (load_use_stall) begin



            if_id_instruction <= if_id_instruction;




            id_ex_opcode <= 4'b0000;

            id_ex_rs <= 2'b0;
            id_ex_rt <= 2'b0;
            id_ex_rd <= 2'b0;

            id_ex_operand_a <= 8'b0;
            id_ex_operand_b <= 8'b0;

            id_ex_immediate <= 8'b0;

            id_ex_alu_operation <= 3'b000;

            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;

            id_ex_jump <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_halt <= 1'b0;

            id_ex_jump_target <= 8'b0;

        end




        else begin



            if_id_instruction <= instruction;




            id_ex_opcode <= if_id_opcode;

            id_ex_rs <= if_id_rs;
            id_ex_rt <= if_id_rt;

            id_ex_operand_a <= register_data_a;
            id_ex_operand_b <= register_data_b;

            id_ex_immediate <= 8'b0;

            id_ex_alu_operation <= 3'b000;

            id_ex_rd <= 2'b0;

            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;

            id_ex_jump <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_halt <= 1'b0;

            id_ex_jump_target <= 8'b0;




            case(if_id_opcode)




                4'b0000:
                    begin

                        id_ex_opcode <= 4'b0000;

                    end




                4'b0001:
                    begin

                        id_ex_rd <= if_id_instruction[11:10];

                        id_ex_immediate <=
                            if_id_instruction[9:2];

                        id_ex_reg_write <= 1'b1;

                    end




                4'b0010:
                    begin

                        id_ex_rs <=
                            if_id_instruction[11:10];

                        id_ex_rd <=
                            if_id_instruction[9:8];

                        id_ex_reg_write <= 1'b1;

                    end




                4'b0011:
                    begin

                        id_ex_rs <=
                            if_id_instruction[11:10];

                        id_ex_immediate <=
                            if_id_instruction[9:2];

                        id_ex_mem_write <= 1'b1;

                    end


 

                4'b0100:
                    begin

                        id_ex_rd <=
                            if_id_instruction[3:2];

                        id_ex_immediate <=
                            if_id_instruction[11:4];

                        id_ex_mem_read <= 1'b1;
                        id_ex_reg_write <= 1'b1;

                    end




                4'b0101:
                    begin

                        id_ex_rs <= if_id_instruction[11:10];
                        id_ex_rt <= if_id_instruction[9:8];
                        id_ex_rd <= if_id_instruction[7:6];

                        id_ex_alu_operation <= 3'b000;

                        id_ex_reg_write <= 1'b1;

                    end




                4'b0110:
                    begin

                        id_ex_rs <= if_id_instruction[11:10];
                        id_ex_rt <= if_id_instruction[9:8];
                        id_ex_rd <= if_id_instruction[7:6];

                        id_ex_alu_operation <= 3'b001;

                        id_ex_reg_write <= 1'b1;

                    end




                4'b0111:
                    begin

                        id_ex_rs <= if_id_instruction[11:10];
                        id_ex_rt <= if_id_instruction[9:8];
                        id_ex_rd <= if_id_instruction[7:6];

                        id_ex_alu_operation <= 3'b010;

                        id_ex_reg_write <= 1'b1;

                    end




                4'b1000:
                    begin

                        id_ex_rs <= if_id_instruction[11:10];
                        id_ex_rt <= if_id_instruction[9:8];
                        id_ex_rd <= if_id_instruction[7:6];

                        id_ex_alu_operation <= 3'b011;

                        id_ex_reg_write <= 1'b1;

                    end




                4'b1001:
                    begin

                        id_ex_rs <= if_id_instruction[11:10];
                        id_ex_rt <= if_id_instruction[9:8];
                        id_ex_rd <= if_id_instruction[7:6];

                        id_ex_alu_operation <= 3'b100;

                        id_ex_reg_write <= 1'b1;

                    end




                4'b1010:
                    begin

                        id_ex_rs <= if_id_instruction[11:10];
                        id_ex_rd <= if_id_instruction[7:6];

                        id_ex_alu_operation <= 3'b101;

                        id_ex_reg_write <= 1'b1;

                    end




                4'b1011:
                    begin

                        id_ex_rs <= if_id_instruction[11:10];
                        id_ex_rd <= if_id_instruction[7:6];

                        id_ex_alu_operation <= 3'b110;

                        id_ex_reg_write <= 1'b1;

                    end




                4'b1100:
                    begin

                        id_ex_rs <= if_id_instruction[11:10];
                        id_ex_rd <= if_id_instruction[7:6];

                        id_ex_alu_operation <= 3'b111;

                        id_ex_reg_write <= 1'b1;

                    end



                4'b1101:
                    begin

                        id_ex_jump <= 1'b1;

                        id_ex_jump_target <=
                            if_id_instruction[11:4];

                    end



                4'b1110:
                    begin

                        id_ex_rs <= if_id_instruction[11:10];
                        id_ex_rt <= if_id_instruction[9:8];

                        id_ex_alu_operation <= 3'b001;

                        id_ex_branch <= 1'b1;

                        id_ex_jump_target <=
                            if_id_instruction[11:4];

                    end




                4'b1111:
                    begin

                        id_ex_halt <= 1'b1;

                    end


                default:
                    begin

                        id_ex_opcode <= 4'b0000;

                    end

            endcase

        end

    end

end


assign wb_reg_write = mem_wb_reg_write;

assign wb_rd = mem_wb_rd;

assign wb_data = mem_wb_data;


endmodule