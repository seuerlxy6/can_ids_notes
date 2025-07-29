DMA 即直接存储器访问，是一种应用在系统中高效搬运数据的专用接口电 路[1]。DMA 可以不借助 CPU，将数据从一个地址空间拷贝到另一个地址空间， 从而在传输过程中释放 CPU。
在大批量的数据传输中，DMA 的功能与工作效率对车规级 MCU 的系统性能至关重要[4]。为了提高车规级 MCU 的工作效率，本文在车规级 MCU 中，创新设计了一个具有低功耗、多通道等特点的 DMA，实现了车规级 MCU 高速传输数据的目标。

先给结论：要拆穿这一段经历，考官只要往 **细节、上下文、一致性、时间轴** 四条线深挖，很快就能戳出破绽。下面把典型“验真”问题列出来，你自己试着逐一演练，确保回答得出。

---

## 1 | 模块背景能否自洽

|追问|暗藏核查点|
|---|---|
|**「这颗 DMA 的寄存器地图长什么样？Block Transfer 要写哪几个寄存器、按什么顺序触发？」**|真做过的人能脱口说出寄存器名、位定义，以及软触发流程（如 `CTRL.EN→SRC→DST→SIZE→START`）；瞎编的一般只会讲概念。|
|**「硬件触发进来的外设信号是同步还是异步？怎么做 CDC？」**|CDC 方案（双触发器 / 手掂握手）说不清，就露馅。|
|**「8‑channel priority 是 RR 还是固定优先级？仲裁延迟几拍？」**|细到时序与延迟，是识别“纸面理解”与“真调过 RTL”的分水岭。|

---

## 2 | UT 细节能否对得上

1. **「你 `uvm_reg_sequence` 里用的 Mirror 模式是 check 还是 compare？reset value mismatch 怎么处理？」**
    
2. **「随机激励 8 通道时，channel×trigger×burst 共多少 bin？Fcov=95% 是具体哪些 bin 掉了？」**
    
3. **「DMA ErrIRQ 注入非法地址——非法到哪一级？AXI Slave 返回什么 response？」**
    

这些问题卡在 **寄存器模型、覆盖模型、协议响应** 三件事；没实操经验的人往往给不出精确回答。

---

## 3 | IT 场景可否闭环

|追问|检查点|
|---|---|
|**「双核抢占时，两颗 CPU 对 DMA 寄存器访问靠什么互斥？Spinlock？Mutex？还是完全靠硬件仲裁？」**|需要说清软硬分工。|
|**「你写的 C‑test 编译进哪路裸机镜像？链接脚本谁维护？SRAM/DDR 物理地址？」**|真跑过板子的人才熟悉启动流程和内存映射。|
|**「address‑alias Bug 具体现象？RTL 哪一行代码改掉了？」**|说不出 diff，就可能是听同事转述。|

---

## 4 | 覆盖率与脚本是否可信

- **「UCDB 统计的 Fcov 95%，Line 90%——Tcov 为什么只有 88%？差的那 12% 哪些状态机分支？」**
    
- **「夜间回归 300 case 用 VCS 单机还是 farm？跑完要多久？fail triage 怎么自动分类？」**
    
- **「Python 脚本核心函数是什么？用哪几个 Option 生成随机种子？」**
    

数字好看却解释不出来源，就成负分项。

---

## 5 | 时间轴是否合理

- **两个月** 想交付 _UT + IT + 自动化 + Bug 修复_，面试官会反问：  
    _“你每天怎么分配时间？UT 覆盖率爬梯子花了几天？CI 环境谁给的权限？”_  
    具体排期说不清，说明故事不落地。
    

---

## 6 | 团队角色对得上资源

> **「整个验证团队几个人？你的 mentor 负责哪块？你的代码 merge 了多少行？」**

实习生往往在现成平台上补 Case，而不是从 0 搭 Jenkins；若你把所有高难活都揽到自己身上，很容易遭反问。

---

### 备忘

- **工具链**：版本号、常用命令、常见报错。
    
