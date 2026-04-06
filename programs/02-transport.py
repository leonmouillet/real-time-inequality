import ot
import numpy as np
import scipy as sp
import pandas as pd
import sys
import datetime
from multiprocessing import Pool
from joblib import Parallel, delayed
import os
import gc
from numba import jit, prange
import argparse
from pathlib import Path

# ---------------------------------------------------------------------------- #
# Command-line arguments
# ---------------------------------------------------------------------------- #

parser = argparse.ArgumentParser(description='Optimal transport')
parser.add_argument('--start_year', type=int, help='First year to process')
parser.add_argument('--end_year', type=int, help='Last year to process (inclusive)')
parser.add_argument('--directory', type=str, help='Transport directory')
parser.add_argument("--sentinel", type=str, help= 'Sentinel file')
args = parser.parse_args()

# ---------------------------------------------------------------------------- #
# Configuration
# ---------------------------------------------------------------------------- #

YEARS = list(range(args.start_year, args.end_year + 1))

DIR = args.directory
os.chdir(DIR)

USE_PARALLEL = False            # Set to False for sequential processing
N_JOBS = 16                     # Number of parallel workers

USE_WAGE_STRAT = True           # Set to False for no wage stratification
MAX_MATRIX_SIZE_GB = 1          # Cost matrix size limit from which wage stratification is implemented
N_WAGE_BINS = 3                 # Number of bins to use for wage stratification
MIN_BIN_SIZE = 100              # Minimum number of observations required in a (target) sub dataset after stratification

VERBOSE = False                 # Set to False for minimal verbosity

# ---------------------------------------------------------------------------- #
# Variables to match
# ---------------------------------------------------------------------------- #

matching_cps = {
    'dina_wage':  'cps_wage',
    'dina_pens':  'cps_pens',
    'dina_bus':   'cps_bus',
    'dina_int':   'cps_int',
    'dina_drt':   'cps_drt',
    'dina_gov':   'cps_gov',
    'dina_ss':    'cps_ss',
    'dina_welfr': 'cps_welfr'
}

matching_scf = {
    'dina_wage':     'scf_wage',
    'dina_pens_ss':  'scf_pens_ss',
    'dina_bus':      'scf_bus',
    'dina_intdivrt': 'scf_intdivrt',
    'dina_kg':       'scf_kg',
    'dina_wfinbus':  'scf_wfinbus',
    'dina_whou':     'scf_whou',
    'dina_wdeb':     'scf_wdeb'
}

cells = ['married', 'old', 'employed']

# ---------------------------------------------------------------------------- #
# Helper functions
# ---------------------------------------------------------------------------- #

def get_file_paths(year):
    """Get file paths for a given year"""
    dina_file = os.path.join(DIR, 'dina', f'usdina{year}.csv')
    cps_file = os.path.join(DIR, 'cps', f'cps{year}.csv')
    scf_file = os.path.join(DIR, 'scf', f'scf{year}.csv') if year >= 1989 else None
    return dina_file, cps_file, scf_file

@jit(nopython=True, parallel=True)
def cityblock_distance_numba(X, Y):
    """
    Compute cityblock (Manhattan) distance between all pairs of rows.
    Much faster than scipy.spatial.distance.cdist for large matrices.
    
    Parameters:
    - X: (m, d) array
    - Y: (n, d) array
    
    Returns:
    - (m, n) array of distances
    """
    m, n = X.shape[0], Y.shape[0]
    d = X.shape[1]
    result = np.empty((m, n), dtype=np.float64)
    
    for i in prange(m):
        for j in range(n):
            dist = 0.0
            for k in range(d):
                dist += abs(X[i, k] - Y[j, k])
            result[i, j] = dist
    
    return result

def should_split_cell(dina_subset, cps_subset, max_matrix_size_gb = MAX_MATRIX_SIZE_GB):
    """Check if cell would create a too-large cost matrix"""
    n_dina = len(dina_subset)
    n_cps = len(cps_subset)
    matrix_size_gb = (n_dina * n_cps * 4) / (1024**3)  # float32 = 4 bytes
    return matrix_size_gb > max_matrix_size_gb, matrix_size_gb

