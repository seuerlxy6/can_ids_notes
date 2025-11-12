每拍输入一个像素，按行主序存入
在 (row,col) ∈ {(7/11/15),(7/11/15)} 时拉高 win_valid 1 拍，并在 win_bus 输出 64 个像素
将当前输入写入 linebuf[7][col]，并在换行时整体"下移"：linebuf[r] <= linebuf[r+1]