一个简单的双端口BRAM
A口写数据data_b
B口读数据data_a
uart串口最终输出2个8bit数据，即为最终fc的输出结果，这部分暂时不看
https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/block_memory_generator.html
https://docs.amd.com/v/u/en-US/pg058-blk-mem-gen
![[Pasted image 20251104172909.png]]
![[Pasted image 20251104174710.png]]
![[Pasted image 20251104175449.png]]
![[Pasted image 20251104175736.png]]
选择原始输出寄存器，读数据延迟2拍

`Mem_Data_Ivld` 这个信号的作用是：**由 Memory Controller 告诉 In_Out_Buffer，“我这拍发出的读地址对应的数据在这拍有效”**。它是**读数据握手的有效标志**。
为了补偿 `CAN_bank0` 端口 B 的两拍同步读延迟，使 `IOB_Data_O_vld` 与 `IOB_Data_Ox` 对齐。