`timescale 1ns / 1ps`
`//////////////////////////////////////////////////////////////////////////////////`
`// Company:` 
`// Engineer:` 
`//` 
`// Create Date: 2025/06/29 22:46:27`
`// Design Name:` 
`// Module Name: tb_mem_ctrl_629`
`// Project Name:` 
`// Target Devices:` 
`// Tool Versions:` 
`// Description:` 
`//` 
`// Dependencies:` 
`//` 
`// Revision:`
`// Revision 0.01 - File Created`
`// Additional Comments:`
`//` 
`//////////////////////////////////////////////////////////////////////////////////`


`//********************************************************************************`
`// tb_imap_mem_ctrl.v  -  Verilog-2001 testbench for imap_mem_ctrl`
`//   · 两层卷积完整流：预加载 CAN → 取层参数 → 读权重 → 计算 → 写输出`
`//   · 时钟 100 MHz（10 ns），复位 5 个周期`
`//   · 仅验证前两层 CNN；全连接层暂不驱动`
`//********************************************************************************`
`timescale 1ns/1ps`

`module tb_mem_ctrl_629;`

`// ------------------------------------------------------------------ 时钟 / 复位`
`localparam CLK_PERIOD = 10;       // 10 ns → 100 MHz`
`reg clk_cal;`
`reg rst_cal_n;`

`initial  clk_cal = 0;`
`always  #(CLK_PERIOD/2) clk_cal = ~clk_cal;`

`initial begin`
    `rst_cal_n = 0;`
    `#(CLK_PERIOD*5);`
    `rst_cal_n = 1;`
`end`

`// ------------------------------------------------------------------ DUT 端口`
`reg  [7:0]  mc_cs, mc_ns;`
`reg  [5:0]  or_cs, or_ns;`
`reg  [3:0]  nn_layer_cnt;`
`reg  [11:0] can_len;`

`wire        memct_init_cmplt;`
`reg         pe_end, Data_I_vld, Data_I_vld_CAN;`
`wire        rd_done, Data_O_vld, lyr_cal_done, ft_can_done;`
`wire        wt_I_vld;`

`wire [12:0] rd_addr, wr_addr, wt_I_addr;`
`wire [12:0] wt_C0_addr, wt_C1_addr, wt_C2_addr, wt_C3_addr,`
            `wt_C4_addr, wt_C5_addr, wt_C6_addr, wt_C7_addr;`

`mem_ctrl_629 dut (`
    `.clk_cal(clk_cal), .rst_cal_n(rst_cal_n),`
    `.mc_cs(mc_cs), .mc_ns(mc_ns),`
    `.or_cs(or_cs), .or_ns(or_ns),`
    `.nn_layer_cnt(nn_layer_cnt),`
    `.memct_init_cmplt(memct_init_cmplt),`

    `.can_len(can_len),`
    `.pe_end(pe_end), .rd_done(rd_done),`
    `.rd_addr(rd_addr), .Data_O_vld(Data_O_vld),`
    `.Data_I_vld(Data_I_vld), .Data_I_vld_CAN(Data_I_vld_CAN),`
    `.wr_addr(wr_addr),`

    `.wt_I_vld(wt_I_vld), .wt_I_addr(wt_I_addr),`
    `.wt_C0_addr(wt_C0_addr), .wt_C1_addr(wt_C1_addr),`
    `.wt_C2_addr(wt_C2_addr), .wt_C3_addr(wt_C3_addr),`
    `.wt_C4_addr(wt_C4_addr), .wt_C5_addr(wt_C5_addr),`
    `.wt_C6_addr(wt_C6_addr), .wt_C7_addr(wt_C7_addr),`

    `.ft_lyr_param_done(), .ft_can_done(ft_can_done),`
    `.ft_wt_done(), .lyr_cal_done(lyr_cal_done)`
`);`

`// ------------------------------------------------------------------ 工具任务`
`task wait_cycles(input integer n);   begin repeat(n) @(posedge clk_cal); end endtask`

`// 生成 pe_end / Data_I_vld` 
`task run_calculation(input integer cycles);`
    `integer i;`
    `begin`
        `for (i = 0; i < cycles; i = i + 1) begin`
            `// 模拟PE每隔15个周期完成一次计算`
            `if (i % 15 == 0) begin`
                `pe_end = 1'b1;`
            `end else begin`
                `pe_end = 1'b0;`
            `end`
            
            `// 模拟R&P单元每隔20个周期写回一次数据`
            `if (i % 200 == 0) begin`
                `Data_I_vld = 1'b1;`
            `end else begin`
                `Data_I_vld = 1'b0;`
            `end`
            `wait_cycles(1);`
        `end`
        `pe_end = 1'b0;`
        `Data_I_vld = 1'b0;`
    `end`
