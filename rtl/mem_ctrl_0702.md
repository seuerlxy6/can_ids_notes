`timescale 1ns / 1ps`
`//////////////////////////////////////////////////////////////////////////////////`
`// Company:` 
`// Engineer:` 
`//` 
`// Create Date: 2025/06/29 22:26:45`
`// Design Name:` 
`// Module Name: mem_ctrl_629`
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

`timescale 1ns/1ps`
`define Bm 8`
`define R  16`
`define	 C	8`
`define DDR_DW 64`
`define DDR_AW 32`

`module mem_ctrl_629(`
    `input               clk_cal,`
    `input               rst_cal_n,`

    `// 状态机`
    `input  [7:0]        mc_cs, mc_ns,`
    `input  [5:0]        or_cs, or_ns,`

    `input  [3:0]        nn_layer_cnt,`
    `output reg          memct_init_cmplt,`

    `input  [11:0]       can_len,`

    `// 与 PE`
    `input               pe_end,`
    `output reg          rd_done,`
    `output		[10:0]		cal_cycle,`				
	`output		[10:0]		pass_cycle,`				
    `// InOutBuffer & WeightBuffer`
    `output reg [13:0]   rd_addr,`
    `output reg          Data_O_vld,` 
    
    `input               Data_I_vld,`
    `input               Data_I_vld_CAN,`
    `output     [13:0]   wr_addr,`
    
    
    `output reg          wt_I_vld,`
    `output reg [12:0]   wt_I_addr,`
    `output reg [12:0]   wt_C0_addr, wt_C1_addr, wt_C2_addr, wt_C3_addr,`
                        `wt_C4_addr, wt_C5_addr, wt_C6_addr, wt_C7_addr,`
    `output reg          wt_C0_O_vld, wt_C1_O_vld, wt_C2_O_vld, wt_C3_O_vld,`
                        `wt_C4_O_vld, wt_C5_O_vld, wt_C6_O_vld, wt_C7_O_vld,`

    `// MCU 通知`
    `output reg          ft_lyr_param_done,`
    `output reg          ft_can_done,`
    `output              ft_wt_done,`
    `output              lyr_cal_done`
`);`


`// ───────────────────── 固定状态码 ─────────────────────`

	`localparam	[7:0]		IDLE		= 8'd0;`
	`localparam	[7:0]		FT_ADDR		= 8'd1;`
	`localparam	[7:0]		ECG_UD		= 8'd2;`
	`localparam	[7:0]		FT_ECG		= 8'd3;`
	`localparam	[7:0]		FT_PARAM	= 8'd4;`
	`localparam	[7:0]		CONV_CAL	= 8'd5;`
	`localparam	[7:0]		LY_DONE		= 8'd6;`
	`localparam	[7:0]		INF_DONE	= 8'd7;`
	
	
	`//---------------------------------STATE OF CALCULATION----------------------------`
	`//CALCULATION CONTROL STATE DECLARATIONS`
	`//---------------------------------------------------------------------------------`

	`localparam	[5:0]		OR_IDLE		= 6'd0;`
	`localparam	[5:0]		OR_FT_WT	= 6'd1;`
	`localparam	[5:0]		OR_CAL		= 6'd2;`
	`localparam	[5:0]		OR_DONE		= 6'd3;`

`// ───────────────────── 层尺寸 (两层 CNN) ───────────────`
    `parameter K=9, K_H=3, K_W=3, S_H=2, S_W=2;`
    `wire	[9:0]	    Hu_w = (nn_layer_cnt==1)? 10'd33:(nn_layer_cnt==2)?10'd33:0;`
    `wire    [14:0]     IN = (nn_layer_cnt==1)? 15'd4096:(nn_layer_cnt==2)?15'd1024:0;`
    `wire    [7:0]      IN_w = (nn_layer_cnt==1)? 15'd64:(nn_layer_cnt==2)?15'd32:0;`
    `wire    [7:0]      IN_h = (nn_layer_cnt==1)? 15'd64:(nn_layer_cnt==2)?15'd32:0;`
    `wire	[7:0]		N = (nn_layer_cnt==1)? 7'd8:(nn_layer_cnt==2)?7'd32:0;`
    `wire	[7:0]		M = (nn_layer_cnt==1)? 7'd3:(nn_layer_cnt==2)?7'd8:0;`
    `wire	[11:0]		OUT = (nn_layer_cnt==1) ? 11'd1024 : (nn_layer_cnt==2) ? 11'd216 : 7'd0;`
    `wire	[7:0]		OUT_w = (nn_layer_cnt==1) ? 7'd32 : (nn_layer_cnt==2) ? 7'd16 : 7'd0;`
    `wire	[7:0]		OUT_h = (nn_layer_cnt==1) ? 7'd32 : (nn_layer_cnt==2) ? 7'd16 : 7'd0;`

