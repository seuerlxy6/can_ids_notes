### 1 | 目录骨架

dma_uvm/
├── rtl/              # dma_stub.sv 放这里
├── tb/
│   ├── if/           # 接口 dma_if.sv
│   ├── env/          # UVM 组件
│   ├── seq/          # 序列
│   └── top/          # tb_top.sv + pkg.sv
├── scripts/          # 编译 / 运行 / 覆盖率
└── doc/              # README、时序图


### 2 | env

![[Pasted image 20250806173021.png]]

### `dma_scoreboard.sv` 的详细解释

`dma_scoreboard`的**核心职责是判断DUT（设计）的行为是否正确**。它像一个裁判，根据从Monitor收集到的信息来打分。

Code snippet

```
// File: dma_scoreboard.sv

class dma_scoreboard extends uvm_component;
    `uvm_component_utils(dma_scoreboard) // UVM组件的工厂注册宏

    uvm_analysis_imp#(string, dma_scoreboard) imp; // 1. 定义一个分析导入端口(imp)
    
    uvm_event transfer_done_event; // 2. 声明一个uvm_event句柄

    function new(string n, uvm_component p); 
        super.new(n,p);
        imp = new("imp", this); // 创建imp端口实例
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 3. 从全局事件池中获取事件句柄
        transfer_done_event = uvm_event_pool::get_global("transfer_done_event");
    endfunction

    // 4. 实现write方法，这是imp端口的核心
    function void write(string t);
        if(t == "DONE") begin
            `uvm_info("SCB", "Transfer completed OK", UVM_LOW)
            // 5. 验证成功，触发事件
            transfer_done_event.trigger();
        end else begin
            `uvm_error("SCB", "Error interrupt observed")
        end
    endfunction
endclass
```

**代码详解**:

1. **`uvm_analysis_imp`**: Scoreboard通过这个端口接收来自Monitor的数据。在你的设计中，Monitor会监测到`irq_done`信号，然后将一个`"DONE"`字符串发送出来。这个字符串最终就会被Scoreboard的`write`方法接收到。
    
2. **`uvm_event`**: 这是一个UVM同步工具。你可以把它想象成一个“信号旗”。当某个条件满足时，一个组件可以举起旗子 (`trigger`)，而另一个组件可以一直等待 (`wait_trigger`) 直到看到旗子被举起。
    
3. **`uvm_event_pool::get_global(...)`**: UVM提供了一个全局的事件池，我们可以通过一个独一无二的字符串名字（这里是`"transfer_done_event"`）来获取同一个事件的句柄。这使得像Scoreboard和Test这样没有直接连接的组件可以方便地进行通信。
    
4. **`write(string t)`**: 这是`uvm_analysis_imp`要求必须实现的方法。每当有分析数据被发送到这个端口，`write`方法就会被自动调用。参数`t`就是接收到的数据（这里是`"DONE"`或`"ERR"`字符串）。
    
5. **`transfer_done_event.trigger()`**: 这是整个机制的关键。当Scoreboard判断出DMA传输成功时（收到了`"DONE"`），它就调用`trigger()`方法“举起信号旗”，通知其他正在等待的组件：“测试成功了，可以进行下一步了！”。
    

---

### `basic_test.sv` 的详细解释

`basic_test`是一个具体的UVM测试用例。它的**核心职责是配置验证环境，并定义测试的执行流程和结束条件**。


```
// File: basic_test.sv

class basic_test extends uvm_test;
    `uvm_component_utils(basic_test) // UVM测试用例的工厂注册宏

    dma_env env; // 1. 声明环境(env)的句柄

    function new(string n, uvm_component p); 
        super.new(n,p); 
    endfunction

    // 2. 在build_phase中，创建env实例
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = dma_env::type_id::create("env", this);
    endfunction

    // 3. run_phase定义了测试的动态行为
    task run_phase(uvm_phase phase);
        // 4. 获取与scoreboard中完全相同的事件
        uvm_event transfer_done_event = uvm_event_pool::get_global("transfer_done_event");

        phase.raise_objection(this); // 5. 挂起objection，防止仿真提前结束

        // 6. 创建并启动测试序列
        sw_transfer_seq seq = sw_transfer_seq::type_id::create("seq");
        seq.start(env.agt.sqr);

        // 7. 等待scoreboard触发事件
        `uvm_info("TEST", "Sequence sent, now waiting for scoreboard event...", UVM_LOW)
        transfer_done_event.wait_trigger();
        `uvm_info("TEST", "Event received from scoreboard, test passed!", UVM_LOW)

        #100; 

        phase.drop_objection(this); // 8. 撤销objection，允许仿真结束
    endtask
endclass
```

**代码详解**:

1. **`dma_env env`**: 在Test中声明了`dma_env`（环境）的句柄。
    
2. **`env = dma_env::type_id::create(...)`**: 在`build_phase`中，Test负责创建`dma_env`。这是UVM层次结构（Test-Env-Agent-Driver/Monitor）的体现。
    
3. **`run_phase`**: 这是UVM的主要运行阶段，所有动态的测试行为都在这里发生。
    
4. **`uvm_event_pool::get_global(...)`**: Test使用和Scoreboard**完全相同的字符串**从全局池中获取了同一个事件的句柄。
    
5. **`raise_objection`**: 这是UVM的结束控制机制。只要有objection被挂起，仿真就不会结束。
    
6. **`seq.start(...)`**: Test通过启动一个sequence来产生激励，驱动DUT。
    
7. **`wait_trigger()`**: 这是与Scoreboard中`trigger()`相对应的操作。代码执行到这里会暂停，直到Scoreboard那边举起“信号旗”。一旦事件被触发，`wait_trigger()`就执行完毕，代码继续向下执行。
    
8. **`drop_objection`**: 当Test确认关键事件已发生，测试目标达成后，它就撤销自己挂起的objection。当所有组件都撤销了objection，UVM就会结束仿真。
    

---

### 回答你的问题

1. basictest是验证的顶层文件吗？
    
    不完全是，但可以理解为UVM验证平台的“总指挥”或“总控制器”。
    
    - 物理上的顶层文件是`tb_top.sv`，它实例化了DUT和interface，并调用`run_test("basic_test")`来启动UVM环境。
        
    - 在UVM的**组件层次结构**中，`basic_test`处于最顶端。它负责搭建下面的`env`等所有组件，并发号施令（启动sequence，决定何时结束）。所以，它是UVM世界的“顶层”。
        
2. 他会调用下面的env？
    
    是的。更准确地说，是创建和配置下面的env。
    
    - 如代码所示，在`basic_test`的`build_phase`中，有这样一行：`env = dma_env::type_id::create("env", this);`。
        
    - 这行代码使用UVM工厂机制创建了`dma_env`的一个实例。`dma_env`接下来会创建它自己的子组件（如agent和scoreboard），agent又会创建driver和monitor，这样一层层地将整个验证平台搭建起来。
        
    - 因此，`basic_test`是整个UVM组件树的树根。
