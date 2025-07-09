# training_and_evaluation.py

import time
import torch
from torch import nn, optim
from torch.utils.tensorboard import SummaryWriter
from tqdm import tqdm

# 混淆矩阵可视化需要以下库
# import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix, ConfusionMatrixDisplay


def run_one_epoch(model, dataloader, criterion, optimizer=None):
    """
    进行单轮训练或验证（由 optimizer 是否为 None 决定）。
    Args:
        model: 当前的 PyTorch 模型
        dataloader: DataLoader
        criterion: 损失函数
        optimizer: 优化器(如果传 None, 就是验证模式)
    Returns:
        avg_loss: 该轮训练/验证的平均损失
        accuracy: 该轮训练/验证的准确率
    """
    is_train = optimizer is not None
    model.train() if is_train else model.eval()

    total_loss, correct, total = 0.0, 0, 0
    # tqdm 加进度条可视化
    loop_desc = "Train" if is_train else "Val"  # 按 batch 显示
    loop = tqdm(dataloader, desc=loop_desc, leave=False)

    # 是否要追踪梯度取决于是否在训练
    with torch.set_grad_enabled(is_train):
        for inputs, labels in loop:
            if is_train:
                optimizer.zero_grad()

            outputs = model(inputs)
            loss = criterion(outputs, labels)

            total_loss += loss.item()

            # 计算准确率
            _, predicted = torch.max(outputs, 1)
            correct += (predicted == labels).sum().item()
            total += labels.size(0)

            if is_train:
                loss.backward()
                optimizer.step()

    avg_loss = total_loss / len(dataloader)
    accuracy = correct / total if total > 0 else 0
    return avg_loss, accuracy


def train_model(model, train_loader, val_loader, log_dir="runs/can_net_training",
                epochs=10, lr=0.001, save_path=None,
                patience=5, use_cosine=True):
    """
    训练并验证模型。
    Args:
        model: PyTorch 模型
        train_loader: 训练集 DataLoader
        val_loader: 验证集 DataLoader
        log_dir: TensorBoard 日志存放路径
        epochs: 最大训练轮次
        lr: 初始学习率
        save_path: 模型最优权重的保存路径 (str or None)
        patience: Early Stopping 容忍的连续验证不提升次数
        use_cosine: 是否使用余弦退火学习率
    Returns:
        model: 训练好的模型
    """
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)

    # 学习率调度器：CosineAnnealingLR
    # 如果不想用余弦退火，就可以换成 ReduceLROnPlateau 或其他
    if use_cosine:
        scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs)
    else:
        # 可以换成其他scheduler，例如:
        # scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, 'max')
        scheduler = None

    writer = SummaryWriter(log_dir)
    start_time = time.time()

    best_val_acc = 0.0
    best_epoch = 0
    wait = 0  # 记录连续多少轮验证集未提升

    for epoch in range(epochs):
        # 1) 训练
        train_loss, train_acc = run_one_epoch(model, train_loader, criterion, optimizer)

        # 2) 验证
        val_loss, val_acc = run_one_epoch(model, val_loader, criterion)

        # 3) 学习率调度器更新
        if scheduler is not None:
            # 对于 CosineAnnealingLR：每个 epoch 都要调用 scheduler.step()
            # 如果是 ReduceLROnPlateau：要 scheduler.step(val_acc)
            scheduler.step()

        # 4) TensorBoard 记录
        current_lr = optimizer.param_groups[0]['lr']
        writer.add_scalars('Loss', {'Train': train_loss, 'Val': val_loss}, epoch + 1)
        writer.add_scalars('Accuracy', {'Train': train_acc, 'Val': val_acc}, epoch + 1)
        writer.add_scalar('Learning Rate', current_lr, epoch + 1)

        # 5) 打印信息
        print(f"""
[Epoch {epoch + 1}/{epochs}]
Train     - Loss: {train_loss:.4f} | Acc: {train_acc:.2%}
Val       - Loss: {val_loss:.4f}   | Acc: {val_acc:.2%}
LR: {current_lr:.6f}
        """.strip())  # .strip()清理前后换行

        # 6) 检查是否是最佳表现, 并进行 Early Stopping 判定
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_epoch = epoch + 1
            wait = 0
            if save_path is not None:
                torch.save(model.state_dict(), save_path)
        else:
            wait += 1
            # 如果验证集不提升次数超 patience, 提前停止
            if wait >= patience:
                print(f"Early Stopping at epoch {epoch + 1}. Best Val Acc: {best_val_acc:.2%} (epoch {best_epoch})")
                break

    writer.close()
    print(f"Training done in {time.time() - start_time:.2f} seconds. Best Val Acc: {best_val_acc:.2%}")

    return model