`endtask`

`// CAN 预加载：简单地打满 can_len 字节`
`task preload_can;`
    `integer i;`
    `begin`
        `mc_cs = 8'd3; mc_ns = 8'd3;                // FT_ECG`
        `for(i=0;i<((can_len+7)>>3); i=i+1) begin`
            `Data_I_vld_CAN = 1; wait_cycles(1);`
            `Data_I_vld_CAN = 0; wait_cycles(1);`
        `end`
        `wait(ft_can_done);                         // 等待标志脉冲`
    `end`
`endtask`

`// ------------------------------------------------------------------ 主测试流程`
`initial begin`
    `// 默认值`
    `mc_cs=0; mc_ns=0; or_cs=0; or_ns=0;`
    `nn_layer_cnt=0; can_len = 12'd3600;`
    `pe_end=0; Data_I_vld=0; Data_I_vld_CAN=0;`

    `wait(memct_init_cmplt);           // 等硬复位完`
    `$display("TB-START @ %0t", $time);`

    `// ────────────── Layer-1 ──────────────`
    `// ① 先保持状态在 FT_ECG`
    `mc_cs = 8'd3;  mc_ns = 8'd3;`
    `nn_layer_cnt = 1;      // 第 1 层`
    `can_len       = 12'd3600;   // e10h  = 3600 B`
    
    `// ② 连续打 450 个 Data_I_vld_CAN 脉冲`
    `repeat(450) begin`
        `Data_I_vld_CAN = 1'b1;      // 1 个 8-byte beat`
        `wait_cycles(1);             // 1 个时钟即可`
        `Data_I_vld_CAN = 1'b0;`
        `wait_cycles(1);             // 隔 1 拍，不冲突就行`
    `end`
    
    `// ③ 等 DUT 发完 ft_can_done 脉冲`
    `wait( ft_can_done);`
    `$display("CAN preload done @ %t", $time);`


    `// ② 获取层参数（ft_lyr_param_done 由 DUT 自生）`
    `mc_cs = 8'd3; mc_ns = 8'd4; wait_cycles(1);       // FT_ECG → FT_PARAM`
    `mc_cs = 8'd4; mc_ns = 8'd4;                       // 停留 1 周期`

    `// ③ 取权重`
    `mc_cs = 8'd4; mc_ns = 8'd5;  wait_cycles(1);                     // FT_PARAM → CONV_CAL`
    `mc_cs = 8'd5; mc_ns = 8'd5;` 
    `or_cs = 0;  or_ns = 1;      wait_cycles(1);       // OR_IDLE → OR_FT_WT`
    `or_cs = 1;  or_ns = 1;                            // 等 ft_wt_done 内部拉高`
    `wait(dut.ft_wt_done);  $display("L1 weight loaded @ %0t", $time);`

    `// ④ 计算`
    
    `or_cs = 1;  or_ns = 2;      wait_cycles(1);       // → OR_CAL`
    `or_cs = 2;  or_ns = 2;`
    `run_calculation(10000000);                            // 1000 clk dummy calc`
    `wait(lyr_cal_done);          $display("L1 done @ %0t", $time);`

    `// ────────────── Layer-2 ──────────────`
    `nn_layer_cnt = 2;`
    `mc_cs = 8'd6; mc_ns = 8'd4;   wait_cycles(1);     // LY_DONE → FT_PARAM`
    `mc_cs = 8'd4; mc_ns = 8'd4;                       // 获取参数`

    `mc_cs = 8'd4; mc_ns = 8'd5;                       // → CONV_CAL`
    `or_cs = 0;  or_ns = 1;       wait_cycles(1);      // 取权重`
    `or_cs = 1;  or_ns = 1;`
    `wait(dut.ft_wt_done);`
    `or_cs = 1;  or_ns = 2;       wait_cycles(1);      // 计算`
    `or_cs = 2;  or_ns = 2;`
    `run_calculation(20000);`
    `wait(lyr_cal_done);          $display("L2 done @ %0t", $time);`

    `// 结束`
    `$display("TB-FINISH @ %0t", $time);`
    `wait_cycles(10);`
    `$finish;`
`end`

`// ------------------------------------------------------------------ 监控`
`initial begin`
    `$monitor("%0t | mc:%0d or:%0d Lyr:%0d rd_addr:%h wr_addr:%h wt_addr:%h vld:%b",`
             `$time, mc_cs, or_cs, nn_layer_cnt,`
             `rd_addr, wr_addr, wt_I_addr, Data_O_vld);`
`end`

`endmodule`

