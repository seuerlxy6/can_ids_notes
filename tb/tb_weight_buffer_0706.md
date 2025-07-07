`//---------------------------------------------------------------------`
`// tb_weight_buffer0704.v`
`//---------------------------------------------------------------------`
`timescale 1ns/1ps`
`module tb_weight_buffer;`

    `//-----------------------------------------------------------------`
    `// 1. 时钟 / 复位`
    `//-----------------------------------------------------------------`
    `reg clk = 0;`
    `always #5 clk = ~clk;               // 100 MHz`

    `reg rst_n = 0;`
    `initial begin`
        `#30 rst_n = 1;                  // 30 ns 解除复位`
    `end`

    `//-----------------------------------------------------------------`
    `// 2. DUT 端口连线`
    `//-----------------------------------------------------------------`
    `// layer-index 信号在本例用不到，置 0`
    `reg  [3:0] layer2weight_cnt = 4'd0;`

    `// 写口拉 0（只读 ROM）`
    `reg  [12:0] wt_I_addr = 13'd0;`

    `// 读地址 & vld 数组`
    `reg  [12:0] wt_C_addr [0:7];`
    `reg         wt_C_vld  [0:7];`

    `wire        wt_Ovld  [0:7];`
    `wire [7:0]  kernel_C [0:7];`

    `// DUT 实例`
    `Weight_buffer0704 dut (`
        `.clk_cal(clk),`
        `.rst_cal_n(rst_n),`
        `.layer2weight_cnt(layer2weight_cnt),`

        `.wt_I_addr(wt_I_addr),          // wea 在 IP 内部恒 0`
        `//input`
        `.wt_C0_addr (wt_C_addr[0]), .wt_C1_addr (wt_C_addr[1]),`
        `.wt_C2_addr (wt_C_addr[2]), .wt_C3_addr (wt_C_addr[3]),`
        `.wt_C4_addr (wt_C_addr[4]), .wt_C5_addr (wt_C_addr[5]),`
        `.wt_C6_addr (wt_C_addr[6]), .wt_C7_addr (wt_C_addr[7]),`
        `//input`
        `.wt_C0_O_vld(wt_C_vld[0]), .wt_C1_O_vld(wt_C_vld[1]),`
        `.wt_C2_O_vld(wt_C_vld[2]), .wt_C3_O_vld(wt_C_vld[3]),`
        `.wt_C4_O_vld(wt_C_vld[4]), .wt_C5_O_vld(wt_C_vld[5]),`
        `.wt_C6_O_vld(wt_C_vld[6]), .wt_C7_O_vld(wt_C_vld[7]),`
        `//out`
        `.wt_Ovld0(wt_Ovld[0]), .wt_Ovld1(wt_Ovld[1]),`
        `.wt_Ovld2(wt_Ovld[2]), .wt_Ovld3(wt_Ovld[3]),`
        `.wt_Ovld4(wt_Ovld[4]), .wt_Ovld5(wt_Ovld[5]),`
        `.wt_Ovld6(wt_Ovld[6]), .wt_Ovld7(wt_Ovld[7]),`

        `.kernel_C0_O(kernel_C[0]), .kernel_C1_O(kernel_C[1]),`
        `.kernel_C2_O(kernel_C[2]), .kernel_C3_O(kernel_C[3]),`
        `.kernel_C4_O(kernel_C[4]), .kernel_C5_O(kernel_C[5]),`
        `.kernel_C6_O(kernel_C[6]), .kernel_C7_O(kernel_C[7])`
    `);`

`/* ============================================================================`
 * `4. 读端激励 -- 8 列"脉冲"流水`
 * `==========================================================================*/`
`integer i;`

`/* ① 初值 */`
`initial begin`
    `for(i=0;i<8;i=i+1) begin`
        `wt_C_addr[i] = 13'd0;`
        `wt_C_vld [i] = 1'b0;`
    `end`
`end`

`/* ② 等复位释放，再发 1 个基准脉冲 */`
`initial begin`
    `@(posedge rst_n);`
    `repeat(4) @(posedge clk);`

    `wt_C_vld[0] <= 1'b1;           // 列0 第 1 拍`
    `@(posedge clk);`
    `wt_C_vld[0] <= 1'b0;           // 只保持 1 cycle`
`end`

`/* ③ 用 8 位 shift-register 形成流水  */`
`reg [7:0] vld_shift;`
`always @(posedge clk or negedge rst_n) begin`
    `if(!rst_n)`
        `vld_shift <= 8'b0;`
    `else`
        `vld_shift <= {vld_shift[6:0], wt_C_vld[0]};   // 右移注入列0脉冲`
`end`

`/* ④ 组合赋值给各列 vld */`
`always @(*) begin`
    `wt_C_vld[0] = vld_shift[0];`
    `wt_C_vld[1] = vld_shift[1];`
    `wt_C_vld[2] = vld_shift[2];`
    `wt_C_vld[3] = vld_shift[3];`
    `wt_C_vld[4] = vld_shift[4];`
    `wt_C_vld[5] = vld_shift[5];`
    `wt_C_vld[6] = vld_shift[6];`
    `wt_C_vld[7] = vld_shift[7];`
`end`

`/* ⑤ 地址在"本列 vld=1"时自增 */`
`always @(posedge clk) begin`
    `for(i=0;i<8;i=i+1)`
        `if (wt_C_vld[i])`
            `wt_C_addr[i] <= wt_C_addr[i] + 1;`
`end`

    `//-----------------------------------------------------------------`
    `// 4. Dump 波形`
    `//-----------------------------------------------------------------`
    `initial begin`
        `$dumpfile("tb_weight_buffer.vcd");`
        `$dumpvars(0, tb_weight_buffer);`
    `end`

    `//-----------------------------------------------------------------`
    `// 5. 仿真结束控制：读够 40 行后结束`
    `//-----------------------------------------------------------------`
    `integer cycle_cnt = 0;`
    `always @(posedge clk)`
        `if(rst_n) begin`
            `cycle_cnt = cycle_cnt + 1;`
            `if(cycle_cnt == 600)  // 自行调整`
                `$finish;`
        `end`

endmodule
