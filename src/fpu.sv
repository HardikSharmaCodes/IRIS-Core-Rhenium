// FPU Register File — 16 FP regs
module fpuRegfile (
    input  logic        clk,
    input  logic        rst,

    input  logic        wr_en1,
    input  logic [3:0]  wr_addr1,
    input  logic [31:0] wr_data1,

    input  logic        wr_en2,
    input  logic [3:0]  wr_addr2,
    input  logic [31:0] wr_data2,

    input  logic        wr_en3,
    input  logic [3:0]  wr_addr3,
    input  logic [31:0] wr_data3,

    input  logic [3:0]  rd_addr1,
    output logic [31:0] rd_data1,
    input  logic [3:0]  rd_addr2,
    output logic [31:0] rd_data2,
    input  logic [3:0]  rd_addr3,
    output logic [31:0] rd_data3,
    input  logic [3:0]  rd_addr4,
    output logic [31:0] rd_data4,
    input  logic [3:0]  rd_addr5,
    output logic [31:0] rd_data5,
    input  logic [3:0]  rd_addr6,
    output logic [31:0] rd_data6
);

reg [31:0] regs [0:15];
integer i;

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        for (i = 0; i < 16; i = i + 1)
            regs[i] <= 32'b0;
    else begin
        if (wr_en1) regs[wr_addr1] <= wr_data1;
        if (wr_en2) regs[wr_addr2] <= wr_data2;
        if (wr_en3) regs[wr_addr3] <= wr_data3;
    end
end

assign rd_data1 = regs[rd_addr1];
assign rd_data2 = regs[rd_addr2];
assign rd_data3 = regs[rd_addr3];
assign rd_data4 = regs[rd_addr4];
assign rd_data5 = regs[rd_addr5];
assign rd_data6 = regs[rd_addr6];

endmodule

// FP Add/Subtract — IEEE 754 single, latency 2
module fpuAddSub (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic        sub,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result,
    output logic        busy,
    output logic        ready,
    output logic        idle
);

parameter LATENCY = 2;

localparam IDLE_ST = 2'b00;
localparam RUN_ST  = 2'b01;
localparam DONE_ST = 2'b10;

reg [1:0] state;
reg [3:0] counter;

reg [31:0] a_reg, b_reg;
reg        sub_reg;

reg sign_a, sign_b;
reg [7:0]  exp_a, exp_b;
reg [23:0] mant_a, mant_b;

reg sign_big, sign_small;
reg [7:0]  exp_big;
reg [23:0] mant_big, mant_small;

reg [24:0] mant_sum;
reg [23:0] mant_res;
reg sign_res;
reg [7:0]  exp_res;

