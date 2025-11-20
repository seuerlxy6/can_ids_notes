module Pool_Reorder #(
    parameter DATA_WIDTH = 8,
    parameter CH_PARALLEL = 8
)(
    input  wire                         clk,
    input  wire                         rst_n,
    
    // 上游输入
    input  wire                         valid_in,
    input  wire [CH_PARALLEL*DATA_WIDTH-1:0] data_in,
    output wire                         ready_in,  // 关键：通知上游暂停
    
    // 下游输出
    output reg                          valid_out,
    output   [CH_PARALLEL*DATA_WIDTH-1:0] data_out
);

    // ============================================================
    // 1. 单一 Buffer 定义
    // ============================================================
    // 32个通道 * 9个点
    reg [DATA_WIDTH-1:0] mem [0:31][0:8];

    // 状态定义
    localparam ST_IDLE  = 2'd0; // 空闲/接收中
    localparam ST_READ  = 2'd1; // 输出中
    
    reg [1:0] state;

    // ============================================================
    // 2. 写入逻辑 (计数器保持不变)
    // ============================================================
    reg [1:0] step_cnt;  // 0-2
    reg [1:0] group_cnt; // 0-3
    reg [1:0] round_cnt; // 0-2

    wire [DATA_WIDTH-1:0] in_unpacked [0:7];
    //数据分包
    genvar i;
    generate
        for (i=0; i<8; i=i+1) begin 
        assign in_unpacked[i] = data_in[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH];
        end
    endgenerate

    // 坐标计算
    wire [4:0] base_ch = {group_cnt, 3'b000}; 
    //×3
    wire [3:0] current_pt = {round_cnt, 1'b0} + round_cnt + step_cnt; 
    
    // 握手信号：只有在 IDLE 状态才允许写入
    assign ready_in = (state == ST_IDLE);
    wire read_done;
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_cnt <= 0; group_cnt <= 0; round_cnt <= 0;
            state <= ST_IDLE;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (valid_in) begin
                        // --- 写入数据 ---
                        for (j = 0; j < 8; j = j + 1) begin
                            mem[base_ch + j][current_pt] <= in_unpacked[j];
                        end

                        // --- 计数器逻辑 ---
                        if (step_cnt == 2) begin
                            step_cnt <= 0;
                            if (group_cnt == 3) begin
                                group_cnt <= 0;
                                if (round_cnt == 2) begin
                                    // 36拍写满，进入读取状态
                                    round_cnt <= 0;
                                    state <= ST_READ; 
                                end else begin
                                    round_cnt <= round_cnt + 1;
                                end
                            end else begin
                                group_cnt <= group_cnt + 1;
                            end
                        end else begin
                            step_cnt <= step_cnt + 1;
                        end
                    end
                end

                ST_READ: begin
                    // 等待读取逻辑完成 (由下面的 read_done 信号触发)
                    // 这里只负责状态跳转
                    if (read_done) begin
                        state <= ST_IDLE;
                    end
                end
            endcase
        end
    end

    // ============================================================
    // 3. 读取逻辑 (Gearbox 展平)
    // ============================================================
    reg [8:0] total_read_cnt; // 0 ~ 287
    reg [5:0] out_cycle_cnt;  // 0 ~ 35
    

    // 只有当状态机切到 ST_READ 且 计数器没跑完时，才有效
    assign read_done = (state == ST_READ) && (out_cycle_cnt == 35);

    reg [DATA_WIDTH-1:0] out_pack [0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_read_cnt <= 0;
            out_cycle_cnt <= 0;
            valid_out <= 0;
        end else begin
            if (state == ST_READ) begin
                valid_out <= 1;

                // --- 展平读取 ---
                for (j = 0; j < 8; j = j + 1) begin
                    // 简单的算术映射，综合器会优化常数除法
                    out_pack[j] <= mem[(total_read_cnt + j) / 9][(total_read_cnt + j) % 9];
                end

                // 计数器
                if (out_cycle_cnt == 35) begin
                    // 读完了，复位计数器
                    total_read_cnt <= 0;
                    out_cycle_cnt <= 0;
                    // 此时 read_done 会拉高，主状态机下个周期跳回 IDLE
                end else begin
                    total_read_cnt <= total_read_cnt + 8;
                    out_cycle_cnt <= out_cycle_cnt + 1;
                end
            end else begin
                valid_out <= 0;
                // 保持计数器复位状态
                total_read_cnt <= 0;
                out_cycle_cnt <= 0;
            end
        end
    end

    // 输出连线
    generate
        for (i=0; i<8; i=i+1) begin
         assign data_out[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] = out_pack[i];
         end
    endgenerate

endmodule