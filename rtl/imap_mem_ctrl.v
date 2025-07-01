`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/28 15:45:12
// Design Name: 
// Module Name: imap_mem_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define Bm 8
`define C  8
`define R  16
`define DDR_DW			64
`define DDR_AW			32

module imap_mem_ctrl(
    //Global signals
	input					clk_cal,
	input					rst_cal_n,
	// State signals with mcu
	input		[7 :0]		mc_cs,					// Current state of accelerator
	input		[7 :0]		mc_ns,					// Next state of accelerator
	input		[5 :0]		or_cs,					// Current state of calculation
	input		[5 :0]		or_ns,					// Next state of calculation
	
	input		[3 :0]		nn_layer_cnt,			// Current layer index, should be 1 when mc_cs[FT_ECG]
	output	reg				memct_init_cmplt,		// Reset Initial complite
	
	// Input CAN paramters from mcu
	input		[11:0]		can_len,				// Lenth of input can signal
	// Signals with PE_Array
	input					pe_end,
	output	reg				rd_done,				// turn pe_end from 1 to 0
	// Signals with Input_Regfile and InOutBuffer

//	output	reg	[5 :0]		Bm_cnt,
//	output	reg	[3 :0]		ft_N_cnt,
//	output  reg [3:0]       kh_cnt,
	output  reg	[12:0]  	rd_addr,
	output	reg				Data_O_vld,
//    output					final_ftNchange_flag,	// newly added with R&P
//    output                  final_column,           
//	output		[2 :0]		final_zeros,			// newly added with R&P
	input					Data_I_vld,				//newly added with R&P
	input 					Data_I_vld_CAN,
	output	reg	[12:0]		wr_addr,
	// Signals with Weight_Buffer
	output	reg				wt_I_vld,				// added in 2.0simple
	output	reg	[12:0]		wt_I_addr,				// added in 2.0simple
	output	reg	[12:0]		wt_C0_addr, wt_C1_addr, wt_C2_addr, wt_C3_addr,
							wt_C4_addr, wt_C5_addr, wt_C6_addr, wt_C7_addr,
							
	output	reg				//wt_C0_O_vld_r, wzx
							wt_C0_O_vld, wt_C1_O_vld, wt_C2_O_vld, wt_C3_O_vld,		//name chaged in 2.0simple
							wt_C4_O_vld, wt_C5_O_vld, wt_C6_O_vld, wt_C7_O_vld,
	// Transmission state signals to mcu
	output	reg				ft_lyr_param_done,
	output	reg				ft_can_done,
	output					ft_wt_done,
	output					lyr_cal_done
    );
    //-------------------------------STATE OF ACCELERATOR------------------------------
	//ACCELERATOR CONTROL STATE DECLARATIONS
	//---------------------------------------------------------------------------------	

	localparam	[7:0]		IDLE		= 8'd0;
	localparam	[7:0]		FT_ADDR		= 8'd1;
	localparam	[7:0]		ECG_UD		= 8'd2;
	localparam	[7:0]		FT_ECG		= 8'd3;
	localparam	[7:0]		FT_PARAM	= 8'd4;
	localparam	[7:0]		CONV_CAL	= 8'd5;
	localparam	[7:0]		LY_DONE		= 8'd6;
	localparam	[7:0]		INF_DONE	= 8'd7;
	
	
	//---------------------------------STATE OF CALCULATION----------------------------
	//CALCULATION CONTROL STATE DECLARATIONS
	//---------------------------------------------------------------------------------

	localparam	[5:0]		OR_IDLE		= 6'd0;
	localparam	[5:0]		OR_FT_WT	= 6'd1;
	localparam	[5:0]		OR_CAL		= 6'd2;
	localparam	[5:0]		OR_DONE		= 6'd3;

//==============================================================================================================================
// II. 顶层状态与完成信号 (Top-Level Status & Done Signals)
//==============================================================================================================================
//    wire rd_lyr_done, wr_lyr_done;

    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n) memct_init_cmplt <= 1'b0;
        else memct_init_cmplt <= 1'b1;

    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n) ft_lyr_param_done <= 1'b0;
        else ft_lyr_param_done <= ((mc_cs == FT_ECG && mc_ns == FT_PARAM) || (mc_cs == LY_DONE && mc_ns == FT_PARAM));
    


// --- 2D卷积参数 (Parameters for 2D Convolution) 硬编码---   
    parameter K     = 9;
    parameter K_H   = 3;
    parameter K_W   = 3;
    parameter S_H   = 2;
    parameter S_W   = 2;
    // 2D Hu (输入数据块) 的高度
    //    assign Hu_w[6:0] = ( `R - 1) * S_W + K_W; // (16-1)*2+3 = 33
    wire	[9:0]		Hu_w;
    wire    [14:0]      IN;
    wire    [7:0]      IN_w;
    wire    [7:0]      IN_h;
    wire	[7:0]		N;
    wire	[7:0]		M;
    wire	[11:0]		OUT;
    wire	[7:0]		OUT_w;
    wire	[7:0]		OUT_h;

    // --- 内部计算值 ---硬编码

    assign	Hu_w = (nn_layer_cnt==1)? 10'd33:(nn_layer_cnt==2)?10'd33:0;
    assign	IN = (nn_layer_cnt==1)? 15'd4096:(nn_layer_cnt==2)?15'd1024:0;
    assign	IN_w = (nn_layer_cnt==1)? 15'd64:(nn_layer_cnt==2)?15'd32:0;
    assign	IN_h = (nn_layer_cnt==1)? 15'd64:(nn_layer_cnt==2)?15'd32:0;
    assign	N = (nn_layer_cnt==1)? 7'd8:(nn_layer_cnt==2)?7'd32:0;
    assign	M = (nn_layer_cnt==1)? 7'd3:(nn_layer_cnt==2)?7'd8:0;
    assign  OUT = (nn_layer_cnt==1) ? 11'd1024 : (nn_layer_cnt==2) ? 11'd216 : 7'd0;
    assign  OUT_w = (nn_layer_cnt==1) ? 7'd32 : (nn_layer_cnt==2) ? 7'd16 : 7'd0;
    assign  OUT_h = (nn_layer_cnt==1) ? 7'd32 : (nn_layer_cnt==2) ? 7'd16 : 7'd0; 
    
    reg					rd_lyr_done;				// The completion signal of read all input maps in this layer
    wire	[12:0]		rd_addr_nxt;
