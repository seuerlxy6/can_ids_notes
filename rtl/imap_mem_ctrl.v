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
// II. ����״̬������ź� (Top-Level Status & Done Signals)
//==============================================================================================================================
//    wire rd_lyr_done, wr_lyr_done;

    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n) memct_init_cmplt <= 1'b0;
        else memct_init_cmplt <= 1'b1;

    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n) ft_lyr_param_done <= 1'b0;
        else ft_lyr_param_done <= ((mc_cs == FT_ECG && mc_ns == FT_PARAM) || (mc_cs == LY_DONE && mc_ns == FT_PARAM));
    


// --- 2D������� (Parameters for 2D Convolution) Ӳ����---   
    parameter K     = 9;
    parameter K_H   = 3;
    parameter K_W   = 3;
    parameter S_H   = 2;
    parameter S_W   = 2;
    // 2D Hu (�������ݿ�) �ĸ߶�
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

    // --- �ڲ�����ֵ ---Ӳ����

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
// II. �������� ("imap") - ����Ƕ��ѭ������
//==============================================================================================================================
    // --- ���������� ---
    reg [5:0]  Bm_cnt;       // ѭ��6 (���ڲ�): �������ݿ������_bmtimes
    reg [7:0]  kh_cnt;       // ѭ��5: ������м�����_kh
    reg [6:0]  M_cnt;        // ѭ��4: ����ͨ��������_m
    reg [3:0]  ft_N_cnt;     // ѭ��3: ���ͨ��Tile������_ntile
    reg [11:0] cal_cnt_x;    // ѭ��2: ����л���������_caltimesw
    reg [11:0] cal_cnt_y;    // ѭ��1 (�����): ����л���������_outh
    // --- ���������� ---
    		

	wire	[7:0]		cal_times_w;					// calculation times of one map
	wire	[3:0]		N_tiles;					// fetch times of one input map
	wire	[5:0]		Bm_times;					// transmission cycle per calculation
    // ��ȡһ��Hu_w������Ҫ�Ĵ���--Bm_cnt
    assign Bm_times = (Hu_w[2:0]==3'b0) ? (Hu_w>>3) : ((Hu_w>>3)+1'b1);// ceil(33/8) = 5
    // ����˸߶�--kh_cnt
    //imap����--M_cnt
    // ���ͨ����tile��--ft_N_cnt
    assign N_tiles = (N[2:0]==3'b0) ? (N>>3) : ((N>>3)+1'b1);// ceil(8/8) = 1
    // ���ں��򻬶�����--cal_cnt_x
    assign	cal_times_w = (nn_layer_cnt >  2) ? 10'd1 :                                   // ����ȫ���Ӳ㣬�������Ϊ1��
	                    (nn_layer_cnt <= 2 && (OUT_w[3:0]==4'b0)) ? OUT_w[7:4] : // ���ھ���㣬������������ߴ���16����������
	                    OUT_w[7:4] + 1;                                        // ������Ҫ��1������ȡ������
	 // �������򻬶�����--cal_cnt_y--out_w     
    // --- ѭ������ź� ---
    wire bm_loop_done, kh_loop_done, m_loop_done, n_loop_done, x_loop_done, y_loop_done;

    // ѭ��6: Bm_cnt (�� pe_end ����)
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
        
    assign bm_loop_done = (Bm_cnt == Bm_times - 1) && pe_end && (or_cs==OR_CAL);//����-lxy-����߼�����̫����
    // �� loop_done ���棬ȷ���� pe_end ����
    reg bm_done_r;
    always @(posedge clk_cal or negedge rst_cal_n)
        if (!rst_cal_n)
            bm_done_r <= 1'b0;
        else if(bm_loop_done)
            bm_done_r <= bm_loop_done;
        else if(pe_end)
            bm_done_r <= 0;
    // ѭ��5: kh_cnt 
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
    // ѭ��4: M_cnt 
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
    // ѭ��3: ft_N_cnt 
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
    // ѭ��2: cal_cnt_x 
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
    // ѭ��1: cal_cnt_y 
    always @(posedge clk_cal or negedge rst_cal_n)
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)|| (rd_lyr_done&&pe_end)) 
            cal_cnt_y <= 0;
        else if (x_done_r &&pe_end) 
            cal_cnt_y <= (cal_cnt_y == OUT_h - 1) ? 0 : cal_cnt_y + 1;
        else 
            cal_cnt_y <= cal_cnt_y;
            
    assign y_loop_done = (cal_cnt_y == OUT_h - 1) && x_loop_done;
