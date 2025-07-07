*****************************************************************************
// @Project Name : ECG_CPU 
// @Author       : Lizhiqing
// @Email        : lizhiqing@seu.edu.cn
// @File Name    : Weight_buffer.v
// @Module Name  : weight_buffer_ECG
// @Created Time : 2020-03-23 09:54
//
// @Abstract     : This module is weight buffer of ECG accelerator, it is used to read
//				   or write weight for PEArray further calculation.
//               
//
// Modification History
// ******************************************************************************
// Date				BY           Version         Change Description
// ------------------------------------------------------------------------------
// 2020-03-17  	Lizhiqing         v1.0a           initial version 
// 2020-05-20  	Lizhiqing         v2.0b           Read data from weight buffer
// 2020-06-03	Huangjunguang      v2.0			  delay between vld and data
// ******************************************************************************

`timescale 1ns / 1ns
`define DDR_DW			64
`define DDR_AW			32
`define	burst_len		128
`define	transfer_size	64
`define	wt_bw			8
`define	ecg_bw			8

module Weight_buffer0704(
	// Global Signals
	input					clk_cal,
	input					rst_cal_n,
	input	[3:0]	  layer2weight_cnt,	

	
	// Write Signals 
	input		[12:0]	wt_I_addr,					// data from memory_contrller
	//input				wt_I_vld,					// data valid signal from memory contrller	
	
	// Signal from Mem_Ctrl
	input		[12:0]		wt_C0_addr, wt_C1_addr, wt_C2_addr, wt_C3_addr,
							wt_C4_addr, wt_C5_addr, wt_C6_addr, wt_C7_addr,
							
	input					wt_C0_O_vld, wt_C1_O_vld, wt_C2_O_vld,		//name chaged in 2.0simple
							wt_C3_O_vld, wt_C4_O_vld, wt_C5_O_vld,
							wt_C6_O_vld, wt_C7_O_vld,
	
	// Read Signals
	output	reg			wt_Ovld0,
	output	reg			wt_Ovld1,
	output	reg			wt_Ovld2,
	output	reg			wt_Ovld3,
	output	reg			wt_Ovld4,
	output	reg			wt_Ovld5,
	output	reg			wt_Ovld6,
	output	reg			wt_Ovld7,
	output  [7:0] 		kernel_C0_O,
	output  [7:0] 		kernel_C1_O,
	output  [7:0] 		kernel_C2_O,
	output  [7:0] 		kernel_C3_O,
	output  [7:0] 		kernel_C4_O,
	output  [7:0] 		kernel_C5_O,
	output  [7:0] 		kernel_C6_O,
	output  [7:0] 		kernel_C7_O
	);
			// Write Signals
			// reg	[31:0]		write_flag;
			// reg	[8:0]		KKM8_cnt;
			// reg	[5:0]		Nt_cnt;
			// reg	[5:0]		addr_wr;
			// reg	[`DDR_DW:1]	data_in_temp0;
			// reg				data_in_vld_temp0;
			
			// Read Signals
    //2 times delay---------------------------------------------------------------------
    reg wt_C0_O_vld_1delay;
    reg wt_C1_O_vld_1delay;
    reg wt_C2_O_vld_1delay;
    reg wt_C3_O_vld_1delay;
    reg wt_C4_O_vld_1delay;
    reg wt_C5_O_vld_1delay;
    reg wt_C6_O_vld_1delay;
    reg wt_C7_O_vld_1delay;
    reg wt_C8_O_vld_1delay;
    wire wt_C0_O_vld_1more;
    wire wt_C1_O_vld_1more;
    wire wt_C2_O_vld_1more;
    wire wt_C3_O_vld_1more;
    wire wt_C4_O_vld_1more;
    wire wt_C5_O_vld_1more;
    wire wt_C6_O_vld_1more;
    wire wt_C7_O_vld_1more;
    assign wt_C0_O_vld_1more = wt_C0_O_vld | wt_C0_O_vld_1delay;
    assign wt_C1_O_vld_1more = wt_C1_O_vld | wt_C1_O_vld_1delay;
    assign wt_C2_O_vld_1more = wt_C2_O_vld | wt_C2_O_vld_1delay;
    assign wt_C3_O_vld_1more = wt_C3_O_vld | wt_C3_O_vld_1delay;
    assign wt_C4_O_vld_1more = wt_C4_O_vld | wt_C4_O_vld_1delay;
    assign wt_C5_O_vld_1more = wt_C5_O_vld | wt_C5_O_vld_1delay;
    assign wt_C6_O_vld_1more = wt_C6_O_vld | wt_C6_O_vld_1delay;
    assign wt_C7_O_vld_1more = wt_C7_O_vld | wt_C7_O_vld_1delay;
    
    //延迟两拍，测试成功
    always @(posedge clk_cal or negedge rst_cal_n) begin
            if (rst_cal_n == 1'b0) begin             
                wt_C0_O_vld_1delay<=1'b0;
    			wt_C1_O_vld_1delay<=1'b0;
                wt_C2_O_vld_1delay<=1'b0;
                wt_C3_O_vld_1delay<=1'b0;
                wt_C4_O_vld_1delay<=1'b0;
                wt_C5_O_vld_1delay<=1'b0;
                wt_C6_O_vld_1delay<=1'b0;
                wt_C7_O_vld_1delay<=1'b0;
            end
    		else begin	
    			wt_C0_O_vld_1delay<=wt_C0_O_vld;
    			wt_C1_O_vld_1delay<=wt_C1_O_vld;
    			wt_C2_O_vld_1delay<=wt_C2_O_vld;
    			wt_C3_O_vld_1delay<=wt_C3_O_vld;
    			wt_C4_O_vld_1delay<=wt_C4_O_vld;
    			wt_C5_O_vld_1delay<=wt_C5_O_vld;
    			wt_C6_O_vld_1delay<=wt_C6_O_vld;
    			wt_C7_O_vld_1delay<=wt_C7_O_vld;
    		end
    end
    
    	always @(posedge clk_cal or negedge rst_cal_n)
    		if(!rst_cal_n)
    			wt_Ovld0 <= 1'b0;
    		else
    			wt_Ovld0 <= wt_C0_O_vld_1delay;
    
    	always @(posedge clk_cal or negedge rst_cal_n)
    		if(!rst_cal_n)
    			begin
    				wt_Ovld1 <= 0;
    				wt_Ovld2 <= 0;
    				wt_Ovld3 <= 0;
    				wt_Ovld4 <= 0;
    				wt_Ovld5 <= 0;
    				wt_Ovld6 <= 0;
    				wt_Ovld7 <= 0;
    			end
    		else
    			begin
    				wt_Ovld1 <= wt_Ovld0;
    				wt_Ovld2 <= wt_Ovld1;
    				wt_Ovld3 <= wt_Ovld2;
    				wt_Ovld4 <= wt_Ovld3;
    				wt_Ovld5 <= wt_Ovld4;
    				wt_Ovld6 <= wt_Ovld5;
    				wt_Ovld7 <= wt_Ovld6;
    			end			
    
    //这里直接用ip核代替
    u_weight_bank0 weight_bank0 (
      .clka(clk_cal),    // input wire clka
      .ena(1'b1),      // input wire ena
      .wea(1'b0),      // input wire [0 : 0] wea，在这里固定为读数据,1-bit write enable for the entire byte
      .addra(wt_I_addr),  // input wire [12 : 0] addra
      .dina(8'b0),    // input wire [7 : 0] dina
      .clkb(clk_cal),    // input wire clkb
      //.enb(layer2weight_cnt_ns[0]&&rdena),      // input wire enb
      .enb(wt_C0_O_vld_1more),      // input wire enb
      .addrb(wt_C0_addr),  // input wire [12 : 0] addrb
      .doutb(kernel_C0_O)  // output wire [7 : 0] doutb
    );
    
    u_weight_bank1 weight_bank1 (
      .clka(clk_cal),    // input wire clka
      .ena(1'b1),      // input wire ena
      .wea(1'b0),      // input wire [0 : 0] wea，在这里固定为读数据
      .addra(wt_I_addr),  // input wire [12 : 0] addra
      .dina(8'b0),    // input wire [7 : 0] dina
      .clkb(clk_cal),    // input wire clkb
      //.enb(layer2weight_cnt_ns[0]&&rdena),      // input wire enb
      .enb(wt_C1_O_vld_1more),      // input wire enb
      .addrb(wt_C1_addr),  // input wire [12 : 0] addrb
      .doutb(kernel_C1_O)  // output wire [7 : 0] doutb
    );
    
    u_weight_bank2 weight_bank2 (
      .clka(clk_cal),    // input wire clka
      .ena(1'b1),      // input wire ena
      .wea(1'b0),      // input wire [0 : 0] wea，在这里固定为读数据
      .addra(wt_I_addr),  // input wire [12 : 0] addra
      .dina(8'b0),    // input wire [7 : 0] dina
      .clkb(clk_cal),    // input wire clkb
      //.enb(layer2weight_cnt_ns[0]&&rdena),      // input wire enb
      .enb(wt_C2_O_vld_1more),      // input wire enb
      .addrb(wt_C2_addr),  // input wire [12 : 0] addrb
      .doutb(kernel_C2_O)  // output wire [7 : 0] doutb
    );
    u_weight_bank3 weight_bank3 (
      .clka(clk_cal),    // input wire clka
      .ena(1'b1),      // input wire ena
      .wea(1'b0),      // input wire [0 : 0] wea，在这里固定为读数据
      .addra(wt_I_addr),  // input wire [12 : 0] addra
      .dina(8'b0),    // input wire [7 : 0] dina
      .clkb(clk_cal),    // input wire clkb
      //.enb(layer2weight_cnt_ns[0]&&rdena),      // input wire enb
      .enb(wt_C3_O_vld_1more),      // input wire enb
      .addrb(wt_C3_addr),  // input wire [12 : 0] addrb
      .doutb(kernel_C3_O)  // output wire [7 : 0] doutb
    );
    
    u_weight_bank4 weight_bank4 (
      .clka(clk_cal),    // input wire clka
      .ena(1'b1),      // input wire ena
      .wea(1'b0),      // input wire [0 : 0] wea，在这里固定为读数据
      .addra(wt_I_addr),  // input wire [12 : 0] addra
      .dina(8'b0),    // input wire [7 : 0] dina
      .clkb(clk_cal),    // input wire clkb
      //.enb(layer2weight_cnt_ns[0]&&rdena),      // input wire enb
      .enb(wt_C4_O_vld_1more),      // input wire enb
      .addrb(wt_C4_addr),  // input wire [12 : 0] addrb
      .doutb(kernel_C4_O)  // output wire [7 : 0] doutb
    );
    
    u_weight_bank5 weight_bank5 (
      .clka(clk_cal),    // input wire clka
      .ena(1'b1),      // input wire ena
      .wea(1'b0),      // input wire [0 : 0] wea，在这里固定为读数据
      .addra(wt_I_addr),  // input wire [12 : 0] addra
      .dina(8'b0),    // input wire [7 : 0] dina
      .clkb(clk_cal),    // input wire clkb
      //.enb(layer2weight_cnt_ns[0]&&rdena),      // input wire enb
      .enb(wt_C5_O_vld_1more),      // input wire enb
      .addrb(wt_C5_addr),  // input wire [12 : 0] addrb
      .doutb(kernel_C5_O)  // output wire [7 : 0] doutb
    );
    
    u_weight_bank6 weight_bank6 (
      .clka(clk_cal),    // input wire clka
      .ena(1'b1),      // input wire ena
      .wea(1'b0),      // input wire [0 : 0] wea，在这里固定为读数据
      .addra(wt_I_addr),  // input wire [12 : 0] addra
      .dina(8'b0),    // input wire [7 : 0] dina
      .clkb(clk_cal),    // input wire clkb
      //.enb(layer2weight_cnt_ns[0]&&rdena),      // input wire enb
      .enb(wt_C6_O_vld_1more),      // input wire enb
      .addrb(wt_C6_addr),  // input wire [12 : 0] addrb
      .doutb(kernel_C6_O)  // output wire [7 : 0] doutb
    );
    
    u_weight_bank7 weight_bank7 (
      .clka(clk_cal),    // input wire clka
      .ena(1'b1),      // input wire ena
      .wea(1'b0),      // input wire [0 : 0] wea，在这里固定为读数据
      .addra(wt_I_addr),  // input wire [12 : 0] addra
      .dina(8'b0),    // input wire [7 : 0] dina
      .clkb(clk_cal),    // input wire clkb
      //.enb(layer2weight_cnt_ns[0]&&rdena),      // input wire enb
      .enb(wt_C7_O_vld_1more),      // input wire enb
      .addrb(wt_C7_addr),  // input wire [12 : 0] addrb
      .doutb(kernel_C7_O)  // output wire [7 : 0] doutb
    );


endmodule
