#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Error Injector (float-friendly) + plotting + export v

Generates 5 error-injected series (float, one value per line):
  1) cordic_series_random.txt
  2) cordic_series_structural.txt
  3) cordic_series_databased_aperiodic.txt
  4) cordic_series_databased_periodic.txt
  5) cordic_series_mixed.txt (+ cordic_series_mixed_owner.txt)

Also saves masks ( *_mask.txt, 1=error ) and 5 plots:
  random.png / structural.png / databased_aperiodic.png / databased_periodic.png / mixed.png

'v' (validation band) is exported to v.txt:
  - --v takes precedence;
  - else if --meta present: v = meta['u'] * --v_scale
  - else default v = 0.01

Note: For visualization we use y_ideal ± v band (y_ideal from --input).
In actual validation, use yRNN ± v (see validate_only.py).
"""

import argparse
import numpy as np
import os
import warnings
import json
import math
import matplotlib.pyplot as plt


# ---------------- utilities ----------------
def save_series(path, y, mask):
    np.savetxt(path, y.astype(np.float64), fmt="%.10f")
    np.savetxt(path.replace(".txt", "_mask.txt"), mask.astype(np.int8), fmt="%d")
    print(f"[OK] {path} | errors: {int(mask.sum())}/{len(mask)} ({mask.mean()*100:.2f}%)")


def clamp_to_range(vals, vmin, vmax):
    return np.clip(vals, vmin, vmax)


def plot_pair(y_ideal, y_faulty, v, out_png, plot_last=0, title=""):
    """Plot ideal vs faulty with shaded ±v around ideal."""
    yi = y_ideal.reshape(-1)
    yf = y_faulty.reshape(-1)
    n = min(len(yi), len(yf))
    yi, yf = yi[:n], yf[:n]
    if plot_last and plot_last < n:
        yi = yi[-plot_last:]
        yf = yf[-plot_last:]
        n = len(yi)
    x = np.arange(n)

    plt.figure(figsize=(10, 5))
    plt.plot(x, yi, label="ideal (proxy of yRNN)", linewidth=1)
    plt.plot(x, yf, label="faulty (sim UUT)", linewidth=1)
    plt.fill_between(x, yi - v, yi + v, alpha=0.15, label=f"±v (v={v:.3e})")
    plt.xlabel("Samples")
    plt.ylabel("Value")
    plt.title(title if title else "Ideal vs Faulty (with ±v)")
    plt.legend(loc="best")
    plt.tight_layout()
    plt.savefig(out_png, dpi=150)
    plt.close()
    print(f"[Plot] {out_png}")


# ---------------- random injection ----------------
def inject_random(x, p, rng, mode="replace", sigma_ratio=0.1, allow_bitflip=False):
    """
    Aperiodic, Data-Independent.
    mode:
      - replace: replace with U[min,max]
      - gauss  : add N(0, sigma_ratio*span)
      - bitflip: ONLY if input is integer and allow_bitflip=True
    """
    n = len(x)
    k = max(1, int(np.floor(p * n)))
    idx = rng.choice(n, k, replace=False)
    y = x.copy().astype(np.float64)
    mask = np.zeros(n, dtype=np.int8)
    mask[idx] = 1
    xmin, xmax = float(x.min()), float(x.max())
    span = max(1e-12, xmax - xmin)

    if mode == "replace":
        y[idx] = rng.uniform(low=xmin, high=xmax, size=k)
    elif mode == "gauss":
        sigma = sigma_ratio * span
        noise = rng.normal(loc=0.0, scale=sigma, size=k)
        y[idx] = clamp_to_range(y[idx] + noise, xmin, xmax)
    elif mode == "bitflip":
        if (np.issubdtype(x.dtype, np.integer) or allow_bitflip):
            y_int = x.astype(np.int64)
            bits = rng.integers(0, 32, size=k)
            flips = (1 << bits).astype(np.int64)
            y_int[idx] = (y_int[idx] ^ flips)
            y = y_int.astype(np.float64)
        else:
            warnings.warn("bitflip ignored for float input; use replace/gauss instead.")
    else:
        raise ValueError("Unknown random mode")
    return y, mask


# ---------------- structural periodic (data-independent) ----------------
def inject_structural_periodic_DI(
    x,
    p,
    period,
    phi,
    rng,
    bias=None,
    rel=0.0,          # 保留签名，不用
    min_gap=20,       # 保留签名，不用
    burst_len=1,
    bias_scale=0.50,
    clamp=False,
):
    """
    Structural (Strict Periodic, Data-Independent drift):
    - 严格按 period 和 phi 取点：idx = (phi + k*period) % n
    - 支持 burst_len > 1：在这个周期点后面再跟几条
    - 不再做 min_gap、不再重新算 step、不再管能不能放下
    - 对这一段加/减同一个 bias（来自原版：span * bias_scale 或者用户给的 bias）
    - mask 对应这些被漂移的点
    """
    n = len(x)
    y = x.copy().astype(np.float64)
    mask = np.zeros(n, dtype=np.int8)

    # 要注入的点数 = p * n
    k_target = max(1, int(np.floor(p * n)))

    xmin, xmax = float(x.min()), float(x.max())
    span = max(1e-12, xmax - xmin)

    # 漂移幅度：沿用你原代码的策略
    base_bias = float(bias) if (bias is not None) else float(bias_scale * span)

    if period <= 0:
        raise ValueError("period must be > 0 for structural periodic DI")

    indices = []
    pos = int(phi)
    # 跟 dp 一样：绕数组一圈一圈取，直到取够 k_target
    while len(indices) < k_target:
        idx = pos % n
        # 一个周期位置可以是一个小 burst
        # 和你原来代码保持一致：同一个 burst 用同一个 sign
        sign = rng.choice([-1.0, 1.0])
        for b in range(burst_len):
            real_idx = (idx + b) % n
            if len(indices) >= k_target:
                break
            # 先记录下来，后面统一加偏移
            indices.append((real_idx, sign))
        pos += period

    # 真正做漂移
    for real_idx, sign in indices:
        y[real_idx] = y[real_idx] + sign * base_bias
        mask[real_idx] = 1

    if clamp:
        y = np.clip(y, xmin, xmax)

    return y, mask


# ---------------- data-based aperiodic ----------------
def inject_databased_aperiodic_DD(
    x,
    p_target,
    rng,
    dd_action="replace_median",   # 这个参数保留是为了兼容原来的函数签名，但下面会直接无视
    bias_scale=0.15,
    quant_step_ratio=0.10,
    wrap_span_ratio=0.50,
    burst_len=1,
    min_gap=20,
    jitter_frac=0.4,
    clamp=False
):
    """
    Data-based Aperiodic (强制非周期 & 强制中位数替换):
    - 不再按等间距 + 抖动的方式放点，直接随机挑位置；
    - 不再根据 dd_action 做多种变换，统一替换成全局中位数；
    - 保留原来的参数只是为了让外面的调用不报错。
    """
    n = len(x)
    y = x.copy().astype(np.float64)
    mask = np.zeros(n, dtype=np.int8)

    # 要注入的点数
    k_target = max(1, int(np.floor(p_target * n)))

    # 随机选 k 个不同的位置，严格无周期
    if k_target >= n:
        idx = np.arange(n, dtype=int)
    else:
        idx = rng.choice(n, size=k_target, replace=False)

    # 强制中位数替换
    med = float(np.median(x))
    y[idx] = med

    mask[idx] = 1
    return y, mask

# ---------------- data-based periodic ----------------
def inject_databased_periodic_DD(
    x,
    p_target,
    period,
    phi,
    rng,
    dd_action="replace_median",   # 保留签名但不使用
    bias_scale=0.15,
    quant_step_ratio=0.10,
    wrap_span_ratio=0.50,
    burst_len=1,
    min_gap=20,
    clamp=False
):
    """
    严格周期版 + 强制中位数替换
    - 完全不再考虑能不能放得下、min_gap、尾部溢出这些因素
    - 就按 idx = (phi + i*period) % n 来取
    - 取够 p_target*n 个位置为止
    - 每个选中的点直接替换成全局中位数
    """
    n = len(x)
    y = x.copy().astype(np.float64)
    mask = np.zeros(n, dtype=np.int8)

    if period <= 0:
        raise ValueError("period must be > 0")

    # 要注入的点数，5% 就是 0.05 * n
    k_target = max(1, int(np.floor(p_target * n)))

    # 先算全局中位数
    med = float(np.median(x))

    indices = []
    pos = int(phi)  # 起始偏移
    for _ in range(k_target):
        idx = pos % n
        # 支持 burst_len > 1，就从这个周期点往后顺带几个
        for b in range(burst_len):
            real_idx = (idx + b) % n
            indices.append(real_idx)
        pos += period

    # 截到正好 k_target（如果有 burst_len > 1 会多一点，这里收一下）
    indices = np.array(indices[:k_target], dtype=int)

    y[indices] = med
    mask[indices] = 1
    return y, mask


# ---------------- mixed (no-overlap + ensure each present) ----------------
def inject_mixed_errors(
    x,
    rng,
    p_rand,
    p_struct,
    p_dd_ap,
    p_dd_p,
    random_mode="replace",
    struct_period=64,
    struct_phi=0,
    struct_bias=None,
    struct_bias_scale=0.15,
    struct_burst_len=1,
    struct_min_gap=20,
    dd_ap_action="replace_median",
    dd_ap_bias_scale=0.15,
    dd_ap_quant_step_ratio=0.10,
    dd_ap_wrap_span_ratio=0.50,
    dd_ap_burst_len=1,
    dd_ap_min_gap=20,
    dd_ap_jitter_frac=0.4,
    dd_p_action="replace_median",
    dd_p_bias_scale=0.15,
    dd_p_quant_step_ratio=0.10,
    dd_p_wrap_span_ratio=0.50,
    dd_p_period=64,
    dd_p_phi=0,
    dd_p_burst_len=1,
    dd_p_min_gap=19,
    clamp_all=False,
    ensure_each_min=1,
):
    n = len(x)
    xmin, xmax = float(x.min()), float(x.max())

    y_r, m_r = inject_random(x, p=p_rand, rng=rng, mode=random_mode)
    y_da, m_da = inject_databased_aperiodic_DD(
        x,
        p_target=p_dd_ap,
        rng=rng,
        dd_action=dd_ap_action,
        bias_scale=dd_ap_bias_scale,
        quant_step_ratio=dd_ap_quant_step_ratio,
        wrap_span_ratio=dd_ap_wrap_span_ratio,
        burst_len=dd_ap_burst_len,
        min_gap=dd_ap_min_gap,
        jitter_frac=dd_ap_jitter_frac,
        clamp=False,
    )
    y_dp, m_dp = inject_databased_periodic_DD(
        x,
        p_target=p_dd_p,
        period=dd_p_period,
        phi=dd_p_phi,
        rng=rng,
        dd_action=dd_p_action,
        bias_scale=dd_p_bias_scale,
        quant_step_ratio=dd_p_quant_step_ratio,
        wrap_span_ratio=dd_p_wrap_span_ratio,
        burst_len=dd_p_burst_len,
        min_gap=dd_p_min_gap,
        clamp=False,
    )
    y_s, m_s = inject_structural_periodic_DI(
        x,
        p=p_struct,
        period=struct_period,
        phi=struct_phi,
        rng=rng,
        bias=struct_bias,
        rel=0.0,
        min_gap=struct_min_gap,
        burst_len=struct_burst_len,
        bias_scale=struct_bias_scale,
        clamp=False,
    )

    k_r = max(0, int(np.floor(p_rand * n)))
    k_da = max(0, int(np.floor(p_dd_ap * n)))
    k_dp = max(0, int(np.floor(p_dd_p * n)))
    k_s = max(0, int(np.floor(p_struct * n)))

    y_mix = x.copy().astype(np.float64)
    owner = np.zeros(n, dtype=np.int8)
    mask = np.zeros(n, dtype=np.int8)

    def take_from_mask(m_src, want, code, y_src):
        nonlocal y_mix, owner, mask
        cand = np.where(m_src != 0)[0]
        cand = cand[owner[cand] == 0]
        if cand.size == 0 or want <= 0:
            return 0
        if cand.size > want:
            cand = rng.choice(cand, size=want, replace=False)
        y_mix[cand] = y_src[cand]
        owner[cand] = code
        mask[cand] = 1
        return cand.size

    got_r = take_from_mask(m_r, k_r, 1, y_r)
    got_da = take_from_mask(m_da, k_da, 3, y_da)
    got_dp = take_from_mask(m_dp, k_dp, 4, y_dp)
    got_s = take_from_mask(m_s, k_s, 2, y_s)

    def fill_short(code, need, y_src):
        nonlocal y_mix, owner, mask
        if need <= 0:
            return 0
        free = np.where(owner == 0)[0]
        if free.size == 0:
            return 0
        if free.size > need:
            free = rng.choice(free, size=need, replace=False)
        y_mix[free] = y_src[free]
        owner[free] = code
        mask[free] = 1
        return free.size

    got_da += fill_short(3, max(0, k_da - got_da), y_da)
    got_dp += fill_short(4, max(0, k_dp - got_dp), y_dp)
    got_s += fill_short(2, max(0, k_s - got_s), y_s)

    def ensure_at_least(code, min_each, y_src):
        cur = int((owner == code).sum())
        need = max(0, min_each - cur)
        if need > 0:
            fill_short(code, need, y_src)

    ensure_at_least(1, ensure_each_min, y_r)
    ensure_at_least(3, ensure_each_min, y_da)
    ensure_at_least(4, ensure_each_min, y_dp)
    ensure_at_least(2, ensure_each_min, y_s)

    if clamp_all:
        y_mix = np.clip(y_mix, xmin, xmax)

    return y_mix, mask, owner


# ---------------- main ----------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", type=str, default="cordic_output_real_shuffled_1e4.txt")
    ap.add_argument("--seed", type=int, default=1234)
    ap.add_argument("--p_min", type=float, default=0.05)
    ap.add_argument("--p_max", type=float, default=0.15)
    # New: fixed ratio for each category (default 5%)
    ap.add_argument(
        "--p_fixed",
        type=float,
        default=0.0125,
        help="fixed error ratio for each category (overrides --p_min/--p_max), e.g., 0.05 for 5%",
    )
    ap.add_argument("--period", type=int, default=64)
    ap.add_argument("--phi", type=int, default=0)
    ap.add_argument(
        "--random_mode",
        type=str,
        default="replace",
        choices=["replace", "gauss", "bitflip"],
    )

    ap.add_argument("--v", type=float, default=None, help="absolute band v")
    ap.add_argument(
        "--meta",
        type=str,
        default=None,
        help="path to training meta.json (contains 'u')",
    )
    ap.add_argument(
        "--v_scale",
        type=float,
        default=1.0,
        help="v = u * v_scale when --v not set",
    )
    ap.add_argument(
        "--plot_last",
        type=int,
        default=0,
        help="if >0, only plot last N samples for clarity",
    )

    args = ap.parse_args()

    if not os.path.isfile(args.input):
        raise FileNotFoundError(args.input)
    x = np.loadtxt(args.input, dtype=np.float64).reshape(-1)
    n = len(x)
    print(
        f"[INFO] Loaded {args.input}, n={n}, min={x.min():.6g}, max={x.max():.6g}"
    )

    # band v
    if args.v is not None:
        v = float(args.v)
    elif args.meta and os.path.isfile(args.meta):
        with open(args.meta, "r") as f:
            meta = json.load(f)
        u = float(meta.get("u", 0.0))
        v = u * float(args.v_scale)
        print(
            f"[INFO] from meta: u={u:.6e}, v_scale={args.v_scale:.3g} -> v={v:.6e}"
        )
    else:
        v = 0.01
        print(f"[WARN] no --v or --meta provided; default v={v:.3g}")
    with open("v.txt", "w") as f:
        f.write(f"{v:.12e}\n")
    print("[OK] v saved to v.txt")

    rng = np.random.default_rng(args.seed)

    # --- Fixed 5% (or user-specified via --p_fixed) for all categories ---
    p_fixed = float(args.p_fixed)
    if not (0.0 < p_fixed <= 1.0):
        raise ValueError("--p_fixed must be in (0,1], e.g., 0.05 for 5%")
    p_rand = p_struct = p_dd_ap = p_dd_p = p_fixed
    print(
        f"[INFO] using fixed p={p_fixed:.2%} for all categories (overrides --p_min/--p_max)"
    )

    # 1) Random
    y_rand, m_rand = inject_random(x, p=p_rand, rng=rng, mode=args.random_mode)
    save_series("cordic_series_random.txt", y_rand, m_rand)
    plot_pair(
        x,
        y_rand,
        v,
        "random.png",
        plot_last=args.plot_last,
        title="Random Error",
    )

    # 2) Structural (Periodic, independent of data)
    y_str, m_str = inject_structural_periodic_DI(
        x,
        p=p_struct,
        period=args.period,
        phi=args.phi,
        rng=rng,
        bias=None,
        rel=0.0,
        min_gap=20,
        burst_len=1,
        bias_scale=0.50,
        clamp=False,
    )
    save_series("cordic_series_structural.txt", y_str, m_str)
    plot_pair(
        x,
        y_str,
        v,
        "structural.png",
        plot_last=args.plot_last,
        title="Structural Error (Periodic, DI)",
    )

    # 3) Data-based Aperiodic
    y_dd_ap, m_dd_ap = inject_databased_aperiodic_DD(
        x,
        p_target=p_dd_ap,
        rng=rng,
        dd_action="replace_median",
        bias_scale=0.15,
        quant_step_ratio=0.10,
        wrap_span_ratio=0.50,
        burst_len=1,
        min_gap=20,
        jitter_frac=0.4,
        clamp=False,
    )
    save_series("cordic_series_databased_aperiodic.txt", y_dd_ap, m_dd_ap)
    plot_pair(
        x,
        y_dd_ap,
        v,
        "databased_aperiodic.png",
        plot_last=args.plot_last,
        title="Data-based Aperiodic Error",
    )

    # 4) Data-based Periodic
    y_dd_p, m_dd_p = inject_databased_periodic_DD(
        x,
        p_target=p_dd_p,
        period=args.period,
        phi=args.phi,
        rng=rng,
        dd_action="replace_median",
        bias_scale=0.15,
        quant_step_ratio=0.10,
        wrap_span_ratio=0.50,
        burst_len=1,
        min_gap=20,
        clamp=False,
    )
    save_series("cordic_series_databased_periodic.txt", y_dd_p, m_dd_p)
    plot_pair(
        x,
        y_dd_p,
        v,
        "databased_periodic.png",
        plot_last=args.plot_last,
        title="Data-based Periodic Error",
    )

    # 5) Mixed (No overlap + At least occurrence per category)
    y_mix, m_mix, owner_mix = inject_mixed_errors(
        x,
        rng,
        p_rand=p_rand,
        p_struct=p_struct,
        p_dd_ap=p_dd_ap,
        p_dd_p=p_dd_p,
        random_mode=args.random_mode,
        struct_period=args.period,
        struct_phi=args.phi,
        struct_bias=None,
        struct_bias_scale=0.15,
        struct_burst_len=1,
        struct_min_gap=20,
        dd_ap_action="replace_median",
        dd_ap_bias_scale=0.15,
        dd_ap_quant_step_ratio=0.10,
        dd_ap_wrap_span_ratio=0.50,
        dd_ap_burst_len=1,
        dd_ap_min_gap=20,
        dd_ap_jitter_frac=0.4,
        dd_p_action="replace_median",
        dd_p_bias_scale=0.15,
        dd_p_quant_step_ratio=0.10,
        dd_p_wrap_span_ratio=0.50,
        dd_p_period=args.period,
        dd_p_phi=args.phi,
        dd_p_burst_len=1,
        dd_p_min_gap=19,
        clamp_all=False,
        ensure_each_min=1,
    )
    save_series("cordic_series_mixed_1e4.txt", y_mix, m_mix)
    np.savetxt("cordic_series_mixed_owner_1e4.txt", owner_mix.astype(np.int8), fmt="%d")
    print(
        "[OK] cordic_series_mixed_owner_1e4.txt | counts:",
        {int(v): int((owner_mix == v).sum()) for v in np.unique(owner_mix)},
    )
    plot_pair(
        x,
        y_mix,
        v,
        "mixed.png",
        plot_last=args.plot_last,
        title="Mixed Error",
    )

    print("[DONE] All series, masks, v.txt, and plots generated.")


if __name__ == "__main__":
    main()