- **协议**：AXI 总线各通道握手、响应码。
    
- **覆盖模型**：cross bin 定义 & why missing。
    
- **Bug 案例**：现象→定位→RTL patch→回归验证，全链路要能讲顺。
    

把这些盲区补牢，才能让经历听起来“像真的”。
### 🔹 DMA 模块背景与寄存器结构

> **问：DMA模块主要功能是什么？触发方式？寄存器配置流程？**

答：我们验证的是一颗 AXI 接口的 8 通道 DMA，支持：

- **三种触发方式**：软件触发（写 `CTRL.EN`）、外设信号硬件触发（如 `TRIGx`）、EIRQ3 链式触发；
    
- **三种传输模式**：单次、自动重载（ring）、链表（link descriptor）；
    
- **支持错误检测**：如非法地址或越界大小会触发 DMA_ERR_IRQ。
    

典型的软触发流程是：`SRC_ADDR` → `DST_ADDR` → `SIZE` → `CTRL.EN=1` → `START=1`。读写寄存器会返回 BUSY 或 DONE 状态，由 `STATUS` 寄存器指示。

### 🔹 UT 验证细节：核心用例拆解

> **问：你具体做了哪些验证场景？怎么设计的？**

5 个核心用例如下：

1. **寄存器读写+reset**：用 `uvm_reg_sequence` 自动化读写 RAL（register abstraction layer），在不同 reset 条件下比对 R/W 一致性；
    
2. **软件触发 block transfer**：模拟 CPU 配置完所有寄存器后置位 `START=1`，观察 AXI 输出行为；
    
3. **硬件触发**：拉高 `TRIG[3:0]` 外设中断信号后进入 transfer，测试 CDC 和去抖动逻辑是否正常；
    
4. **多通道仲裁**：随机激励所有通道，观察仲裁策略是否遵循 priority register 配置（静态优先）；
    
5. **DMA 错误中断**：向 `SRC_ADDR` 写入非法地址（未对齐 / 超过地址映射区间），验证是否正确拉起 `DMA_ERR_IRQ`。

 ## **IT 阶段你在 SoC（C031 MPW，双核 ARM Cortex‑M）里具体验证了什么？C 程序怎么写的？**

我把 IP‑级激励迁移到裸机 C 环境，围绕 **寄存器可达性／中断／异常** 三条主线设计了 4 个系统场景，全部跑在 MMIO 直访、无 RTOS 的框架下（DMA 基址 0x1C00_0000）：

|场景|目标|关键步骤（内核视角）|
|---|---|---|
|**① 双核寄存器 & Reset**|确认 CPU0/CPU1 均能可靠访问 DMA RAL，并验证 POR / SYSRST 后 reset value|- CPU0 读写 `CTRL`, `SIZE`，CPU1 随机读回 - 下发 `SYSRST`，再次比对 all 32 个寄存器默认值|
|**② EIRQ3 外设触发搬运**|验证硬件链路：PORT‑INT PTM → EIRQ3 → DMA → AXI|- 配置 PTM/EIRQ3 打通触发通路 - 外设脉冲拉高 EIRQ3，DMA 把 1 KB 数据从 SRAM0→SRAM1 - CRC 校验搬运结果|
|**③ Completion Interrupt（CPU1）**|检查 Transaction‑Done 中断向量与 clear 流程|- CPU0 发起软触发 Block Transfer - CPU1 进入 WFI，捕获 `TC_IRQ` - ISR 里清 `IRQ_STATUS`，写日志标记完成|
|**④ Halt / Resume**|评估 dma_haltreq 流控|- Pattern 定时 toggle `dma_haltreq` (200 clk 高电平) - 读 `STATUS=0x4`→halt，低电平后确认 DMA 续传并输出正确结果|

四个场景共享一套 `dma_drv.c/h` 小驱动（init、kick、poll），加上 linker script 把代码放到 `0x1000_0000` ITCM、数据放到 DTCM，跑完一轮约 90 ms。所有 test case 加入 Makefile‑based regression，PASS/FAIL 由串口 log 关键字比对。