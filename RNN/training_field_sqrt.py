# -*- coding: utf-8 -*-
"""
RNN training script for learning sqrt/CORDIC-like pattern
with randomized input order.

- 支持从文件读取 CORDIC 输入/输出 (和原来一致)
- 支持合成随机顺序的 sqrt 数据，用来训练“模式”而不是“序号”
- 绘图时 x 轴为采样时间 index，曲线呈现杂乱分布
- RNN 预测曲线颜色改为橙色
"""

import os
import json
import argparse
import numpy as np
import tensorflow as tf
from mpl_toolkits.axes_grid1.inset_locator import mark_inset, inset_axes
from tensorflow.keras import layers, models
import matplotlib.pyplot as plt
from sklearn.metrics import mean_squared_error, r2_score



# -------------------- 参数 --------------------
def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--x", default="cordic_input_real_shuffled.txt", help="path to input x file")
    ap.add_argument("--y", default="cordic_output_real_shuffled.txt", help="path to target y file")
    ap.add_argument("--seq_len", type=int, default=4, help="window length (>=1)")
    ap.add_argument("--epochs", type=int, default=120, help="training epochs")
    ap.add_argument("--batch", type=int, default=128, help="batch size")
    ap.add_argument("--out_dir", default="rnn_xy_out_train_only", help="where to save outputs")
    ap.add_argument("--seed", type=int, default=1234)
    ap.add_argument("--thresh_k_mad", type=float, default=3.0, help="u = k * MAD on train residuals")
    ap.add_argument("--plot_last", type=int, default=0,
                    help="if >0, only plot the last N points for readability")
    # 合成随机顺序数据
    ap.add_argument("--synthetic_n", type=int, default=0,
                    help="if >0, generate N synthetic sqrt samples instead of reading from file")
    ap.add_argument("--synthetic_min", type=float, default=0.0)
    ap.add_argument("--synthetic_max", type=float, default=1.0)
    ap.add_argument("--traj_len", type=int, default=128,
                    help="split synthetic data into trajectories of this length (optional)")
    ap.add_argument("--low_y_thresh", type=float, default=0.4,
                    help="samples with y < this get higher loss weight")
    ap.add_argument("--low_y_weight", type=float, default=5.0,
                    help="loss weight for samples with small y")

    return ap.parse_args()


# -------------------- 工具函数 --------------------
def load_col(path):
    return np.loadtxt(path, dtype=np.float64).reshape(-1, 1)


def build_windows(x, y, L):
    """
    x: [N, 1]
    y: [N, 1]
    return:
      X: [N-L+1, L, 1]
      Y: [N-L+1, 1]
    """
    assert len(x) == len(y)
    N = len(x)
    if L < 1:
        raise ValueError("seq_len must be >=1")
    X = np.array([x[i - L + 1:i + 1] for i in range(L - 1, N)], dtype=np.float64)
    Y = y[L - 1:]
    return X, Y


def standardize_fit(X, Y):
    mu_x = X.mean(axis=0)
    std_x = X.std(axis=0)
    std_x[std_x == 0] = 1.0
    mu_y = Y.mean(axis=0)
    std_y = Y.std(axis=0)
    std_y[std_y == 0] = 1.0
    return mu_x, std_x, mu_y, std_y


def standardize_apply_X(X, mu_x, std_x):
    return (X - mu_x) / std_x


def inv_y(y_n, mu_y, std_y):
    return y_n * std_y + mu_y


# -------------------- 合成随机顺序的 sqrt 数据 --------------------
def generate_sqrt_sequences(n_samples, vmin, vmax, traj_len):
    """
    生成 sqrt 数据，并打乱顺序，模拟实际运行时的输入到达顺序。
    返回:
      x_all: [N, 1]
      y_all: [N, 1]
      time_index: [N] 采样时间顺序
    """
    # 1) 随机采样
    x_all = np.random.uniform(vmin, vmax, size=(n_samples, 1)).astype(np.float64)
    y_all = np.sqrt(x_all)

    # 2) 完全打乱顺序，模拟实时输入
    idx = np.arange(n_samples)
    np.random.shuffle(idx)
    x_all = x_all[idx]
    y_all = y_all[idx]

    # 3) 保留采样时间序号
    time_index = np.arange(len(x_all))

    # 4) （可选）分段成轨迹，这里只是把乱序后的数据再按块切开，主要是为了和滑窗配合
    if traj_len > 0 and traj_len < n_samples:
        # 这里不再打乱块顺序，保持打乱后的时间就是训练时的时间
        pass

    return x_all, y_all, time_index


