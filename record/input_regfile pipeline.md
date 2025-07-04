1、读数据
IR_Data_I_vld
Bm_cnt_in[5:0]
kh_cnt_in[5:0]
三个信号共同控制
第一批hu，33——5列——5×8=40个reg存一行，一共需要120个reg
IR_Data_I_vld
Bm_cnt_in[5:0]
kh_cnt_in[5:0]同时进入，计数器用来算地址，完成120个数据的输入
![[Pasted image 20250704162119.png]]

