1、layer1 can数据输入
![[Pasted image 20250702211950.png]]
主状态机--3
8个数据一组写入
2、layer1-2的imap写出到input regfile
3、layer1-2的omap从output regfile写回
4、权重从DDR--BUFFER（去掉）
5、权重从buffer读出