//    // ---------- 1. ����/һ���Բ��� ---------- //
//    reg [13:0] imap_span, imap_span_y;       // ��Hu_w ����
//    always @(posedge clk_cal)
//        if(or_cs==OR_FT_WT && or_ns==OR_CAL) begin
//            imap_span   <= (IN  + 7) >> 3;   // ceil(IN/8)
//            imap_span_y <= (IN_w+ 7) >> 3;   // ceil(W/8)
//        end
    
//    // ---------- 2. ��ַ��ˮ ---------- //
//    reg [13:0] base_addr_r, row_addr_r;      // stage-1, stage-2
//    always @(posedge clk_cal) begin
//        // stage-1������ M_cnt, cal_cnt_x ��ȷ��
//        base_addr_r <= (M_cnt-1) * imap_span
//                     + cal_cnt_x * (S_W<<1); // 2*S_W*cal_cnt_x
    
//        // stage-2��������ƫ��
//        row_addr_r  <= base_addr_r
//                     + cal_cnt_y * S_H * imap_span_y
//                     + kh_cnt    *       imap_span_y;
//    end
    
//    // stage-3�����ڲ� Bm_cnt���õ����ն���ַ
//    always @(posedge clk_cal)
//        if(pe_end && or_cs==OR_CAL)
//            rd_addr <= row_addr_r + Bm_cnt;
    
//    // ---------- 3. ѭ�������ˮ ---------- //
////    reg bm_done_r, kh_done_r, m_done_r, n_done_r, x_done_r;
    
//    always @(posedge clk_cal) begin
//        bm_done_r <= pe_end && (Bm_cnt==Bm_times-1);
    
//        // kh_done ֻ����һ�ĵ� bm_done
//        kh_done_r <= bm_done_r && (kh_cnt==K_H-1);
    
//        m_done_r  <= kh_done_r && (M_cnt==M);
//        n_done_r  <= m_done_r  && (ft_N_cnt==N_tiles);
//        x_done_r  <= n_done_r  && (cal_cnt_x==cal_times_w-1);
    
//        rd_lyr_done <= x_done_r && (cal_cnt_y==OUT_h-1); // lyr done
//    end
//    assign lyr_cal_done = rd_lyr_done;

// --- ����ַ���� (2D) ---������洢�������еȼ���imap�����У�����8��Ϊimapһ��
   	wire	[13:0]		imap_addr_span;				
	wire	[13:0]		imap_addr_span_w;			
    assign	imap_addr_span = (IN[2:0]==3'b0) ? (IN>>3) : ((IN>>3)+1'b1);//һ��imapռ������
    assign	imap_addr_span_w = (IN_w[2:0]==3'b0) ? (IN_w>>3) : ((IN_w>>3)+1'b1);//imap һ��ռ������
    // ��ַ��λ�� "��" (8�ֽ�)