def build_model(L):
    inp = layers.Input(shape=(L, 1))
    if L == 1:
        x = layers.LSTM(16, return_sequences=False)(inp)
    else:
        x = layers.LSTM(64, return_sequences=True)(inp)
        x = layers.LSTM(32, return_sequences=False)(x)
    out = layers.Dense(1)(x)
    model = models.Model(inp, out)
    model.compile(optimizer="adam", loss="mse")
    return model


def mad_threshold(residual, k=3.0):
    r = residual.reshape(-1)
    med = np.median(r)
    mad = np.median(np.abs(r - med)) + 1e-12
    return float(k * mad)


def metrics(y_true, y_pred):
    mse = float(np.mean((y_true - y_pred) ** 2))
    rmse = float(np.sqrt(mse))
    ss_res = float(np.sum((y_true - y_pred) ** 2))
    ss_tot = float(np.sum((y_true - np.mean(y_true)) ** 2))
    r2 = 1.0 - ss_res / ss_tot if ss_tot > 0 else float("nan")
    return mse, rmse, r2


def plot_all(y, yhat, u, mse, rmse, r2, out_dir,
             plot_last=0, time_index=None,
             inset_range=(4000, 4050)):
    yt = y.reshape(-1)
    yp = yhat.reshape(-1)

    if time_index is None:
        time_index = np.arange(len(yt))

    # optional truncation
    if plot_last and plot_last < len(yt):
        yt = yt[-plot_last:]
        yp = yp[-plot_last:]
        time_index = time_index[-plot_last:]

    # main figure
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.scatter(time_index, yt, s=8, label="True sqrt(x)", alpha=0.7)
    ax.scatter(time_index, yp, s=8, label="RNN pred", alpha=0.7, color='orange')

    txt = f"MSE={mse:.3e}\nRMSE={rmse:.3e}\nR²={r2:.6f}"
    ax.text(0.02, 0.98, txt, transform=ax.transAxes,
            va="top", ha="left", bbox=dict(boxstyle="round", alpha=0.2))

    ax.set_xlabel("Sample Time Index")
    ax.set_ylabel("Value")
    ax.set_title("RNN Prediction vs True sqrt(x) (Randomized Order)")
    ax.legend(loc="lower left")

    # ---- inset zoom ----
    start, end = inset_range  # e.g. (4000, 4050)
    # pick indices within this window
    mask = (time_index >= start) & (time_index <= end)
    # create inset axes: width, height, loc
    axins = inset_axes(ax, width="35%", height="35%", loc="upper right")

    axins.scatter(time_index[mask], yt[mask], s=12, alpha=0.8)
    axins.scatter(time_index[mask], yp[mask], s=12, alpha=0.8, color='orange')

    axins.set_xlim(start, end)
    # optional: make y-range tight around this segment
    y_min = min(yt[mask].min(), yp[mask].min())
    y_max = max(yt[mask].max(), yp[mask].max())
    pad = (y_max - y_min) * 0.1 if y_max > y_min else 0.01
    axins.set_ylim(y_min - pad, y_max + pad)
    axins.set_xticks([])
    axins.set_yticks([])

    # draw connectors
    mark_inset(ax, axins, loc1=2, loc2=4, fc="none", ec="0.5")

    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, "comparison_random_order.png"), dpi=150)
    plt.close(fig)

    # the other two plots can stay simple
    plt.figure(figsize=(10, 5))
    plt.scatter(time_index, yt, s=6)
    plt.xlabel("Sample Time Index")
    plt.ylabel("True sqrt(x)")
    plt.title("Ideal Output Sequence (Training, randomized)")
    plt.tight_layout()
    plt.savefig(os.path.join(out_dir, "truth_train.png"), dpi=150)
    plt.close()

    plt.figure(figsize=(10, 5))
    plt.scatter(time_index, yp, s=6, color='orange')
    plt.xlabel("Sample Time Index")
    plt.ylabel("RNN pred")
    plt.title("RNN Predicted Output Sequence (Training, randomized)")
    plt.tight_layout()
    plt.savefig(os.path.join(out_dir, "predict_train.png"), dpi=150)
    plt.close()

