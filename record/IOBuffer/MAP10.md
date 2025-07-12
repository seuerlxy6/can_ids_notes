对于IP本身来说：A口写B口读
但代码里面是data_a是读出来的数据，data_b是写进去的数据
重新写memory_map01
只保留ram功能，暂时不要uart
读数据使能到数据出来差两个时钟
![[Pasted image 20250712215522.png]]
读优先
先读数据1f再写数据01
![[Pasted image 20250712215653.png]]