//==============================================================================================================================
// II. 读数据流 ("imap") - 六层嵌套循环控制
//==============================================================================================================================
    // --- 计数器声明 ---
    reg [5:0]  Bm_cnt;       // 循环6 (最内层): 行内数据块计数器_bmtimes
    reg [7:0]  kh_cnt;       // 循环5: 卷积核行计数器_kh
    reg [6:0]  M_cnt;        // 循环4: 输入通道计数器_m
    reg [3:0]  ft_N_cnt;     // 循环3: 输出通道Tile计数器_ntile
    reg [11:0] cal_cnt_x;    // 循环2: 输出列滑动计数器_caltimesw
    reg [11:0] cal_cnt_y;    // 循环1 (最外层): 输出行滑动计数器_outh
    // --- 计数器顶点 ---
    		

	wire	[7:0]		cal_times_w;					// calculation times of one map
	wire	[3:0]		N_tiles;					// fetch times of one input map
	wire	[5:0]		Bm_times;					// transmission cycle per calculation
    // 读取一行Hu_w数据需要的次数--Bm_cnt
    assign Bm_times = (Hu_w[2:0]==3'b0) ? (Hu_w>>3) : ((Hu_w>>3)+1'b1);// ceil(33/8) = 5
    // 卷积核高度--kh_cnt
    //imap张数--M_cnt
    // 输出通道的tile数--ft_N_cnt
    assign N_tiles = (N[2:0]==3'b0) ? (N>>3) : ((N>>3)+1'b1);// ceil(8/8) = 1
    // 窗口横向滑动次数--cal_cnt_x
    assign	cal_times_w = (nn_layer_cnt >  2) ? 10'd1 :                                   // 对于全连接层，计算次数为1。
	                    (nn_layer_cnt <= 2 && (OUT_w[3:0]==4'b0)) ? OUT_w[7:4] : // 对于卷积层，如果卷积后输出尺寸是16的整数倍。
	                    OUT_w[7:4] + 1;                                        // 否则，需要加1（向上取整）。
	 // 窗口纵向滑动次数--cal_cnt_y--out_w     
    // --- 循环完成信号 ---
    wire bm_loop_done, kh_loop_done, m_loop_done, n_loop_done, x_loop_done, y_loop_done;

    // 循环6: Bm_cnt (由 pe_end 驱动)
    always @(posedge clk_cal or negedge rst_cal_n)
       if(!rst_cal_n)                                                               
			Bm_cnt <= 0;                                                        
		else if(or_cs==OR_FT_WT && or_ns==OR_CAL)                                      
			Bm_cnt <= 0;                                                           
		else if((rd_lyr_done && pe_end))                                                           
			Bm_cnt <= 0;  
        else if (pe_end && (or_cs==OR_CAL)) 
            Bm_cnt <= (Bm_cnt == Bm_times - 1) ? 0 : Bm_cnt + 1;
        else 
            Bm_cnt <= Bm_cnt;
        
    assign bm_loop_done = (Bm_cnt == Bm_times - 1) && pe_end && (or_cs==OR_CAL);//新增-lxy-组合逻辑不能太长，
    // 把 loop_done 锁存，确保与 pe_end 对齐
    reg bm_done_r;
    always @(posedge clk_cal or negedge rst_cal_n)
        if (!rst_cal_n)
            bm_done_r <= 1'b0;
        else if(bm_loop_done)
            bm_done_r <= bm_loop_done;
        else if(pe_end)
            bm_done_r <= 0;
    // 循环5: kh_cnt 
    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL) || (rd_lyr_done&&pe_end)) 
            kh_cnt <= 0;
