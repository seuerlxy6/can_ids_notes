![[Pasted image 20250706174833.png]]
每个bank的最大深度为907
[[20250705weightbuffer_分析思考源代码]]

把 Block RAM 用 .coe 文件做 初始化 ROM，比特流下载进 FPGA 时，权重已经随配置数据写进片内 BRAM，不用取权重了
**A口写，B口读**
把wea写成 0，固定为读数据，等价于把这块 BRAM当只读 ROM
B口读有两个时钟延迟
![[Pasted image 20250702220103.png]]
在memctrl中权重有效和地址都是流水给出的
![[Pasted image 20250706182532.png]]
设计文件逻辑正确，1more和数据读出差两个时钟
testbench有点问题但不用修改,weight_bufferok