integer shift;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state   <= IDLE_ST;
        counter <= 0;
        busy    <= 1'b0;
        ready   <= 1'b0;
        idle    <= 1'b1;
        result  <= 32'b0;
    end else begin
        ready <= 1'b0;
        case (state)
            IDLE_ST: begin
                busy <= 1'b0;
                idle <= 1'b1;
                if (start) begin
                    a_reg   <= a;
                    b_reg   <= b;
                    sub_reg <= sub;
                    counter <= LATENCY - 1;
                    busy    <= 1'b1;
                    idle    <= 1'b0;
                    state   <= RUN_ST;
                end
            end
            RUN_ST: begin
                if (counter != 0) begin
                    counter <= counter - 1;
                end else begin
                    sign_a = a_reg[31];
                    sign_b = b_reg[31] ^ sub_reg;
                    exp_a  = a_reg[30:23];
                    exp_b  = b_reg[30:23];
                    mant_a = (exp_a == 0) ? {1'b0, a_reg[22:0]} : {1'b1, a_reg[22:0]};
                    mant_b = (exp_b == 0) ? {1'b0, b_reg[22:0]} : {1'b1, b_reg[22:0]};

                    if (exp_a >= exp_b) begin
                        exp_big    = exp_a;
                        mant_big   = mant_a;
                        sign_big   = sign_a;
                        mant_small = mant_b >> (exp_a - exp_b);
                        sign_small = sign_b;
                    end else begin
                        exp_big    = exp_b;
                        mant_big   = mant_b;
                        sign_big   = sign_b;
                        mant_small = mant_a >> (exp_b - exp_a);
                        sign_small = sign_a;
                    end

                    exp_res = exp_big;

                    if (sign_big == sign_small) begin
                        mant_sum = mant_big + mant_small;
                        sign_res = sign_big;
                        if (mant_sum[24]) begin
                            mant_res = mant_sum[24:1];
                            exp_res  = exp_res + 1;
                        end else
                            mant_res = mant_sum[23:0];
                    end else begin
                        if (mant_big >= mant_small) begin
                            mant_res = mant_big - mant_small;
                            sign_res = sign_big;
                        end else begin
                            mant_res = mant_small - mant_big;
                            sign_res = sign_small;
                        end
                        if (mant_res == 0) begin
                            exp_res  = 0;
                            sign_res = 0;
                        end else begin
                            shift = 0;
                            while ((mant_res[23] == 0) && (exp_res > 0) && (shift < 24)) begin
                                mant_res = mant_res << 1;
                                exp_res  = exp_res - 1;
                                shift    = shift + 1;
                            end
                        end
                    end

                    result <= (mant_res == 0) ? 32'b0 : {sign_res, exp_res, mant_res[22:0]};
                    state  <= DONE_ST;
                end
            end
            DONE_ST: begin
                busy  <= 1'b0;
                idle  <= 1'b1;
                ready <= 1'b1;
                state <= IDLE_ST;
            end
        endcase
    end
end

endmodule

// FP Multiplier — IEEE 754 single, latency 4
module fpuMultiplier (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result,
    output logic        busy,
    output logic        ready,
    output logic        idle
);

parameter LATENCY = 4;

localparam IDLE_ST = 2'b00;
localparam RUN_ST  = 2'b01;
localparam DONE_ST = 2'b10;

reg [1:0] state;
reg [3:0] counter;
reg [31:0] a_reg, b_reg;

reg sign_a, sign_b;
reg [7:0]  exp_a, exp_b;
reg [23:0] mant_a, mant_b;
reg sign_res;
reg [7:0]  exp_res;
reg [47:0] mant_prod;
reg [22:0] frac_res;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state   <= IDLE_ST;
        counter <= 0;
        busy    <= 1'b0;
        ready   <= 1'b0;
        idle    <= 1'b1;
        result  <= 32'b0;
    end else begin
        ready <= 1'b0;
        case (state)
            IDLE_ST: begin
                busy <= 1'b0;
                idle <= 1'b1;
                if (start) begin
                    a_reg   <= a;
                    b_reg   <= b;
                    counter <= LATENCY - 1;
                    busy    <= 1'b1;
                    idle    <= 1'b0;
                    state   <= RUN_ST;
                end
            end
            RUN_ST: begin
                if (counter != 0) begin
                    counter <= counter - 1;
                end else begin
                    sign_a = a_reg[31];
                    sign_b = b_reg[31];
                    exp_a  = a_reg[30:23];
                    exp_b  = b_reg[30:23];
                    mant_a = (exp_a == 0) ? {1'b0, a_reg[22:0]} : {1'b1, a_reg[22:0]};
                    mant_b = (exp_b == 0) ? {1'b0, b_reg[22:0]} : {1'b1, b_reg[22:0]};

                    sign_res  = sign_a ^ sign_b;
                    exp_res   = exp_a + exp_b - 8'd127;
                    mant_prod = mant_a * mant_b;

                    if (mant_prod[47]) begin
                        frac_res = mant_prod[46:24];
                        exp_res  = exp_res + 1;
                    end else
                        frac_res = mant_prod[45:23];

                    if ((a_reg[30:0] == 0) || (b_reg[30:0] == 0))
                        result <= 32'b0;
                    else
                        result <= {sign_res, exp_res, frac_res};

                    state <= DONE_ST;
                end
            end
            DONE_ST: begin
                busy  <= 1'b0;
                idle  <= 1'b1;
                ready <= 1'b1;
                state <= IDLE_ST;
            end
        endcase
    end
