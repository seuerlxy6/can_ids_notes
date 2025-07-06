![[Pasted image 20250706171418.png]]
每个bank的最大深度为907
[[20250705weightbuffer_分析思考源代码]]

把 Block RAM 用 .coe 文件做 初始化 ROM，比特流下载进 FPGA 时，权重已经随配置数据写进片内 BRAM，不用取权重了
把wea写成 0，固定为读数据，等价于把这块 BRAM当只读 ROM