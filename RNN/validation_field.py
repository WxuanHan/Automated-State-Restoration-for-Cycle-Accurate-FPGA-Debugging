#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Validation + segment(supervised) classification for mixed errors.
"""

import os
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import tensorflow as tf
from tensorflow.keras.models import load_model

np.random.seed(1234)
tf.random.set_seed(1234)

# ============ 配置 ============
MODEL_PATH        = "rnn_xy_shuffle.keras"
INPUT_X_PATH      = "cordic_input_real_shuffled_1e4.txt"
ERROR_Y_PATH      = "cordic_series_mixed_1e4.txt"
ERROR_MASK_PATH   = "cordic_series_mixed_1e4_mask.txt"
OWNER_PATH        = "cordic_series_mixed_owner_1e4.txt"   # mixed 才用

OUT_DIR           = "val_out"
DETAIL_CSV        = "scored.csv"
SUMMARY_JSON      = "summary.json"
SUMMARY_TXT       = "summary.txt"
PLOT_LOCAL        = "pred_vs_true_local.png"
PLOT_ROC_PR       = "roc_pr.png"

# 把注入器里的 period 固定下来
PERIOD_HINT       = 64


# ============ 基础IO ============
def load_vec(path: str) -> np.ndarray:
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    vals = []
    with open(path, "r", encoding="utf-8") as f:
        for ln in f:
            s = ln.strip()
            if s:
                vals.append(float(s))
    return np.asarray(vals, dtype=np.float64)


def load_mask(path: str) -> np.ndarray:
    arr = load_vec(path)
    return (arr != 0).astype(np.int32)


def make_model_input(x: np.ndarray, model) -> np.ndarray:
    ish = model.input_shape
    if isinstance(ish, (list, tuple)) and isinstance(ish[0], (list, tuple)):
        ish = ish[0]
    x = np.asarray(x, dtype=np.float32)

    if len(ish) == 2:
        feats = ish[1] if ish[1] is not None else 1
        X = np.zeros((x.shape[0], feats), dtype=np.float32)
        X[:, 0] = x
        return X
    elif len(ish) == 3:
        timesteps = ish[1] if ish[1] is not None else 1
        features  = ish[2] if ish[2] is not None else 1
        X = np.zeros((x.shape[0], timesteps, features), dtype=np.float32)
        X[:, :, 0] = x.reshape(-1, 1)
        return X
    else:
        raise ValueError(f"Unsupported model input shape: {ish}")


def robust_threshold_from_residual(resid: np.ndarray, k: float = 3.0) -> float:
    r = np.asarray(resid, dtype=np.float64)
    med = np.median(r)
    mad = np.median(np.abs(r - med))
    mad_eq = 1.4826 * mad
    thr = med + k * mad_eq
    return max(thr, 1e-9)


def binary_metrics(y_true_bin: np.ndarray, y_pred_bin: np.ndarray) -> dict:
    y_true_bin = y_true_bin.astype(np.int32).reshape(-1)
    y_pred_bin = y_pred_bin.astype(np.int32).reshape(-1)
    tp = int(np.sum((y_true_bin == 1) & (y_pred_bin == 1)))
    tn = int(np.sum((y_true_bin == 0) & (y_pred_bin == 0)))
    fp = int(np.sum((y_true_bin == 0) & (y_pred_bin == 1)))
    fn = int(np.sum((y_true_bin == 1) & (y_pred_bin == 0)))
    acc = (tp + tn) / max(1, (tp + tn + fp + fn))
    prec = tp / max(1, (tp + fp))
    rec = tp / max(1, (tp + fn))
    f1 = 2 * prec * rec / max(1, (prec + rec))
    return dict(tp=tp, tn=tn, fp=fp, fn=fn,
                accuracy=acc, precision=prec, recall=rec, f1=f1)


# ============ ROC / PR ============
def compute_roc_pr(scores: np.ndarray, gt_bin: np.ndarray, num_points: int = 400):
    y = gt_bin.astype(np.int32).reshape(-1)
    s = scores.reshape(-1).astype(np.float64)

    smin, smax = float(np.min(s)), float(np.max(s))
    if smax == smin:
        thresholds = np.linspace(smin - 1, smax + 1, num_points)
    else:
        thresholds = np.linspace(smax, smin, num_points)

    TPR, FPR, PREC = [], [], []
    for thr in thresholds:
        pred = (s > thr).astype(np.int32)
        tp = np.sum((y == 1) & (pred == 1))
        tn = np.sum((y == 0) & (pred == 0))
        fp = np.sum((y == 0) & (pred == 1))
        fn = np.sum((y == 1) & (pred == 0))

        tpr = tp / max(1, (tp + fn))
        fpr = fp / max(1, (fp + tn))
        prec = tp / max(1, (tp + fp))

        TPR.append(tpr)
        FPR.append(fpr)
        PREC.append(prec)

    TPR = np.asarray(TPR)
    FPR = np.asarray(FPR)
    PREC = np.asarray(PREC)

    order_roc = np.argsort(FPR)
    auc = float(np.trapezoid(TPR[order_roc], FPR[order_roc]))

    order_pr = np.argsort(TPR)
    auprc = float(np.trapezoid(PREC[order_pr], TPR[order_pr]))

    return FPR, TPR, PREC, auc, auprc


# ============ 自动放大检测密集区域 ============
def plot_local_view(base_idx,
                    y_true,
                    y_pred,
                    pred_bin,
                    gt_bin,
                    out_path: str,
                    window_size: int = 200):
    N = len(y_true)
    if N == 0:
        return

    ws = min(window_size, N)
    best_cnt, best_lo, best_hi = -1, 0, ws
    for start in range(0, N - ws + 1):
        end = start + ws
        cnt = int(np.sum(pred_bin[start:end] == 1))
        if cnt > best_cnt:
            best_cnt, best_lo, best_hi = cnt, start, end

    if best_cnt <= 0:
        best_lo, best_hi = 0, ws

    plt.figure(figsize=(7.0, 5.0))
    plt.plot(base_idx[best_lo:best_hi], y_true[best_lo:best_hi],
             label="Observed output (with injected disturbances)",
             linewidth=1.0)
    plt.plot(base_idx[best_lo:best_hi], y_pred[best_lo:best_hi],
             label="RNN-based estimation",
             linewidth=1.0)

    gt_mask = (gt_bin[best_lo:best_hi] == 1)
    if np.any(gt_mask):
        plt.scatter(base_idx[best_lo:best_hi][gt_mask],
                    y_true[best_lo:best_hi][gt_mask],
                    s=22,
                    c='orange',
                    label="Ground-truth anomaly location",
                    zorder=3)
    det_mask = (pred_bin[best_lo:best_hi] == 1)
    if np.any(det_mask):
        plt.scatter(base_idx[best_lo:best_hi][det_mask],
                    y_true[best_lo:best_hi][det_mask],
                    s=28,
                    marker='x',
                    c='blue',
                    linewidths=0.8,
                    label="RNN-indicated anomaly",
                    zorder=4)

    plt.xlabel("Sample index (dimensionless)")
    plt.ylabel("Signal magnitude")
    plt.title("Localized magnified view (region with highest detection density)")
    plt.legend(loc="best", fontsize=8)
    plt.tight_layout()
    plt.savefig(out_path, dpi=200)
    plt.close()


def plot_roc_pr(FPR, TPR, PREC, auc, auprc, out_path: str):
    plt.figure(figsize=(10, 4))

    ax1 = plt.subplot(1, 2, 1)
    ax1.plot(FPR, TPR, label=f"ROC (AUC = {auc:.4f})", linewidth=1.0)
    ax1.plot([0, 1], [0, 1], 'k--', alpha=0.4)
    ax1.set_xlabel("False Positive Rate")
    ax1.set_ylabel("True Positive Rate")
    ax1.set_title("Receiver Operating Characteristic")
    ax1.legend(loc="lower right", fontsize=8)

    ax2 = plt.subplot(1, 2, 2)
    ax2.plot(TPR, PREC, label=f"PR curve (AUPRC = {auprc:.4f})", linewidth=1.0)
    ax2.set_xlabel("Recall")
    ax2.set_ylabel("Precision")
    ax2.set_title("Precision–Recall Curve")
    ax2.legend(loc="lower left", fontsize=8)

    plt.tight_layout()
    plt.savefig(out_path, dpi=200)
    plt.close()


# ============ 构造监督分类用特征 ============
def build_segment_features(idx: np.ndarray,
                           y_err: np.ndarray,
                           y_hat: np.ndarray,
                           resid: np.ndarray,
                           owner: np.ndarray,
                           period_hint: int = 64) -> pd.DataFrame:
    N = len(idx)
    global_med = float(np.median(y_err))

    err_positions = np.where(owner != 0)[0]
    prev_err = np.full(N, -1, dtype=int)
    next_err = np.full(N, -1, dtype=int)
    for k, pos in enumerate(err_positions):
        prev_err[pos] = err_positions[k - 1] if k - 1 >= 0 else -1
        next_err[pos] = err_positions[k + 1] if k + 1 < len(err_positions) else -1

    feats = {
        "idx": [],
        "resid": [],
        "y_err": [],
        "y_hat": [],
        "abs_err_to_global_median": [],
        "local_resid_median": [],
        "local_resid_std": [],
        "interval_prev": [],
        "interval_next": [],
        "idx_mod_period": [],
        "owner": []
    }

    for i in range(N):
        if owner[i] == 0:
            continue

        lo = max(0, i - 4)
        hi = min(N, i + 5)
        local_resid = resid[lo:hi]
        feats["idx"].append(i)
        feats["resid"].append(float(resid[i]))
        feats["y_err"].append(float(y_err[i]))
        feats["y_hat"].append(float(y_hat[i]))
        feats["abs_err_to_global_median"].append(abs(y_err[i] - global_med))
        feats["local_resid_median"].append(float(np.median(local_resid)))
        feats["local_resid_std"].append(float(np.std(local_resid)))

        if prev_err[i] >= 0:
            feats["interval_prev"].append(i - prev_err[i])
        else:
            feats["interval_prev"].append(0)

        if next_err[i] >= 0:
            feats["interval_next"].append(next_err[i] - i)
        else:
            feats["interval_next"].append(0)

        feats["idx_mod_period"].append(i % period_hint)
        feats["owner"].append(int(owner[i]))

    return pd.DataFrame(feats)


# ============ 检测到的样本上做分类评估 ============
def confusion_matrix_5_detected(gt: np.ndarray,
                                pred: np.ndarray,
                                detected_mask: np.ndarray):
    cm = np.zeros((5, 5), dtype=np.int32)
    for g, p, d in zip(gt, pred, detected_mask):
        if d != 1:
            continue
        if 0 <= g < 5 and 0 <= p < 5:
            cm[g, p] += 1
    return cm


def per_class_accuracy_detected(gt: np.ndarray,
                                pred: np.ndarray,
                                detected_mask: np.ndarray):
    accs = {}
    calc_detail = {}
    for c in range(1, 5):
        mask_c = (gt == c) & (detected_mask == 1)
        total = int(np.sum(mask_c))
        if total == 0:
            accs[c] = None
            calc_detail[c] = f"class {c}: no detected samples"
        else:
            correct = int(np.sum((pred == c) & mask_c))
            accs[c] = correct / total
            calc_detail[c] = f"class {c}: {correct}/{total} = {accs[c]:.2f}"
    return accs, calc_detail


# ============ 主流程 ============
def main():
    print("[INFO] loading model ...")
    model = load_model(MODEL_PATH)

    print("[INFO] loading data ...")
    x_in   = load_vec(INPUT_X_PATH)
    y_err  = load_vec(ERROR_Y_PATH)
    m_err  = load_mask(ERROR_MASK_PATH)

    do_classify = "mixed" in os.path.basename(ERROR_Y_PATH)

    if do_classify:
        owner = load_vec(OWNER_PATH).astype(np.int32)
        N = min(len(x_in), len(y_err), len(m_err), len(owner))
        owner = owner[:N]
    else:
        owner = None
        N = min(len(x_in), len(y_err), len(m_err))

    x_in  = x_in[:N]
    y_err = y_err[:N]
    m_err = m_err[:N]
    idx   = np.arange(N, dtype=np.int32)

    print(f"[INFO] total samples: {N}")

    X_model = make_model_input(x_in, model)
    y_hat   = model.predict(X_model, verbose=0).astype(np.float64)
    if y_hat.ndim > 1:
        y_hat = y_hat.reshape(y_hat.shape[0], -1)[:, 0]

    resid = np.abs(y_err - y_hat)
    thr = robust_threshold_from_residual(resid, k=3.0)
    pred_mask = (resid > thr).astype(np.int32)

    metrics = binary_metrics(m_err, pred_mask)
    FPR, TPR, PREC, auc, auprc = compute_roc_pr(resid, m_err, num_points=500)

    # === 分类部分 ===
    if do_classify:
        df_feats = build_segment_features(idx, y_err, y_hat, resid, owner, period_hint=PERIOD_HINT)

        pred_owner = np.zeros(N, dtype=np.int32)

        if len(df_feats) > 0:
            try:
                from sklearn.ensemble import RandomForestClassifier
                clf = RandomForestClassifier(
                    n_estimators=120,
                    max_depth=6,
                    random_state=1234
                )
                X_train = df_feats.drop(columns=["owner", "idx"]).values
                y_train = df_feats["owner"].values
                clf.fit(X_train, y_train)

                detected_idx = np.where(pred_mask == 1)[0]
                for i in detected_idx:
                    lo = max(0, i - 4)
                    hi = min(N, i + 5)
                    global_med = float(np.median(y_err))

                    det_positions = detected_idx
                    pos = np.searchsorted(det_positions, i)
                    if pos - 1 >= 0:
                        interval_prev = i - det_positions[pos - 1]
                    else:
                        interval_prev = 0
                    if pos + 1 < len(det_positions):
                        interval_next = det_positions[pos + 1] - i
                    else:
                        interval_next = 0

                    local_resid = resid[lo:hi]
                    feat_vec = [
                        float(resid[i]),
                        float(y_err[i]),
                        float(y_hat[i]),
                        abs(y_err[i] - global_med),
                        float(np.median(local_resid)),
                        float(np.std(local_resid)),
                        float(interval_prev),
                        float(interval_next),
                        float(i % PERIOD_HINT),
                    ]
                    pred_cls = int(clf.predict([feat_vec])[0])
                    pred_owner[i] = pred_cls

            except ImportError:
                pred_owner = np.zeros(N, dtype=np.int32)
                data_tol = 2.0 * (np.median(np.abs(y_err - np.median(y_err))) + 1e-9)
                detected_idx = np.where(pred_mask == 1)[0]
                for i in detected_idx:
                    is_data = abs(y_err[i] - np.median(y_err)) < data_tol
                    pred_owner[i] = 3 if is_data else 1

        cm5 = confusion_matrix_5_detected(owner, pred_owner, pred_mask)
        per_class_acc, calc_detail = per_class_accuracy_detected(owner, pred_owner, pred_mask)
        overall_on_detected = (
            int(np.sum((owner == pred_owner) & (pred_mask == 1)))
            / max(1, int(np.sum(pred_mask == 1)))
        )

        classification_summary = {
            "executed": True,
            "overall_accuracy_on_detected": overall_on_detected,
            "r_accuracy": per_class_acc.get(1, None),
            "s_accuracy": per_class_acc.get(2, None),
            "da_accuracy": per_class_acc.get(3, None),
            "dp_accuracy": per_class_acc.get(4, None),
            "confusion_matrix_5x5_detected": cm5.tolist(),
            "calculation_process": {
                "r_accuracy": calc_detail.get(1, ""),
                "s_accuracy": calc_detail.get(2, ""),
                "da_accuracy": calc_detail.get(3, ""),
                "dp_accuracy": calc_detail.get(4, "")
            }
        }
    else:
        pred_owner = np.zeros_like(pred_mask)
        classification_summary = {"executed": False}

    # === 落盘 ===
    os.makedirs(OUT_DIR, exist_ok=True)
    df_out = pd.DataFrame({
        "idx": idx,
        "x_in": x_in,
        "y_err": y_err,
        "y_hat": y_hat,
        "residual_abs": resid,
        "gt_mask": m_err,
        "rnn_mask": pred_mask,
        "pred_owner": pred_owner
    })
    if do_classify:
        df_out["gt_owner"] = owner
    df_out.to_csv(os.path.join(OUT_DIR, DETAIL_CSV), index=False)

    summary = {
        "model_path": MODEL_PATH,
        "input_path": INPUT_X_PATH,
        "error_y_path": ERROR_Y_PATH,
        "error_mask_path": ERROR_MASK_PATH,
        "num_samples": int(N),
        "auto_threshold": float(thr),
        "metrics_binary": metrics,
        "roc_auc": float(auc),
        "pr_auprc": float(auprc),
        "classification": classification_summary
    }
    with open(os.path.join(OUT_DIR, SUMMARY_JSON), "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    with open(os.path.join(OUT_DIR, SUMMARY_TXT), "w", encoding="utf-8") as f:
        f.write(json.dumps(summary, indent=2, ensure_ascii=False))

    # 图
    plot_local_view(idx, y_err, y_hat, pred_mask, m_err,
                    out_path=os.path.join(OUT_DIR, PLOT_LOCAL),
                    window_size=200)
    plot_roc_pr(FPR, TPR, PREC, auc, auprc,
                out_path=os.path.join(OUT_DIR, PLOT_ROC_PR))

    print(f"[DONE] results saved to: {OUT_DIR}")


if __name__ == "__main__":
    main()
