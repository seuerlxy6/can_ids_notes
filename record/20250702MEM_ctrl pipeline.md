## 1、layer1 can数据输入
![[Pasted image 20250702214719.png]]
主状态机--3
8个数据一组写入，从0地址开始，行主序写入64×64×3=4096的一张图
## 2、取参数、取权重
![[Pasted image 20250702215230.png]]
参数硬编码，这里的取参数是伪
第一层权重3×3×3有8个，直接放到8个bank里面，wt_I_addr从0-26
## 3、layer1-2的imap写出到input regfile
![[Pasted image 20250702215610.png]]
读第一层的数据，hu=33×3，一批数据01234----89abc----def...-----rd_done----进入regfile----rd_addr=20是第一批hu进入regfile的最后一个数据
rd_done---rd_done_temp读权重wt_C0_O_Vld有效的同时，读出第一列的第一个权重0，第一列一共读0-8共九个权重，这次计算产生的部分和存在pe单元中，后续列流水读出
![[Pasted image 20250702220103.png]]
![[Pasted image 20250702220423.png]]
到这才算是完成3个通道的乘累加得到omap的一组（16×8个）像素点
## 4、layer1-2的omap从output regfile写回
![[Pasted image 20250702220648.png]]
写回相对简单，三层循环，32×32×8的图像，先按通道走1-8，8个8个写，一行32个点，要走4次走完一行0-3，然后换行0-31，
这样算是完成一次计算