`//==============================================================================================================================`
`// III. 内部信号声明 (Internal Signal Declarations)`
`//==============================================================================================================================`
			`reg					rd_lyr_done;				// The completion signal of read all input maps in this layer`
			`reg					wr_lyr_done;				// The completion signal of write all output maps in this layer` 
		`// Signals of writing layer1 input map in In_Out_Buffer`
			`wire	[8:0]		ft_can_times;`
			`reg		[12:0]		ft_can_cnt;`
			`wire	[12:0]		ft_can_cnt_nxt;`
			
		`// Signals of writing layer2-layer6 output map in In_Out_Buffer`
								
			`wire	[9:0]		omap_addr_span;				// address span of one output map`
			`wire    [9:0]      omap_addr_span_w;`
			`wire    [9:0]      omap_addr_span_h;`
            `reg		[6:0]		N_cnt;`	 
            `reg     [11:0]      ox_cnt;`
            `reg     [11:0]      oy_cnt;` 
            `wire n_write_loop_done, x_write_loop_done;`
            
			`wire	[12:0]		wr_addr_nxt;`
			`wire				wr_lyr_done_w;`

		
		`//Signals of reading layer1-layer6 input map from In_Out_Buffer`
		    `// --- 计数器声明 ---`
            `reg     [5:0]       Bm_cnt;       // 循环6 (最内层): 行内数据块计数器_bmtimes`
            `reg     [7:0]       kh_cnt;       // 循环5: 卷积核行计数器_kh`
            `reg     [6:0]       M_cnt;        // 循环4: 输入通道计数器_m`
            `reg     [3:0]       ft_N_cnt;     // 循环3: 输出通道Tile计数器_ntile`
            `reg     [11:0]      cal_cnt_x;    // 循环2: 输出列滑动计数器_caltimesw`
            `reg     [11:0]      cal_cnt_y;    // 循环1 (最外层): 输出行滑动计数器_outh`
            `// --- 计数器顶点 ---`
    		
	        `wire	[7:0]		cal_times_w;					// calculation times of one map`
	        `wire	[3:0]		N_tiles;					// fetch times of one input map`
	        `wire	[5:0]		Bm_times;					// transmission cycle per calculation`
			`//地址计算`
			`wire	[13:0]		imap_addr_span;`				
	        `wire	[13:0]		imap_addr_span_w;`	
			`wire	[12:0]		rd_addr_nxt;`
			
			`// --- 权重地址生成相关 ---`
	        `wire	[12:0]		wt_C0_addr_nxt;`
	        
	        `reg		[8:0]		K_cnt;`
	        `reg		[6:0]		wt_M_cnt;`
	        `reg		[3:0]		wt_N_cnt;`
	        
	        `reg				    rd_done_temp;`
	        
	        `wire    [12:0]      wt_addr_base;`
