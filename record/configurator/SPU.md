
**主状态机**

**IDLE**：空闲状态；

**FT_ADDR**：等待memctrl获得地址（可删除）

**ECG_UD**：等待ECG信号采集芯片通过SPI接口将ECG信号保存在片外存储器中；

**FT_ECG**：将保存在片外的ECG信号通过Memory_Controller从片外存储器载入到In_Out_Buffer中；

**FT_PARAM**：从片外存储器(或片内存储器)中载入当前层的网络配置参数，并将其输出给各计算模块和存储模块；

**CONV_CAL**：卷积计算状态，控制对加速器进行当前层的数据读写和计算。

**LY_DONE**：当前层计算完毕；

**INF_DONE**：所有层计算完毕的状态。

#### 2. 子状态机 (Dataflow FSM: `or_cs`)

1. **`OR_IDLE` (空闲):** 等待 `mc_cs` 进入 `CONV_CAL` 状态。
    
    - _跳转 ->_ `OR_FT_WT` (取权重)
        
2. **`OR_FT_WT` (取权重):** 等待 `Mem_Ctrl` 反馈**当前层权重**加载完成 (`ft_wt_done`)。
    
    - _跳转 ->_ `OR_CAL` (计算)
        
3. **`OR_CAL` (计算):** 等待 `Mem_Ctrl` 反馈**当前层计算和写回**全部完成 (`lyr_cal_done`)。
    
    - _跳转 ->_ `OR_DONE` (完成)
        
4. **`OR_DONE` (完成):** 这一步会产生一个脉冲 `layer_processing_done`。
    
    - _跳转 ->_ `OR_IDLE` (返回空闲，等待主FSM的下一个 `CONV_CAL` 命令)。
