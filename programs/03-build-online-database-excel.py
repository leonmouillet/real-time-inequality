"""
Build full online database Excel file for RTI website download.
Produces a single Excel with 3 sheets:
  - income_wealth  : percentile groups, all income concepts + wealth
  - labor          : percentile groups, labor income
  - demographics   : demographic groups (gender/race/cross), all concepts

Usage: python 03-build-online-database-excel.py <path_to_website_update_folder>
"""

import pandas as pd
import numpy as np
import sys
import os

INCOME_CONCEPTS = ['factor_income', 'pretax_income', 'disposable_income', 'posttax_income', 'wealth']
LABOR_CONCEPT   = 'labor_income'
DEMO_CONCEPTS   = ['factor_income', 'pretax_income', 'disposable_income', 'posttax_income', 'wealth', 'labor_income']

def add_quarter(df):
    df['quarter'] = ((df['month'] - 1) // 3) + 1
    return df

def deflate(df, concepts, deflator_col='deflator'):
    """Deflate nominal values to real values using the deflator column."""
    df = df.copy()

    for c in concepts:
        if c in df.columns:
            df[c] = df[c] / df[deflator_col]
    for c in [col for col in df.columns if col.startswith('threshold_')]:
        df[c] = df[c] / df[deflator_col]
    return df

# Groups for which entry thresholds are not meaningful
NO_THRESHOLD_GROUPS = {'Bottom 50%', 'First Quartile', 'Total'}

def process_threshold_cols(df):
    """Rename threshold_* → *_threshold and set NaN for groups without meaningful thresholds."""
    renames = {c: c.replace('threshold_', '') + '_threshold'
               for c in df.columns if c.startswith('threshold_')}
    df = df.rename(columns=renames)
    thresh_cols = [c for c in df.columns if c.endswith('_threshold')]
    df.loc[df['group'].isin(NO_THRESHOLD_GROUPS), thresh_cols] = np.nan
    return df, sorted(thresh_cols)

def compute_derived_cols(df, concepts, pop_col):
    """Add per_unit and share columns for each concept."""
    df = df.copy()
    for c in concepts:
        if c not in df.columns:
            continue

        df[f'total_{c}'] = df[c]
        df[f'{c}_per_unit'] = np.where(df[pop_col] > 0, df[c] / df[pop_col], np.nan)

        total_vals = (
            df[df['group'] == 'Total']
            .set_index(['year', 'month', 'unit'])[c]
            .rename(f'total_val_{c}')
        )
        df = df.join(total_vals, on=['year', 'month', 'unit'])
        df[f'{c}_share'] = np.where(df[f'total_val_{c}'] > 0,
                                     df[c] / df[f'total_val_{c}'], np.nan)
        df = df.drop(columns=[f'total_val_{c}', c])
    return df

def build_income_wealth(base_path):
    df = pd.read_csv(os.path.join(base_path, 'online-database.csv'))
    pop = pd.read_csv(os.path.join(base_path, 'online-database-popul-deflator.csv'))

    pop_cols = ['year', 'month', 'pop_adults', 'pop_working_age', 'pop_households']
    df = df.merge(pop[pop_cols], on=['year', 'month'], how='left')

    unit_to_pop = {
        'adult_equal_split':       'pop_adults',
        'working_age_equal_split': 'pop_working_age',
        'adult_households':        'pop_households',
    }
    df['population'] = df.apply(
        lambda r: r[unit_to_pop.get(r['unit'], 'pop_adults')], axis=1
    )

    df = add_quarter(df)
    df = deflate(df, INCOME_CONCEPTS)
    df = compute_derived_cols(df, INCOME_CONCEPTS, 'population')
    df, thresh_cols = process_threshold_cols(df)

    cols = ['year', 'quarter', 'month', 'group', 'unit', 'population', 'deflator']
    value_cols = []
    for c in INCOME_CONCEPTS:
        value_cols += [f'total_{c}', f'{c}_per_unit', f'{c}_share']
    return df[cols + value_cols + thresh_cols].sort_values(['unit', 'group', 'year', 'month'])

def build_labor(base_path):
    df  = pd.read_csv(os.path.join(base_path, 'online-database-labor.csv'))
    pop = pd.read_csv(os.path.join(base_path, 'online-database-popul-deflator.csv'))

    df = df.merge(pop[['year', 'month', 'pop_working_age', 'deflator']], on=['year', 'month'], how='left')
    df = df.rename(columns={'pop_working_age': 'population', 'pop': 'population_raw'})

    df = add_quarter(df)
    df = deflate(df, [LABOR_CONCEPT])
    df = compute_derived_cols(df, [LABOR_CONCEPT], 'population')
    df, thresh_cols = process_threshold_cols(df)

    cols = ['year', 'quarter', 'month', 'group', 'unit', 'population', 'deflator']
    value_cols = [f'total_{LABOR_CONCEPT}', f'{LABOR_CONCEPT}_per_unit', f'{LABOR_CONCEPT}_share']
    return df[cols + value_cols + thresh_cols].sort_values(['unit', 'group', 'year', 'month'])

def build_demographics(base_path):
    df = pd.read_csv(os.path.join(base_path, 'online-database-demographics.csv'))
    df = add_quarter(df)

    present = [c for c in DEMO_CONCEPTS if c in df.columns]

    df = deflate(df, present)

    df['_unit_demo'] = df['unit'] + '|' + df['demo_type']
    orig_unit = df['unit'].copy()
    df['unit'] = df['_unit_demo']
    df = compute_derived_cols(df, present, 'population')
    df['unit'] = orig_unit
    df = df.drop(columns=['_unit_demo'])

    cols = ['year', 'quarter', 'demo_type', 'group', 'unit', 'population', 'deflator']
    value_cols = []
    for c in present:
        value_cols += [f'total_{c}', f'{c}_per_unit', f'{c}_share']
    available = [c for c in cols + value_cols if c in df.columns]
    return df[available].sort_values(['unit', 'demo_type', 'group', 'year', 'quarter'])

def main():
    if len(sys.argv) != 2:
        print("Usage: python 03-build-online-database-excel.py <path_to_website_update_folder>")
        return 1

    base_path = sys.argv[1]
    out_path  = os.path.join(base_path, 'full-online-database.xlsx')

    print("Building income/wealth sheet...")
    df_iw   = build_income_wealth(base_path)
    print("Building labor sheet...")
    df_lab  = build_labor(base_path)
    print("Building demographics sheet...")
    df_demo = build_demographics(base_path)

    print(f"Writing to {out_path}...")
    with pd.ExcelWriter(out_path, engine='openpyxl') as writer:
        df_iw.to_excel(writer,   sheet_name='income_wealth',  index=False)
        df_lab.to_excel(writer,  sheet_name='labor',          index=False)
        df_demo.to_excel(writer, sheet_name='demographics',   index=False)

    print("Done.")
    return 0

if __name__ == "__main__":
    sys.exit(main())