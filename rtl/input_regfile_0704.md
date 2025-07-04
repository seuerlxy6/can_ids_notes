```
// =============================================================================
//  Input_Regfile  ── 修正版 2025-07-06
//  关键改动：
//    1. 写地址 = kh_cnt * ROW_BLK * 8 + Bm_cnt * 8       ← 行号进地址
//    2. 参数 ROW_BLK 自动由 Hu_w 推导                   ← 行宽可改
//    3. 读地址基 = kh_cnt_r * ROW_BLK * 8                ← 三行环形
// =============================================================================
`timescale 1ns/1ps
`define BM 8
`define R  16

module input_reg_0703 (

    input              clk_cal,
    input              rst_cal_n,

    // === 写侧 ===
    input  [7:0]       IR_Data_I0, IR_Data_I1, IR_Data_I2, IR_Data_I3,
                       IR_Data_I4, IR_Data_I5, IR_Data_I6, IR_Data_I7,
    input              IR_Data_I_vld,
    input  [3:0]       nn_layer_cnt,
    input  [5:0]       Bm_cnt_in,               // 0 … ROW_BLK-1
    input  [1:0]       kh_cnt_in,               // 0 … K_H-1

    // === 读侧 ===
    input  [7:0]       K,                       // 核宽
    input  [7:0]       S,                       // 步长
    input              Weight_Data_Ovld,
    input              pe_end,

    output reg [7:0]   IR_Data_O0,  IR_Data_O1,  IR_Data_O2,  IR_Data_O3,
                       IR_Data_O4,  IR_Data_O5,  IR_Data_O6,  IR_Data_O7,
                       IR_Data_O8,  IR_Data_O9,  IR_Data_Oa,  IR_Data_Ob,
                       IR_Data_Oc,  IR_Data_Od,  IR_Data_Oe,  IR_Data_Of,
    output reg         IR_Data_O_vld
);
    parameter    HU_W_MAX   = 33;               // Regfile 最大行宽（Byte）
    parameter    K_H        = 3 ;               // 卷积核高
    // ---------- 行宽推导 ----------
    localparam integer ROW_BLK = (HU_W_MAX + `BM - 1) / `BM;   // ceil(Hu_w/8)
    localparam integer RF_SIZE = ROW_BLK * `BM * K_H;          // 至少能放 K_H 行

    // ---------- Regfile ----------
    reg [7:0] Regfile [RF_SIZE-1:0];

    // ---------- 信号打拍 ----------
    reg IR_vld_d1, Wgt_vld_d1, Wgt_vld_d2, pe_end_d1;
    always @(posedge clk_cal or negedge rst_cal_n) begin
        if(!rst_cal_n) begin
            IR_vld_d1   <= 0;
            Wgt_vld_d1  <= 0;
            Wgt_vld_d2  <= 0;
            pe_end_d1   <= 0;
        end else begin
            IR_vld_d1   <= IR_Data_I_vld;
            Wgt_vld_d1  <= Weight_Data_Ovld;
            Wgt_vld_d2  <= Wgt_vld_d1;
            pe_end_d1   <= pe_end;
        end
    end

    // ---------- 写地址 ----------
    wire [7:0] wr_addr =
        kh_cnt_in * ROW_BLK * `BM+   // 行基址
        Bm_cnt_in * `BM;              // 列块偏移
//    reg [7:0] wr_addr_r;    
//    always @(posedge clk_cal or negedge rst_cal_n)
//		if(!rst_cal_n)
//			wr_addr_r <= 8'b0;
//		else if(IR_Data_I_vld)
//			wr_addr_r <= kh_cnt_in * ROW_BLK * `BM+   // 行基址
//                       Bm_cnt_in * `BM;              // 列块偏移
//		else
//			wr_addr_r <= 8'b0;
    integer i;
    always @(posedge clk_cal)
        if(!rst_cal_n)
			begin
				for(i=0;i<160;i=i+1)
					Regfile[i] <= 0;
			end
		else if(IR_Data_I_vld) // && (Bm_cnt!=`Bm))
				begin
					Regfile[wr_addr+0] <= IR_Data_I0;
					Regfile[wr_addr+1] <= IR_Data_I1;
					Regfile[wr_addr+2] <= IR_Data_I2;
					Regfile[wr_addr+3] <= IR_Data_I3;
					Regfile[wr_addr+4] <= IR_Data_I4;
					Regfile[wr_addr+5] <= IR_Data_I5;
					Regfile[wr_addr+6] <= IR_Data_I6;
					Regfile[wr_addr+7] <= IR_Data_I7;
				end

    // ---------- 读地址 ----------
    reg [7:0] rd_off;                 // 窗口内横向偏移
    reg [1:0] kh_cnt_r;               // 行号延迟寄存
    always @(posedge clk_cal or negedge rst_cal_n) begin
        if(!rst_cal_n) begin
            rd_off   <= 0;
            kh_cnt_r <= 0;
        end else if(pe_end_d1) begin   // 一批 Hu 完成
            rd_off   <= 0;
            kh_cnt_r <= 0;
        end else if(Wgt_vld_d2) begin
            if(rd_off == K_H-1) begin
                rd_off   <= 0;
                kh_cnt_r <= (kh_cnt_r==K_H-1) ? 0 : kh_cnt_r+1;
            end else
                rd_off <= rd_off + 1;
        end
    end

    wire [7:0] rd_base = kh_cnt_r * ROW_BLK * `BM + rd_off;

    // ---------- 输出到 PE ----------
    always @(posedge clk_cal or negedge rst_cal_n) begin
        if(!rst_cal_n) begin
            {IR_Data_O0,IR_Data_O1,IR_Data_O2,IR_Data_O3,
             IR_Data_O4,IR_Data_O5,IR_Data_O6,IR_Data_O7,
             IR_Data_O8,IR_Data_O9,IR_Data_Oa,IR_Data_Ob,
             IR_Data_Oc,IR_Data_Od,IR_Data_Oe,IR_Data_Of} <= {128{1'b0}};
            IR_Data_O_vld <= 0;
        end
        else begin
            IR_Data_O_vld <= Wgt_vld_d1;              // 数据与权重同拍输出
            if(Wgt_vld_d1) begin
                IR_Data_O0 <= Regfile[rd_base +  0*S];
                IR_Data_O1 <= Regfile[rd_base +  1*S];
                IR_Data_O2 <= Regfile[rd_base +  2*S];
                IR_Data_O3 <= Regfile[rd_base +  3*S];
                IR_Data_O4 <= Regfile[rd_base +  4*S];
                IR_Data_O5 <= Regfile[rd_base +  5*S];
                IR_Data_O6 <= Regfile[rd_base +  6*S];
                IR_Data_O7 <= Regfile[rd_base +  7*S];
                IR_Data_O8 <= Regfile[rd_base +  8*S];
                IR_Data_O9 <= Regfile[rd_base +  9*S];
                IR_Data_Oa <= Regfile[rd_base + 10*S];
                IR_Data_Ob <= Regfile[rd_base + 11*S];
                IR_Data_Oc <= Regfile[rd_base + 12*S];
                IR_Data_Od <= Regfile[rd_base + 13*S];
                IR_Data_Oe <= Regfile[rd_base + 14*S];
                IR_Data_Of <= Regfile[rd_base + 15*S];
            end
        end
    end
endmodule

```