//        else if ((Bm_cnt == Bm_times - 1) && pe_end) 
        else if (bm_done_r && pe_end) 
            kh_cnt <= (kh_cnt == K_H - 1) ? 0 : kh_cnt + 1;
        else 
            kh_cnt <= kh_cnt;
            
    assign kh_loop_done = (kh_cnt == K_H - 1) && bm_loop_done ;// one hu read done 
    reg kh_done_r;
    always @(posedge clk_cal or negedge rst_cal_n)
        if (!rst_cal_n)
            kh_done_r <= 1'b0;
        else if(bm_loop_done)
            kh_done_r <= kh_loop_done;
        else if(pe_end)
            kh_done_r <= 0;
    // 循环4: M_cnt 
    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL) || (rd_lyr_done&&pe_end)) 
            M_cnt <= 1;
        else if (kh_done_r && pe_end) 
            M_cnt <= (M_cnt == M) ? 1 : M_cnt + 1;
        else 
            M_cnt <= M_cnt;
            
    assign m_loop_done = (M_cnt == M) && kh_loop_done;// out begin
    reg m_done_r;
    always @(posedge clk_cal or negedge rst_cal_n)
        if (!rst_cal_n)
            m_done_r <= 1'b0;
        else if(bm_loop_done)
            m_done_r <= m_loop_done;
        else if(pe_end)
            m_done_r <= 0;
    // 循环3: ft_N_cnt 
    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL) || (rd_lyr_done&&pe_end)) 
            ft_N_cnt <= 1;
        else if (m_done_r&& pe_end) 
            ft_N_cnt <= (ft_N_cnt == N_tiles) ? 1 : ft_N_cnt + 1;
        else 
            ft_N_cnt <= ft_N_cnt;
            
    assign n_loop_done = (ft_N_cnt == N_tiles) && m_loop_done;
    reg n_done_r;
    always @(posedge clk_cal or negedge rst_cal_n)
        if (!rst_cal_n)
            n_done_r <= 1'b0;
        else if(bm_loop_done)
            n_done_r <= n_loop_done;
        else if(pe_end)
            n_done_r <= 0;
    // 循环2: cal_cnt_x 
    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)|| (rd_lyr_done&&pe_end)) 
            cal_cnt_x <= 0;
        else if (n_done_r && pe_end) 
            cal_cnt_x <= (cal_cnt_x == cal_times_w - 1) ? 0 : cal_cnt_x + 1;
        else 
            cal_cnt_x <= cal_cnt_x;
            
    assign x_loop_done = (cal_cnt_x == cal_times_w - 1) && n_loop_done;
    reg x_done_r;
    always @(posedge clk_cal or negedge rst_cal_n)
        if (!rst_cal_n)
            x_done_r <= 1'b0;
        else if(x_loop_done)
            x_done_r <= x_loop_done;
        else if(pe_end)
            x_done_r <= 0;
    // 循环1: cal_cnt_y 
    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)|| (rd_lyr_done&&pe_end)) 
            cal_cnt_y <= 0;
        else if (x_done_r &&pe_end) 
            cal_cnt_y <= (cal_cnt_y == OUT_h - 1) ? 0 : cal_cnt_y + 1;
        else 
            cal_cnt_y <= cal_cnt_y;
            
    assign y_loop_done = (cal_cnt_y == OUT_h - 1) && x_loop_done;
