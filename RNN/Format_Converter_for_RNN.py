#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Clean PuTTY dump into a single-column decimal series for RNN training.

- Extract the hex after "Value:"
- Drop 0x00000000 and 0xFFFFFFFF
- Convert to signed 32-bit decimal
- Output one value per line as 'cordic_series.txt' in the same folder
"""

import re
import os
import sys
import numpy as np

HEX_RE = re.compile(r"Value:\s*([0-9A-Fa-f]{1,8})")  # catch 1..8 hex digits

def hex_to_int32_signed(x):
    """Convert 32-bit hex (string without 0x) to signed int."""
    u = int(x, 16)
    u &= 0xFFFFFFFF
    if u & 0x80000000:
        u -= 0x100000000
    return u

def main():
    # Input file
    if len(sys.argv) >= 2:
        in_path = sys.argv[1]
    else:
        in_path = "putty.log"  # default

    if not os.path.isfile(in_path):
        print(f"[ERROR] file not found: {in_path}")
        sys.exit(1)

    # Output file in same folder
    out_path = os.path.join(os.path.dirname(os.path.abspath(in_path)), "cordic_series.txt")

    vals = []
    with open(in_path, "r", errors="ignore") as f:
        for line in f:
            m = HEX_RE.search(line)
            if not m:
                continue
            hx = m.group(1).zfill(8)  # normalize to 8 hex digits
            # Drop 0x00000000 and 0xFFFFFFFF
            if hx.upper() == "00000000" or hx.upper() == "FFFFFFFF":
                continue
            vals.append(hex_to_int32_signed(hx))

    if not vals:
        print("[WARN] No values extracted. Check your input format.")
    else:
        np.savetxt(out_path, np.array(vals, dtype=np.int32), fmt="%d")
        print(f"[OK] Saved {len(vals)} values to: {out_path}")

if __name__ == "__main__":
    main()