`//==============================================================================================================================`
`// III. 顶层 Done 信号` 
`//==============================================================================================================================`
`// ───────────────────── ──────────────────`
    `always @(posedge clk_cal or negedge rst_cal_n)`
    		`if(!rst_cal_n)`
    			`memct_init_cmplt <= 1'b0;`
    		`else`
    			`memct_init_cmplt <= 1'b1;`

    `// 当前层计算完成信号`
	`assign lyr_cal_done = (or_cs == OR_CAL && wr_lyr_done && rd_lyr_done) ? 1'b1 : 1'b0;`

	`// 层参数获取完成信号（在此版本中为伪操作）`
	`always @(posedge clk_cal or negedge rst_cal_n)`
		`if(!rst_cal_n) ft_lyr_param_done <= 1'b0;`
		`else if((mc_cs == FT_ECG && mc_ns == FT_PARAM) || (mc_cs == LY_DONE && mc_ns == FT_PARAM))`
			`ft_lyr_param_done <= 1'b1;`
		`else ft_lyr_param_done <= 1'b0;`
    `// --- 性能周期计算 ---`
    	`assign	cal_cycle = K*M;`
    	`assign	pass_cycle = (nn_layer_cnt==1||nn_layer_cnt==2)?((wt_M_cnt==M)?(`C + K - Bm_times):(K)):(`R + `C + K - 1-2);`
`//==============================================================================================================================`
`// III. layer1 imap_read`
`//==============================================================================================================================`
    `assign	ft_can_times = (can_len[2:0]==3'b0) ? (can_len >> 3) : ((can_len >> 3) + 1);`
    `always @(posedge clk_cal or negedge rst_cal_n)`          
		`if(!rst_cal_n)`                                     
			`ft_can_cnt <= 13'b0;`                            
		`else if(Data_I_vld_CAN && (mc_cs == FT_ECG))`           
			`ft_can_cnt <= ft_can_cnt_nxt;`                  
		`else`                                              
			`ft_can_cnt <= ft_can_cnt;`                     
	
	`// ft_ecg_cnt_nxt: 组合逻辑，计算ft_ecg_cnt的下一个值。`
	`assign ft_can_cnt_nxt = (ft_can_cnt == ft_can_times - 1'b1) ? 8'b0 : ft_can_cnt + 1'b1;` 
	
	`// ft_ecg_done: 初始ECG数据加载完成标志的生成逻辑。`
	`always @(posedge clk_cal or negedge rst_cal_n)`          
		`if(!rst_cal_n)`                                     
			`ft_can_done <= 1'b0;`                           
		`else if(ft_can_cnt == ft_can_times - 1'b1)`          
			`ft_can_done <= 1'b1;`                           
		`else`                                               
			`ft_can_done <= 1'b0;`        
`//==============================================================================================================================`
`// layer2-4 输出数据写入控制` 
`//------------------------------------------------------------------------------------------------------------------------------`
`//==============================================================================================================================`
`//写数据流 ("omap") - 三层嵌套循环控制`
`//==============================================================================================================================`

    `assign	omap_addr_span = (OUT[2:0]==3'b0) ? (OUT>>3) : ((OUT>>3)+1'b1);`
    
    `assign	omap_addr_span_w = (OUT_w[2:0]==3'b0) ? (OUT_w>>3) : ((OUT_w>>3)+1'b1);//`
    
    `assign	omap_addr_span_h = (OUT_h[2:0]==3'b0) ? (OUT_h>>3) : ((OUT_h>>3)+1'b1);`

    `always @(posedge clk_cal or negedge rst_cal_n) // 循环3: N_cnt`
        `if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL))` 
            `N_cnt <= 0;`
        `else if(Data_I_vld && (or_cs==OR_CAL))` 
            `N_cnt <= (N_cnt == N) ? 1 : N_cnt + 1;`
                
    `assign n_write_loop_done = (N_cnt == N) && Data_I_vld && (or_cs==OR_CAL);`

    `always @(posedge clk_cal or negedge rst_cal_n) // 循环2: ox_cnt`
        `if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL))` 
            `ox_cnt <= 0;`
        `else if(N_cnt==N && Data_I_vld && !wr_lyr_done)` 
            `ox_cnt <= (ox_cnt == omap_addr_span_w - 1) ? 0 : ox_cnt + 1;`
        
    `assign x_write_loop_done = (ox_cnt == omap_addr_span_w - 1) && n_write_loop_done;`

    `always @(posedge clk_cal or negedge rst_cal_n) // 循环1: oy_cnt`
        `if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL))` 
            `oy_cnt <= 0;`
        `else if(N_cnt==N && Data_I_vld && !wr_lyr_done&&(ox_cnt == omap_addr_span_w - 1))` 
            `oy_cnt <= oy_cnt + 1;` 
            
            
    `assign wr_lyr_done_w = (oy_cnt == OUT_h - 1) && x_write_loop_done;`
    `// 使用一级流水线寄存器来延迟 wr_lyr_done_w，生成稳定的 wr_lyr_done 信号。`
	`reg			wr_lyr_done_1;                                                          // 流水线寄存器。`
	`always @(posedge clk_cal or negedge rst_cal_n)                                      // 时钟上升沿或复位下降沿触发。`
		`if(!rst_cal_n)                                                                 // 异步复位逻辑：`
			`begin                                                                      //`
				`wr_lyr_done <= 1'b0;                                                   // 写完成标志清零。`
				`wr_lyr_done_1 <= 1'b0;                                                 // 流水线寄存器清零。`
			`end                                                                        //`
		`else                                                                           // 同步逻辑：`
			`begin                                                                      //`
				`wr_lyr_done <= wr_lyr_done_1;                                          // 将上一周期的状态赋给最终的写完成标志。`
				`wr_lyr_done_1 <= wr_lyr_done_w;                                        // 锁存当前周期的完成状态。`
			`end                                                                        //`
   
    `assign	wr_addr = (mc_cs==FT_ECG) ? ft_can_cnt :                                      // 如果处于"获取ECG"状态，写地址由ECG数据计数器决定。`
						`(Data_I_vld)  ? ((N_cnt-1)*omap_addr_span + oy_cnt * omap_addr_span_w + ox_cnt) :` 
						`(!rst_cal_n||wr_lyr_done)  ? 0 :// 如果有有效数据写入，地址由"通道基址"+"通道内偏移"构成。`
						`wr_addr;                                                             // 其他情况地址为0。`
