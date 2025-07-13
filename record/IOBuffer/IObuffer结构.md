![[Pasted image 20250712221808.png]]

| ram1         | ram2        |
| ------------ | ----------- |
| map_10-map17 | map01-map08 |
ram1需要8个bank存入第一层input的数据
![[Pasted image 20250712230521.png]]
![[iobuffer (1).png]]
整体仿真：
4层计算，先读后写
![[Pasted image 20250713000329.png]]
FC:
![[Pasted image 20250713000458.png]]

1、读第一层数据（64×64×3的图片）
预先存在ram1里的coe，可以正确读出
![[Pasted image 20250712235215.png]]写回
![[Pasted image 20250713001806.png]]
2、第二层读正是第一层写
![[Pasted image 20250713002901.png]]