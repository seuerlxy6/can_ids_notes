
### 模块回顾 (2): `Configurator.v`

#### 1. 核心功能 (Basic Logic)

`Configurator` 本身不是一个FSM。它是一个**结构化封装 (Structural Wrapper)** 模块。

它的唯一工作就是例化 (instantiate) 你整个控制系统的两个核心：

1. **`SPU cfg_SPU_ECG`:** 这就是你说的“状态机”。它是**高级指挥官 (大脑)**。它决定了整个推理流程的**状态**（例如，空闲、加载权重、计算、写回）。
    
2. **`Mem_Ctrl cfg_Mem_Ctrl`:** 这是**低级执行官 (小脑/手脚)**。它接收来自 `SPU` 的高级命令（即当前状态），并将其**翻译**成给各个 Buffer (如 `iobuffer`, `weightbuffer`) 的**具体地址 (`rd_addr`, `wr_addr`) 和使能信号 (`vld`)**。
    

---

#### 2. 关键 I/O 与握手关系

这个模块最关键的是**定义了 `SPU` 和 `Mem_Ctrl` 之间的握手接口**。

**A. 内部握手 (SPU <-> Mem_Ctrl)**

- **`SPU` -> `Mem_Ctrl` (命令):**
    
    - `mc_cs`, `or_cs`, `mc_ns`, `or_ns` (状态信号): `SPU` 把自己的**当前状态**和**下一状态**直接告诉 `Mem_Ctrl`。
        
    - `nn_layer_cnt` (层号): `SPU` 告诉 `Mem_Ctrl` 当前正在处理第几层。
        
    - **逻辑:** `Mem_Ctrl` 内部会有一个 `case(mc_cs)` 语句。例如，当 `SPU` 进入 `FETCH_WEIGHT` 状态时, `Mem_Ctrl` 检测到 `mc_cs == FETCH_WEIGHT`，就开始主动生成 `wt_I_addr` 和 `wt_I_vld` 信号去加载权重。
        
- **`Mem_Ctrl` -> `SPU` (反馈):**
    
    - `ft_lyr_param_done`, `ft_wt_done`, `ft_ecg_done` (完成标志): `Mem_Ctrl` 告诉 `SPU`：“你要求的（加载参数/权重/输入数据）任务**已完成**。”
        
    - `lyr_cal_done` (层计算完成): `Mem_Ctrl` 告诉 `SPU`：“这一层的数据已经全部处理完毕（包括写回）。”
        
    - **逻辑:** `SPU` 在 `WAIT_FETCH_WT` 状态会一直等待 `ft_wt_done` 信号变为高，然后才跳转到下一个 `COMPUTE` 状态。
        

**B. 外部握手 (Configurator <-> 其他模块)**

从 `iobuffer` 和 `weightbuffer` 的角度看，`Configurator` 模块就是它们的**唯一主宰 (Master)**。

- **To `In_Out_Buffer` (IOB):**
    
    - `rd_addr`, `wr_addr`: 由 `Mem_Ctrl` 产生，透传出去。
        
    - `Data_O_vld`: 由 `Mem_Ctrl` 产生，透传出去。(这就是 `iobuffer` 接收到的 `Mem_Data_Ivld` 信号)。
        
    - `nn_layer_cnt`: 由 `SPU` 产生，透传出去。(这就是 `iobuffer` 用来做乒乓切换的**关键信号**)。
        
- **To `Weight_Buffer` (WB):**
    
    - `wt_I_vld`, `wt_I_addr`: "加载权重"信号。由 `Mem_Ctrl` 产生，告诉 WB 开始接收权重数据。
        
    - `wt_C0_O_vld` ... `wt_C7_O_vld`: "读取权重"有效信号。由 `Mem_Ctrl` 产生。
        
    - `wt_C0_addr` ... `wt_C7_addr`: "读取权重"地址。由 `Mem_Ctrl` 产生。
        
    - **推论:** 这有力地表明，你的 `Weight_Buffer` 有 **8 个并行的读端口**，每个端口服务于一个通道 (Channel)，并且由 `Mem_Ctrl` 独立控制地址和使能。
        

---

