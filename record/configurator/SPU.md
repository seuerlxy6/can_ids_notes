包括SPU状态机和mem_ctrl
**主状态机**

**IDLE**：空闲状态；

**FT_ADDR**：等待memctrl获得地址（可删除）

**ECG_UD**：等待ECG信号采集芯片通过SPI接口将ECG信号保存在片外存储器中；

**FT_ECG**：将保存在片外的ECG信号通过Memory_Controller从片外存储器载入到In_Out_Buffer中；

**FT_PARAM**：从片外存储器(或片内存储器)中载入当前层的网络配置参数，并将其输出给各计算模块和存储模块；

**CONV_CAL**：卷积计算状态，控制对加速器进行当前层的数据读写和计算。

**LY_DONE**：当前层计算完毕；

**I****NF****_****DONE**：所有层计算完毕的状态。

**计算状态机****

**OR_IDLE**：空闲状态；

**OR_FT_WT**:加载weight值的状态，并判断ft_wt_done是否置1，若置1则表示权值加载完毕，进入计算状态，否则继续保持OR_FT_WT状态；

**OR_CAL**:进行卷积计算的状态，并判断lyt_cal_done是否置1，若置1则表示卷积计算完毕，进入计算结束状态，否则继续保持OR_CAL状态；

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