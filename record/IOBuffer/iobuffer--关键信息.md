
### 模块回顾 (1): `In_Out_Buffer.v`

#### 1. 核心功能 (Basic Logic)

你设计的 `In_Out_Buffer` **不是一个简单的输入缓存**，它是一个**“中间特征图缓存” (Intermediate Feature Map Buffer)**。

它的核心作用是**暂存**上一层（如Conv, Pool, FC）计算完成的**输出特征图 (OFM)**，以便**下一层**计算时（通过 `Input_Regfile`）可以将其作为**输入特征图 (IFM)** 来读取。

#### 2. 核心逻辑：基于层号的乒乓操作 (Ping-Pong)

这是该模块最关键的设计。你没有使用一个通用的 `sel` 信号，而是巧妙地利用了**当前层号 `nn_layer_cnt`** 来自动控制乒乓读写。

- **内部存储:** 你例化了 **16 个 BRAM**，分成了两个 Bank（RAM1 和 RAM2）。
    
    - **Bank-1 (RAM1):** 由 `u_map_10` ~ `u_map_17` 组成（共8个BRAM）。
        
    - **Bank-2 (RAM2):** 由 `u_map_00` ~ `u_map_07` 组成（共8个BRAM）。
        
- **并行度:** 每个 Bank 都是 8 字节（64位）宽的，每个BRAM（`memory_mapX` 或 `memoryX`）负责存储 8 字节中的 1 字节数据。
    
- **乒乓控制信号:** `nn_layer_cnt[0]` (即层号的奇偶性)。
    

**乒乓操作流程如下：**

- **当层号为偶数 (Even Layers, 如 0, 2, ...):**
    
    - `nn_layer_cnt[0] == 0`
        
    - **写使能 (Write):** `wen_ram1` 有效 ( `~nn_layer_cnt[0]` )。
        
    - **读使能 (Read):** RAM2 的 `rdena` 有效 ( `~nn_layer_cnt[0]` )。
        
    - **结论:** 在偶数层，计算结果**写入 Bank-1**，同时从 **Bank-2** 读取数据（作为本层的输入）。
        
- **当层号为奇数 (Odd Layers, 如 1, 3, ...):**
    
    - `nn_layer_cnt[0] == 1`
        
    - **写使能 (Write):** `wen_ram2` 有效 ( `nn_layer_cnt[0]` )。
        
    - **读使能 (Read):** RAM1 的 `rdena` 有效 ( `nn_layer_cnt[0]` )。
        
    - **结论:** 在奇数层，计算结果**写入 Bank-2**，同时从 **Bank-1** 读取数据（作为本层的输入）。
        

> **总结：** 这个设计完美地实现了流水线操作。当第 N 层在计算（从一个 Bank _读取_ IFM）时，第 N-1 层的计算结果（OFM）可以同时_写入_到另一个 Bank，两者互不干扰。

---

#### 3. 关键 I/O 信号与握手关系

我们按模块交互对象来梳理：

|**交互模块**|**信号 (I/O)**|**方向 (Direction)**|**描述 (Logic & Handshake)**|
|---|---|---|---|
|**全局**|`clk_cal`, `rst_cal_n`|Input|时钟和复位。|
|**`spu` / `Mem_Ctrl`**<br><br>  <br><br>**(控制器)**|`nn_layer_cnt [3:0]`|Input|**[核心控制]** 当前层号。`[0]` 位用于乒乓切换。|
||`wr_addr [12:0]`|Input|**[核心控制]** 写地址。由控制器（`Mem_Ctrl`）产生。|
||`rd_addr [12:0]`|Input|**[核心控制]** 读地址。由控制器（`Mem_Ctrl`）产生。|
||`Mem_Data_Ivld`|Input|**[读握手: 输入]** "内存数据输入有效" (Input Valid)。这是来自 `Mem_Ctrl` 的**读使能**信号，它告诉 IOB："请在 `rd_addr` 上开始一次读取"。|
||`SPI_start`|Input|特殊模式标志，用于第0层加载CAN/ECG原始信号。|
|**`Conv/Pool` 单元**<br><br>  <br><br>**(写入方)**|`IOB_Data_I_vld`|Input|**[写握手: 输入]** Conv/Pool 模块的数据有效信号。|
||`IOB_Data_I0...I7`|Input|8 字节宽的**数据输入** (来自 Conv/Pool)。|
|**`FC` 单元**<br><br>  <br><br>**(写入方)**|`IOB_FC_vld`|Input|**[写握手: 输入]** FC 模块的数据有效信号。|
||`IOB_FC_I0...I7`|Input|8 字节宽的**数据输入** (来自 FC)。|
|**`Input_Regfile`**<br><br>  <br><br>**(读取方)**|`IOB_Data_O0...O7`|Output|8 字节宽的**数据输出**（喂给下一级 `Input_Regfile`）。|
||`IOB_Data_O_vld`|Output|**[读握手: 输出]** "IOB 数据输出有效" (Output Valid)。|

---

#### 4. 握手逻辑详解

**A. 写操作 (来自 Conv/Pool/FC)**

1. **数据选择 (Mux):** 模块内部的 `always @(*)` 块根据 `nn_layer_cnt` 来决定是接收 Conv/Pool 的数据 (`IOB_Data_I*`) 还是 FC 的数据 (`IOB_FC*`)。
    
2. **使能传递:** 选中的 `vld` 信号 (如 `IOB_Data_I_vld`) 会驱动总的 `IOB_Data_vld`。
    
3. **Bank 选择:** `IOB_Data_vld` 结合 `nn_layer_cnt[0]` 产生 `wen_ram1` 或 `wen_ram2`，在 `wr_addr` 指定的地址写入数据。
    
    - **握手方式:** 这是**前向 `valid` 握手**。IOB 假设 `Conv/Pool/FC` 模块和 `spu` (提供 `wr_addr`) 之间是同步的。当 `IOB_Data_I_vld` 为高时，IOB 就在当前时钟周期执行写入。
        

**B. 读操作 (喂给 Input_Regfile)**

1. **启动:** `Mem_Ctrl` (控制器) 发出 `Mem_Data_Ivld` 信号（并提供 `rd_addr`）。
    
2. **Bank 选择:** `Mem_Data_Ivld` 结合 `nn_layer_cnt[0]` 产生 `rdena`（读使能）给对应的 BRAM Bank。
    
3. **数据输出:** BRAM 经过固定的读延迟（代码中注释为2拍）后，在 `ramX_OdataX` 上输出数据。
    
4. **Mux 输出:** 模块根据 `nn_layer_cnt[0]` 选择是输出 `ram1_OdataX` 还是 `ram2_OdataX` 到 `IOB_Data_O0...O7`。
    
5. **Valid 对齐:** 为了让 `vld` 信号与数据同步到达 `Input_Regfile`，你用两级触发器延迟了 `Mem_Data_Ivld`：
    
    - `IOB_Data_O_vld_d1 <= Mem_Data_Ivld;`
        
    - `IOB_Data_O_vld <= IOB_Data_O_vld_d1;`
        
    - **握手方式:** 当 `Input_Regfile` 在 T 周期检测到 `IOB_Data_O_vld` 为高时，它就知道 `IOB_Data_O0...O7` 上的数据在 T 周期是有效的，可以锁存。
        

---

这个模块回顾清楚了吗？

接下来，我们是回顾 `weightbuffer` 还是 `memctrl`？