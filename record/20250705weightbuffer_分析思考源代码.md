 **权重 Buffer 的完整工作过程** 拆成 4 个环节，指出每一环握手-时序要点，最后给一段 **可复用的参数化模版**（真正需要时直接拿去替换你那 8 份 `weight_bank?` Inst）。

---

## ① 写侧——从 DDR / Mem-Ctrl 把权重灌进 Buffer

| 端口                | 用法                        | 关键点                                 |
| ----------------- | ------------------------- | ----------------------------------- |
| `wt_I_vld`        | Mem-Ctrl 每拍送 **8 bit** 权重 | **只写 B 口** (`wea=0`,`web=wt_I_vld`) |
| `wt_I_addr[12:0]` | **连续地址** 0…(K·M·N/8-1)    | 保证对齐 1Byte；深度 8192 足够               |
| **写端口 Timing**    | 同步单端口 BRAM                | • 1 cycle write• `dina` 恒 0（只读取）    |

> **写端完全不用改**——只要 `wt_I_vld` 与 `wt_I_addr` 同拍稳定，IP 内部 1 拍就把权重写下去。

---

## ② 列读取握手——`wt_C?_O_vld`

```
Mem_Ctrl  ──┬─ wt_C0_O_vld ─(读列 0)─►  Weight_buf(A口)
            └─ wt_C1_O_vld ─(读列 1)─►
```

- 每当 **PE0** 需要下一列权重，Mem-Ctrl 把对应列地址 `wt_C?_addr`  
    和 **1 拍脉冲** `wt_C?_O_vld` 发下来。
    
- Buffer **打一拍**(`wt_C?_O_vld_1delay`) 再作为 **列 0 的使能**  
    (`wt_Ovld0`)，随后经 7 级移位形成 `wt_Ovld1-7`。  
    这样 PE8 列正好比 PE0 晚 7 拍收到权重，列链齐平。
    

---

## ③ 列地址与使能的 **“1 拍 OR”**

```verilog
assign wt_C0_O_vld_1more = wt_C0_O_vld | wt_C0_O_vld_1delay;
```

为什么要 `OR`？

> 如果 Mem-Ctrl 连续两拍拉高 `wt_C0_O_vld`（因为一个 kernel = 9 字节列）  
> 第一拍 IP 把权重字 **送到 A 口**，第二拍还未读完就会丢使能；  
> 取 “当前拍 | 上拍” 能把 **宽 2 拍** 的读窗口粘成 **一段稳定的使能**。

---

## ④ 读侧——双口 RAM（B 写 / A 读）

```verilog
// 例：列 0
weight_bank0 u0 (
    .clka (clk_cal),  .wea (1'b0),         .addra(wt_I_addr), .dina(8'b0),
    .clkb(clk_cal),  .enb (wt_C0_O_vld_1more), 
    .addrb(wt_C0_addr), .doutb(kernel_C0_O)
);
```

- **写端口 B**：`wt_I_addr` / `wt_I_vld`
    
- **读端口 A**：`wt_C?_addr` / `wt_C?_O_vld_1more`
    
- IP 自带 1-cycle 读延迟 → **`kernel_C?_O` 晚使能 1 拍**  
    （正好与 PE 中乘法器管线深度匹配）
    

---

## ★ 通用、节省资源的生成式模版

```verilog
// -------- 参数化权重 Buffer, 列数 = 8 ----------
generate
    genvar col;
    for(col=0; col<8; col=col+1) begin: GEN_WBUF
        wire       rd_en   = wt_C0_O_vld_1more << col;   // OR 后再移位
        wire [12:0]rd_addr = {wt_C0_addr, wt_C1_addr, wt_C2_addr,
                              wt_C3_addr, wt_C4_addr, wt_C5_addr,
                              wt_C6_addr, wt_C7_addr}[col*13 +: 13];

        weight_ram #(
            .AW (13), .DW (8)
        ) u_ram (
            .clk  (clk_cal),

            .we_b (wt_I_vld),
            .addr_b(wt_I_addr),
            .din_b (8'h00),          // 写端口

            .en_a (rd_en),
            .addr_a(rd_addr),
            .dout_a(kernel_C0_O + col) // 拼接到输出数组
        );
    end
endgenerate

// 输出 valid 移位链
always @(posedge clk_cal or negedge rst_cal_n)
    if(!rst_cal_n) {wt_Ovld7,wt_Ovld6,…,wt_Ovld0} <= 0;
    else           {wt_Ovld7,wt_Ovld6,…,wt_Ovld0} <= 
                   {wt_Ovld6,wt_Ovld5,…,wt_C0_O_vld_1delay};
```