def add_wage_bins_matched(dina_df, cps_df, scf_df=None, n_bins= N_WAGE_BINS, min_bin_size= MIN_BIN_SIZE):
    """
    Add wage bins to all datasets using common thresholds
    Use same bins are created across all datasets
    Adaptively reduces number of bins if any bin would be too small, or if there exist orphan bins
    """
    # Combine all wages to determine common bin edges
    all_wages = pd.concat([dina_df['dina_wage'], cps_df['cps_wage']])
    if scf_df is not None:
        all_wages = pd.concat([all_wages, scf_df['scf_wage']])
    
    # Try with requested number of bins, reduce if imbalanced
    current_n_bins = n_bins

    while current_n_bins >= 2:

        # Calculate quantile thresholds from combined data
        try:
            _, bin_edges = pd.qcut(all_wages, q=current_n_bins, labels=False, retbins=True, duplicates='drop')
        except:
            # Fallback: use percentiles manually
            percentiles = [i/current_n_bins for i in range(current_n_bins+1)]
            bin_edges = all_wages.quantile(percentiles).values
        
        # Apply binning to each dataset
        dina_bins_series = pd.cut(dina_df['dina_wage'], bins=bin_edges, labels=False, include_lowest=True)
        cps_bins_series = pd.cut(cps_df['cps_wage'], bins=bin_edges, labels=False, include_lowest=True)
        scf_bins_series = pd.cut(scf_df['scf_wage'], bins=bin_edges, labels=False, include_lowest=True) if scf_df is not None else None
        
        # Check conditions
        cps_counts = cps_bins_series.value_counts()
        min_cps = cps_counts.min() if len(cps_counts) > 0 else 0
        bins_in_cps = set(cps_counts.index)
        bins_in_dina = set(dina_bins_series.dropna().unique())

        min_target = min_cps
        common_bins = bins_in_dina & bins_in_cps
        all_bins = bins_in_dina | bins_in_cps
        
        if scf_df is not None:
            scf_counts = scf_bins_series.value_counts()
            min_scf = scf_counts.min() if len(scf_counts) > 0 else 0
            bins_in_scf = set(scf_counts.index)
            
            min_target = min(min_cps, min_scf)
            common_bins = bins_in_dina & bins_in_cps & bins_in_scf
            all_bins = bins_in_dina | bins_in_cps | bins_in_scf

        if min_target >= min_bin_size and len(common_bins) == len(all_bins): 
            # Sufficient size and no orphan bin
            # Apply bins and return
            dina_df['wage_bin'] = dina_bins_series.fillna(0).astype(int)
            cps_df['wage_bin'] = cps_bins_series.fillna(0).astype(int)
            if scf_df is not None:
                scf_df['wage_bin'] = scf_bins_series.fillna(0).astype(int)
            return dina_df, cps_df, scf_df
        
        # Reduce bins and try again
        current_n_bins -= 1
    
    # Fallback: single bin
    dina_df['wage_bin'] = 0
    cps_df['wage_bin'] = 0
    if scf_df is not None:
        scf_df['wage_bin'] = 0
    
    return dina_df, cps_df, scf_df

# ---------------------------------------------------------------------------- #
# Processing functions
# ---------------------------------------------------------------------------- #