//    wire [15:0] base_addr, v_offset, h_offset;
//    assign base_addr = (M_cnt - 1) * (IN / `Bm);
//    assign v_offset  = (cal_cnt_y * S_H + kh_cnt) * (W_IN / `Bm);
//    assign h_offset  = (cal_cnt_x * `R * S_W / `Bm);
    assign rd_addr_nxt = (M_cnt-1'b1)*imap_addr_span +        //�����ڼ���imap
                         cal_cnt_x*S_W*2 +             //���ں��򻬶�ƫ��tile
                         //����16�У�һ��hu�൱��16�����ڣ�
                         //��һ��hu��Ҫ����16*S������ܵõ���һ��hu�ĵ�һ�����ڣ�������8��bank���д棬�����ٳ���8
                         cal_cnt_y * S_H * imap_addr_span_w + //�����ڼ���imap
                         kh_cnt * imap_addr_span_w +          //�������ڵĵڼ���
                         Bm_cnt;    
    	// rd_done: �������ݿ�(Hu)��ȡ����źš�
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
     // --- ��������Ч�ź� ---
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

	// --- ���ļ�������״̬��־�߼� (Core Counter and Status Flag Logic) ---

	// ft_ecg_cnt: ���ڼ��س�ʼECG���ݵļ���������ֵҲֱ����Ϊ��ʼд���ַ��
	always @(posedge clk_cal or negedge rst_cal_n)          
		if(!rst_cal_n)                                     
			ft_can_cnt <= 13'b0;                            
		else if(Data_I_vld_CAN && (mc_cs == FT_ECG))           
			ft_can_cnt <= ft_can_cnt_nxt;                  
		else                                              
			ft_can_cnt <= ft_can_cnt;                     
	
	// ft_ecg_cnt_nxt: ����߼�������ft_ecg_cnt����һ��ֵ��
	assign ft_can_cnt_nxt = (ft_can_cnt == ft_can_times - 1'b1) ? 8'b0 : ft_can_cnt + 1'b1; 
	
	// ft_ecg_done: ��ʼECG���ݼ�����ɱ�־�������߼���
	always @(posedge clk_cal or negedge rst_cal_n)          
		if(!rst_cal_n)                                     
			ft_can_done <= 1'b0;                           
		else if(ft_can_cnt == ft_can_times - 1'b1)          
			ft_can_done <= 1'b1;                           
		else                                               
			ft_can_done <= 1'b0;                           
//==============================================================================================================================
// IV. д������ ("omap") - ����Ƕ��ѭ������
//==============================================================================================================================
    wire [9:0]omap_addr_span;
    assign	omap_addr_span = (OUT[2:0]==3'b0) ? (OUT>>3) : ((OUT>>3)+1'b1);
    wire [9:0]omap_addr_span_w;
    assign	omap_addr_span_w = (OUT_w[2:0]==3'b0) ? (OUT_w>>3) : ((OUT_w>>3)+1'b1);
    reg [6:0]  N_cnt;
    reg [11:0] ox_cnt;
    reg [11:0] oy_cnt;
    wire n_write_loop_done, x_write_loop_done;

    always @(posedge clk_cal or negedge rst_cal_n) // ѭ��3: N_cnt
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)) 
            N_cnt <= 1;
        else if(Data_I_vld && (or_cs==OR_CAL)) 
                N_cnt <= (N_cnt == N) ? 1 : N_cnt + 1;
                
    assign n_write_loop_done = (N_cnt == N) && Data_I_vld && (or_cs==OR_CAL);

    always @(posedge clk_cal or negedge rst_cal_n) // ѭ��2: ox_cnt
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)) 
            ox_cnt <= 0;
        else if(n_write_loop_done) 
            ox_cnt <= (ox_cnt == OUT_w - 1) ? 0 : ox_cnt + 1;
        
    assign x_write_loop_done = (ox_cnt == OUT_w - 1) && n_write_loop_done;

    always @(posedge clk_cal or negedge rst_cal_n) // ѭ��1: oy_cnt
        if(!rst_cal_n || (or_cs==OR_FT_WT && or_ns==OR_CAL)) 
            oy_cnt <= 0;
        else if(x_write_loop_done) 
            oy_cnt <= oy_cnt + 1;

    assign wr_lyr_done = (oy_cnt == OUT_h - 1) && x_write_loop_done;
    
    always @(posedge clk_cal or negedge rst_cal_n) // д��ַ����
        if(!rst_cal_n) 
            wr_addr <= 0;
        else if (mc_cs == FT_ECG) 
            wr_addr <= ft_can_cnt; // ��ʼ����
        else if(Data_I_vld && (or_cs == OR_CAL))
            wr_addr <= (N_cnt-1)*omap_addr_span + oy_cnt * omap_addr_span_w + (ox_cnt/`Bm);
            

//==============================================================================================================================
// V. Ȩ������������ (Weight Dataflow Control)
//==============================================================================================================================
// @Abstract: ���ڸ����� OR_FT_WT ״̬�£�����ǰ�����������Ȩ�أ����ⲿ�洢���ص�Ƭ�ϵ� Weight_Buffer �С�
//            ������һ���򵥵�����������ַ(wt_I_addr)��ʹ���ź�(wt_I_vld)�������������Ȩ��д�롣
//            This section handles the bulk loading of all weights for the current layer into the on-chip
//            Weight_Buffer during the OR_FT_WT state. It generates a simple, linearly increasing
//            address (wt_I_addr) and an enable signal (wt_I_vld) to perform this bulk write.
//==============================================================================================================================

	// wt_I_vld: Ȩ�ؼ�����Ч�źţ��ߵ�ƽ��ʾ������Weight_Buffer��д��Ȩ�ء�
	always @(posedge clk_cal or negedge rst_cal_n)                            
		if(!rst_cal_n)                                                       
			wt_I_vld <= 1'b0;                                                  
		else if(or_cs==IDLE && or_ns==OR_FT_WT && !ft_wt_done)                 
			wt_I_vld <= 1'b1;                                                 
		else if(ft_wt_done)                                                   
			wt_I_vld <= 1'b0;                                             

	// ft_wt_done: Ȩ�ؼ�����ɱ�־��ͨ���жϼ��ص�ַ�Ƿ�ﵽ��ǰ���Ȩ��������������
	// Ȩ������ K*M*N (bytes), ÿ�δ���8�ֽڣ������ܴ���Ϊ K*M*N/8��
	assign ft_wt_done = (nn_layer_cnt==3) ? ((wt_I_addr==288) ? 1:0) :           
						(nn_layer_cnt==4) ? ((wt_I_addr==64) ? 1:0) :         
						((wt_I_addr==K*M*N/8 - 1) ? 1:0);                       

	// wt_I_addr: Ȩ�ؼ��ص�д��ַ��������
	always @(posedge clk_cal or negedge rst_cal_n)                            
		if(!rst_cal_n)                                                      
			wt_I_addr <= 13'b0;                                                
		else if(wt_I_vld)                                                    
			wt_I_addr <= wt_I_addr + 1'b1;                                
		else                                                                 
			wt_I_addr <= 13'b0;                                              
	

//==============================================================================================================================
// VI-B. Ȩ�ض�ȡ���� (On-the-fly Weight Read Control - State OR_CAL)
//------------------------------------------------------------------------------------------------------------------------------
// @Abstract: ���ڸ����� OR_CAL ����״̬�£����ݵ�ǰ�ļ���������M_cnt, K_cnt, wt_N_cnt�Ⱦ�������
//            ���ɾ�ȷ�Ķ���ַ(wt_C0_addr)����Weight_Buffer�ж�ȡȨ������PE���С�
//            This section generates precise read addresses (wt_C0_addr) during the OR_CAL state
//            to fetch specific weights from the Weight_Buffer and send them to the PE array,
//            based on the current computation progress (determined by M_cnt, K_cnt, etc.).
//==============================================================================================================================
	// --- �ڲ��ź����� (Internal Signal Declarations) ---
	wire	[12:0]	wt_C0_addr_nxt;       // ��һ�����ڵ�Ȩ�ض���ַ������߼���
	reg		[6:0]	wt_M_cnt;             // ���ڵ�ַ���������ͨ��(M)������
	reg		[8:0]	K_cnt;                // ���ڵ�ַ����ľ������(K)������
	reg		[3:0]	wt_N_cnt;             // ���ڵ�ַ��������ͨ��(N)������
	reg				rd_done_temp;         // rd_done�źŵ��ӳٰ汾������ʱ�����

	// --- Ȩ����Ч�ź����� (Weight Valid Signal Generation) ---

	// ����rd_done��һ���ӳ٣�����ͬ����
	always @(posedge clk_cal)                                                 // ÿ��ʱ�������ش�����
		rd_done_temp <= rd_done;                                              // ��rd_done��ֵ����һ�ġ�HU

	// wt_C0_O_vld: ����PE���е�һ�е�Ȩ��������Ч�źš�
	always @(posedge clk_cal or negedge rst_cal_n)                             
		if(!rst_cal_n)                                                         
			wt_C0_O_vld <= 1'b0;                                               
		else if(rd_done_temp)                                               
			wt_C0_O_vld <= 1'b1;                                              
		else if((!pe_end && (K_cnt>=K)) || !or_cs==OR_CAL)                     
			wt_C0_O_vld <= 1'b0;                                               
			
	// ��Ȩ����Ч�ź�(wt_C0_O_vld)���ģ���������PE���к������е��ӳ���Ч�źš�
	always @(posedge clk_cal or negedge rst_cal_n)                             
		if(!rst_cal_n)                                                        
			begin                                                              
				wt_C1_O_vld <= 1'b0;                                           // �����ӳ��ź����㡣
				wt_C2_O_vld <= 1'b0;                                           
				wt_C3_O_vld <= 1'b0;                                           
				wt_C4_O_vld <= 1'b0;                                           
				wt_C5_O_vld <= 1'b0;                                           
				wt_C6_O_vld <= 1'b0;                                           
				wt_C7_O_vld <= 1'b0;                                           
			end                                                                
		else                                                                   // ������ͨ����㣬
			begin                                                              //
				wt_C1_O_vld <= wt_C0_O_vld;                                    // ����һ����λ�Ĵ���ʽ����ˮ�ߣ�
				wt_C2_O_vld <= wt_C1_O_vld;                                    // ÿһ������Ч�ź�����һ�����ӳ١�
				wt_C3_O_vld <= wt_C2_O_vld;                                    //
				wt_C4_O_vld <= wt_C3_O_vld;                                    //
				wt_C5_O_vld <= wt_C4_O_vld;                                    //
				wt_C6_O_vld <= wt_C5_O_vld;                                    //
				wt_C7_O_vld <= wt_C6_O_vld;                                    //
			end                                                                //

	// --- Ȩ�ض�ȡ��ַ���� (Weight Read Address Generation) ---

	// Ȩ�ص�ַ�������õ��ڲ�������������ͨ����������ͨ·��������ֵ������ͬ����
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
			
	// wt_addr_base: ��ǰ��Ȩ����Weight_Buffer�еĻ���ַƫ�ơ�
	wire [12:0] wt_addr_base;
	assign wt_addr_base = (nn_layer_cnt==1) ? 13'd0     :                      // ��1�����ַΪ0��
						  (nn_layer_cnt==2) ? 13'd32    :                      // ��2�����ַΪ32��
						  (nn_layer_cnt==3) ? 13'd336   : // 32+304
						  (nn_layer_cnt==4) ? 13'd928   :13'd0;// ...+592
						  
											
	// wt_C0_addr_nxt: ��������PE���е�һ�е���һ��Ȩ�ص�ַ��
	assign	wt_C0_addr_nxt = (wt_N_cnt-1)*K*M + (wt_M_cnt-1)*K + K_cnt + wt_addr_base;	// ��ַ��ʽ: (���ͨ��ƫ��)+(����ͨ��ƫ��)+(����ƫ��)+(���ַ)
	
	// wt_C0_addr: ���沢������յ�Ȩ�ض���ַ��
	always @(posedge clk_cal or negedge rst_cal_n)                             
		if(!rst_cal_n)                                                         
			wt_C0_addr <= 13'b0;                                               
		else if((or_cs==OR_FT_WT && or_ns==OR_CAL) || (wt_C0_addr == K*M*N_tiles-1'b1+wt_addr_base)) // ͬ���߼������¼��㿪ʼ���ַ���ʱ��
			wt_C0_addr <= wt_addr_base;                                        // ��ַ��λΪ��ǰ��Ļ���ַ��
		else if(or_cs==OR_DONE)                                                // ���������ɣ�
			wt_C0_addr <= wt_C0_addr;                                          // ��ַ���ֲ��䡣
		else if(or_cs==OR_CAL && wt_C0_O_vld)                                  // ����ڼ���״̬��Ȩ����Ч��
			wt_C0_addr <= wt_C0_addr_nxt;                                      // ����Ϊ��һ������õĵ�ַ��

	// ����Ȩ�ض���ַ(wt_C0_addr)���ģ���������PE���к������е��ӳٵ�ַ��
	always @(posedge clk_cal or negedge rst_cal_n)                             
		if(!rst_cal_n)                                                         
			begin                                                              //
				wt_C1_addr <= 13'b0;                                           // �����ӳٵ�ַ���㡣
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
// V-C. �������ȡ���� (Layer Parameter Fetch Control)
//------------------------------------------------------------------------------------------------------------------------------
// @Abstract: ���ڸ�������"�������ȡ���"�ı�־�ź�(ft_lyr_param_done)��
//            [��Ҫ˵��] �ڴ���Ƶĵ�ǰ�汾�У����������Ĳ�������ͨ�� `assign` ���Ӳ������Ӳ���У�
//            ��˱�ģ�鲻��ִ��ʵ�ʵ��ڴ��ȡ���������Ĺ��ܱ���Ϊ������״̬��(MCU)����
//            FT_PARAM״̬ʱ����������һ��������壬������״̬����ת����һ����
//            [IMPORTANT NOTE] In the current version of this design, all layer parameters are hardcoded
//            via `assign` statements. Therefore, this module no longer performs actual memory reads.
//            Its function is simplified to generating a completion pulse (ft_lyr_param_done) immediately
//            when the main FSM enters the FT_PARAM state, in order to drive the FSM to the next state.
//==============================================================================================================================

	// --- (ԭʼ��Ʋο�) �����Ǳ�ע�͵��ġ�ԭʼ��������ڴ洢�������ź� ---
	// reg	[`DDR_DW-1:0]	nn_param_mem[80:0];       // (ԭʼ���) ���ڴ洢��DDR���ص����в������Ƭ���ڴ档
	// reg	[`DDR_AW-1:0]	nn_lyr_param_addr;        // (ԭʼ���) ָ�� nn_param_mem �ĵ�ַָ�롣

	
