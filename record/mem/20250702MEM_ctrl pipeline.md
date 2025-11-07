## 1、layer1 can数据输入
![[Pasted image 20250702214719.png]]
主状态机--3——FT_ECG，从ddr读数据到iob
8个数据一组写入，从0地址开始，行主序写入64×64×3=4096的一张图
## 2、取参数、取权重
![[Pasted image 20250702215230.png]]
参数硬编码，这里的取参数是伪
第一层权重3×3×3有8个，直接放到8个bank里面，wt_I_addr从0-26
## 3、layer1-2的imap写出到input regfile
![[Pasted image 20250702215610.png]]
读第一层的数据，hu=33×3，一批数据01234----89abc----def...-----rd_done----进入regfile----rd_addr=20是第一批hu进入regfile的最后一个数据
rd_done---rd_done_temp读权重wt_C0_O_Vld有效的同时，读出第一列的第一个权重0，第一列一共读0-8共九个权重，这次计算产生的部分和存在pe单元中，后续列流水读出
![[Pasted image 20250702220103.png]]
![[Pasted image 20250702220423.png]]
到这才算是完成3个通道的乘累加得到omap的一组（16×8个）像素点
## 4、layer1-2的omap从output regfile写回
![[Pasted image 20250702220648.png]]
写回相对简单，三层循环，32×32×8的图像，先按通道走1-8，8个8个写，一行32个点，要走4次走完一行ox_cnt：0-3，然后换行纵向oy_cnt：0-31，
这样算是完成一次计算

#### 1. 响应 `mc_cs[IDLE]`：系统初始化

- **SPU 命令:** `mc_cs` 处于 `IDLE` 或 `FT_ADDR`。
    
- **Mem_Ctrl 行为:**
    
    - `SPU` 等待 `memct_init_cmplt` 信号。
        
    - 你的 `Mem_Ctrl` 代码：`always @(...) memct_init_cmplt <= 1'b1;` (复位后)
        
    - **分析:** 这是一个**“伪握手”**。`Mem_Ctrl` 只是简单地告诉 `SPU`：“我永远准备好了”。这呼应了我们之前的讨论，`FT_ADDR` 状态（和 `ft_all_addr_done`）在当前设计中是冗余的，因为没有真正的、需要时间的初始化过程。
        

#### 2. 响应 `mc_cs[FT_ECG]`：加载 CAN 数据

- **SPU 命令:** `SPU` 进入 `FT_ECG` 状态，等待 `ft_can_done`。
    
- **Mem_Ctrl 行为:**
    
    - 它**侦听** `Data_I_vld_CAN` 信号 (来自外部 CAN/SPI 模块)。
        
    - 它**生成** `wr_addr` (`assign wr_addr = (mc_cs[FT_ECG]) ? ft_can_cnt : ...`)，这个地址基于 `ft_can_cnt` 计数器。
        
    - 它**生成** `ft_can_done` 信号，当 `ft_can_cnt` 达到 `ft_can_times` (由 `can_len` 计算得出) 时拉高。
        
    - **分析:** `Mem_Ctrl` 此时充当一个简单的“DMA 控制器”，它为 `IOBuffer` 提供正确的**写地址**，同时告诉 `SPU` 什么时候数据传完了。
        

#### 3. 响应 `mc_cs[FT_PARAM]`：加载层参数

- **SPU 命令:** `SPU` 进入 `FT_PARAM` 状态，等待 `ft_lyr_param_done`。
    
- **Mem_Ctrl 行为:**
    
    - `always @(...) else if((mc_cs [FT_ECG] && mc_ns [FT_PARAM]) || ...) ft_lyr_param_done <= 1'b1;`
        
    - **【关键发现】** `Mem_Ctrl` 并没有**去**片外存储器读取参数。它只是**检测**到 `SPU` _即将_进入 `FT_PARAM` 状态，就**立刻**拉高了 `ft_lyr_param_done` 信号。
        
    - **分析:** 这是一个**“伪操作”**。`Mem_Ctrl` 告诉 `SPU` “参数已取回”，但它实际上根本没取。为什么？
        
    - **答案在代码顶部：**
        
        Verilog
        
        ```
        parameter K=9, K_H=3, K_W=3, S_H=2, S_W=2;
        wire [9:0] Hu_w = (nn_layer_cnt==1)? 10'd33:...;
        wire [14:0] IN = (nn_layer_cnt==1)? 15'd4096:...;
        ...
        ```
        
    - **结论：所有层参数都硬编码 (Hardcoded) 在 `Mem_Ctrl` 内部了！** 这是一个**为特定 2 层 CNN 定制**的控制器，而不是一个通用的控制器。
        

