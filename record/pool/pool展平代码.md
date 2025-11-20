// =====================================================================
// 32 通道 pool 输出缓冲：收 3x3x32 = 288 个数据，展平成 8 字节一拍写回 IOB
// - 上游：8 通道 pool 顶层，一次给 8 个通道的 pool_data + pool_valid
// - 通道分组：用 ft_N_cnt 区分 0..7 / 8..15 / 16..23 / 24..31
// - 每个通道 9 个数（3x3），内部先按 idx=ch*9+win_idx 存到 buf[0..287]
// - 全部收完后自动进入 FLUSH 状态，连续 36 拍，每拍 8 字节 IOB_Data_I* 有效
// =====================================================================
`timescale 1ns/1ns

module back_buffer #(
    parameter DATAW   = 8,
    parameter N_CH    = 32,
    parameter WIN_NUM = 9                         // 每通道 9 个数据
)(
    input                       clk,
    input                       rst_n,

    // 标记当前卷积核循环（通道组）
    // 0001 -> ch 0..7
    // 0010 -> ch 8..15
    // 0011 -> ch 16..23
    // 0100 -> ch 24..31
    input       [3:0]           ft_N_cnt,

    // 来自 8 通道 pool 单元的输出
    input       [7:0]           pool_valid,       // 8 通道同时 valid，一般同拍
    input signed [DATAW-1:0]    pool_data0,
    input signed [DATAW-1:0]    pool_data1,
    input signed [DATAW-1:0]    pool_data2,
    input signed [DATAW-1:0]    pool_data3,
    input signed [DATAW-1:0]    pool_data4,
    input signed [DATAW-1:0]    pool_data5,
    input signed [DATAW-1:0]    pool_data6,
    input signed [DATAW-1:0]    pool_data7,

    // 写回 IOB（接 In_Out_Buffer 的 IOB_Data_I*）
    output reg                  IOB_Data_I_vld,
    output reg signed [DATAW-1:0] IOB_Data_I0,
    output reg signed [DATAW-1:0] IOB_Data_I1,
    output reg signed [DATAW-1:0] IOB_Data_I2,
    output reg signed [DATAW-1:0] IOB_Data_I3,
    output reg signed [DATAW-1:0] IOB_Data_I4,
    output reg signed [DATAW-1:0] IOB_Data_I5,
    output reg signed [DATAW-1:0] IOB_Data_I6,
    output reg signed [DATAW-1:0] IOB_Data_I7,

    // 状态辅助信号
    output reg                  collecting_done,  // 288 个数收集完 1 拍
    output reg                  flushing,         // flush 阶段拉高
    output reg                  flush_done        // 36 个 word 写完 1 拍
);

    localparam TOT_ELE  = N_CH * WIN_NUM;         // 32*9 = 288
    localparam IDXW     = 9;                      // log2(288) ~= 8.2，取 9bit

    // 内部缓冲：3×3×32 展平成 288 深度的小 RAM/寄存器
    reg signed [DATAW-1:0] buffer [0:TOT_ELE-1];

    // 当前正在收的元素计数
    reg [IDXW:0]   collect_cnt;                   // 最多 288
    reg [3:0]      win_idx;                       // 当前通道组的 window 序号 0..8
    reg [3:0]      last_ft;

    // flush 时读索引
    reg [IDXW:0]   out_idx;

    // FSM
    localparam S_IDLE     = 2'd0;
    localparam S_COLLECT  = 2'd1;
    localparam S_FLUSH    = 2'd2;

    reg [1:0] state, next_state;

    // 判断有没有任何通道 valid
    wire any_pool_valid = |pool_valid;

    // -----------------------------
    // base_ch 计算：由 ft_N_cnt 决定当前 8 通道的全局通道号起点
    // -----------------------------
    reg [5:0] base_ch; // 0/8/16/24

    always @(*) begin
        case (ft_N_cnt)
            4'b0001: base_ch = 6'd0;
            4'b0010: base_ch = 6'd8;
            4'b0011: base_ch = 6'd16;
            4'b0100: base_ch = 6'd24;
            default: base_ch = 6'd0;
        endcase
    end

    // -----------------------------
    // FSM 状态跳转
    // -----------------------------
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                // 一旦开始收到 pool_valid，就进入 COLLECT
                if (any_pool_valid)
                    next_state = S_COLLECT;
            end
            S_COLLECT: begin
                // 收满 288 个以后进入 FLUSH
                if (collect_cnt == TOT_ELE)
                    next_state = S_FLUSH;
            end
            S_FLUSH: begin
                // 写完 288 个（每拍 8 个）回到 IDLE
                if (out_idx == TOT_ELE)
                    next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // -----------------------------
    // 主时序：收集 + flush + 计数
    // -----------------------------
    integer ch_local;
    integer idx_calc;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            win_idx         <= 4'd0;
            last_ft         <= 4'd0;
            collect_cnt     <= 0;
            out_idx         <= 0;
            IOB_Data_I_vld  <= 1'b0;
            IOB_Data_I0     <= 0;
            IOB_Data_I1     <= 0;
            IOB_Data_I2     <= 0;
            IOB_Data_I3     <= 0;
            IOB_Data_I4     <= 0;
            IOB_Data_I5     <= 0;
            IOB_Data_I6     <= 0;
            IOB_Data_I7     <= 0;
            collecting_done <= 1'b0;
            flushing        <= 1'b0;
            flush_done      <= 1'b0;
            // buf 清零（仿真友好，可选）
            for (i = 0; i < TOT_ELE; i = i+1)
                buffer[i] <= 0;
        end else begin
            state           <= next_state;

            // 默认拉低单拍信号
            collecting_done <= 1'b0;
            flush_done      <= 1'b0;
            IOB_Data_I_vld  <= 1'b0;

            case (state)
                // ----------------- IDLE -----------------
                S_IDLE: begin
                    flushing    <= 1'b0;
                    out_idx     <= 0;
                    collect_cnt <= 0;
                    win_idx     <= 0;
                    last_ft     <= ft_N_cnt;
                    // 等待 any_pool_valid，跳转在 next_state 里
                end

                // ----------------- COLLECT 收集阶段 -----------------
                S_COLLECT: begin
                    flushing <= 1'b0;

                    if (any_pool_valid) begin
                        // ft_N_cnt 变化，说明切换到下一组通道，从 0 重新起一个 3x3
                        if (ft_N_cnt != last_ft) begin
                            win_idx <= 0;
                            last_ft <= ft_N_cnt;
                        end else begin
                            // 同一组通道的下一个窗口
                            // win_idx: 0..8
                            if (win_idx == (WIN_NUM-1))
                                win_idx <= 0;
                            else
                                win_idx <= win_idx + 1;
                        end

                        // 8 通道写入 buf
                        // ch_local = 0..7，对应 pool_data0..7
                        // ch_global = base_ch + ch_local
                        // idx = ch_global * 9 + win_idx
                        for (ch_local = 0; ch_local < 8; ch_local = ch_local + 1) begin
                            idx_calc = (base_ch + ch_local) * WIN_NUM + win_idx;
                            case (ch_local)
                                0: if (pool_valid[0]) buffer[idx_calc] <= pool_data0;
                                1: if (pool_valid[1]) buffer[idx_calc] <= pool_data1;
                                2: if (pool_valid[2]) buffer[idx_calc] <= pool_data2;
                                3: if (pool_valid[3]) buffer[idx_calc] <= pool_data3;
                                4: if (pool_valid[4]) buffer[idx_calc] <= pool_data4;
                                5: if (pool_valid[5]) buffer[idx_calc] <= pool_data5;
                                6: if (pool_valid[6]) buffer[idx_calc] <= pool_data6;
                                7: if (pool_valid[7]) buffer[idx_calc] <= pool_data7;
                            endcase
                        end

                        // 这一拍实际写入的个数（假设 8 个通道都 valid）
                        collect_cnt <= collect_cnt + 8;

                        if (collect_cnt + 8 == TOT_ELE) begin
                            collecting_done <= 1'b1; // 收集完成单拍
                        end
                    end
                end

                // ----------------- FLUSH 展平写 IOB -----------------
                S_FLUSH: begin
                    flushing <= 1'b1;

                    if (out_idx < TOT_ELE) begin
                        IOB_Data_I_vld <= 1'b1;

                        IOB_Data_I0 <= buffer[out_idx + 0];
                        IOB_Data_I1 <= buffer[out_idx + 1];
                        IOB_Data_I2 <= buffer[out_idx + 2];
                        IOB_Data_I3 <= buffer[out_idx + 3];
                        IOB_Data_I4 <= buffer[out_idx + 4];
                        IOB_Data_I5 <= buffer[out_idx + 5];
                        IOB_Data_I6 <= buffer[out_idx + 6];
                        IOB_Data_I7 <= buffer[out_idx + 7];

                        out_idx <= out_idx + 8;

                        if (out_idx + 8 == TOT_ELE) begin
                            flush_done <= 1'b1;  // 全部 288 写完
                        end
                    end else begin
                        // 防御：写完后保持 idle 状态
                        IOB_Data_I_vld <= 1'b0;
                    end
                end

                default: begin
                    // 不写特殊逻辑，保持默认
                end
            endcase
        end
    end

endmodule