`//    always @(posedge clk_cal or negedge rst_cal_n) // 写地址生成`
`//        if(!rst_cal_n)` 
`//            wr_addr <= 0;`
`//        else if (mc_cs == FT_ECG)` 
`//            wr_addr <= ft_can_cnt; // 初始加载`
`//        else if(Data_I_vld && (or_cs == OR_CAL))`
`//            wr_addr <= (N_cnt-1)*omap_addr_span + oy_cnt * omap_addr_span_w + ox_cnt;`
`// ───────────────────── 读数据六层循环 ──────────────────`
`//==============================================================================================================================`
`// II. 读数据流 ("imap") - 六层嵌套循环控制`
`//==============================================================================================================================`
`//    // --- 计数器声明 ---`
`//    reg [5:0]  Bm_cnt;       // 循环6 (最内层): 行内数据块计数器_bmtimes`
`//    reg [7:0]  kh_cnt;       // 循环5: 卷积核行计数器_kh`
`//    reg [6:0]  M_cnt;        // 循环4: 输入通道计数器_m`
`//    reg [3:0]  ft_N_cnt;     // 循环3: 输出通道Tile计数器_ntile`
`//    reg [11:0] cal_cnt_x;    // 循环2: 输出列滑动计数器_caltimesw`
`//    reg [11:0] cal_cnt_y;    // 循环1 (最外层): 输出行滑动计数器_outh`
`//    // --- 计数器顶点 ---`
    		