def process_cell_core(dina_subset, cps_subset, scf_subset):
    """
    Core function for processing a single cell, possibly after wage stratification
    """

    # Calculate pairwise distance between observations in DINA and CPS
    dina_cols = list(matching_cps.keys())
    cps_cols = [matching_cps[col] for col in dina_cols]
    dina_arr = dina_subset.loc[:, dina_cols].fillna(0).to_numpy(dtype=np.float32)
    cps_arr = cps_subset.loc[:, cps_cols].fillna(0).to_numpy(dtype=np.float32)
    cost_cps = cityblock_distance_numba(dina_arr, cps_arr).astype(np.float32)
    
    # Extract and normalize weights
    dina_weights = dina_subset['weight'].to_numpy().astype(np.float32) 
    cps_weights = cps_subset['weight'].to_numpy().astype(np.float32) 
    dina_mass = dina_weights.sum()
    cps_mass = cps_weights.sum()
    dina_weights /= dina_mass
    cps_weights /= cps_mass

    # Find optimal transport map
    ot_map = ot.emd(dina_weights, cps_weights, cost_cps, numItermax=1e9)
    ot_map = ot_map.astype(np.float32)
    del cost_cps, dina_arr, cps_arr

    if scf_subset is None:
        # If no SCF to match, save directly
        nonzero_entries = np.nonzero(ot_map)
        group_matches = pd.DataFrame({
            'dina_id': dina_subset.iloc[nonzero_entries[0]]['id'].values,
            'cps_id': cps_subset.iloc[nonzero_entries[1]]['id'].values,
            'weight': dina_mass * ot_map[nonzero_entries]
        })

    else:
        # If there is SCF to match, first create the matched DINA-CPS dataset with required variables
        dina_cols = list(matching_scf.keys())
        scf_cols = [matching_scf[col] for col in dina_cols]
        nonzero_entries = np.nonzero(ot_map)
        dina_matched = dina_subset.iloc[nonzero_entries[0]]
        dina_cps_subset = pd.DataFrame({
            'dina_id': dina_matched['id'].values,
            'cps_id': cps_subset.iloc[nonzero_entries[1]]['id'].values,
            'weight': dina_mass * ot_map[nonzero_entries]
        })
        for c in dina_cols:
            dina_cps_subset[c] = dina_matched[c].values

        # Do the second transport
        dina_cps_arr = dina_cps_subset.loc[:, dina_cols].fillna(0).to_numpy(dtype=np.float32)
        scf_arr = scf_subset.loc[:, scf_cols].fillna(0).to_numpy(dtype=np.float32)
        cost_scf = cityblock_distance_numba(dina_cps_arr, scf_arr).astype(np.float32)

        dina_cps_weights = dina_cps_subset['weight'].to_numpy().astype(np.float32)
        scf_weights = scf_subset['weight'].to_numpy().astype(np.float32)
        dina_cps_mass = dina_cps_weights.sum()
        scf_mass = scf_weights.sum()
        dina_cps_weights /= dina_cps_mass
        scf_weights /= scf_mass

        ot_map = ot.emd(dina_cps_weights, scf_weights, cost_scf, numItermax=1e9)
        ot_map = ot_map.astype(np.float32)
        del cost_scf, dina_cps_arr, scf_arr

        # Save the double match
        nonzero_entries = np.nonzero(ot_map)
        dina_cps_matched = dina_cps_subset.iloc[nonzero_entries[0]]
        group_matches = pd.DataFrame({
            'dina_id': dina_cps_matched['dina_id'].values,
            'cps_id': dina_cps_matched['cps_id'].values,
            'scf_id': scf_subset.iloc[nonzero_entries[1]]['id'].values,
            'weight': dina_cps_mass * ot_map[nonzero_entries]
        })

    return group_matches

