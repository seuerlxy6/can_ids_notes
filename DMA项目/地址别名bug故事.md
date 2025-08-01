面试官您好，关于您问到的这个Bug，是我在实习期间遇到的一个印象最深刻的问题，我从**现象、定位、解决**三个方面来详细说明一下。

### 1. 现象：Bug是如何暴露的？

这个Bug是在一次**系统级的集成测试（IT）**中暴露的。

- **测试场景(Test Case):** 我当时正在运行一个自己设计的复杂场景，目的是为了压力测试系统总线。该场景中，**CPU的双核与DMA模块会同时并发访问SRAM**。具体来说，CPU核0正在对SRAM中`A区域`的数据执行运算，与此同时，DMA被配置为从外部设备搬运一个数据块到SRAM的`B区域`。A区域和B区域在地址规划上是两个独立的、不重叠的区间。
    
- **具体错误现象:** 测试结束后，UVM环境中的Scoreboard报出了`Fatal Error`，提示数据比对失败。我检查后发现，DMA搬运到`B区域`的数据被污染了。这些数据并不是随机的乱码，而是**部分地、非预期地掺杂了CPU核0正在`A区域`处理的数据**。这非常奇怪，因为从逻辑上讲，这两个模块操作的地址空间是完全独立的，本不应该有任何交集。
    

### 2. 定位：如何一步步找到根源？

看到这个现象，我的第一反应是问题可能出在系统层面，而不是DMA模块本身。我的排查步骤如下：

- **简化环境，排除干扰：**
    
    1. 首先，我怀疑是Cache一致性问题，于是我**关闭了CPU的Cache**，但问题依旧复现。
        
    2. 接着，我怀疑是我的UVM环境或者Scoreboard逻辑有问题，但经过检查和回溯，验证了环境的正确性。
        
    3. 排除了这些可能后，我将**怀疑的焦点集中在了SoC的地址映射和总线仲裁上**。
        
- **分析波形，寻找线索：**
    
    1. 我使用Verdi打开了失败场景的波形，重点追踪AXI总线上所有进出SRAM的读写事务。
        
    2. 我在波形中设置了一个触发条件：当总线主控方(master)是CPU核0，且其目标地址在`A区域`时，观察SRAM `B区域`的写使能信号。
        
    3. 很快，我找到了关键线索：**当CPU核0向`A区域`的一个地址发起写操作时，SRAM `B区域`对应地址的写使能信号竟然也被拉高了！** 这意味着，一个发往`A区域`的写操作，被错误地“广播”到了`B区域`，导致了数据污染。
        
- **提出假设，并设计最小用例验证：**
    
    1. 这个现象让我立刻想到了一个典型原因——**地址别名（Address Alias）**。我的假设是：SRAM控制器的地址译码逻辑存在缺陷，**可能忽略了某个高位的地址比特**，导致两个不同的地址`0x1000_1234`和`0x1100_1234`被错误地译码到了同一个物理存储单元。
        
    2. 为了验证这个猜想，我编写了一个极简的C语言裸机程序，不再需要复杂的DMA和双核并发。这个程序只做两件事：首先，让CPU向`A区域`的某个地址（例如`0x1000_1234`）写入一个“魔法数字”，比如`0xDEADBEEF`。然后，立刻从`B区域`对应的地址（`0x1100_1234`）读取数据。
        
    3. **测试结果是，CPU成功地从B区域读回了那个“魔法数字”`0xDEADBEEF`**。至此，我100%确定，这就是一个地址别名Bug。
        

### 3. 解决：如何沟通与推动修复？

在确认了Bug的根源后，我采取了以下步骤来推动解决：

- **准备充分的证据：** 我没有直接去找设计工程师说“你的代码有Bug”。而是整理了一份清晰的“Bug报告”，里面包含了：
    
    1. 能稳定复现问题的**最小C代码用例**。
        
    2. 关键的**波形截图**，并用箭头和注释标明了错误的地址译码行为。
        
    3. 我对Bug根源（地址别名）的**分析和猜想**。
        
- **高效沟通：** 我拿着这份报告和设计工程师进行了当面沟通。他看到这个最小复现用例和清晰的波形后，立刻就理解了问题的所在，并很快在RTL代码中定位到了具体问题——SRAM地址译码器确实少判断了一个地址比特。
    
- **验证修复：** 设计工程师修复RTL后，我首先用之前的最小用例和最初的复杂并发场景进行了验证，确保Bug被修复。之后，我又跑了一轮更大范围的回归测试，确认这个修复没有引入新的问题。最终，这个Bug被顺利关闭。
    

通过处理这个Bug，我不仅锻炼了从系统层面分析和定位问题的能力，也深刻体会到了在团队中，如何通过清晰、高效的沟通来协同解决问题。