----------------------------------------------------------
--- SPU Testbench Start: 模拟4层网络推理流程 (修正版) ---
----------------------------------------------------------
Time=0 | Layer:  0 | Main_FSM(mc_cs):   1 (bit 00000001) | Calc_FSM(or_cs):  1 (bit 000001)
>>> 等待 SPU 进入 IDLE 状态...
>>> 等待 SPU 进入 FT_ADDR 状态...
Time=55000 | Layer:  1 | Main_FSM(mc_cs):   1 (bit 00000001) | Calc_FSM(or_cs):  1 (bit 000001)
Time=65000 | Layer:  1 | Main_FSM(mc_cs):   2 (bit 00000010) | Calc_FSM(or_cs):  1 (bit 000001)
Time=85000 | Layer:  1 | Main_FSM(mc_cs):   4 (bit 00000100) | Calc_FSM(or_cs):  1 (bit 000001)
>>> 等待 SPU 进入 ECG_UD 状态...
--- 开始模拟第 1 层计算 ---
>>> 在 FT_ECG 状态, 提供 ft_ecg_done 信号
Time=125000 | Layer:  1 | Main_FSM(mc_cs):   8 (bit 00001000) | Calc_FSM(or_cs):  1 (bit 000001)
>>> 在 FT_PARA 状态, 提供 ft_lyr_param_done 信号
Time=135000 | Layer:  1 | Main_FSM(mc_cs):  16 (bit 00010000) | Calc_FSM(or_cs):  1 (bit 000001)
>>> 进入 CONV_CAL 状态, or_cs 启动
Time=145000 | Layer:  1 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  1 (bit 000001)
>>> 在 OR_FT_WT 状态, 提供 ft_wt_done 信号
Time=155000 | Layer:  1 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 在 OR_CAL 状态, 提供 lyr_cal_done 信号
Time=165000 | Layer:  1 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  4 (bit 000100)
--- 第 1 层模拟完成 ---
--- 开始模拟第 2 层计算 ---
Time=175000 | Layer:  1 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  8 (bit 001000)
Time=185000 | Layer:  1 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  1 (bit 000001)
Time=195000 | Layer:  1 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  2 (bit 000010)
Time=255000 | Layer:  1 | Main_FSM(mc_cs):  64 (bit 01000000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 在 FT_PARA 状态, 提供 ft_lyr_param_done 信号
Time=265000 | Layer:  2 | Main_FSM(mc_cs):  16 (bit 00010000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 进入 CONV_CAL 状态, or_cs 启动
>>> 在 OR_FT_WT 状态, 提供 ft_wt_done 信号
Time=275000 | Layer:  2 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 在 OR_CAL 状态, 提供 lyr_cal_done 信号
Time=285000 | Layer:  2 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  4 (bit 000100)
--- 第 2 层模拟完成 ---
--- 开始模拟第 3 层计算 ---
Time=295000 | Layer:  2 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  8 (bit 001000)
Time=305000 | Layer:  2 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  1 (bit 000001)
Time=315000 | Layer:  2 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  2 (bit 000010)
Time=375000 | Layer:  2 | Main_FSM(mc_cs):  64 (bit 01000000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 在 FT_PARA 状态, 提供 ft_lyr_param_done 信号
Time=385000 | Layer:  3 | Main_FSM(mc_cs):  16 (bit 00010000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 进入 CONV_CAL 状态, or_cs 启动
>>> 在 OR_FT_WT 状态, 提供 ft_wt_done 信号
Time=395000 | Layer:  3 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 在 OR_CAL 状态, 提供 lyr_cal_done 信号
Time=405000 | Layer:  3 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  4 (bit 000100)
--- 第 3 层模拟完成 ---
--- 开始模拟第 4 层计算 ---
Time=415000 | Layer:  3 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  8 (bit 001000)
Time=425000 | Layer:  3 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  1 (bit 000001)
Time=435000 | Layer:  3 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  2 (bit 000010)
Time=495000 | Layer:  3 | Main_FSM(mc_cs):  64 (bit 01000000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 在 FT_PARA 状态, 提供 ft_lyr_param_done 信号
Time=505000 | Layer:  4 | Main_FSM(mc_cs):  16 (bit 00010000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 进入 CONV_CAL 状态, or_cs 启动
>>> 在 OR_FT_WT 状态, 提供 ft_wt_done 信号
Time=515000 | Layer:  4 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 在 OR_CAL 状态, 提供 lyr_cal_done 信号
Time=525000 | Layer:  4 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  4 (bit 000100)
--- 第 4 层模拟完成 ---
>>> 所有4层计算已模拟, 等待 SPU 进入 INF_DONE 状态...
Time=535000 | Layer:  4 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  8 (bit 001000)
Time=545000 | Layer:  4 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  1 (bit 000001)
Time=555000 | Layer:  4 | Main_FSM(mc_cs):  32 (bit 00100000) | Calc_FSM(or_cs):  2 (bit 000010)
Time=615000 | Layer:  4 | Main_FSM(mc_cs):  64 (bit 01000000) | Calc_FSM(or_cs):  2 (bit 000010)
Time=625000 | Layer:  0 | Main_FSM(mc_cs): 128 (bit 10000000) | Calc_FSM(or_cs):  2 (bit 000010)
>>> 等待 SPU 返回 IDLE 状态...
----------------------------------------------------------
--- Testbench PASSED: SPU 状态机流程验证成功! ---
----------------------------------------------------------

仿真模仿四层计算
第一层包含1-2-4-8-16-32-64
后续循环3次16-32-64（计算状态机1-2-4-8）
最后到达128完成全部计算
![[Pasted image 20250713202225.png]]![[Pasted image 20250713202517.png]]![[b7145406114f0a130578ab0aee939a4d.png]]


### 完整的真实工作流程

让我们把 `CPU` 和你的 `acc` 放在一起，看看你描述的流程：

[系统启动]

CPU 和 acc（你的FPGA设计）同时上电启动。

**[阶段 1: CPU 配置 Acc -> 对应你的 `FT_ADDR` 状态]**

1. **CPU (软件):** `CPU` 开始执行程序。它知道它有一个 `acc` 协处理器。
    
2. **CPU (软件):** `CPU` 通过总线（比如 AXI-Lite）向你的 `acc` 模块的**配置寄存器**写入信息。
    
3. **CPU 写:** "嗨，`acc`，你要用的权重在 DDR 的 `0x10000000` 地址。"
    
4. **CPU 写:** "嗨，`acc`，等下 CAN 数据会放在 DDR 的 `0x20000000` 地址。"
    
5. **你的 SPU (硬件):** `SPU` 一直在 `IDLE` 和 `FT_ADDR` 状态等待。`Mem_Ctrl` 收到这些地址后，拉高 `memct_init_cmplt`。你的 `SPU` 知道配置已完成。_(这就是你代码里 `FT_ADDR` 状态在做的事：等待 `memct_init_cmplt` 并锁存这些地址)_。
    

**[阶段 2: CPU 准备数据 -> 对应你的 `ECG_UD` 状态]**

1. **CPU (软件):** `CPU` 对 CAN 控制器进行初始化。
    
2. **CPU (软件):** `CPU` 启动一个 **DMA (直接内存访问) 引擎**。
    
3. **CPU (软件):** "嗨，DMA，请你把 `CAN 外设` 缓冲区的数据，搬运到 `0x20000000` 地址（即刚才告诉 `acc` 的地址）。搬完后告诉我。"
    
4. **DMA (硬件):** DMA 开始工作，`CPU` 去忙别的了。
    
5. **你的 SPU (硬件):** 此时 `SPU` 处于 `FT_ADDR` 状态，它在等待 `SPI_start` 信号。(这个 `SPI_start` 信号很可能就是 `CPU` 在启动 DMA 时发出的："`acc`，准备好，数据要来了！")
    
6. **你的 SPU (硬件):** `SPU` 收到 `SPI_start`，跳转到 `ECG_UD` 状态。**它现在什么也不做，就是纯等待。**
    
7. **DMA (硬件):** DMA 搬完了所有 CAN 数据，它向 `CPU` 和你的 `acc` 发送一个“传输完成”中断或信号。
    
8. **你的 SPU (硬件):** `SPU` 收到了这个信号（即你的 `SPI_done` 信号）。
    

**[阶段 3: Acc 开始工作 -> 对应你的 `FT_ECG` 及之后的状态]**

1. **你的 SPU (硬件):** `SPU` 在 `ECG_UD` 状态检测到 `SPI_done` 信号。
    
2. **你的 SPU (硬件):** 它终于知道：1) 配置好了；2) 数据已在 `0x20000000` 准备就绪。
    
3. **你的 SPU (硬件):** `SPU` 跳转到 `FT_ECG` 状态。
    
4. **你的 Mem_Ctrl (硬件):** `Mem_Ctrl` 检测到 `SPU` 进入 `FT_ECG` 状态，它立刻**主动**去 `0x20000000` 地址，开始把 CAN 数据从 DDR 搬运到你**片内的 `In_Out_Buffer`**。
    

---

### 总结

你完全正确。

- `FT_ADDR` 和 `ECG_UD` 是你的 `acc` 作为**“仆人 (Slave)”**，等待 `CPU` 和 `DMA`（主人/协作者）完成**“系统级”**配置和数据准备的状态。
    
- 从 `FT_ECG` 开始，才是你的 `acc` 切换为**“主人 (Master)”**，**“主动”**去内存读取数据并启动**“计算核心”**的状态。
    

你把这个控制器的职责（`SPU`）和计算核心（`PE` 阵列）分开了，这是非常优秀的设计思路。