'''
def plot_all(y, yhat, u, mse, rmse, r2, out_dir, plot_last=0, time_index=None):
    yt = y.reshape(-1)
    yp = yhat.reshape(-1)

    if time_index is None:
        time_index = np.arange(len(yt))

    # Optionally truncate to last samples
    if plot_last and plot_last < len(yt):
        yt = yt[-plot_last:]
        yp = yp[-plot_last:]
        time_index = time_index[-plot_last:]

    n = len(yt)
    # Plot at most ~5000 points to avoid marker overflow
    if n > 5000:
        step = n // 5000
        yt = yt[::step]
        yp = yp[::step]
        time_index = time_index[::step]
        print(f"[plot_all] Downsampled to {len(yt)} points for plotting")

    # ---- main scatter plot ----
    plt.figure(figsize=(10, 5))
    plt.scatter(time_index, yt, s=8, label="True sqrt(x)", alpha=0.7)
    plt.scatter(time_index, yp, s=8, label="RNN pred", alpha=0.7, color='orange')
    txt = f"MSE={mse:.3e}\nRMSE={rmse:.3e}\nR²={r2:.6f}"
    plt.text(0.02, 0.98, txt, transform=plt.gca().transAxes,
             va="top", ha="left", bbox=dict(boxstyle="round", alpha=0.2))
    plt.xlabel("Sample Time Index")
    plt.ylabel("Value")
    plt.title("RNN Prediction vs True sqrt(x) (Randomized Order)")
    plt.legend(loc="best")
    plt.tight_layout()
    plt.savefig(os.path.join(out_dir, "comparison_random_order.png"), dpi=150)
    plt.close()

    # ---- true-only ----
    plt.figure(figsize=(10, 5))
    plt.scatter(time_index, yt, s=6)
    plt.xlabel("Sample Time Index")
    plt.ylabel("True sqrt(x)")
    plt.title("Ideal Output Sequence (Training, randomized)")
    plt.tight_layout()
    plt.savefig(os.path.join(out_dir, "truth_train.png"), dpi=150)
    plt.close()

    # ---- pred-only ----
    plt.figure(figsize=(10, 5))
    plt.scatter(time_index, yp, s=6, color='orange')
    plt.xlabel("Sample Time Index")
    plt.ylabel("RNN pred")
    plt.title("RNN Predicted Output Sequence (Training, randomized)")
    plt.tight_layout()
    plt.savefig(os.path.join(out_dir, "predict_train.png"), dpi=150)
    plt.close()


# -------------------- 绘图 --------------------
def plot_all(y, yhat, u, mse, rmse, r2, out_dir, plot_last=0, time_index=None):
    yt = y.reshape(-1)
    yp = yhat.reshape(-1)

    if time_index is None:
        time_index = np.arange(len(yt))

    # 截尾显示
    if plot_last and plot_last < len(yt):
        yt = yt[-plot_last:]
        yp = yp[-plot_last:]
        time_index = time_index[-plot_last:]

    # 主图：真实 vs 预测（预测曲线为橙色）
    plt.figure(figsize=(10, 5))
    plt.plot(time_index, yt, 'o-', label="True sqrt(x)", markersize=3)
    plt.plot(time_index, yp, 'x-', label="RNN pred", markersize=3, color='orange')
    plt.fill_between(time_index, yt - u, yt + u, alpha=0.15, label=f"±u band")
    txt = f"MSE={mse:.3e}\nRMSE={rmse:.3e}\nR²={r2:.6f}"
    plt.text(0.02, 0.98, txt, transform=plt.gca().transAxes,
             va="top", ha="left", bbox=dict(boxstyle="round", alpha=0.2))
    plt.xlabel("Sample Time Index")
    plt.ylabel("Value")
    plt.title("RNN Prediction vs True sqrt(x) (Randomized Order)")
    plt.legend(loc="best")
    plt.tight_layout()
    plt.savefig(os.path.join(out_dir, "comparison_random_order.png"), dpi=150)
    plt.close()

    # 真实值单独
    plt.figure(figsize=(10, 5))
    plt.plot(time_index, yt, linewidth=1)
    plt.xlabel("Sample Time Index")
    plt.ylabel("True sqrt(x)")
    plt.title("Ideal Output Sequence (Training, randomized)")
    plt.tight_layout()
    plt.savefig(os.path.join(out_dir, "truth_train.png"), dpi=150)
    plt.close()

    # 预测值单独（橙色）
    plt.figure(figsize=(10, 5))
    plt.plot(time_index, yp, linewidth=1, color='orange')
    plt.xlabel("Sample Time Index")
    plt.ylabel("RNN pred")
    plt.title("RNN Predicted Output Sequence (Training, randomized)")
    plt.tight_layout()
    plt.savefig(os.path.join(out_dir, "predict_train.png"), dpi=150)
    plt.close()
    '''