def evaluate_model(model, dataloader, show_confusion=True):
    """
    二分类评估：输出Accuracy, Precision, Recall, F1, FNR等，并可选混淆矩阵可视化
    Args:
        model: PyTorch 模型
        dataloader: 测试/验证集 DataLoader
        show_confusion: 是否可视化混淆矩阵
    """
    model.eval()
    correct, total = 0, 0
    FN = FP = TP = TN = 0
    all_labels = []
    all_preds = []

    start_time = time.time()

    with torch.no_grad():
        for inputs, labels in dataloader:
            outputs = model(inputs)
            _, predicted = torch.max(outputs, 1)
            correct += (predicted == labels).sum().item()
            total += labels.size(0)
            FN += ((predicted == 0) & (labels == 1)).sum().item()
            FP += ((predicted == 1) & (labels == 0)).sum().item()
            TP += ((predicted == 1) & (labels == 1)).sum().item()
            TN += ((predicted == 0) & (labels == 0)).sum().item()

            # 用于混淆矩阵
            all_labels.extend(labels.cpu().numpy())
            all_preds.extend(predicted.cpu().numpy())

    acc = correct / total if total > 0 else 0
    precision = TP / (TP + FP) if (TP + FP) else 0.0
    recall = TP / (TP + FN) if (TP + FN) else 0.0
    f1_score = 2 * (precision * recall) / (precision + recall) if (precision + recall) else 0.0
    fnr = FN / (TP + FN) if (TP + FN) else 0.0

    print(f"Evaluation completed in {time.time() - start_time:.2f} seconds")
    print(f"""
Accuracy:        {acc:.4%}
Error Rate:      {1 - acc:.4f}
Precision:       {precision:.4f}
Recall:          {recall:.4f}
F1-score:        {f1_score:.4f}
FNR (漏报率):     {fnr:.4f}
False Negatives: {FN}
False Positives: {FP}
True Positives:  {TP}
True Negatives:  {TN}
    """.strip())
'''
    if show_confusion:
        # 生成并可视化混淆矩阵
        cm = confusion_matrix(all_labels, all_preds, labels=[0, 1])
        disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=[0, 1])
        disp.plot(cmap=plt.cm.Blues)
        plt.title("Confusion Matrix")
        plt.show()

'''
# ---- 使用示例（main 入口） ----
if __name__ == "__main__":
    import torch.nn.functional as F
    from torch.utils.data import DataLoader, TensorDataset

    # [示例用随机数据构造一下训练/验证/测试集]
    # 数据规模很小，只是演示结构
    X_train = torch.randn(200, 10)  # 200 条，10 维特征
    y_train = torch.randint(0, 2, (200,))  # 0/1 二分类
    X_val = torch.randn(50, 10)
    y_val = torch.randint(0, 2, (50,))
    X_test = torch.randn(30, 10)
    y_test = torch.randint(0, 2, (30,))

    train_dataset = TensorDataset(X_train, y_train)
    val_dataset = TensorDataset(X_val, y_val)
    test_dataset = TensorDataset(X_test, y_test)

    train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=32)
    test_loader = DataLoader(test_dataset, batch_size=32)


    # [示例模型：一个简单的全连接网络]
    class SimpleNet(nn.Module):
        def __init__(self):
            super().__init__()
            self.fc1 = nn.Linear(10, 16)
            self.fc2 = nn.Linear(16, 2)

        def forward(self, x):
            x = F.relu(self.fc1(x))
            x = self.fc2(x)
            return x


    model = SimpleNet()

    # 训练模型
    model = train_model(
        model,
        train_loader=train_loader,
        val_loader=val_loader,
        log_dir="runs_20epoch_rgb_all_data/demo_experiment",
        epochs=20,
        lr=0.01,
        save_path="unable/best_model.pth",
        patience=5,
        use_cosine=True
    )

    # 加载最好模型权重
    model.load_state_dict(torch.load("unable/best_model.pth", weights_only=False))

    # 在测试集上评估
    evaluate_model(model, test_loader, show_confusion=True)
