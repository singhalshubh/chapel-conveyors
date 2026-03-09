#!/usr/bin/env python3
import sys
import pandas as pd

def load_csv(path: str) -> pd.DataFrame:
    # low_memory=False avoids mixed-type chunk inference surprises
    return pd.read_csv(path, low_memory=False)

def numeric_frame(df: pd.DataFrame, regex: str) -> pd.DataFrame:
    """
    Select columns by regex and convert to numeric robustly:
      - strip whitespace
      - remove commas
      - pd.to_numeric(errors="coerce")
    """
    cols = df.filter(regex=regex)
    if cols.shape[1] == 0:
        return cols  # empty
    clean = cols.astype(str).apply(lambda s: s.str.strip().str.replace(",", "", regex=False))
    return clean.apply(pd.to_numeric, errors="coerce")

def per_column_delta(nums: pd.DataFrame) -> tuple[pd.Series, float]:
    """
    For each column: (last_valid - first_valid).
    Returns:
      - Series of per-column deltas (NaN if no numeric data)
      - total delta across columns (skipping NaNs)
    """
    deltas = {}
    total = 0.0
    for name in nums.columns:
        s = nums[name].dropna()
        if s.empty:
            deltas[name] = float("nan")
            continue
        d = float(s.iloc[-1] - s.iloc[0])
        deltas[name] = d
        total += d
    return pd.Series(deltas), total

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 network-extract.py <input.csv> <nodes>")
        sys.exit(1)

    csv_file = sys.argv[1]
    nodes = float(sys.argv[2])
    df = load_csv(csv_file)

    # ---- 1) Bandwidth stats ----
    bw_field = "omnistat_network_cxi_bidirectional_bandwidth_bytes_per_second"
    bw = numeric_frame(df, rf"^{bw_field}")

    if bw.shape[1] == 0:
        print(f"[BW] No columns found matching: ^{bw_field}")
        bw_vals = pd.Series(dtype="float64")
        bw_avg = float("nan")
        bw_max = float("nan")
    else:
        bw_vals = bw.stack(dropna=True)
        bw_avg = float(bw_vals.mean()) if len(bw_vals) else float("nan")
        bw_max = float(bw_vals.max()) if len(bw_vals) else float("nan")

    # ---- 2) RX/TX octet deltas ----
    rx_field = "omnistat_network_cxi_rx_ok_octets"
    tx_field = "omnistat_network_cxi_tx_ok_octets"

    rx_nums = numeric_frame(df, rf"^{rx_field}")
    tx_nums = numeric_frame(df, rf"^{tx_field}")

    if rx_nums.shape[1] == 0:
        print(f"[RX] No columns found matching: ^{rx_field}")
        rx_diff = pd.Series(dtype="float64")
        total_rx = 0.0
    else:
        rx_diff, total_rx = per_column_delta(rx_nums)

    if tx_nums.shape[1] == 0:
        print(f"[TX] No columns found matching: ^{tx_field}")
        tx_diff = pd.Series(dtype="float64")
        total_tx = 0.0
    else:
        tx_diff, total_tx = per_column_delta(tx_nums)

    total_bytes = total_rx + total_tx

    # ---- 3) Your derived metric ----
    # (total_rx + total_tx) / (max_bandwidth * 2)
    if pd.isna(bw_max) or bw_max == 0.0:
        ratio = float("nan")
    else:
        ratio = total_bytes / (bw_max * 2.0)

    ##---- Print report ----
    print("\n=== CXI Bandwidth Stats ===")
    print("Field:", bw_field)
    print("Columns detected:", bw.shape[1])
    print("Total numeric samples:", len(bw_vals) if "bw_vals" in locals() else 0)
    print("Average bandwidth (bytes/sec):", bw_avg)
    print("Maximum bandwidth (bytes/sec):", bw_max)

    print("\n=== RX OK Octets: per-column (last_valid - first_valid) ===")
    if len(rx_diff):
        for k, v in rx_diff.items():
            print(f"{k:45s} {v}")
    print("TOTAL RX bytes:", total_rx)

    print("\n=== TX OK Octets: per-column (last_valid - first_valid) ===")
    if len(tx_diff):
        for k, v in tx_diff.items():
            print(f"{k:45s} {v}")
    print("TOTAL TX bytes:", total_tx)

    print("\n=== Totals ===")
    print("TOTAL (RX+TX) bytes:", total_bytes)

    print("\n=== Derived Metric ===")
    print("Energy(J) =", nodes*60.0*ratio)

if __name__ == "__main__":
    main()