# -------------------- 主程序 --------------------
def main():
    args = parse_args()
    np.random.seed(args.seed)
    tf.random.set_seed(args.seed)
    os.makedirs(args.out_dir, exist_ok=True)

    # 1) 数据来源
    if args.synthetic_n > 0:
        # 合成随机顺序 sqrt 数据
        x, y, time_index = generate_sqrt_sequences(
            n_samples=args.synthetic_n,
            vmin=args.synthetic_min,
            vmax=args.synthetic_max,
            traj_len=args.traj_len
        )
    else:
        # 从文件读取
        x = load_col(args.x)
        y = load_col(args.y)
        n = min(len(x), len(y))
        x, y = x[:n], y[:n]
        time_index = np.arange(len(x))

    # 2) 构建滑窗
    X, Y = build_windows(x, y, args.seq_len)
    # 滑窗之后，序列长度变成 N - L + 1，要把时间轴也裁剪到这个长度
    time_index_win = time_index[args.seq_len - 1:]

    # build sample weights: emphasize small y
    Y_flat = Y.reshape(-1)
    sample_weight = np.ones_like(Y_flat, dtype=np.float32)
    mask_small = (Y_flat < args.low_y_thresh)
    sample_weight[mask_small] = args.low_y_weight

    # 3) 标准化
    mu_x, std_x, mu_y, std_y = standardize_fit(X, Y)
    X_n = standardize_apply_X(X, mu_x, std_x)
    Y_n = (Y - mu_y) / std_y

    # 4) RNN 模型
    model = build_model(args.seq_len)
    model.fit(
        X_n, Y_n,
        sample_weight=sample_weight,
        batch_size=args.batch,
        epochs=args.epochs,
        shuffle=True,  # 一定要打乱，防止学到时间位置
        verbose=1
    )

    # 5) 预测
    yhat_n = model.predict(X_n, verbose=0)
    yhat = inv_y(yhat_n, mu_y, std_y)

    # 6) 计算指标
    mse, rmse, r2 = metrics(Y, yhat)
    residual = (Y - yhat)
    u = mad_threshold(residual, args.thresh_k_mad)
    in_band = (np.abs(residual) <= u).mean() * 100.0

    print(f"[Train] MSE={mse:.6e}, RMSE={rmse:.6e}, R2={r2:.6f}, u={u:.6e}")
    print(f"[Train] In-band ratio (|y - yRNN| <= u): {in_band:.2f}%")

    # 7) 保存结果
    np.savetxt(os.path.join(args.out_dir, "yRNN_train.txt"),
               yhat.reshape(-1), fmt="%.10f")
    with open(os.path.join(args.out_dir, "u.txt"), "w") as f:
        f.write(f"{u:.12e}\n")

    plot_all(
        Y, yhat, u, mse, rmse, r2,
        args.out_dir,
        plot_last=args.plot_last,
        time_index=time_index_win
    )

    meta = {
        "mode": "train_only",
        "seq_len": args.seq_len,
        "epochs": args.epochs,
        "batch": args.batch,
        "seed": args.seed,
        "train_size": int(len(X)),
        "u": u,
        "in_band_percent": in_band,
        "metrics_train": {"mse": mse, "rmse": rmse, "r2": r2},
        "mu_x": mu_x.reshape(-1).tolist(),
        "std_x": std_x.reshape(-1).tolist(),
        "mu_y": float(mu_y[0]),
        "std_y": float(std_y[0]),
        "synthetic_n": args.synthetic_n
    }
    with open(os.path.join(args.out_dir, "meta.json"), "w") as f:
        json.dump(meta, f, indent=2)

    model.save(os.path.join(args.out_dir, "rnn_xy_shuffle.keras"))
    print(f"[Save] Outputs -> {args.out_dir}")


if __name__ == "__main__":
    main()
