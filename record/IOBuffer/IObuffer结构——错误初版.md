## 代码结构——硬件结构
![[Pasted image 20250707221557.png]]

| ram1         | ram2        |
| ------------ | ----------- |
| map_10-map17 | map01-map08 |
一共16个bank
##### **ram1**
map10包含一个bram1和一个uart串口调试模块
map11-map17只有bram，直接用ip核
##### **ram2**
8个bank全部为自写rtl，强制映射到bram，仿真快，逻辑可见
 `(* ram_style = "block" *)                      // 综合时强制映射到 Block-RAM`


| 网络阶段                 | 需要缓存到 BRAM 的 **最大**特征图        | 点数 (= W × H × C)        | 每 Bank 存 8 Byte需要多少行？ | 2048 行是否足够 |
| -------------------- | ----------------------------- | ----------------------- | --------------------- | ---------- |
| **卷积层 1** 输入 (原 ECG) | 64 × 64 × 3 = **12 288** Byte | 12 288 ÷ 8 = **1536** 行 | 1536 ≤ 2048           | ✔          |
| 卷积层 1 输出 / 卷积层 2 输入  | 32 × 32 × 8 = **8192** Byte   | 8192 ÷ 8 = **1024** 行   | 1024 ≤ 2048           | ✔          |
| 卷积层 2 输出 / Pool 输入   | 16 × 16 × 32 = **8192** Byte  | 8192 ÷ 8 = **1024** 行   | 1024 ≤ 2048           | ✔          |
| Pool 输出 / FC1 输入     | 3 × 3 × 32 = **288** Byte     | 288 ÷ 8 = **36** 行      | 36 ≪ 2048             | ✔          |
**ram设置成2048深度**

## 首先测试map10（ram1-bank1）
### 1、`ram_wea = wrenb && !rdena;` 的含义

```verilog
wire ram_wea;
assign ram_wea = wrenb && (!rdena);
```

| 信号          | 来源                     | 含义                                       |
| ----------- | ---------------------- | ---------------------------------------- |
| **`wrenb`** | 写端口 B 的 `write enable` | “**想写**”——In-Out-Buffer 把新特征图送进 BRAM 时拉高 |
| **`rdena`** | 读端口 A 的 `read enable`  | “**正在读**”——Mem-Ctrl/PE 要从同一块 BRAM 读数据时拉高 |

> **目的：** **同一个时钟沿**里如果既想写又想读，就**先保证读**，把写关掉，避免**读写冲突**。

| 时钟沿        | `rdena` | `wrenb` | `ram_wea` | 说明                                               |
| ---------- | ------- | ------- | --------- | ------------------------------------------------ |
| **Ping-写** | 0       | 1       | 1         | 当前层 `nn_layer_cnt[0]=1` → 写 **bank1**（CAN_bank1） |
| **Pong-读** | 1       | 0       | 0         | 另一半阵列在读 **bank0**，写端保持低                          |
| **冲突沿**    | 1       | 1       | 0         | 万一两边同时拉高，用 `!rdena` 禁掉这拍写                        |

> _Vivado 的 Block Memory Generator 在 **Simple Dual-Port (SDP)** 配置下，  
> 同时对 **同一个端口** 做读写会产生不确定数据或冲突警告。_  
> 因为 `addr_a/addr_b` 在系统里可能还没完全解耦（尤其 pipeline 阶段同拍发生时）。


### 2、map10仿真波形

**A口读延迟要三个周期？**
no change
bram要2个时钟延迟，data_a寄存要1个时钟，一共三个
![[Pasted image 20250710213618.png]]
****
**B口写**
无延迟 write first
![[Pasted image 20250710214937.png]]

**读优先**
![[Pasted image 20250710225251.png]]


参考手册：Block Memory Generator v8.4 LogiCORE IP Product Guide

### 3、关于uart
输出最后一层fc2数据，0 or 1
![[Pasted image 20250711165620.png]]
### 4、整体仿真
#### 整体框架（Ping-Pong 双 Bank）

                 ┌───────── Mem_Ctrl 给 wr_addr / rd_addr ─────────┐
                 │                                                │
┌── 写数据选择 ──┤                                       ┌─ Bank-0 : map_10-17  ──┤─► PE 输入
│                            │                                       │                                        │
│                            │ Layer 偶 → 写 Bank-0   │ 读 Bank-1                        │
│ IOB_Data_vld ─►│ Layer 奇 → 写 Bank-1   │ 读 Bank-0                        │
└────────────────┘                                     └───────────────────────┘
#### 关键握手关系

| 信号                    | 生产者      | 消费者                       | 作用     |
| --------------------- | -------- | ------------------------- | ------ |
| `wr_addr` / `rd_addr` | Mem_Ctrl | 本模块 16×RAM                | 地址统一   |
| `IOB_Data_vld`        | 输入阶段逻辑   | 写端 `wen_ram?`             | 写同步    |
| `Mem_Data_Ivld`       | Mem_Ctrl | 读端 enb + `IOB_Data_O_vld` | 读同步    |
| `IOB_Data_O_vld`      | 本模块      | Input_Regfile             | 数据到齐标志 |

- 写：IOB_Data_vld 必须与 8×Byte 同拍 → 地址、数据、wen 都在 同一拍。
- 读：Mem_Data_Ivld 必须与 rd_addr 同拍给 RAM，读出数据再经过 2 个 BRAM latency (2clk)，到 Input_Regfile 时用 IOB_Data_O_vld 对齐。
B口写，A口读

**`Mem_Data_Ivld`就是mem的`Data_O_vld`**	



