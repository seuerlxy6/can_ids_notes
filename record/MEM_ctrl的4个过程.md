1、layer1 can数据输入
![[Pasted image 20250702214719.png]]
主状态机--3
8个数据一组写入，从0地址开始，行主序写入64×64×3=4096的一张图
2、取参数、取权重
![[Pasted image 20250702215230.png]]
参数硬编码，这里的取参数是伪
第一层权重3×3×3有8个，直接放到8个bank里面，wt_I_addr从0-26
2、layer1-2的imap写出到input regfile
![[Pasted image 20250702215610.png]]
读第一层的数据，hu=33×3，一批数据01234----89abc----def。。。-----rd_done----进入regfile
rd_done---rd_done_temp读权重

3、layer1-2的omap从output regfile写回
4、权重从DDR--BUFFER（去掉）
5、权重从buffer读出