//    // ---------- 1. 常量/一次性参数 ---------- //
//    reg [13:0] imap_span, imap_span_y;       // ≈Hu_w 常量
//    always @(posedge clk_cal)
//        if(or_cs==OR_FT_WT && or_ns==OR_CAL) begin
//            imap_span   <= (IN  + 7) >> 3;   // ceil(IN/8)
//            imap_span_y <= (IN_w+ 7) >> 3;   // ceil(W/8)
//        end
    
//    // ---------- 2. 地址流水 ---------- //
//    reg [13:0] base_addr_r, row_addr_r;      // stage-1, stage-2
//    always @(posedge clk_cal) begin
//        // stage-1：依赖 M_cnt, cal_cnt_x 已确定
//        base_addr_r <= (M_cnt-1) * imap_span
//                     + cal_cnt_x * (S_W<<1); // 2*S_W*cal_cnt_x
    
//        // stage-2：加入行偏移
//        row_addr_r  <= base_addr_r
//                     + cal_cnt_y * S_H * imap_span_y
//                     + kh_cnt    *       imap_span_y;
//    end
    
//    // stage-3：最内层 Bm_cnt，得到最终读地址
//    always @(posedge clk_cal)
//        if(pe_end && or_cs==OR_CAL)
//            rd_addr <= row_addr_r + Bm_cnt;
    
//    // ---------- 3. 循环完成流水 ---------- //
////    reg bm_done_r, kh_done_r, m_done_r, n_done_r, x_done_r;
    
//    always @(posedge clk_cal) begin
//        bm_done_r <= pe_end && (Bm_cnt==Bm_times-1);
    
//        // kh_done 只看上一拍的 bm_done
//        kh_done_r <= bm_done_r && (kh_cnt==K_H-1);
    
//        m_done_r  <= kh_done_r && (M_cnt==M);
//        n_done_r  <= m_done_r  && (ft_N_cnt==N_tiles);
//        x_done_r  <= n_done_r  && (cal_cnt_x==cal_times_w-1);
    
//        rd_lyr_done <= x_done_r && (cal_cnt_y==OUT_h-1); // lyr done
//    end
//    assign lyr_cal_done = rd_lyr_done;

// --- 读地址生成 (2D) ---行主序存储，相邻列等价于imap相邻行，相邻8列为imap一行
   	wire	[13:0]		imap_addr_span;				
	wire	[13:0]		imap_addr_span_w;			
    assign	imap_addr_span = (IN[2:0]==3'b0) ? (IN>>3) : ((IN>>3)+1'b1);//一个imap占几个列
    assign	imap_addr_span_w = (IN_w[2:0]==3'b0) ? (IN_w>>3) : ((IN_w>>3)+1'b1);//imap 一行占几个列
    // 地址单位是 "列" (8字节)
//    wire [15:0] base_addr, v_offset, h_offset;
//    assign base_addr = (M_cnt - 1) * (IN / `Bm);
//    assign v_offset  = (cal_cnt_y * S_H + kh_cnt) * (W_IN / `Bm);
//    assign h_offset  = (cal_cnt_x * `R * S_W / `Bm);
    assign rd_addr_nxt = (M_cnt-1'b1)*imap_addr_span +        //滑到第几张imap
                         cal_cnt_x*S_W*2 +             //窗口横向滑动偏移tile
                         //阵列16行，一批hu相当于16个窗口，
                         //下一批hu需要滑动16*S个点才能得到下一批hu的第一个窗口，但是有8个bank并行存，所以再除以8
                         cal_cnt_y * S_H * imap_addr_span_w + //滑到第几行imap
                         kh_cnt * imap_addr_span_w +          //滑到窗口的第几行
                         Bm_cnt;    
    	// rd_done: 单个数据块(Hu)读取完成信号。
	always @(posedge clk_cal or negedge rst_cal_n)                                    
		if(!rst_cal_n)                                                               
			rd_done <= 1'b0;                                                         
		else if(pe_end && (Bm_cnt == Bm_times-1)&&(kh_cnt == K_H - 1))                                  
			rd_done <= 1'b1;                                                           
		else                                                                          
			rd_done <= 1'b0;                             
			                                          
    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n) 
            rd_addr <= 0;
        else if(pe_end && (or_cs == OR_CAL))
            rd_addr <= rd_addr_nxt;
        else
            rd_addr <= rd_addr;
	always @(posedge clk_cal or negedge rst_cal_n)                                    
		if(!rst_cal_n)                                                                 
			rd_lyr_done <= 1'b0;                                                      
		else if(lyr_cal_done)                                                          
			rd_lyr_done <= 1'b0;                                                    
		else if(x_done_r && (cal_cnt_y==OUT_h-1))           
			rd_lyr_done <= 1'b1;                                                     