| **信号类型**                                            | **信号名称 (Signal Name)**                        | **来源 (Source)**                 | **目的地 (Destination)** | **作用与描述 (Function & Description)**                                                        |
| --------------------------------------------------- | --------------------------------------------- | ------------------------------- | --------------------- | ----------------------------------------------------------------------------------------- |
| **全局信号**                                            | `clk_cal`                                     | Top Level                       | 所有模块                  | 计算时钟域 (Calculation Clock)                                                                 |
|                                                     | `rst_cal_n`                                   | Top Level                       | 所有模块                  | 低有效复位 (Active-low Reset)                                                                  |
| **IOB 核心控制**                                        | `nn_layer_cnt[3:0]`                           | `SPU` (via `Configurator`)      | `In_Out_Buffer`       | **[核心乒乓控制]** 当前层号。`[0]` 位用于决定读/写哪个 Bank。**`spu` 启动时设为 1**。                                |
| **IOB 读操作**<br><br>  <br><br>(IOB -> Input_Regfile) | `rd_addr[12:0]`                               | `Mem_Ctrl` (via `Configurator`) | `In_Out_Buffer`       | **[读地址]** `Mem_Ctrl` 告诉 IOB "去读这个地址"。                                                     |
|                                                     | `Data_O_vld`                                  | `Mem_Ctrl` (via `Configurator`) | `In_Out_Buffer`       | **[读握手 1]** "读使能"。`Mem_Ctrl` 告诉 IOB "你可以开始读了"。 (在 IOB 内部此信号被命名为 `Mem_Data_Ivld`)。         |
|                                                     | `IOB_Data_O0...O7`                            | `In_Out_Buffer`                 | `Input_Regfile`       | **[读数据]** 8 字节宽的输出数据 (作为 IFM)。                                                            |
|                                                     | `IOB_Data_O_vld`                              | `In_Out_Buffer`                 | `Input_Regfile`       | **[读握手 2]** "数据输出有效"。此信号将 `Data_O_vld` 延迟 1 周期，以匹配 BRAM 的 1 周期读延迟 (_注：原代码延迟 2 周期，有 bug_)。 |
| **IOB 写操作**<br><br>  <br><br>(Conv/Pool -> IOB)     | `wr_addr[12:0]`                               | `Mem_Ctrl` (via `Configurator`) | `In_Out_Buffer`       | **[写地址]** `Mem_Ctrl` 告诉 IOB "把结果写到这个地址"。                                                  |
|                                                     | `IOB_Data_I_vld`                              | `Conv / Pool`                   | `In_Out_Buffer`       | **[写握手 1]** "写数据有效"。计算单元告诉 IOB "我这有新数据了"。                                                 |
|                                                     | `IOB_Data_I0...I7`                            | `Conv / Pool`                   | `In_Out_Buffer`       | **[写数据 1]** 8 字节宽的输入数据 (来自 Conv/Pool 的 OFM)。                                              |
|                                                     | `IOB_FC_vld`                                  | `FC`                            | `In_Out_Buffer`       | **[写握手 2]** "写数据有效"。FC 单元告诉 IOB "我这有新数据了"。                                                |
|                                                     | `IOB_FC_I0...I7`                              | `FC`                            | `In_Out_Buffer`       | **[写数据 2]** 8 字节宽的输入数据 (来自 FC 的 OFM)。                                                     |
| **权重缓存控制**                                          | `wt_I_vld`                                    | `Mem_Ctrl` (via `Configurator`) | `Weight_Buffer`       | **[加载握手]** "权重加载有效"。`Mem_Ctrl` 告诉 WB "开始接收权重数据"。                                          |
|                                                     | `wt_I_addr`                                   | `Mem_Ctrl` (via `Configurator`) | `Weight_Buffer`       | **[加载地址]** `Mem_Ctrl` 告诉 WB "把权重写到这个地址"。                                                  |
|                                                     | `wt_C0_O_vld` ... `wt_C7_O_vld`               | `Mem_Ctrl` (via `Configurator`) | `Weight_Buffer`       | **[读取握手]** 8 个并行的"权重输出有效"信号，`Mem_Ctrl` 告诉 WB "开始输出这8个通道的权重"。                              |
|                                                     | `wt_C0_addr` ... `wt_C7_addr`                 | `Mem_Ctrl` (via `Configurator`) | `Weight_Buffer`       | **[读取地址]** 8 个并行的读地址，`Mem_Ctrl` 告诉 WB "去读这些地址的权重"。                                        |
| **内部状态握手**                                          | `mc_cs[7:0]` / `or_cs[5:0]`                   | `SPU`                           | `Mem_Ctrl`            | **[命令]** `SPU` (大脑) 告诉 `Mem_Ctrl` (手脚) 当前处于什么状态。                                          |
|                                                     | `ft_wt_done` / `ft_ecg_done` / `lyr_cal_done` | `Mem_Ctrl`                      | `SPU`                 | **[反馈]** `Mem_Ctrl` (手脚) 告诉 `SPU` (大脑) "任务已完成"。                                           |