`//	wire	[7:0]		cal_times_w;					// calculation times of one map`
`//	wire	[3:0]		N_tiles;					// fetch times of one input map`
`//	wire	[5:0]		Bm_times;					// transmission cycle per calculation`
    `// 读取一行Hu_w数据需要的次数--Bm_cnt`
    `assign Bm_times = (Hu_w[2:0]==3'b0) ? (Hu_w>>3) : ((Hu_w>>3)+1'b1);// ceil(33/8) = 5`
    `// 卷积核高度--kh_cnt`
    `//imap张数--M_cnt`
    `// 输出通道的tile数--ft_N_cnt`
    `assign N_tiles = (N[2:0]==3'b0) ? (N>>3) : ((N>>3)+1'b1);// ceil(8/8) = 1`
    `// 窗口横向滑动次数--cal_cnt_x`
    `assign	cal_times_w = (nn_layer_cnt >  2) ? 10'd1 :                                   // 对于全连接层，计算次数为1。`
	                    `(nn_layer_cnt <= 2 && (OUT_w[3:0]==4'b0)) ? OUT_w[7:4] : // 对于卷积层，如果卷积后输出尺寸是16的整数倍。`
	                    `OUT_w[7:4] + 1;                                        // 否则，需要加1（向上取整）。`
	 `// 窗口纵向滑动次数--cal_cnt_y--out_w`     
    `// --- 循环完成信号 ---`
    `wire bm_loop_done, kh_loop_done, m_loop_done, n_loop_done, x_loop_done, y_loop_done;`

    `// 循环6: Bm_cnt (由 pe_end 驱动)`
    `always @(posedge clk_cal or negedge rst_cal_n)`
       `if(!rst_cal_n)`                                                               
			`Bm_cnt <= 0;`                                                        
		`else if(or_cs==OR_FT_WT && or_ns==OR_CAL)`                                      
			`Bm_cnt <= 0;`                                                           
		`else if((rd_lyr_done && pe_end))`                                                           
			`Bm_cnt <= 0;`  
        `else if (pe_end && (or_cs==OR_CAL))` 
            `Bm_cnt <= (Bm_cnt == Bm_times - 1) ? 0 : Bm_cnt + 1;`
        `else` 
            `Bm_cnt <= Bm_cnt;`
        
    `assign bm_loop_done = ( Bm_cnt == Bm_times - 1 ) && pe_end && (or_cs==OR_CAL);//新增-lxy-组合逻辑不能太长，`
    `// 把 loop_done 锁存，确保与 pe_end 对齐`
    `reg bm_done_r;`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if (!rst_cal_n)`
            `bm_done_r <= 1'b0;`
        `else if(bm_loop_done)`
            `bm_done_r <= bm_loop_done;`
        `else if(pe_end)`
            `bm_done_r <= 0;`
    `// 循环5: kh_cnt` 
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL) || (rd_lyr_done&&pe_end))` 
            `kh_cnt <= 0;`
`//        else if ((Bm_cnt == Bm_times - 1) && pe_end)` 
        `else if (bm_done_r && pe_end)` 
            `kh_cnt <= (kh_cnt == K_H - 1) ? 0 : kh_cnt + 1;`
        `else` 
            `kh_cnt <= kh_cnt;`
            
    `assign kh_loop_done = (kh_cnt == K_H - 1) && bm_loop_done ;// one hu read done` 
    `reg kh_done_r;`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if (!rst_cal_n)`
            `kh_done_r <= 1'b0;`
        `else if(bm_loop_done)`
            `kh_done_r <= kh_loop_done;`
        `else if(pe_end)`
            `kh_done_r <= 0;`
    `// 循环4: M_cnt` 
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL) || (rd_lyr_done&&pe_end))` 
            `M_cnt <= 1;`
        `else if (kh_done_r && pe_end)` 
            `M_cnt <= (M_cnt == M) ? 1 : M_cnt + 1;`
        `else` 
            `M_cnt <= M_cnt;`
            
    `assign m_loop_done = (M_cnt == M) && kh_loop_done;// out begin`
    `reg m_done_r;`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if (!rst_cal_n)`
            `m_done_r <= 1'b0;`
        `else if(bm_loop_done)`
            `m_done_r <= m_loop_done;`
        `else if(pe_end)`
            `m_done_r <= 0;`
    `// 循环3: ft_N_cnt` 
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL) || (rd_lyr_done&&pe_end))` 
            `ft_N_cnt <= 1;`
        `else if (m_done_r&& pe_end)` 
            `ft_N_cnt <= (ft_N_cnt == N_tiles) ? 1 : ft_N_cnt + 1;`
        `else` 
            `ft_N_cnt <= ft_N_cnt;`
            
    `assign n_loop_done = (ft_N_cnt == N_tiles) && m_loop_done;`
    `reg n_done_r;`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if (!rst_cal_n)`
            `n_done_r <= 1'b0;`
        `else if(bm_loop_done)`
            `n_done_r <= n_loop_done;`
        `else if(pe_end)`
            `n_done_r <= 0;`
    `// 循环2: cal_cnt_x` 
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)|| (rd_lyr_done&&pe_end))` 
            `cal_cnt_x <= 0;`
        `else if (n_done_r && pe_end)` 
            `cal_cnt_x <= (cal_cnt_x == cal_times_w - 1) ? 0 : cal_cnt_x + 1;`
        `else` 
            `cal_cnt_x <= cal_cnt_x;`
            
    `assign x_loop_done = (cal_cnt_x == cal_times_w - 1) && n_loop_done;`
    `reg x_done_r;`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if (!rst_cal_n)`
            `x_done_r <= 1'b0;`
        `else if(x_loop_done)`
            `x_done_r <= x_loop_done;`
        `else if(pe_end)`
            `x_done_r <= 0;`
    `// 循环1: cal_cnt_y` 
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)|| (rd_lyr_done&&pe_end))` 
            `cal_cnt_y <= 0;`
        `else if (x_done_r &&pe_end)` 
            `cal_cnt_y <= (cal_cnt_y == OUT_h - 1) ? 0 : cal_cnt_y + 1;`
        `else` 
            `cal_cnt_y <= cal_cnt_y;`
            
    `assign y_loop_done = (cal_cnt_y == OUT_h - 1) && x_loop_done;`


`// --- 读地址生成 (2D) ---行主序存储，相邻列等价于imap相邻行，相邻8列为imap一行`
`//   	wire	[13:0]		imap_addr_span;`				
`//	wire	[13:0]		imap_addr_span_w;`			
    `assign	imap_addr_span = (IN[2:0]==3'b0) ? (IN>>3) : ((IN>>3)+1'b1);//一个imap占几个列`
    `assign	imap_addr_span_w = (IN_w[2:0]==3'b0) ? (IN_w>>3) : ((IN_w>>3)+1'b1);//imap 一行占几个列`
    `// 地址单位是 "列" (8字节)`