//    assign lyr_cal_done =rd_lyr_done;
     // --- 读数据有效信号 ---
    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n) 
            Data_O_vld <= 1'b0;
        else 
            Data_O_vld <= pe_end && (or_cs == OR_CAL) && !rd_lyr_done;
            


        // ...          
    // Signals of writing layer1 input map in In_Out_Buffer
    wire	[8:0]		ft_can_times;
    reg		[12:0]		ft_can_cnt;
    wire	[12:0]		ft_can_cnt_nxt;
    assign	ft_can_times = (can_len[2:0]==3'b0) ? (can_len >> 3) : ((can_len >> 3) + 1);

	// --- 核心计数器与状态标志逻辑 (Core Counter and Status Flag Logic) ---

	// ft_ecg_cnt: 用于加载初始ECG数据的计数器，其值也直接作为初始写入地址。
	always @(posedge clk_cal or negedge rst_cal_n)          
		if(!rst_cal_n)                                     
			ft_can_cnt <= 13'b0;                            
		else if(Data_I_vld_CAN && (mc_cs == FT_ECG))           
			ft_can_cnt <= ft_can_cnt_nxt;                  
		else                                              
			ft_can_cnt <= ft_can_cnt;                     
	
	// ft_ecg_cnt_nxt: 组合逻辑，计算ft_ecg_cnt的下一个值。
	assign ft_can_cnt_nxt = (ft_can_cnt == ft_can_times - 1'b1) ? 8'b0 : ft_can_cnt + 1'b1; 
	
	// ft_ecg_done: 初始ECG数据加载完成标志的生成逻辑。
	always @(posedge clk_cal or negedge rst_cal_n)          
		if(!rst_cal_n)                                     
			ft_can_done <= 1'b0;                           
		else if(ft_can_cnt == ft_can_times - 1'b1)          
			ft_can_done <= 1'b1;                           
		else                                               
			ft_can_done <= 1'b0;                           
//==============================================================================================================================
// IV. 写数据流 ("omap") - 三层嵌套循环控制
//==============================================================================================================================
    wire [9:0]omap_addr_span;
    assign	omap_addr_span = (OUT[2:0]==3'b0) ? (OUT>>3) : ((OUT>>3)+1'b1);
    wire [9:0]omap_addr_span_w;
    assign	omap_addr_span_w = (OUT_w[2:0]==3'b0) ? (OUT_w>>3) : ((OUT_w>>3)+1'b1);
    reg [6:0]  N_cnt;
    reg [11:0] ox_cnt;
    reg [11:0] oy_cnt;
    wire n_write_loop_done, x_write_loop_done;

    always @(posedge clk_cal or negedge rst_cal_n) // 循环3: N_cnt
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)) 
            N_cnt <= 1;
        else if(Data_I_vld && (or_cs==OR_CAL)) 
                N_cnt <= (N_cnt == N) ? 1 : N_cnt + 1;
                
    assign n_write_loop_done = (N_cnt == N) && Data_I_vld && (or_cs==OR_CAL);

    always @(posedge clk_cal or negedge rst_cal_n) // 循环2: ox_cnt
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)) 
            ox_cnt <= 0;
        else if(n_write_loop_done) 
            ox_cnt <= (ox_cnt == OUT_w - 1) ? 0 : ox_cnt + 1;
        
    assign x_write_loop_done = (ox_cnt == OUT_w - 1) && n_write_loop_done;

    always @(posedge clk_cal or negedge rst_cal_n) // 循环1: oy_cnt
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)) 
            oy_cnt <= 0;
        else if(x_write_loop_done) 
            oy_cnt <= oy_cnt + 1;

    assign wr_lyr_done = (oy_cnt == OUT_h - 1) && x_write_loop_done;
    
    always @(posedge clk_cal or negedge rst_cal_n) // 写地址生成
        if(!rst_cal_n) 
            wr_addr <= 0;
        else if (mc_cs == FT_ECG) 
            wr_addr <= ft_can_cnt; // 初始加载
        else if(Data_I_vld && (or_cs == OR_CAL))
            wr_addr <= (N_cnt-1)*omap_addr_span + oy_cnt * omap_addr_span_w + (ox_cnt/`Bm);
            

//==============================================================================================================================
// V. 权重数据流控制 (Weight Dataflow Control)
//==============================================================================================================================
// @Abstract: 本节负责在 OR_FT_WT 状态下，将当前层所需的所有权重，从外部存储加载到片上的 Weight_Buffer 中。
//            它生成一个简单的线性增长地址(wt_I_addr)和使能信号(wt_I_vld)，以完成批量的权重写入。
//            This section handles the bulk loading of all weights for the current layer into the on-chip
//            Weight_Buffer during the OR_FT_WT state. It generates a simple, linearly increasing
//            address (wt_I_addr) and an enable signal (wt_I_vld) to perform this bulk write.
//==============================================================================================================================

	// wt_I_vld: 权重加载有效信号，高电平表示正在向Weight_Buffer中写入权重。
	always @(posedge clk_cal or negedge rst_cal_n)                            
		if(!rst_cal_n)                                                       
			wt_I_vld <= 1'b0;                                                  
		else if(or_cs==IDLE && or_ns==OR_FT_WT && !ft_wt_done)                 
			wt_I_vld <= 1'b1;                                                 
		else if(ft_wt_done)                                                   
			wt_I_vld <= 1'b0;                                             

	// ft_wt_done: 权重加载完成标志。通过判断加载地址是否达到当前层的权重总量来决定。
	// 权重总量 K*M*N (bytes), 每次传输8字节，所以总次数为 K*M*N/8。
	assign ft_wt_done = (nn_layer_cnt==3) ? ((wt_I_addr==288) ? 1:0) :           
						(nn_layer_cnt==4) ? ((wt_I_addr==64) ? 1:0) :         
						((wt_I_addr==K*M*N/8 - 1) ? 1:0);                       

	// wt_I_addr: 权重加载的写地址计数器。
	always @(posedge clk_cal or negedge rst_cal_n)                            
		if(!rst_cal_n)                                                      
			wt_I_addr <= 13'b0;                                                
		else if(wt_I_vld)                                                    
			wt_I_addr <= wt_I_addr + 1'b1;                                
		else                                                                 
			wt_I_addr <= 13'b0;                                              
	

//==============================================================================================================================
// VI-B. 权重读取控制 (On-the-fly Weight Read Control - State OR_CAL)
//------------------------------------------------------------------------------------------------------------------------------
// @Abstract: 本节负责在 OR_CAL 计算状态下，根据当前的计算需求（由M_cnt, K_cnt, wt_N_cnt等决定），
//            生成精确的读地址(wt_C0_addr)，从Weight_Buffer中读取权重送往PE阵列。
//            This section generates precise read addresses (wt_C0_addr) during the OR_CAL state
//            to fetch specific weights from the Weight_Buffer and send them to the PE array,
//            based on the current computation progress (determined by M_cnt, K_cnt, etc.).
//==============================================================================================================================
	// --- 内部信号声明 (Internal Signal Declarations) ---
	wire	[12:0]	wt_C0_addr_nxt;       // 下一个周期的权重读地址（组合逻辑）
	reg		[6:0]	wt_M_cnt;             // 用于地址计算的输入通道(M)计数器
	reg		[8:0]	K_cnt;                // 用于地址计算的卷积核内(K)计数器
	reg		[3:0]	wt_N_cnt;             // 用于地址计算的输出通道(N)计数器
	reg				rd_done_temp;         // rd_done信号的延迟版本，用于时序对齐

	// --- 权重有效信号生成 (Weight Valid Signal Generation) ---

	// 创建rd_done的一拍延迟，用于同步。
	always @(posedge clk_cal)                                                 // 每个时钟上升沿触发。
		rd_done_temp <= rd_done;                                              // 将rd_done的值锁存一拍。HU

	// wt_C0_O_vld: 送往PE阵列第一列的权重数据有效信号。
	always @(posedge clk_cal or negedge rst_cal_n)                             
		if(!rst_cal_n)                                                         
			wt_C0_O_vld <= 1'b0;                                               
		else if(rd_done_temp)                                               
			wt_C0_O_vld <= 1'b1;                                              
		else if((!pe_end && (K_cnt>=K)) || !or_cs==OR_CAL)                     
			wt_C0_O_vld <= 1'b0;                                               
			
	// 将权重有效信号(wt_C0_O_vld)打拍，生成送往PE阵列后续各列的延迟有效信号。
	always @(posedge clk_cal or negedge rst_cal_n)                             
		if(!rst_cal_n)                                                        
			begin                                                              
				wt_C1_O_vld <= 1'b0;                                           // 所有延迟信号清零。
				wt_C2_O_vld <= 1'b0;                                           
				wt_C3_O_vld <= 1'b0;                                           
				wt_C4_O_vld <= 1'b0;                                           
				wt_C5_O_vld <= 1'b0;                                           
				wt_C6_O_vld <= 1'b0;                                           
				wt_C7_O_vld <= 1'b0;                                           
			end                                                                
		else                                                                   // 对于普通卷积层，
			begin                                                              //
				wt_C1_O_vld <= wt_C0_O_vld;                                    // 构建一个移位寄存器式的流水线，
				wt_C2_O_vld <= wt_C1_O_vld;                                    // 每一级的有效信号是上一级的延迟。
				wt_C3_O_vld <= wt_C2_O_vld;                                    //
				wt_C4_O_vld <= wt_C3_O_vld;                                    //
				wt_C5_O_vld <= wt_C4_O_vld;                                    //
				wt_C6_O_vld <= wt_C5_O_vld;                                    //
				wt_C7_O_vld <= wt_C6_O_vld;                                    //
			end                                                                //

	// --- 权重读取地址生成 (Weight Read Address Generation) ---

	// 权重地址生成所用的内部计数器。它们通过锁存数据通路计数器的值来保持同步。
	always @(posedge clk_cal or negedge rst_cal_n)                             
		if(!rst_cal_n) wt_N_cnt <= 0;                                          
		else if(or_cs==OR_FT_WT && or_ns==OR_CAL) wt_N_cnt <= 0;                 
		else if(rd_done) wt_N_cnt <= ft_N_cnt;                               

	always @(posedge clk_cal or negedge rst_cal_n)                            
		if(!rst_cal_n) wt_M_cnt <= 0;                                           
		else if(or_cs==OR_FT_WT && or_ns==OR_CAL) wt_M_cnt <= 0;               
		else if(rd_done) wt_M_cnt <= M_cnt;                                    

	always @(posedge clk_cal or negedge rst_cal_n)                          
		if(!rst_cal_n) K_cnt <= 0;                                             
		else if(rd_done) K_cnt <= 0;                                          
		else if(or_cs==OR_CAL) K_cnt <= K_cnt + 1'b1;                      
			
	// wt_addr_base: 当前层权重在Weight_Buffer中的基地址偏移。
	wire [12:0] wt_addr_base;
	assign wt_addr_base = (nn_layer_cnt==1) ? 13'd0     :                      // 第1层基地址为0。
						  (nn_layer_cnt==2) ? 13'd32    :                      // 第2层基地址为32。
						  (nn_layer_cnt==3) ? 13'd336   : // 32+304
						  (nn_layer_cnt==4) ? 13'd928   :13'd0;// ...+592
						  
											
	// wt_C0_addr_nxt: 计算送往PE阵列第一列的下一个权重地址。
	assign	wt_C0_addr_nxt = (wt_N_cnt-1)*K*M + (wt_M_cnt-1)*K + K_cnt + wt_addr_base;	// 地址公式: (输出通道偏移)+(输入通道偏移)+(核内偏移)+(层基址)
	
	// wt_C0_addr: 锁存并输出最终的权重读地址。
	always @(posedge clk_cal or negedge rst_cal_n)                             
		if(!rst_cal_n)                                                         
			wt_C0_addr <= 13'b0;                                               
		else if((or_cs==OR_FT_WT && or_ns==OR_CAL) || (wt_C0_addr == K*M*N_tiles-1'b1+wt_addr_base)) // 同步逻辑：在新计算开始或地址溢出时，
			wt_C0_addr <= wt_addr_base;                                        // 地址复位为当前层的基地址。
		else if(or_cs==OR_DONE)                                                // 如果计算完成，
			wt_C0_addr <= wt_C0_addr;                                          // 地址保持不变。
		else if(or_cs==OR_CAL && wt_C0_O_vld)                                  // 如果在计算状态且权重有效，
			wt_C0_addr <= wt_C0_addr_nxt;                                      // 更新为下一个计算好的地址。

	// 将主权重读地址(wt_C0_addr)打拍，生成送往PE阵列后续各列的延迟地址。
	always @(posedge clk_cal or negedge rst_cal_n)                             
		if(!rst_cal_n)                                                         
			begin                                                              //
				wt_C1_addr <= 13'b0;                                           // 所有延迟地址清零。
				wt_C2_addr <= 13'b0;                                           //
				wt_C3_addr <= 13'b0;                                           //
				wt_C4_addr <= 13'b0;                                           //
				wt_C5_addr <= 13'b0;                                           //
				wt_C6_addr <= 13'b0;                                           //
				wt_C7_addr <= 13'b0;                                           //
			end                                                               
		else                                                                  
			begin                                                              
				wt_C1_addr <= wt_C0_addr;                                      
				wt_C2_addr <= wt_C1_addr;                                     
				wt_C3_addr <= wt_C2_addr;                                     
				wt_C4_addr <= wt_C3_addr;                                      
				wt_C5_addr <= wt_C4_addr;                                     
				wt_C6_addr <= wt_C5_addr;                                      
				wt_C7_addr <= wt_C6_addr;                                      
			end
//
	assign	cal_cycle = K*M;
	//assign	pass_cycle = `R + `C + K - 1-2;
	//assign	pass_cycle = `C + K + 4;
	assign	pass_cycle = (nn_layer_cnt>=1&&nn_layer_cnt<=2)?((wt_M_cnt==M)?(`C + K - Bm_times):(K)):(`R + `C + K - 1-2);    
	assign lyr_cal_done = (or_cs == OR_CAL) && wr_lyr_done && rd_lyr_done;
	//==============================================================================================================================
// V-C. 层参数获取控制 (Layer Parameter Fetch Control)
//------------------------------------------------------------------------------------------------------------------------------
// @Abstract: 本节负责生成"层参数获取完成"的标志信号(ft_lyr_param_done)。
//            [重要说明] 在此设计的当前版本中，所有网络层的参数都已通过 `assign` 语句硬编码在硬件中，
//            因此本模块不再执行实际的内存读取操作。它的功能被简化为：在主状态机(MCU)进入
//            FT_PARAM状态时，立即产生一个完成脉冲，以驱动状态机流转到下一步。
//            [IMPORTANT NOTE] In the current version of this design, all layer parameters are hardcoded
//            via `assign` statements. Therefore, this module no longer performs actual memory reads.
//            Its function is simplified to generating a completion pulse (ft_lyr_param_done) immediately
//            when the main FSM enters the FT_PARAM state, in order to drive the FSM to the next state.
//==============================================================================================================================

	// --- (原始设计参考) 以下是被注释掉的、原始设计中用于存储参数的信号 ---
	// reg	[`DDR_DW-1:0]	nn_param_mem[80:0];       // (原始设计) 用于存储从DDR加载的所有层参数的片上内存。
	// reg	[`DDR_AW-1:0]	nn_lyr_param_addr;        // (原始设计) 指向 nn_param_mem 的地址指针。

	
//	// --- "伪"参数加载完成信号的生成逻辑 ---
	
//	// ft_lyr_param_done: 层参数获取完成标志。
//	always @(posedge clk_cal or negedge rst_cal_n)          // 时钟上升沿或复位下降沿触发。
//		if(!rst_cal_n)                                     // 异步复位逻辑：
//			begin                                          //
//				//nn_lyr_param_addr <= 0;                   // (原始设计) 复位时地址指针清零。
//				ft_lyr_param_done <= 0;                    // 完成标志清零。
//			end                                            //
//		else if((mc_cs==FT_ECG && mc_ns==FT_PARAM) || (mc_cs==LY_DONE && mc_ns==FT_PARAM)) // 同步逻辑：当主状态机准备进入"获取参数"(FT_PARAM)状态时，
//			begin                                          // (这发生在第一层ECG加载后，或任一层计算完成后)
//				// --- (原始设计参考) 以下是原始设计中会执行的实际读取操作 ---
//				// nn_lyr_param_addr <= nn_lyr_param_saddr + (nn_layer_cnt-1)*10;	// (原始设计) 计算当前层参数在片上内存中的基地址。
//				// $readmemb("...", nn_param_mem);        // (原始设计-仅仿真) 从文本文件将参数读入片上内存。
				
//				// --- 当前版本的简化逻辑 ---
//				ft_lyr_param_done <= 1;                    // 在此设计中，由于参数已硬编码，加载过程瞬时完成，故直接将完成标志置位。
//			end                                            //
//		else                                               // 在其他所有状态下，
//			ft_lyr_param_done <= 0;                        // 完成标志保持为低。    

endmodule