end

endmodule

// FP Divider — IEEE 754 single, latency 8
module fpuDivider (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result,
    output logic        busy,
    output logic        ready,
    output logic        idle
);

parameter LATENCY = 8;

localparam IDLE = 2'b00;
localparam RUN  = 2'b01;
localparam DONE = 2'b10;

reg [1:0] state;
reg [3:0] counter;
reg [31:0] a_reg, b_reg;

reg sign_a, sign_b;
reg [7:0]  exp_a, exp_b;
reg [23:0] mant_a, mant_b;
reg sign_res;
reg [7:0]  exp_res;
reg [47:0] dividend;
reg [23:0] mant_res;

integer shift;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state   <= IDLE;
        busy    <= 1'b0;
        ready   <= 1'b0;
        idle    <= 1'b1;
        counter <= 4'd0;
        result  <= 32'b0;
    end else begin
        ready <= 1'b0;
        case (state)
            IDLE: begin
                busy <= 1'b0;
                idle <= 1'b1;
                if (start) begin
                    a_reg   <= a;
                    b_reg   <= b;
                    counter <= LATENCY - 1;
                    busy    <= 1'b1;
                    idle    <= 1'b0;
                    state   <= RUN;
                end
            end
            RUN: begin
                if (counter != 0) begin
                    counter <= counter - 1;
                end else begin
                    sign_a = a_reg[31];
                    sign_b = b_reg[31];
                    exp_a  = a_reg[30:23];
                    exp_b  = b_reg[30:23];
                    mant_a = (exp_a == 0) ? {1'b0, a_reg[22:0]} : {1'b1, a_reg[22:0]};
                    mant_b = (exp_b == 0) ? {1'b0, b_reg[22:0]} : {1'b1, b_reg[22:0]};

                    sign_res = sign_a ^ sign_b;
                    exp_res  = exp_a - exp_b + 8'd127;
                    dividend = {mant_a, 24'b0};
                    mant_res = (mant_b == 0) ? 24'b0 : dividend / mant_b;

                    if (!mant_res[23]) begin
                        shift = 0;
                        while ((mant_res[23] == 0) && (mant_res != 0) && (shift < 24)) begin
                            mant_res = mant_res << 1;
                            exp_res  = exp_res - 1;
                            shift    = shift + 1;
                        end
                    end

                    if (b_reg[30:0] == 0)
                        result <= 32'h7F800000; // +inf
                    else if (a_reg[30:0] == 0)
                        result <= 32'b0;
                    else
                        result <= {sign_res, exp_res, mant_res[22:0]};

                    state <= DONE;
                end
            end
            DONE: begin
                busy  <= 1'b0;
                idle  <= 1'b1;
                ready <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule

// FPU Top — dispatches FP instructions to execution units
// Instruction format [47:42]=opcode, [41:38]=Fd, [37:34]=Fs1, [33:30]=Fs2
module fpu (
    input  logic        clk,
    input  logic        rst,
    input  logic [47:0] cpu_out,    // instruction word from CPU dispatch
    input  logic        dispatch,   // issue strobe

    // Writeback to integer regfile (FCMP result)
    output logic        int_wr_en,
    output logic [3:0]  int_wr_addr,
    output logic [31:0] int_wr_data
);

// FP regfile wires
logic        rf_wr_en1, rf_wr_en2, rf_wr_en3;
logic [3:0]  rf_wr_addr1, rf_wr_addr2, rf_wr_addr3;
logic [31:0] rf_wr_data1, rf_wr_data2, rf_wr_data3;

logic [3:0]  rf_rd_addr1, rf_rd_addr2, rf_rd_addr3;
logic [3:0]  rf_rd_addr4, rf_rd_addr5, rf_rd_addr6;
logic [31:0] rf_rd_data1, rf_rd_data2, rf_rd_data3;
logic [31:0] rf_rd_data4, rf_rd_data5, rf_rd_data6;

// AddSub
logic        fadd_start, fadd_sub;
logic [31:0] fadd_a, fadd_b, fadd_result;
logic        fadd_busy, fadd_ready, fadd_idle;
logic [3:0]  fadd_dest;

// Multiplier
logic        fmul_start;
logic [31:0] fmul_a, fmul_b, fmul_result;
logic        fmul_busy, fmul_ready, fmul_idle;
logic [3:0]  fmul_dest;

// Divider
logic        fdiv_start;
logic [31:0] fdiv_a, fdiv_b, fdiv_result;
logic        fdiv_busy, fdiv_ready, fdiv_idle;
logic [3:0]  fdiv_dest;

// Decode pipeline stages
reg [47:0] ins1, ins2;

fpuRegfile fp_regs (
    .clk(clk), .rst(rst),
    .wr_en1(rf_wr_en1), .wr_addr1(rf_wr_addr1), .wr_data1(rf_wr_data1),
    .wr_en2(rf_wr_en2), .wr_addr2(rf_wr_addr2), .wr_data2(rf_wr_data2),
    .wr_en3(rf_wr_en3), .wr_addr3(rf_wr_addr3), .wr_data3(rf_wr_data3),
    .rd_addr1(rf_rd_addr1), .rd_data1(rf_rd_data1),
    .rd_addr2(rf_rd_addr2), .rd_data2(rf_rd_data2),
    .rd_addr3(rf_rd_addr3), .rd_data3(rf_rd_data3),
    .rd_addr4(rf_rd_addr4), .rd_data4(rf_rd_data4),
    .rd_addr5(rf_rd_addr5), .rd_data5(rf_rd_data5),
    .rd_addr6(rf_rd_addr6), .rd_data6(rf_rd_data6)
);

fpuAddSub fadd_unit (
    .clk(clk), .rst(rst),
    .start(fadd_start), .sub(fadd_sub),
    .a(fadd_a), .b(fadd_b),
    .result(fadd_result),
    .busy(fadd_busy), .ready(fadd_ready), .idle(fadd_idle)
);

fpuMultiplier fmul_unit (
    .clk(clk), .rst(rst),
    .start(fmul_start),
    .a(fmul_a), .b(fmul_b),
    .result(fmul_result),
    .busy(fmul_busy), .ready(fmul_ready), .idle(fmul_idle)
);

fpuDivider fdiv_unit (
    .clk(clk), .rst(rst),
    .start(fdiv_start),
    .a(fdiv_a), .b(fdiv_b),
    .result(fdiv_result),
    .busy(fdiv_busy), .ready(fdiv_ready), .idle(fdiv_idle)
);

// Stage 1: register read
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        ins1 <= 48'b0;
        rf_rd_addr1 <= 4'b0; rf_rd_addr2 <= 4'b0;
        rf_rd_addr3 <= 4'b0; rf_rd_addr4 <= 4'b0;
        rf_rd_addr5 <= 4'b0; rf_rd_addr6 <= 4'b0;
    end else if (dispatch) begin
        ins1 <= cpu_out;
        // FADD, FSUB, FCMP use ports 1,2; FMUL uses 3,4; FDIV uses 5,6; FNEG/FABS use 1 only
        case (cpu_out[47:42])
            6'b011100, 6'b011101, 6'b100010: begin // FADD, FSUB, FCMP
                rf_rd_addr1 <= cpu_out[37:34];
                rf_rd_addr2 <= cpu_out[33:30];
            end
            6'b011110: begin // FMUL
                rf_rd_addr3 <= cpu_out[37:34];
                rf_rd_addr4 <= cpu_out[33:30];
            end
            6'b011111: begin // FDIV
                rf_rd_addr5 <= cpu_out[37:34];
                rf_rd_addr6 <= cpu_out[33:30];
            end
            6'b100000, 6'b100001: begin // FNEG, FABS
                rf_rd_addr1 <= cpu_out[37:34];
            end
            default: ;
        endcase
    end else
        ins1 <= 48'b0;
end

// Stage 2: dispatch to execution unit
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        ins2        <= 48'b0;
        fadd_start  <= 1'b0; fadd_sub <= 1'b0;
        fmul_start  <= 1'b0;
        fdiv_start  <= 1'b0;
        fadd_a      <= 32'b0; fadd_b <= 32'b0;
        fmul_a      <= 32'b0; fmul_b <= 32'b0;
        fdiv_a      <= 32'b0; fdiv_b <= 32'b0;
        fadd_dest   <= 4'b0;
        fmul_dest   <= 4'b0;
        fdiv_dest   <= 4'b0;
    end else begin
        fadd_start <= 1'b0;
        fmul_start <= 1'b0;
        fdiv_start <= 1'b0;
        ins2       <= ins1;

        case (ins1[47:42])
            6'b011100: begin // FADD
                if (fadd_idle) begin
                    fadd_start <= 1'b1;
                    fadd_sub   <= 1'b0;
                    fadd_a     <= rf_rd_data1;
                    fadd_b     <= rf_rd_data2;
                    fadd_dest  <= ins1[41:38];
                end
            end
            6'b011101: begin // FSUB
                if (fadd_idle) begin
                    fadd_start <= 1'b1;
                    fadd_sub   <= 1'b1;
                    fadd_a     <= rf_rd_data1;
                    fadd_b     <= rf_rd_data2;
                    fadd_dest  <= ins1[41:38];
                end
            end
            6'b011110: begin // FMUL
                if (fmul_idle) begin
                    fmul_start <= 1'b1;
                    fmul_a     <= rf_rd_data3;
                    fmul_b     <= rf_rd_data4;
                    fmul_dest  <= ins1[41:38];
                end
            end
            6'b011111: begin // FDIV
                if (fdiv_idle) begin
                    fdiv_start <= 1'b1;
                    fdiv_a     <= rf_rd_data5;
                    fdiv_b     <= rf_rd_data6;
                    fdiv_dest  <= ins1[41:38];
                end
            end
            6'b100000: begin // FNEG — negate sign bit
                rf_wr_en1   <= 1'b1;
                rf_wr_addr1 <= ins1[41:38];
                rf_wr_data1 <= {~rf_rd_data1[31], rf_rd_data1[30:0]};
            end
            6'b100001: begin // FABS — clear sign bit
                rf_wr_en1   <= 1'b1;
                rf_wr_addr1 <= ins1[41:38];
                rf_wr_data1 <= {1'b0, rf_rd_data1[30:0]};
            end
            6'b100010: begin // FCMP
                rf_wr_en1   <= 1'b1;
                rf_wr_addr1 <= ins1[41:38]; // dest is FP reg
                rf_wr_data1 <= (rf_rd_data1 == rf_rd_data2) ? 32'd1 : 32'd0;
            end
            default: begin
                rf_wr_en1 <= 1'b0;
            end
        endcase
    end
end

// Writeback from execution units
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        rf_wr_en2   <= 1'b0;
        rf_wr_en3   <= 1'b0;
        int_wr_en   <= 1'b0;
    end else begin
        rf_wr_en2 <= 1'b0;
        rf_wr_en3 <= 1'b0;
        int_wr_en <= 1'b0;

        if (fadd_ready) begin
            rf_wr_en2   <= 1'b1;
            rf_wr_addr2 <= fadd_dest;
            rf_wr_data2 <= fadd_result;
        end
        if (fmul_ready) begin
            rf_wr_en3   <= 1'b1;
            rf_wr_addr3 <= fmul_dest;
            rf_wr_data3 <= fmul_result;
        end
        if (fdiv_ready) begin
            // reuse wr_en1 is safe since FNEG/FABS are single cycle
            rf_wr_en1   <= 1'b1;
            rf_wr_addr1 <= fdiv_dest;
            rf_wr_data1 <= fdiv_result;
        end
    end
end

endmodule
