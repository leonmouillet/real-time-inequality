# ---------------------------------------------------------------------------- #
# Import Wilshire 5000 index from Yahoo Finance
# Merge with historical FRED data
# ---------------------------------------------------------------------------- #

import sys
import yfinance as yf
import pandas as pd
from pathlib import Path
import matplotlib.pyplot as plt

def main():
    if len(sys.argv) < 4:
        print("Usage: python 01-scrape-yahoo.py <historical_dta> <output_csv> <output_graph>")
        sys.exit(1)
    
    original_dta = sys.argv[1]
    output_file = sys.argv[2]
    output_graph = sys.argv[3]
    
    Path(output_file).parent.mkdir(parents=True, exist_ok=True)
    Path(output_graph).parent.mkdir(parents=True, exist_ok=True)
    
    # Load historical FRED data and scrap Yahoo data

    print("Reading historical FRED Wilshire data...")
    fred_data = pd.read_stata(original_dta)
    fred_data = fred_data[['year', 'month', 'wilshire']].copy()
    fred_data['year'] = fred_data['year'].astype(int)
    fred_data['month'] = fred_data['month'].astype(int)
    fred_data = fred_data.dropna(subset=['wilshire'])
    fred_data.rename(columns={'wilshire': 'fred'}, inplace=True)
    print(f"FRED data: {fred_data['year'].min()}-{fred_data['year'].max()}")
    
    print("Downloading Wilshire 5000 from Yahoo Finance...")
    wilshire_raw = yf.download("^W5000", start="1970-01-01", progress=False, auto_adjust=False)
    wilshire_raw = wilshire_raw[['Close']].reset_index()
    wilshire_raw.columns = ['date', 'yahoo']
    wilshire_raw['date'] = pd.to_datetime(wilshire_raw['date'])
    wilshire_raw['year'] = wilshire_raw['date'].dt.year
    wilshire_raw['month'] = wilshire_raw['date'].dt.month
    yahoo_monthly = wilshire_raw.groupby(['year', 'month'])['yahoo'].last().reset_index()
    print(f"Yahoo data: {yahoo_monthly['year'].min()}-{yahoo_monthly['year'].max()}")
    
    # Merge FRED and Yahoo data
    combined = fred_data.merge(yahoo_monthly, on=['year', 'month'], how='outer')
    combined = combined.sort_values(['year', 'month']).reset_index(drop=True)
    
    # Calculate ratio
    combined['coef'] = combined['yahoo'] / combined['fred']
    combined['coef'] = combined['coef'].fillna(method='ffill')
    combined['coef'] = combined['coef'].fillna(method='bfill')
    
    # Create final series: use FRED where available, extrapolate with Yahoo/coef where missing
    combined['wilshire'] = combined['fred'].copy()
    mask = combined['fred'].isna()
    combined.loc[mask, 'wilshire'] = combined.loc[mask, 'yahoo'] / combined.loc[mask, 'coef']
    
    # Get overlap data for validation
    overlap = combined[combined['fred'].notna() & combined['yahoo'].notna()].copy()
    overlap['date'] = pd.to_datetime(overlap[['year', 'month']].assign(day=1))
    
    print(f"Overlap period: {overlap['year'].min()}-{overlap['year'].max()}")
    
    # Create validation graph
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))
    
    # Top panel: Level comparison
    combined['date'] = pd.to_datetime(combined[['year', 'month']].assign(day=1))
    fred_mask = combined['fred'].notna()
    extrapolated_mask = combined['fred'].isna() & combined['wilshire'].notna()
    
    ax1.plot(combined.loc[fred_mask, 'date'], combined.loc[fred_mask, 'wilshire'], 
            label='FRED (historical)', linewidth=2, color='#DC143C')
    ax1.plot(combined.loc[extrapolated_mask, 'date'], combined.loc[extrapolated_mask, 'wilshire'], 
            label='Yahoo (extrapolated)', linewidth=2, color='#4682B4', linestyle='--')
    
    last_fred_date = combined.loc[fred_mask, 'date'].max()
    ax1.axvline(last_fred_date, color='gray', linestyle=':', linewidth=1, alpha=0.5)
    ax1.text(last_fred_date, ax1.get_ylim()[1]*0.95, 'Transition', 
            rotation=90, verticalalignment='top', fontsize=9, color='gray')
    
    ax1.set_xlabel('Date', fontsize=11)
    ax1.set_ylabel('Index Level (FRED scale)', fontsize=11)
    ax1.set_title('Wilshire 5000: Historical FRED + Yahoo Extrapolation', fontsize=13)
    ax1.legend(fontsize=10)
    ax1.grid(True, alpha=0.3)
    
    # Bottom panel: Percentage changes in overlap period
    overlap['chg_fred'] = 100 * overlap['fred'].pct_change()
    overlap['yahoo_extrapolated'] = overlap['yahoo'] / overlap['coef']
    overlap['chg_yahoo'] = 100 * overlap['yahoo_extrapolated'].pct_change()
    overlap_clean = overlap.dropna(subset=['chg_fred', 'chg_yahoo'])
    
    ax2.scatter(overlap_clean['chg_fred'], overlap_clean['chg_yahoo'], 
               alpha=0.6, s=20, color='#4682B4')
    
    min_val = min(overlap_clean['chg_fred'].min(), overlap_clean['chg_yahoo'].min())
    max_val = max(overlap_clean['chg_fred'].max(), overlap_clean['chg_yahoo'].max())
    ax2.plot([min_val, max_val], [min_val, max_val], 'r-', linewidth=2, label='45° line')
    ax2.set_xlabel('FRED (% change)', fontsize=11)
    ax2.set_ylabel('Yahoo/ratio (% change)', fontsize=11)
    ax2.set_title('Validation: Monthly Changes Comparison (Overlap Period)', fontsize=13)
    ax2.grid(True, alpha=0.3)
    
    corr = overlap_clean['chg_fred'].corr(overlap_clean['chg_yahoo'])
    ax2.text(0.05, 0.95, f'Correlation: {corr:.4f}', 
            transform=ax2.transAxes, fontsize=11, verticalalignment='top',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    plt.tight_layout()
    plt.savefig(str(output_graph), dpi=300, bbox_inches='tight')
    print(f"Validation graph saved to {output_graph}")
    plt.close()
    
    # Save final data
    output_data = combined[['year', 'month', 'wilshire']].copy()
    output_data = output_data.dropna(subset=['wilshire'])
    output_data.to_csv(str(output_file), index=False)
    
    n_fred = combined['fred'].notna().sum()
    n_extrapolated = (combined['fred'].isna() & combined['wilshire'].notna()).sum()
    
    print(f"\nSuccessfully saved {len(output_data)} monthly observations to {output_file}")
    print(f"  - {n_fred} from historical FRED data ({combined[combined['fred'].notna()]['year'].min():.0f}-{combined[combined['fred'].notna()]['year'].max():.0f})")
    print(f"  - {n_extrapolated} extrapolated from Yahoo using ratio method ({combined[combined['fred'].isna() & combined['wilshire'].notna()]['year'].min():.0f}-{combined[combined['fred'].isna() & combined['wilshire'].notna()]['year'].max():.0f})")

if __name__ == "__main__":
    main()