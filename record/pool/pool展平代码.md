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

我们来对刚才的高强度讨论和代码开发做一个系统性的**阶段性总结**。

这份总结可以作为你毕业设计文档或论文中“硬件架构设计 - 数据重排单元”部分的素材。

---

### 1. 项目背景与需求 (Context)

- **项目**：基于 CAN 总线入侵检测的 CNN 硬件加速器。
    
- **模块**：`IOB_Reorder` (数据重排单元)。
    
- **位置**：位于计算阵列 (PE/Pooling) 与 片上存储 (IOB) 之间。
    
- **核心任务**：将计算模块输出的“乱序”或“分块”数据，整理成下一层（如全连接层 FC）所需要的“连续、线性”数据格式，以便高效存取。
    

### 2. 遇到的核心挑战 (The Challenge)

针对 **Pooling (池化) 层** 的输出处理，我们遇到了特殊的数据流错配问题：

1. **输入侧 (Scatter - 乱序)**：
    
    - 由于硬件并行度限制，Pooling 模块输出数据的顺序非常复杂：**“先发 3 个窗口点 $\rightarrow$ 切换 4 个通道组 $\rightarrow$ 循环 3 轮”**。
        
    - 这导致数据在时间上是破碎的，无法直接写入地址连续的内存。
        
2. **输出侧 (Gather - 线性)**：
    
    - 下一层网络 (FC) 需要的是**完全展平 (Flattened)** 的数据流。
        
    - 即：`Ch0_p0...p8` $\rightarrow$ `Ch1_p0...p8`...
        
    - 且要求中间**无气泡**，总线利用率 100%。
        

### 3. 解决方案架构 (The Solution)

我们设计了一个 **`Pool_Reorder_SingleBuf`** 核心模块，采用 **“存储-转发 (Store-and-Forward)”** 机制。

#### A. 存储架构 (Memory)

- **单缓冲 (Single Buffer)**：由于数据流是按“张 (Tile)”处理的（一次处理 288 个点），我们放弃了面积较大的双缓冲（Ping-Pong），采用**半双工模式**。
    
- **容量**：`[32 通道] x [9 空间点]`。
    

#### B. 写入逻辑 (Smart Scatter)

- **三级计数器**：使用 `step_cnt` (窗口点)、`group_cnt` (通道组)、`round_cnt` (循环轮次) 精确追踪输入数据的时序。
    
- **坐标映射**：实时计算 `Base_Channel` 和 `Current_Point`，将乱序飞来的数据精确填入二维数组的正确格子中。
    

#### C. 读取逻辑 (Gearbox / Flattening)

- **数学展平**：将二维数组视为一维线性空间。
    
- **跨界拼接**：利用 `/ 9` (除法) 和 `% 9` (取模) 算法，实现跨通道的数据拼接。即使 Ch0 只有 9 个点，也能和 Ch1 无缝连接，凑满 8-Lane 的输出总线。
    

#### D. 握手机制 (Handshake)

- **`ready_in` 信号**：在读取阶段拉低，通知上游 Pooling 模块暂停发送，防止数据溢出。
    

### 4. 调试与验证 (Verification)

在仿真过程中，我们发现并解决了一个关键 Bug：

- **问题**：Valid-Data Misalignment (有效信号错位)。
    
    - 现象：TB 报错，显示接收到的数据比期望值“慢了一拍”或“错位”。
        
    - 原因：RAM 读取存在固有延迟，导致 `valid_out` 拉高时，数据总线上还是旧值。
        
- **修复**：在 Verilog 中对 `valid_out` 进行了打拍处理（寄存器输出），确保它与 RAM 读出的数据严格对齐。
    
- **结果**：Testbench (`tb_pool_single.v`) 最终**全线通过**。日志显示数据流完美的按照 `Ch0_p0` 到 `Ch31_p8` 的顺序输出。
    

### 5. 最终代码结构 (Top Level)

最终的顶层模块 `IOB_Reorder_Top` 结构清晰：

- **`IOB_Reorder_Top`** (顶层壳子)
    
    - **`Conv_Logic`**: 处理 $8 \times 8$ 卷积层的转置（直接集成或子模块）。
        
    - **`Pool_Reorder_SingleBuf`**: 处理 $3 \times 3$ 池化层的乱序重排与展平（本次核心成果）。
        
    - **`Mux`**: 根据 `mode` 信号选择输出路径。
        

---

### 接下来你可以做的事情 (Next Steps)

1. **集成**：将这个经过验证的 `IOB_Reorder_Top` 放入你的整个加速器工程中。
    
2. **连接 IOB**：编写 IOB 的**写控制逻辑**。
    
    - 现在 Reorder 输出的数据已经很完美了，IOB 的写逻辑会变得非常简单：只需要一个线性递增的地址计数器即可（0, 1, 2... 35）。
        
3. **连接 FC**：确认 FC 层的权重存储顺序与我们的输出顺序（先通道内，后通道间）一致，如果不一致，记得调整权重的 `.coe` 文件。
    

这部分工作非常扎实，既解决了复杂的工程痛点，又节省了硬件资源。你可以稍微休息一下，准备进行下一步的集成工作。