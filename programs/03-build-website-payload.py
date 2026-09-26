"""
Build the website payload for Real-Time Inequality.

Reads the intermediate CSVs produced by 03-build-online-database.do,
03-build-online-database-labor.do and 03-build-online-database-demographics.do
(all under work-data/) and writes, into the update folder, exactly the set of
files the website expects under public/temp_data/ — nothing more, nothing less:

    online-database.json
    online-database-labor.json
    online-database-demographics.json
    online-database-popul-deflator.json
    full-online-database.xlsx        3 sheets: income_wealth, labor, demographics
    wealth-extrapolation-data.csv    base-period wealth composition by bracket
    metadata.json                    data_reference_date, generated_at, update_id

Transferring an update to the website repository is therefore a plain copy of
this folder's contents into public/temp_data/.

Usage:
    python 03-build-website-payload.py <work_dir> <out_dir> <update_id> <date_end>

<date_end> is the Stata monthly date ($date_end), i.e. months elapsed since
January 1960; it is converted here into the YYYY-MM-01 reference date.
"""

import datetime
import json
import os
import shutil
import sys

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Inputs: which work-data folder each intermediate CSV comes from
# ---------------------------------------------------------------------------

CSV_SOURCES = {
    'online-database.csv':                 '03-build-online-database',
    'online-database-popul-deflator.csv':  '03-build-online-database',
    'wealth-extrapolation-data.csv':       '03-build-online-database',
    'online-database-labor.csv':           '03-build-online-database-labor',
    'online-database-demographics.csv':    '03-build-online-database-demographics',
}

# CSVs served to the website as JSON
TO_JSON = [
    'online-database.csv',
    'online-database-labor.csv',
    'online-database-popul-deflator.csv',
    'online-database-demographics.csv',
]

# CSVs copied verbatim
TO_COPY = ['wealth-extrapolation-data.csv']

INCOME_CONCEPTS = ['factor_income', 'pretax_income', 'disposable_income', 'posttax_income', 'wealth']
LABOR_CONCEPT   = 'labor_income'
DEMO_CONCEPTS   = ['factor_income', 'pretax_income', 'disposable_income', 'posttax_income', 'wealth', 'labor_income']

# Groups for which entry thresholds are not meaningful
NO_THRESHOLD_GROUPS = {'Bottom 50%', 'First Quartile', 'Total'}


def csv_path(work_dir, filename):
    return os.path.join(work_dir, CSV_SOURCES[filename], filename)


def read_csv(work_dir, filename):
    return pd.read_csv(csv_path(work_dir, filename))


# ---------------------------------------------------------------------------
# Reference date
# ---------------------------------------------------------------------------

def stata_month_to_date(date_end):
    """Convert a Stata monthly date (months since January 1960) to YYYY-MM-01."""
    date_end = int(date_end)
    year = 1960 + date_end // 12
    month = date_end % 12 + 1
    return f'{year:04d}-{month:02d}-01', year, month


def check_reference_date(work_dir, year, month):
    """The reference period must be the last period present in the database.

    The website uses this date as the base period for its Zillow/VTI/CPI
    projections, so a stale value silently shifts every projection.
    """
    df = read_csv(work_dir, 'online-database.csv')
    ym = df['year'] * 12 + df['month']
    last = df.loc[ym.idxmax()]
    last_y, last_m = int(last['year']), int(last['month'])
    if (last_y, last_m) != (year, month):
        raise SystemExit(
            f'ERROR: reference date {year:04d}-{month:02d} does not match the last '
            f'period in online-database.csv ({last_y:04d}-{last_m:02d}).\n'
            f'       $date_end and the database are out of sync — rebuild the '
            f'database, or correct $date_end in 00-setup.do.'
        )


# ---------------------------------------------------------------------------
# JSON conversion
# ---------------------------------------------------------------------------

def write_json(df, out_path):
    records = json.loads(df.to_json(orient='records'))
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump({'data': records}, f, separators=(',', ':'))


# ---------------------------------------------------------------------------
# Excel workbook
# ---------------------------------------------------------------------------

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


def process_threshold_cols(df):
    """Rename threshold_* → *_threshold and blank the groups without thresholds."""
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


def build_income_wealth(work_dir):
    df = read_csv(work_dir, 'online-database.csv')
    pop = read_csv(work_dir, 'online-database-popul-deflator.csv')

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


def build_labor(work_dir):
    df  = read_csv(work_dir, 'online-database-labor.csv')
    pop = read_csv(work_dir, 'online-database-popul-deflator.csv')

    df = df.merge(pop[['year', 'month', 'pop_working_age', 'deflator']],
                  on=['year', 'month'], how='left')
    df = df.rename(columns={'pop_working_age': 'population', 'pop': 'population_raw'})

    df = add_quarter(df)
    df = deflate(df, [LABOR_CONCEPT])
    df = compute_derived_cols(df, [LABOR_CONCEPT], 'population')
    df, thresh_cols = process_threshold_cols(df)

    cols = ['year', 'quarter', 'month', 'group', 'unit', 'population', 'deflator']
    value_cols = [f'total_{LABOR_CONCEPT}', f'{LABOR_CONCEPT}_per_unit', f'{LABOR_CONCEPT}_share']
    return df[cols + value_cols + thresh_cols].sort_values(['unit', 'group', 'year', 'month'])


def build_demographics(work_dir):
    df = read_csv(work_dir, 'online-database-demographics.csv')
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


# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) != 5:
        print(__doc__)
        return 1

    work_dir, out_dir, update_id, date_end = sys.argv[1:5]

    missing = [f for f in CSV_SOURCES if not os.path.exists(csv_path(work_dir, f))]
    if missing:
        raise SystemExit(
            'ERROR: missing intermediate CSV(s):\n  '
            + '\n  '.join(csv_path(work_dir, f) for f in missing)
            + '\n  Run 03-build-online-database.do, -labor.do and -demographics.do first.'
        )

    reference_date, year, month = stata_month_to_date(date_end)
    check_reference_date(work_dir, year, month)
    print(f'Reference date: {reference_date}')

    os.makedirs(out_dir, exist_ok=True)

    for filename in TO_JSON:
        out_path = os.path.join(out_dir, filename.replace('.csv', '.json'))
        print(f'Converting {filename} -> {os.path.basename(out_path)}...')
        write_json(read_csv(work_dir, filename), out_path)

    for filename in TO_COPY:
        print(f'Copying {filename}...')
        shutil.copyfile(csv_path(work_dir, filename), os.path.join(out_dir, filename))

    print('Building income/wealth sheet...')
    df_iw = build_income_wealth(work_dir)
    print('Building labor sheet...')
    df_lab = build_labor(work_dir)
    print('Building demographics sheet...')
    df_demo = build_demographics(work_dir)

    xlsx_path = os.path.join(out_dir, 'full-online-database.xlsx')
    print(f'Writing {os.path.basename(xlsx_path)}...')
    with pd.ExcelWriter(xlsx_path, engine='openpyxl') as writer:
        df_iw.to_excel(writer,   sheet_name='income_wealth', index=False)
        df_lab.to_excel(writer,  sheet_name='labor',         index=False)
        df_demo.to_excel(writer, sheet_name='demographics',  index=False)

    # generated_at is the day this payload was built, shown on the website as
    # the publication date of the monthly figures.
    with open(os.path.join(out_dir, 'metadata.json'), 'w', encoding='utf-8') as f:
        json.dump({'data_reference_date': reference_date,
                   'generated_at': datetime.date.today().isoformat(),
                   'update_id': update_id}, f, indent=2)

    print(f'\nPayload ready in {out_dir}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