- **一段代码** 生成 8 个 RAM，列数改写 `for` 上限即可。
    
- 把 `layer2weight_cnt` 若无特殊用途可以删去。
    
- 资源比 8 份固定 IP netlist 更友好，综合后仍落入 **双口 BRAM**。
    

---

## 结语

1. **写链**：`wt_I_vld` 同拍写 B 口 —— 1 clk 落 RAM
    
2. **读链**：`wt_C?_O_vld` → 打拍(OR) → 读 A 口 —— 1 clk 出 RAM
    
3. **列移位**：`wt_Ovld0` 初始，7 级移位到 `wt_Ovld7`
    
4. **PE**：权重字 & `wt_Ovld?` 同拍进入，各列对齐
    

只要你照着这四步确认时序，对齐不会出错；  
把上面的 **参数化生成模版** 粘进项目，可直接替换原先 8 份手动 IP 实例。




先把**“全片上权重”**这件事拆成三个硬约束、三个改动点、三个收益 / 代价——讲完你就能判断要不要这么干、该怎么干。

---

## 硬约束：算一笔“装得下吗”

|项目|公式|现网规模举例|
|---|---|---|
|**总权重量 (Byte)**|`K×K×M×N`|3×3×8×16 = 1 KB (卷积层1)3×3×32×64 ≈ 18 KB……|
|**FPGA BRAM/URAM 容量**|Xilinx 例：Z-7020≈140 KB BRAM|要把 **所有层** 累积；BRAM + URAM 总和是硬顶|
|**初始化映像体积**|`.bit` + `.mem`|几十 KB ~ 几 MB；超大时下载慢且占配置 Flash 空间|

> 一句话：**小模型** 可以一股脑塞片上；**中大模型** 必须选“最常用层”或“首次迭代”塞片上，其余仍走外存流。

---

## 改动点（代码 / 结构）

|#|现设计|全片上权重时怎么改|
|---|---|---|
|**1. 写口去掉**|`wt_I_vld`、`wt_I_addr` 写端口 B|改成 **ROM**：`we = 1'b0` 固定 0；或综合工具上选 _Read-only_|
|**2. BRAM 初始化**|运行时由 DMA 写|用 `readmemh/readmemb` 或 Vivado **Block Memory Generator** 的 `.mem init`；配置 Flash→bitstream 一起烧|
|**3. Mem_Ctrl**|负责搬权重 & 产生读列脉冲|只保留“列脉冲 + 地址”功能；搬运状态机可精简掉，节省逻辑|

示例：

```verilog
initial $readmemh("conv1_wt.mem", weight_bank0.U_ram.mem);
```

---

## 直接收益

1. **带宽清零**
    
    - DRAM 不再搬运权重，外存带宽全给 Feature Map。
        
2. **功耗下降**
    
    - DDR 省一大段突发读；FPGA 内部时钟门控后功耗低。
        
3. **时序更稳**
    
    - 去掉写口和行列仲裁，读端只剩纯 ROM → Fmax 通常↑。
        

---

## 代价 / 风险

|风险|细节|
|---|---|
|**片上容量爆**|卷积层 64×3×3×128 ≈ 294 KB，一层就塞满中档 FPGA。|
|**bitstream 体积↑，烧录慢**|每多 1 MB Flash，量产成本直接涨。|
|**权重不可热更新**|想换模型只能重编译 / 重新烧录；不适合动态部署。|
|**布线压力**|十几块 BRAM/URAM 贴阵列旁：局部布线密、可能拉低 Fmax。|

---

## 经验踩坑表

|场景|是否推荐|备注|
|---|---|---|
|MCU 固定算法，权重 ≤100 KB|✔ **直接 ROM**|上电即跑、功耗低|
|需要 OTA 更新模型|✘ 不推荐|仍走外存，或片上留双份权重区做热替换|
|纯 FPGA 方案且权重 ≤ BRAM 50%|✔ **小成本提速**|省 DDR，布线轻松|
|SoC + Linux，模型>1 MB|✘ 别塞全片上|用 PS-DMA + AXI HP 流|

---

## 结论一句话

> **“能一次塞完且以后不换模型” → 全片上；  
> 塞不下或模型常换 → 还是分层流。**

如果你决定塞片上——

1. 把 8 个 `weight_bank?` IP 改成 **ROM 模式** 或综合期的 `readmemb`；
    
2. `wt_I_*` 写口统统割掉，Mem_Ctrl 精简为 **读列脉冲生成器**；
    
3. 重新算片上 BRAM/URAM 用量，留 10–20% 余量给其它缓冲区，就可以收工。