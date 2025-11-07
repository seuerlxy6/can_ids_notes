## 1、写数据
IR_Data_I_vld
Bm_cnt_in[5:0]
kh_cnt_in[5:0]
三个信号共同控制
第一批hu，33——5列——5×8=40个reg存一行，一共需要120个reg
IR_Data_I_vld
Bm_cnt_in[5:0]
kh_cnt_in[5:0]同时进入，计数器用来算地址，完成120个数据的输入
![[Pasted image 20250704162119.png]]

## 2、读数据
**延迟信号我没看明白，但可以肯定的是权重和数据需要一起到达pe阵列才对**
这里的延迟要等顶层连接时才能看出来
![[Pasted image 20250704173358.png]]
现在这里的读地址和输出有效可以对齐
一行给9个数据对应地址
- row0---0、1、2
- row1---40、41、42
- row2---80、81、82
从第一列数据可以看出来，每行的窗口滑动2步




| **交互接口 (Interface With)**                             | **信号 (Signal Name)** | **方向 (I/O)** | **逻辑与握手关系 (Logic & Handshake)**                                   |
| ----------------------------------------------------- | -------------------- | ------------ | ----------------------------------------------------------------- |
| **1. `IOBuffer`**<br><br>  <br><br>(Data Writer)      | `IR_Data_I0...I7`    | **In**       | 8 字节宽的 IFM 数据 (来自 `IOB_Data_O...`)。                               |
|                                                       | `IR_Data_I_vld`      | **In**       | “数据有效”握手信号 (来自 `IOB_Data_O_vld`)。                                 |
| **2. `Mem_Ctrl`**<br><br>  <br><br>(Write Controller) | `Bm_cnt_in`          | **In**       | **[写地址]** "块" 计数器 (0...4)。                                        |
|                                                       | `kh_cnt_in`          | **In**       | **[写地址]** "核高" 计数器 (0...2)，用于选择写入第几行。                             |
| **3. `Mem_Ctrl`**<br><br>  <br><br>(Read Controller)  | `K` (Kernel Width)   | **In**       | 卷积核宽度 (例如 3)。                                                     |
|                                                       | `S` (Stride)         | **In**       | 卷积步长 (例如 1 或 2)。                                                  |
|                                                       | `pe_end`             | **In**       | `PE` 阵列的 "计算完成" 信号。                                               |
| **4. `Weight_Buffer`**<br><br>  <br><br>(Sync Master) | `Weight_Data_Ovld`   | **In**       | **[核心时钟]** 权重的 `vld` 信号。`Input_Regfile` 的**所有读操作**都由这个信号**同步触发**。 |
| **5. `PE` 阵列**<br><br>  <br><br>(Data Reader)         | `IR_Data_O0...Of`    | **Out**      | **16 字节宽**的并行数据输出 (喂给 16 个 PE)。                                   |
|                                                       | `IR_Data_O_vld`      | **Out**      | “数据有效”握手信号 (发往 `PE` 阵列)。                                          |