`//    wire [15:0] base_addr, v_offset, h_offset;`
`//    assign base_addr = (M_cnt - 1) * (IN / Bm);`
`//    assign v_offset  = (cal_cnt_y * S_H + kh_cnt) * (W_IN / Bm);`
`//    assign h_offset  = (cal_cnt_x * R * S_W / Bm);`
    `assign rd_addr_nxt = (M_cnt-1'b1)*imap_addr_span +        //滑到第几张imap`
                         `cal_cnt_x*S_W*2 +             //窗口横向滑动偏移tile`
                         `//阵列16行，一批hu相当于16个窗口，`
                         `//下一批hu需要滑动16*S个点才能得到下一批hu的第一个窗口，但是有8个bank并行存，所以再除以8`
                         `cal_cnt_y * S_H * imap_addr_span_w + //滑到第几行imap`
                         `kh_cnt * imap_addr_span_w +          //滑到窗口的第几行`
                         `Bm_cnt;`    
    `// rd_done: 单个数据块(Hu)读取完成信号。`
	`always @(posedge clk_cal or negedge rst_cal_n)`                                    
		`if(!rst_cal_n)`                                                               
			`rd_done <= 1'b0;`                                                         
		`else if(pe_end && (Bm_cnt == Bm_times-1)&&(kh_cnt == K_H - 1))`                                  
			`rd_done <= 1'b1;`                                                           
		`else`                                                                          
			`rd_done <= 1'b0;`                             
			                                          
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n)` 
            `rd_addr <= 0;`
        `else if(pe_end && (or_cs == OR_CAL))`
            `rd_addr <= rd_addr_nxt;`
        `else`
            `rd_addr <= rd_addr;`
	`always @(posedge clk_cal or negedge rst_cal_n)`                                    
		`if(!rst_cal_n)`                                                                 
			`rd_lyr_done <= 1'b0;`                                                      
		`else if(lyr_cal_done)`                                                          
			`rd_lyr_done <= 1'b0;`                                                    
		`else if(x_done_r && (cal_cnt_y==OUT_h-1))`           
			`rd_lyr_done <= 1'b1;`                                                     
`//    assign lyr_cal_done =rd_lyr_done;`
     `// --- 读数据有效信号 ---`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n)` 
            `Data_O_vld <= 1'b0;`
        `else` 
            `Data_O_vld <= pe_end && (or_cs == OR_CAL) && !rd_lyr_done;`

`//// ───────────────────── CAN 预加载计数 (简略) ────────────`
`//    wire	[8:0]		ft_can_times;`
`//    reg		[12:0]		ft_can_cnt;`
`//    wire	[12:0]		ft_can_cnt_nxt;`
`//    assign	ft_can_times = (can_len[2:0]==3'b0) ? (can_len >> 3) : ((can_len >> 3) + 1);`

`//	// --- 核心计数器与状态标志逻辑 (Core Counter and Status Flag Logic) ---`

`//	// ft_ecg_cnt: 用于加载初始ECG数据的计数器，其值也直接作为初始写入地址。`
`//	always @(posedge clk_cal or negedge rst_cal_n)`          
`//		if(!rst_cal_n)`                                     
`//			ft_can_cnt <= 13'b0;`                            
`//		else if(Data_I_vld_CAN && (mc_cs == FT_ECG))`           
`//			ft_can_cnt <= ft_can_cnt_nxt;`                  
`//		else if(ft_can_done)`                                             
`//			ft_can_cnt <= 0;`                     
	
`//	// ft_ecg_cnt_nxt: 组合逻辑，计算ft_ecg_cnt的下一个值。`
`//	assign ft_can_cnt_nxt = (ft_can_cnt == ft_can_times - 1'b1) ? 8'b0 : ft_can_cnt + 1'b1;` 
	
`//	// ft_ecg_done: 初始ECG数据加载完成标志的生成逻辑。`
`//	always @(posedge clk_cal or negedge rst_cal_n)`          
`//		if(!rst_cal_n)`                                     
`//			ft_can_done <= 1'b0;`                           
`//		else if(ft_can_cnt == ft_can_times - 1'b1)`          
`//			ft_can_done <= 1'b1;`                           
`//		else`                                               
`//			ft_can_done <= 1'b0;`                              
    