def process_cell(dina_data, cps_data, scf_data, year, cell_values):
    """
    Wrapper function for processing a cell, prior to any wage stratification
    """

    print(f"   * Processing year {year}, cell {cell_values} [{datetime.datetime.now().time()}]")
    
    mask_dina = (dina_data['married'] == cell_values[0]) & \
                (dina_data['old'] == cell_values[1]) & \
                (dina_data['employed'] == cell_values[2])
    dina_subset = dina_data[mask_dina].copy()
    
    mask_cps = (cps_data['married'] == cell_values[0]) & \
               (cps_data['old'] == cell_values[1]) & \
               (cps_data['employed'] == cell_values[2])
    cps_subset = cps_data[mask_cps].copy()
    
    if scf_data is not None:
        mask_scf = (scf_data['married'] == cell_values[0]) & \
                   (scf_data['old'] == cell_values[1]) & \
                   (scf_data['employed'] == cell_values[2])
        scf_subset = scf_data[mask_scf].copy()
    else:
        scf_subset = None
    
    # Check if subsets are empty
    if len(dina_subset) == 0 or len(cps_subset) == 0:
        if VERBOSE:
            print(f"      [SKIP] Empty cell")
        return None

    # Process with or without wage stratification

    if not USE_WAGE_STRAT: # If no stratification is wanted, just process the cell as it is
        return process_cell_core(dina_subset, cps_subset, scf_subset)

    # Otherwise, check if splitting is needed
    needs_split, matrix_size = should_split_cell(dina_subset, cps_subset, max_matrix_size_gb=MAX_MATRIX_SIZE_GB)
    
    if not needs_split: # If no splitting is needed, just process the cell as it is
        if VERBOSE:
            print(f"      [FULL] Matrix is {matrix_size:.2f}GB - no splitting needed")
        return process_cell_core(dina_subset, cps_subset, scf_subset)

    # If splitting is needed, compute wage bins and perform OT on substrats
    if VERBOSE:
        print(f"      [SPLIT] Matrix would be {matrix_size:.2f}GB - splitting by wage bins")

    # Compute wage bins        
    dina_subset_binned, cps_subset_binned, scf_subset_binned = add_wage_bins_matched(
        dina_subset, cps_subset, scf_subset,
        n_bins=N_WAGE_BINS, min_bin_size=MIN_BIN_SIZE
    )
    
    # Process each bin
    sub_matches = []
    for wage_bin in dina_subset_binned['wage_bin'].unique():
        dina_sub = dina_subset_binned[dina_subset_binned['wage_bin'] == wage_bin]
        cps_sub = cps_subset_binned[cps_subset_binned['wage_bin'] == wage_bin]
        scf_sub = scf_subset_binned[scf_subset_binned['wage_bin'] == wage_bin] if scf_subset_binned is not None else None

        if VERBOSE:
            scf_info = f", {len(scf_sub)} SCF" if scf_sub is not None else ""
            print(f"         [SUB] Wage bin {wage_bin} - {len(dina_sub)} DINA × {len(cps_sub)} CPS{scf_info}")
        
        sub_matches.append(process_cell_core(dina_sub, cps_sub, scf_sub))

        
    return pd.concat(sub_matches, ignore_index=True)

def process_year(year):
    """
    Wrapper function for processing one year.
    Enables parallel processing.
    """

    dina_file, cps_file, scf_file = get_file_paths(year)
    dina_data = pd.read_csv(dina_file)
    cps_data = pd.read_csv(cps_file)
    scf_data = pd.read_csv(scf_file) if scf_file is not None else None

    year_matches = []
    dina_groups = dina_data.groupby(cells).groups

    for cell_values in dina_groups.keys():
        cell_matches = process_cell(
            dina_data,
            cps_data,
            scf_data,
            year,
            cell_values
        )

        if cell_matches is not None and len(cell_matches) > 0:
            year_matches.append(cell_matches)

    del dina_data, cps_data, scf_data
    gc.collect()

    if year_matches:
        return year, pd.concat(year_matches, ignore_index=True)
    else:
        return year, pd.DataFrame()

# ---------------------------------------------------------------------------- #
# Perform the matches
# ---------------------------------------------------------------------------- #

if __name__ == '__main__':

    print(f"OPTIMAL TRANSPORT MATCHING: Processing years {YEARS[0]}–{YEARS[-1]} ")
    if USE_WAGE_STRAT:
        print(f"* Adaptive wage stratification for cost matrices > {MAX_MATRIX_SIZE_GB} GB")

    # Process all years
    if USE_PARALLEL: # in parallel
        print(f"* Parallel processing with {N_JOBS} workers")
        results = Parallel(n_jobs=N_JOBS, backend='loky', batch_size=1)(delayed(process_year)(year) for year in YEARS)

    else: # or sequentially
        print(f"* Sequential processing")
        results = []
        for year in YEARS:
            results.append(process_year(year))
    
    # Save each year
    print(f"* Saving transport maps as CSV [{datetime.datetime.now().time()}]")
    for year, matches in results:
        if matches is None or matches.empty:
            print(f"   [SKIP] Year {year} - no matches")
            continue
        output_file = os.path.join(DIR, "match", f"match-{year}.csv")
        matches.to_csv(output_file, index=False)
        print(f"   Saved {year}: {len(matches)} matches → {output_file}")
    
    # Create sentinel file
    if args.sentinel:
        Path(args.sentinel).write_text("done")
        print(f"Sentinel file created at {args.sentinel}")