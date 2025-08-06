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