#### 4. 响应 `or_cs[OR_FT_WT]`：加载权重

- **SPU 命令:** `SPU` 子状态机进入 `OR_FT_WT`，等待 `ft_wt_done`。
    
- **Mem_Ctrl 行为:**
    
    - 它拉高 `wt_I_vld` 信号 (发给 `Weight_Buffer`)。
        
    - 它启动一个简单的线性计数器 `wt_I_addr`。
        
    - 它**计算** `ft_wt_done` (`assign ft_wt_done = (wt_I_addr == ((K*M*N)>>3)-1);`)。
        
    - **分析:** 这是一个简单的“DMA 控制器”，它按顺序填满 `Weight_Buffer`，并在达到总权重大小（由 _硬编码_ 的 K, M, N 计算得出）时通知 `SPU`。
        

#### 5. 响应 `or_cs[OR_CAL]`：执行计算 (最核心)

- **SPU 命令:** `SPU` 子状态机进入 `OR_CAL`，等待 `lyr_cal_done`。
    
- **Mem_Ctrl 行为:** `Mem_Ctrl` 此时“火力全开”，它必须**同时**管理三组数据流：
    
    **A. 读输入 (IOBuffer -> PEs):**
    
    - **工作:** `Mem_Ctrl` 启动一个**6层嵌套循环**的地址生成器！
        
        - `cal_cnt_y` (Y-向滑动窗口)
            
        - `cal_cnt_x` (X-向滑动窗口)
            
        - `ft_N_cnt` (输出通道 Tile)
            
        - `M_cnt` (输入通道)
            
        - `kh_cnt` (卷积核高度)
            
        - `Bm_cnt` (数据块)
            
    - **输出:** `assign rd_addr_nxt = ...` 基于这 6 个计数器计算出 `IOBuffer` 的**读地址**。
        
    - **握手:** `assign Data_O_vld = pe_end && ...`。它**等待** `PE` 阵列完成计算 (`pe_end` 高)，然后**才**发出 `Data_O_vld`（`IOBuffer` 的 `Mem_Data_Ivld`）去取**下一个**数据。这是**完美的反压 (back-pressure)** 握手。
        
    
    **B. 写输出 (PEs -> IOBuffer):**
    
    - **工作:** `Mem_Ctrl` 启动一个**3层嵌套循环**的地址生成器。
        
        - `oy_cnt` (输出 Y 坐标)
            
        - `ox_cnt` (输出 X 坐标)
            
        - `N_cnt` (输出通道)
            
    - **输入:** 它侦听 `Data_I_vld` (来自 `PEs` 的“计算完成”信号)。
        
    - **输出:** `assign wr_addr = ...` 基于这 3 个计数器，计算出 `IOBuffer`（的另一个 Bank）的**写地址**。
        
    
    **C. 读权重 (WeightBuffer -> PEs):**
    
    - **工作:** `Mem_Ctrl` 启动一个并行的权重地址生成器。
        
    - **输出:**
        
        - `wt_C0_addr` ... `wt_C7_addr`: **8 个并行的**权重读地址。
            
        - `wt_C0_O_vld` ... `wt_C7_O_vld`: **8 个并行的**权重有效信号。
            
    - **分析:** 这些 `vld` 和 `addr` 信号被组织为**移位寄存器**（`wt_C1_addr <= wt_C0_addr;`）。这**强烈**表明你的 `PE` 阵列是一个 **8 列宽的脉动阵列 (Systolic Array)**，`Mem_Ctrl` 正在以**流水线**的方式把权重“泵”入这个阵列。
        

#### 6. 响应 `or_cs[OR_CAL]`：报告完成

- **SPU 命令:** `SPU` 等待 `lyr_cal_done`。
    
- **Mem_Ctrl 行为:**
    
    - `assign lyr_cal_done = (or_cs [OR_CAL] && wr_lyr_done && rd_lyr_done) ? 1'b1 : 1'b0;`
        
    - **分析:** `Mem_Ctrl` 内部维护两个独立的完成标志：`wr_lyr_done` (来自“写输出”循环) 和 `rd_lyr_done` (来自“读输入”循环)。当这两个循环都报告完成后，`Mem_Ctrl` 才向 `SPU` 报告“层计算完成”。