`//// wr_addr（包括 CAN 预写）`
`//wire [9:0] omap_span   = ( (OUT +7)>>3 );`
`//wire [9:0] omap_span_w = (OUT_w+7)>>3;`

`//reg [6:0]  N_cnt;`
`//reg [11:0] ox_cnt, oy_cnt;`
`//always @(posedge clk_cal or negedge rst_cal_n)`
`//    if(!rst_cal_n) wr_addr <= 0;`
`//    else if(mc_cs==FT_ECG) wr_addr <= ft_can_cnt;`
`//    else if(Data_I_vld && or_cs==OR_CAL)`
`//        wr_addr <= (N_cnt-1)*omap_span + oy_cnt*omap_span_w + (ox_cnt/Bm);`

`// ───────────────────── 权重加载 (只留关键) ───────────────`
 `// wt_I_vld: 权重加载有效信号，高电平表示正在向Weight_Buffer中写入权重。`
	`always @(posedge clk_cal or negedge rst_cal_n)`                            
		`if(!rst_cal_n)`                                                         
			`wt_I_vld <= 1'b0;                                                  // 信号无效。`
		`else if(or_cs==IDLE && or_ns==OR_FT_WT && !ft_wt_done)                  // 同步逻辑：当FSM从IDLE切换到取权重状态，且尚未完成时，`
			`wt_I_vld <= 1'b1;                                                  // 启动权重加载。`
		`else if(ft_wt_done)                                                    // 当加载完成时，`
			`wt_I_vld <= 1'b0;                                                  // 停止加载。`
    
    `assign ft_wt_done = (wt_I_addr == ((K*M*N)>>3)-1);`
    
`// wt_I_addr: 权重加载的写地址计数器。`
	`always @(posedge clk_cal or negedge rst_cal_n)                               // 时钟上升沿或复位下降沿触发。`
		`if(!rst_cal_n)                                                         // 异步复位逻辑：`
			`wt_I_addr <= 13'b0;                                                // 地址清零。`
		`else if(wt_I_vld)                                                      // 同步逻辑：如果加载有效，`
			`wt_I_addr <= wt_I_addr + 1'b1;                                     // 地址线性递增。`
		`else                                                                   // 如果加载停止，`
			`wt_I_addr <= 13'b0;                                                // 地址清零，为下一层做准备。`
    
`//=====================================================================`
`// VI-C. 8-列权重读取流水 -- 仅卷积层(两层 CNN)                   <FIX>`
`//=====================================================================`

`// -------- 1) 对齐 rd_done，用来产生权重有效脉冲 -------------------`
	`reg				rd_done_temp;         // rd_done信号的延迟版本，用于时序对齐`

	`// --- 权重有效信号生成 (Weight Valid Signal Generation) ---`

	`// 创建rd_done的一拍延迟，用于同步。`
	`always @(posedge clk_cal)                                                 // 每个时钟上升沿触发。`
		`rd_done_temp <= rd_done;                                              // 将rd_done的值锁存一拍。HU`

`// -------- 2) C0 列权重有效信号 -----------------------------------`
`// wt_C0_O_vld: 送往PE阵列第一列的权重数据有效信号。`
	`always @(posedge clk_cal or negedge rst_cal_n)`                             
		`if(!rst_cal_n)`                                                         
			`wt_C0_O_vld <= 1'b0;`                                               
		`else if(rd_done_temp)`                                                  
			`wt_C0_O_vld <= 1'b1;`                                               
		`else if((!pe_end && (K_cnt>=K)) || !or_cs==OR_CAL)`                     
			`wt_C0_O_vld <= 1'b0;`                                              

    `// -------- 3) 7 级移位寄存器，生成 C1~C7 列有效 -------------------`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n) begin`
            `{wt_C7_O_vld,wt_C6_O_vld,wt_C5_O_vld,wt_C4_O_vld,`
             `wt_C3_O_vld,wt_C2_O_vld,wt_C1_O_vld} <= 7'b0;`
        `end else begin`
            `wt_C1_O_vld <= wt_C0_O_vld;`
            `wt_C2_O_vld <= wt_C1_O_vld;`
            `wt_C3_O_vld <= wt_C2_O_vld;`
            `wt_C4_O_vld <= wt_C3_O_vld;`
            `wt_C5_O_vld <= wt_C4_O_vld;`
            `wt_C6_O_vld <= wt_C5_O_vld;`
            `wt_C7_O_vld <= wt_C6_O_vld;`
        `end`
    
    `// -------- 4) 内部计数器：卷积核内 K_cnt ---------------------------`
    `//reg [3:0] K_cnt;                       // 0‥8，只需 4 bit`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n)               K_cnt <= 0;`
        `else if(rd_done)           K_cnt <= 0;          // 一个 Hu 重新计数`
        `else if(or_cs==OR_CAL)         K_cnt <= K_cnt + 1;  // 每列 +1`
    
    `// -------- 5) 同步输入通道计数 wt_M_cnt ----------------------------`
    `//reg [6:0] wt_M_cnt;`
    `// ❶ 先做个一拍延迟，把 "还没 ++ 的 M_cnt" 存下来。`
    `reg [6:0] M_cnt_d;           // 前一拍的 M_cnt`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n)`
            `M_cnt_d <= 0;`
        `else`
            `M_cnt_d <= M_cnt;`
    
    `// ❷ 用这个快照去更新 wt_M_cnt`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n)`
            `wt_M_cnt <= 0;`
        `else if(or_cs==OR_FT_WT && or_ns==OR_CAL)`
            `wt_M_cnt <= 0;                    // 层首清零`
        `else if(rd_done)                      // rd_done 与 pe_end 同拍`
            `wt_M_cnt <= M_cnt_d;              // 锁住 ++ 之前的值`
