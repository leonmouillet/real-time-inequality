"""
Download monthly adjusted-close prices for Forbes ticker crosswalk.
Called from Stata via:
    shell "$pythonscript" "$programs/03-build-monthly-forbes-m2-download.py" \
          "$work/03-build-monthly-forbes/public-tickers.csv" \
          "$work/03-build-monthly-forbes/tickers-monthly.csv"

Incremental logic:
  - If the output file already exists it is loaded first.
  - A ticker is skipped when its most recent row is less than 45 days old
    (i.e. already covers the current or previous calendar month).
  - For stale tickers only the tail (from one month before the last known
    observation) is re-downloaded and merged, avoiding a full re-download.
  - On failure the existing rows for that ticker are kept untouched, so a
    delisted or temporarily unavailable ticker never wipes prior data.
"""

import sys
import os
import pandas as pd
import yfinance as yf
from datetime import datetime, timedelta

# ---- Paths from command-line arguments ----
if len(sys.argv) < 3:
    print("Usage: script.py <tickers_csv> <output_csv>")
    sys.exit(1)

tickers_path = sys.argv[1]
output_path  = sys.argv[2]

os.makedirs(os.path.dirname(output_path), exist_ok=True)

# ---- Load ticker list ----
tickers = pd.read_csv(tickers_path)["ticker"].unique().tolist()
print(f"Total tickers in crosswalk: {len(tickers)}")

# ---- Load existing output (if any) ----
if os.path.exists(output_path):
    existing = pd.read_csv(output_path, dtype={"ticker": str})
    existing["year"]  = pd.to_numeric(existing["year"],  errors="coerce").astype("Int64")
    existing["month"] = pd.to_numeric(existing["month"], errors="coerce").astype("Int64")
    existing["price"] = pd.to_numeric(existing["price"], errors="coerce")
    existing = existing.dropna(subset=["ticker", "year", "month"])
    print(f"Loaded {len(existing)} existing rows from {output_path}")
else:
    existing = pd.DataFrame(columns=["ticker", "year", "month", "price"])
    print("No existing output file — full download.")

# ---- Decide what to download for each ticker ----
# A ticker is considered up-to-date when its latest observation is within the
# last 45 days (covers the case where the current month is not yet complete).
today  = datetime.today()
cutoff = today - timedelta(days=45)

TIMEOUT_SECONDS = 20

def get_start_date(ticker):
    """
    Return (needs_download, start_date_str).
    start_date is one month before the last known observation so the merge
    overlap ensures no gap is introduced.
    """
    sub = existing[existing["ticker"] == ticker]
    if sub.empty:
        return True, "1970-01-01"
    # Find most recent (year, month) for this ticker
    latest = sub.sort_values(["year", "month"]).iloc[-1]
    ly, lm = int(latest["year"]), int(latest["month"])
    latest_dt = datetime(ly, lm, 1)
    if latest_dt >= cutoff.replace(day=1):
        return False, None                          # already fresh
    # Stale: re-download from one month before the last known point
    from_dt = (latest_dt - timedelta(days=31)).replace(day=1)
    return True, from_dt.strftime("%Y-%m-%d")

# ---- Download ----
new_frames  = []
n_skipped   = 0
n_ok        = 0
n_failed    = 0

for ticker in tickers:
    needed, start_date = get_start_date(ticker)
    if not needed:
        n_skipped += 1
        continue

    label = "new" if start_date == "1970-01-01" else f"from {start_date}"
    print(f"  {ticker} ({label}) ...", flush=True)
    try:
        raw = yf.Ticker(ticker).history(
            start=start_date, auto_adjust=True, timeout=TIMEOUT_SECONDS
        )
        if raw.empty:
            print(f"    -> no data (keeping existing if any)")
            n_failed += 1
            continue

        try:
            monthly = raw[["Close"]].resample("ME").last()
        except Exception:
            monthly = raw[["Close"]].resample("M").last()

        monthly            = monthly.reset_index()
        monthly.columns    = ["Date", "price"]
        monthly["ticker"]  = ticker
        monthly["year"]    = monthly["Date"].dt.year
        monthly["month"]   = monthly["Date"].dt.month
        new_frames.append(monthly[["ticker", "year", "month", "price"]])
        print(f"    -> {len(monthly)} monthly observations")
        n_ok += 1

    except Exception as e:
        print(f"    -> ERROR: {e}  (keeping existing if any)")
        n_failed += 1

print(f"\nResults: {n_ok} downloaded, {n_skipped} up-to-date (skipped), "
      f"{n_failed} failed (existing data preserved).")

# ---- Merge new data with existing ----
if new_frames:
    new_data = pd.concat(new_frames, ignore_index=True)
    # Concatenate; for duplicate (ticker, year, month) keep the new row
    combined = (
        pd.concat([existing, new_data], ignore_index=True)
          .drop_duplicates(subset=["ticker", "year", "month"], keep="last")
          .sort_values(["ticker", "year", "month"])
          .reset_index(drop=True)
    )
else:
    combined = existing
    if n_skipped == len(tickers):
        print("All tickers up-to-date — output file unchanged.")
    else:
        print("No new data downloaded — output file unchanged.")

# ---- Save ----
if len(combined) > 0:
    combined.to_csv(output_path, index=False)
    print(f"Saved {len(combined)} rows to {output_path}")
else:
    print("WARNING: no data at all — output file not created")
    sys.exit(1)
