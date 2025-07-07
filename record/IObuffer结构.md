![[Pasted image 20250707221557.png]]

| ram1         | ram2        |
| ------------ | ----------- |
| map_10-map17 | map01-map08 |
##### **ram1**
map10包含一个bram1和一个uart串口调试模块
map11-map17只有bram
##### **ram2**
8个bank全部为自写rtl，强制映射到bram，仿真快，逻辑可见
 `(* ram_style = "block" *)                      // 综合时强制映射到 Block-RAM`

## 首先测试map10
### `ram_wea = wrenb && !rdena;` 的含义

```verilog
wire ram_wea;
assign ram_wea = wrenb && (!rdena);
```

|信号|来源|含义|
|---|---|---|
|**`wrenb`**|写端口 B 的 `write enable`|“**想写**”——In-Out-Buffer 把新特征图送进 BRAM 时拉高|
|**`rdena`**|读端口 A 的 `read enable`|“**正在读**”——Mem-Ctrl/PE 要从同一块 BRAM 读数据时拉高|

> **目的：** **同一个时钟沿**里如果既想写又想读，就**先保证读**，把写关掉，避免**读写冲突**。

---

#### 1. 典型工作场景

|时钟沿|`rdena`|`wrenb`|`ram_wea`|说明|
|---|---|---|---|---|
|**Ping-写**|0|1|1|当前层 `nn_layer_cnt[0]=1` → 写 **bank1**（CAN_bank1）|
|**Pong-读**|1|0|0|另一半阵列在读 **bank0**，写端保持低|
|**冲突沿**|1|1|0|万一两边同时拉高，用 `!rdena` 禁掉这拍写|

> _Vivado 的 Block Memory Generator 在 **Simple Dual-Port (SDP)** 配置下，  
> 同时对 **同一个端口** 做读写会产生不确定数据或冲突警告。_  
> 因为 `addr_a/addr_b` 在系统里可能还没完全解耦（尤其 pipeline 阶段同拍发生时）。

---

#### 2. 如果 **确定两端口地址永不相同**

- 可以 **直接用 `ram_wea = wrenb`**，BRAM 支持 **两端口异步操作**。
    
- 但要确保：
    
    1. `addr_a` 与 `addr_b` **不在同一拍指向同一地址**；
        
    2. IP **配置为 True Dual-Port，独立写口**。
        

否则保持现在的 **互斥写** 更安全。

---

#### 3. 与 `SPI_start`、层流水的关系

- `SPI_start` 高时整块 BRAM 当作 **原始 ECG 环形缓冲**，  
    写端口实际来自 `IOB_Data_I_vld_ECG`，这里 `wrenb` 会被拉低或屏蔽。
    
- 层间 **Ping/Pong**：`nn_layer_cnt[0]` 决定是 **bank0** 还是 **bank1** 写入，  
    读端始终反相取另一半，配合 `ram_wea` 保证 **读优先**。
    

---

### 小贴士

1. **写、读在不同端口**且地址完全分离 → 直接用 `ram_wea = wrenb` 更高带宽。
    
2. 想保留“读优先”但允许并发，可做 **地址比较** 只屏蔽同地址冲突：
    
    ```verilog
    assign ram_wea = wrenb && !(rdena && (addr_a == addr_b));
    ```
    
3. 如果最后把 IP 配成 **独立时钟 True-DP**，Vivado 会内部处理冲突，可去掉该门控。