`//        always @(posedge clk_cal or negedge rst_cal_n)`                             
`//    		if(!rst_cal_n)` 
`//    		      wt_M_cnt <= 0;`                                         
`//    		else if(or_cs==OR_FT_WT && or_ns==OR_CAL)` 
`//    		      wt_M_cnt <= 0;`                
`//    		else if(rd_done)` 
`//    		      wt_M_cnt <= M_cnt;`                                    
        
    `always @(posedge clk_cal or negedge rst_cal_n)`                             
		`if(!rst_cal_n) wt_N_cnt <= 0;`                                           
		`else if(or_cs==OR_FT_WT && or_ns==OR_CAL) wt_N_cnt <= 0;`                
		`else if(rd_done) wt_N_cnt <= ft_N_cnt;                                 // 在读完一个数据块后，从数据通路锁存ft_N_cnt的值。`
    
    
    
    `// -------- 6) 行列权重地址基址 (两层 CNN) --------------------------`
    `wire [12:0] wt_base = (nn_layer_cnt==1) ? 13'd0  :`
                          `(nn_layer_cnt==2) ? 13'd32 : 13'd0; // 仅两层`
    
    `// -------- 7) 计算 C0 列下一拍地址 ---------------------------------`
    `assign wt_C0_addr_nxt =`
                `wt_base +`
                `(wt_N_cnt-1) * K * M +        // 输出通道块偏移`
                `(wt_M_cnt-1) * K      +       // 输入通道内偏移`
                `K_cnt;                        // 核内偏移`
    
    `// -------- 8) C0 列权重地址寄存 ------------------------------------`
    `always @(posedge clk_cal or negedge rst_cal_n)`                             
		`if(!rst_cal_n)`                                                         
			`wt_C0_addr <= 13'b0;`                                               
		`else if((or_cs==OR_FT_WT && or_ns==OR_CAL) || (wt_C0_addr == K*M*N_tiles-1'b1+wt_addr_base))` 
			`wt_C0_addr <= wt_addr_base;`                                        
		`else if(or_cs==OR_DONE)`                                                
			`wt_C0_addr <= wt_C0_addr;`                                         
		`else if(or_cs==OR_CAL && wt_C0_O_vld)`                              
			`wt_C0_addr <= wt_C0_addr_nxt;`                                      
    
    `// -------- 9) 7 级移位寄存器，生成 C1~C7 列地址 --------------------`
    `always @(posedge clk_cal or negedge rst_cal_n)`
        `if(!rst_cal_n) begin`
            `{wt_C7_addr,wt_C6_addr,wt_C5_addr,wt_C4_addr,`
             `wt_C3_addr,wt_C2_addr,wt_C1_addr} <= 0;`
        `end else begin`
            `wt_C1_addr <= wt_C0_addr;`
            `wt_C2_addr <= wt_C1_addr;`
            `wt_C3_addr <= wt_C2_addr;`
            `wt_C4_addr <= wt_C3_addr;`
            `wt_C5_addr <= wt_C4_addr;`
            `wt_C6_addr <= wt_C5_addr;`
            `wt_C7_addr <= wt_C6_addr;`
        `end`
    `// --------------------------- 结束 ----------------------------------`

`endmodule`

