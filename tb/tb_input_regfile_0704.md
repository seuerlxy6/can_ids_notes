`timescale 1ns/1ps

module tb_input_regfile;

    /* ---------- DUT 端口 ---------- */
    reg         clk_cal   = 0;
    reg         rst_cal_n = 0;

    reg  [3:0]  nn_layer_cnt = 1;   // 卷积层
    reg  [7:0]  K  = 9;             // 3×3
    reg  [7:0]  S  = 2;             // stride 2

    reg         Weight_Data_Ovld = 0;
    reg         pe_end           = 0;

    reg  [7:0]  IR_Data_I0,IR_Data_I1,IR_Data_I2,IR_Data_I3,
                IR_Data_I4,IR_Data_I5,IR_Data_I6,IR_Data_I7;
    reg         IR_Data_I_vld = 0;
    reg  [5:0]  Bm_cnt_in     = 0;
    reg  [1:0]  kh_cnt_in     = 0;

    wire        IR_Data_O_vld;
    wire [7:0]  IR_Data_O0,IR_Data_O1,IR_Data_O2,IR_Data_O3,
                IR_Data_O4,IR_Data_O5,IR_Data_O6,IR_Data_O7,
                IR_Data_O8,IR_Data_O9,IR_Data_Oa,IR_Data_Ob,
                IR_Data_Oc,IR_Data_Od,IR_Data_Oe,IR_Data_Of;

    /* ---------- 时钟 ---------- */
    always #5 clk_cal = ~clk_cal;   // 100 MHz

    /* ---------- DUT ---------- */
    input_reg_0703 dut (
        .clk_cal(clk_cal), .rst_cal_n(rst_cal_n),
        .nn_layer_cnt(nn_layer_cnt),
        .K(K), .S(S),
        .Weight_Data_Ovld(Weight_Data_Ovld),
        .pe_end(pe_end),
        .IR_Data_I0(IR_Data_I0), .IR_Data_I1(IR_Data_I1),
        .IR_Data_I2(IR_Data_I2), .IR_Data_I3(IR_Data_I3),
        .IR_Data_I4(IR_Data_I4), .IR_Data_I5(IR_Data_I5),
        .IR_Data_I6(IR_Data_I6), .IR_Data_I7(IR_Data_I7),
        .IR_Data_I_vld(IR_Data_I_vld),
        .Bm_cnt_in(Bm_cnt_in), .kh_cnt_in(kh_cnt_in),
        .IR_Data_O_vld(IR_Data_O_vld),
        .IR_Data_O0(IR_Data_O0), .IR_Data_O1(IR_Data_O1),
        .IR_Data_O2(IR_Data_O2), .IR_Data_O3(IR_Data_O3),
        .IR_Data_O4(IR_Data_O4), .IR_Data_O5(IR_Data_O5),
        .IR_Data_O6(IR_Data_O6), .IR_Data_O7(IR_Data_O7),
        .IR_Data_O8(IR_Data_O8), .IR_Data_O9(IR_Data_O9),
        .IR_Data_Oa(IR_Data_Oa), .IR_Data_Ob(IR_Data_Ob),
        .IR_Data_Oc(IR_Data_Oc), .IR_Data_Od(IR_Data_Od),
        .IR_Data_Oe(IR_Data_Oe), .IR_Data_Of(IR_Data_Of)
    );

    /* ---------- 任务：写一个 8-Byte 列块 ---------- */
    task write_block;
        input [5:0] bm;
        begin
            @(posedge clk_cal);
            Bm_cnt_in     <= bm;
            IR_Data_I_vld <= 1;
            IR_Data_I0 <= $random; IR_Data_I1 <= $random;
            IR_Data_I2 <= $random; IR_Data_I3 <= $random;
            IR_Data_I4 <= $random; IR_Data_I5 <= $random;
            IR_Data_I6 <= $random; IR_Data_I7 <= $random;
            @(posedge clk_cal);
            IR_Data_I_vld <= 0;
        end
    endtask

    /* ---------- 任务：送一拍权重 ---------- */
    task send_weight;
        begin
            @(posedge clk_cal);
            Weight_Data_Ovld <= 1;
            @(posedge clk_cal);
            Weight_Data_Ovld <= 0;
        end
    endtask
integer w;
    /* ---------- 主激励 ---------- */
    initial begin
    
        /* dump */
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_input_regfile);

        /* 复位 */
        #1  rst_cal_n = 0;
        #10 rst_cal_n = 1;

        /* 三行 × 5 列块 = Hu_w 33，Hu 99 */
        repeat (3) begin : rows
            integer col;
            for (col=0; col<5; col=col+1) begin
                write_block(col[5:0]);
            end
            kh_cnt_in = kh_cnt_in + 1;
        end

        /* 送权重脉冲 × 99（读窗口）*/
        
        for (w=0; w<99; w=w+1) begin
            send_weight();
            @(posedge clk_cal);     // 模拟 PE 反馈
            pe_end <= 1;
           wait(20);
            pe_end <= 0;
        end

        /* 结束 */
        #100 $finish;
    end

    /* ---------- 简单断言 ---------- */
    always @(posedge clk_cal) if (IR_Data_O_vld) begin
        if (^{
            IR_Data_O0,IR_Data_O1,IR_Data_O2,IR_Data_O3,
            IR_Data_O4,IR_Data_O5,IR_Data_O6,IR_Data_O7,
            IR_Data_O8,IR_Data_O9,IR_Data_Oa,IR_Data_Ob,
            IR_Data_Oc,IR_Data_Od,IR_Data_Oe,IR_Data_Of
        } === 1'bX)
            $error("读到 X 数据，行缓存可能覆盖出错！");
    end

endmodule
