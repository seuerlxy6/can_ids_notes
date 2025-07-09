
目标：给已有CAN总线 / 神经网络背景的研究生
范围：数据预处理 → RGB 编码 → 轻量 CNN 设计 → 一次性剪枝 + INT8 PTQ → 评估  
## 0. 环境配置

| 类别      | 版本                                                                                         |
| ------- | ------------------------------------------------------------------------------------------ |
| Python  | 3.11                                                                                       |
| PyTorch | 2.5.1                                                                                      |

---

## 1、数据集与目录结构
[HCRL - Car-Hacking Dataset](https://ocslab.hksecurity.net/Datasets/car-hacking-dataset)
### HCRL Car-Hacking Dataset 
Car-Hacking-Dataset/
├── normal.csv                  # 正常行驶（约 30 min）
├── DoS_dataset.csv             # DoS 注入
├── Fuzzy_dataset.csv           # Fuzzy 随机注入
├── Gear_dataset.csv            # 变速挡位欺骗
└── RPM_dataset.csv             # 转速表欺骗
每个 .csv 文件都记录一段独立实验：约 30–40 min 总时长，期间重复 300 次注入事件，单次攻击持续 3–5 s

| 列名            | 类型    | 描述                   |
| ------------- | ----- | -------------------- |
| `Timestamp`   | float | 记录时间，Unix 秒          |
| `CAN ID`      | hex   | 11-bit ID（示例 `043f`） |
| `DLC`         | int   | Data Length Code，0–8 |
| `DATA[0]…[7]` | hex   | 0–8 字节报文内容           |
| `Flag`        | char  | `T`=注入帧，`R`=正常帧      |

### 代码目录
├─dataset_hack(原始数据集)
├─dataset_img_hack
**get_image.py生成的图片和标签,0.2代表取了原数据集每个csv20%的数据，具体比例可根据脚本中的参数修改，取不同数量的数据**
│  ├─0.2_can_images
│  ├─0.2_label.csv
├─get_image.py
├─dataloader_rgb.py（配合get_image）
├─CNN_RGB_NICE.py（保存原始模型，打印模型结构、保留原始训练验证函数）
├─purne.py（剪枝）
├─quant.py（量化）
├─rgb-main.py（主函数）
├─training_and_evaluation.py（训练测试脚本）
├─print.py（模型打印脚本）
├─can_net_cp_0.2_20.pth
├─can_net_cp_0.2_20.pthpruned_finetuned.pth
├─can_net_cp_0.2_20.pthpruned_quantized.pth
├─runs（tensorboard）
│  └─can_net_training
## 2、主函数--rgb-main.py
**整体流程**
原始 CAN 日志                                            
        │ 16 帧滑窗
16×16×3 CAN‑RGB 图像               
        │ 线性放大                            
        └────► 64×64×3 图像 ─► 轻量 CNN (CANET‑33K) ─► 一次式剪枝 + INT8 量(CANET‑7K) 

`if __name__ == "__main__":`  
    `model = CanNet_complex()`  
	//训练
    `train_model(model, img_dataloader, val_dataloader, log_dir='runs/can_net_cp_0.2_20', epochs=20, save_path='CNN/can_net_cp_0.2_20.pth')`  
    `model.load_state_dict(torch.load('CNN/can_net_cp_0.2_20.pth', weights_only=True))`  
    //验证
    `evaluate_model(model, test_dataloader)`  
    `device = torch.device("cuda" if torch.cuda.is_available() else "cpu")`  
	  //剪枝
    `model = run_structured_pruning(`  
        `model_class=CanNet_complex,`  
        `dataloaders=(img_dataloader, val_dataloader, test_dataloader),`  
        `original_model_path="CNN/can_net_cp_0.2_20.pth",`  
        `pruned_model_path="CNN/can_net_cp_0.2_20_pruned.pth",`  
        `device=device`  
    `)`  
	  //量化
    `quant_model = quantize_and_compare_model(`  
        `model_fp32=model,`  
        `calib_loader=cer_dataloader,`  
        `test_loader=test_dataloader,`  
        `fp32_path="CNN/can_net_cp_0.2_20_pruned.pth",`  
        `save_path="CNN/can_net_cp_0.2_20_pruned_quantized.pth"`  
    `)`
## 3、数据预处理CAN‑RGB 编码--dataloader_rgb.py
参考论文
S. Gao, L. Zhang, L. He, and F. Wang, “Attack detection for intelligent vehicles via CAN-bus: A lightweight image network approach,” IEEE Trans. Veh. Technol., vol. 72, no. 12, pp. 16 624–16 636, 2023.
将CAN报文序列数据转换成图像
CNN擅长识别颜色纹理异常，把时间、ID、数据长度这些维度映射进 RGB 通道，CNN就能发现入侵痕迹。

| 信息维度           | 映射规则                     |
| -------------- | ------------------------ |
| **时序**         | 第 _k_ 帧 → 第 _k_ 行        |
| **DLC（数据长度码）** | DLC 取值 0‑8 → 第 _x_ 列     |
| **ID**         | ID 低 12 位 → RGB 颜色（线性映射） |
| **空位**         | 填黑                       |
行号 (y轴)：代表报文的先后顺序。第 k 帧报文就画在第 k 行 。这样就保留了时间顺序信息 。
列号 (x轴)：由报文的“数据长度码（DLC）”决定。DLC的值是几，就画在第几列 。这样就体现了数据结构信息 。
像素颜色 (RGB)：由报文的ID决定。我们取ID的末尾三位十六进制数 (h_2,h_1,h_0)，通过一个公式 (R=255−17h_2,G=255−17h_1,B=255−17h_0) 转换成RGB颜色值 。
编码后得到 16×16×3 的小张量，再放大到 64×64 供 CNN 提取更细纹理

![[CAN_RGB_encoding_v4 (5).png]]

## 4、轻量 CNN（CANET‑33K）——CNN_RGB_NICE.py
多种尝试后确定的网络结构（参照lenet5）
- 3 个卷积（带 stride 直接下采样）+ 1 个 MaxPool + 两层全连接
- 参数量：32 962（132 kB）
- 这里可以自己去跑print.py 更直观

|层级|配置|输出尺寸|参数量|
|---|---|---|---|
|Conv1|3→16, 3×3, s2|16×32×32|448|
|Conv2|16→32, 3×3, s2|32×16×16|4 640|
|Conv3|32→32, 3×3, s2|32×8×8|9 248|
|MaxPool|4×4, s2|32×3×3|0|
|FC1|288→64|64|18 432|
|FC2|64→2|2|130|
## 5、剪枝 + INT8 量化——purne.py quant.py
**结构化剪枝：**
不断调参尝试——改范数，改剪枝比例，发现剪fc对精度影响相对较小，最后得出以下方案

卷积层1和2使用L1范数在通道方向选最弱通道删掉一半，直接删除卷积层3，FC 单元剪 3/4,
关键是**剪枝后将置0的位置彻底删除**才能真的减少模型参数，再微调 10 个 epoch，获得剪枝后的新模型，参数从32 962下降到7208，减少了约78%，计算量减少了62%
**后8bit量化：**
用 1 万张未见过的样本做校准，模型大小直接减半，从31.76 kB缩小到17.05 kB，而准确率几乎没有变化（保持在99.72%）

## 6 训练与评估设置

- **数据集**：公开多攻击类型 CAN 日志，共 124 k 张编码图。
- **划分**：8:1:1（Train:Val:Test），额外 10 k 张做量化校准。
- **优化器**：Adam，批量 32；学习率余弦退火。
- **指标**：Accuracy/F1/FNR + 参数量、模型大小、MACs。
通过 Early‑Stopping，可在 15‑20 分钟内用 CPU 完成本地微调。

## 7 主要实验对比

**剪枝量化效果**：

| 模型版本              | 大小 (kB) | 参数量     | MACs (M) | 准确率 (%) |
| ----------------- | ------- | ------- | -------- | ------- |
| 原始模型 (CANET-33K)  | 132.82  | 32.96 k | 2.31     | 99.89   |
| 剪枝后 (Pruned)      | 31.76   | 7.22 k  | 0.88     | 99.72   |
| 剪枝+量化后 (CANET-7k) | 17.05   | 7.22 k  | 0.88     | 99.72   |
**和参考文献对比：**

|模型|尺寸|MACs|准确率|
|---|---|---|---|
|Inception‑ResNet|7 MB|18 M|99.9 %|
|Gao 2023 轻量 CNN|280 kB|—|99.7 %|
|**本工作 INT8**|**17 kB**|0.88 M|**99.72 %**|
结果说明：在尺寸上 **比深模型小 410 倍**，性能几乎相当；非常适合资源受限的车载 ECU。
