![[Pasted image 20250707221557.png]]

| ram1         | ram2        |
| ------------ | ----------- |
| map_10-map17 | map01-map08 |
##### **ram1**
map10包含一个bram1和一个uart串口调试模块
map11-map17只有bram
##### **ram2**
8个bank全部为自写rtl，强制映射到bram，仿真快，逻辑可见
 `(* ram_style = "block" *)                      // 综合时强制映射到 Block-RAM`

## 首先测试map10
`wire ram_wea;`
`assign ram_wea = wrenb && (!rdena);`