//	// --- "α"������������źŵ������߼� ---
	
//	// ft_lyr_param_done: �������ȡ��ɱ�־��
//	always @(posedge clk_cal or negedge rst_cal_n)          // ʱ�������ػ�λ�½��ش�����
//		if(!rst_cal_n)                                     // �첽��λ�߼���
//			begin                                          //
//				//nn_lyr_param_addr <= 0;                   // (ԭʼ���) ��λʱ��ַָ�����㡣
//				ft_lyr_param_done <= 0;                    // ��ɱ�־���㡣
//			end                                            //
//		else if((mc_cs==FT_ECG && mc_ns==FT_PARAM) || (mc_cs==LY_DONE && mc_ns==FT_PARAM)) // ͬ���߼�������״̬��׼������"��ȡ����"(FT_PARAM)״̬ʱ��
//			begin                                          // (�ⷢ���ڵ�һ��ECG���غ󣬻���һ�������ɺ�)
//				// --- (ԭʼ��Ʋο�) ������ԭʼ����л�ִ�е�ʵ�ʶ�ȡ���� ---
//				// nn_lyr_param_addr <= nn_lyr_param_saddr + (nn_layer_cnt-1)*10;	// (ԭʼ���) ���㵱ǰ�������Ƭ���ڴ��еĻ���ַ��
//				// $readmemb("...", nn_param_mem);        // (ԭʼ���-������) ���ı��ļ�����������Ƭ���ڴ档
				
//				// --- ��ǰ�汾�ļ��߼� ---
//				ft_lyr_param_done <= 1;                    // �ڴ�����У����ڲ�����Ӳ���룬���ع���˲ʱ��ɣ���ֱ�ӽ���ɱ�־��λ��
//			end                                            //
//		else                                               // ����������״̬�£�
//			ft_lyr_param_done <= 0;                        // ��ɱ�־����Ϊ�͡�    

endmodule
