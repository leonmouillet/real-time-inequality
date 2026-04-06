// -------------------------------------------------------------------------- //
// Create monthly version of QCEW data
// -------------------------------------------------------------------------- //

// -------------------------------------------------------------------------- //
// Combine NAICS and SIC files
// -------------------------------------------------------------------------- //

use "$work/01-import-qcew/qcew-raw.dta", clear
generate version = "NAICS"
append using "$work/01-import-qcew/qcew-legacy-raw.dta"
replace version = "SIC" if missing(version)

// Fix typo in the input file
replace month2_emplvl = 153 if month2_emplvl == 30000153 & ///
    area_fips == "12103" & ///
    industry_code == "SIC_0J92" & ///
    own_code == 3

// ----------------------------------------------------------------------------------------- //
// Drop new cells in public sector appearing in 2022 (~ 5M new workers breaking consistency)
// ----------------------------------------------------------------------------------------- //

preserve
	keep if year == 2021 | year == 2022
	keep if month1_emplvl + month2_emplvl+ month3_emplvl > 0 
	keep area_fips own_code industry_code year
	duplicates drop
	sort area_fips own_code industry_code year
	by area_fips own_code industry_code: generate existed_prev = (year[_n-1] == year - 1)
	generate new_cell = (existed_prev != 1)
	keep if year == 2022
	keep if own_code == 2 | own_code == 3 
	keep area_fips own_code industry_code new_cell
	tempfile new_cells_2022
	save "`new_cells_2022'"
restore

merge m:1 area_fips own_code industry_code using "`new_cells_2022'", nogenerate
drop if new_cell == 1 & year >= 2022

// -------------------------------------------------------------------------- //
// Simple disaggregation: get monthly employment levels, keep average
// quarterly wage
// -------------------------------------------------------------------------- //

generate qtrly_emplvl = month1_emplvl + month2_emplvl + month3_emplvl
drop if qtrly_emplvl == 0 // This drops all censored observations. 

expand 3
hashsort version area_fips own_code industry_code year qtr
by version area_fips own_code industry_code year qtr: generate month = _n

generate mthly_emplvl = .
replace mthly_emplvl = month1_emplvl if month == 1
replace mthly_emplvl = month2_emplvl if month == 2
replace mthly_emplvl = month3_emplvl if month == 3
drop month1_emplvl month2_emplvl month3_emplvl
drop if mthly_emplvl == 0
replace month = (qtr - 1)*3 + month

// Calculate average monthly wages in constant USD
merge n:1 year month using "$work/01-import-cu/bls-cpi.dta", ///
    keep(master match) assert(match using) keepusing(cpi) nogenerate

hashsort version area_fips own_code industry_code year qtr
gegen qtrly_cpi = mean(cpi), by(version area_fips own_code industry_code year qtr)
by version area_fips own_code industry_code year qtr: generate avg_mthly_wages = total_qtrly_wages/qtrly_emplvl/qtrly_cpi

drop qtr qtrly_emplvl total_qtrly_wages qtrly_cpi cpi

// -------------------------------------------------------------------------- //
// Take a 12-month moving average of wages, to get rid of seasonality,
// and assuming that they are sticky anyway
// -------------------------------------------------------------------------- //

gegen id = group(version area_fips own_code industry_code)
generate time = ym(year, month)

tsset id time, monthly

egen avg_mthly_wages_ma = filter(avg_mthly_wages), lags(0/11) normalize
// Drop first year of data because of moving average
drop if version == "SIC" & year == 1975
drop if version == "NAICS" & year == 1990

// -------------------------------------------------------------------------- //
// Patch 2022 missing MA values using crosswalk to link with 2021 data
// -------------------------------------------------------------------------- //

// Identify which 2022 observations have missing MA
generate needs_patch = (year == 2022 & missing(avg_mthly_wages_ma))

// Import NAICS crosswalk
// <https://data.bls.gov/cew/apps/bls_naics/2022_changes.csv>
preserve
	import delimited "$rawdata/crosswalks/naics-2017-2022.csv", clear varnames(noname) rowrange(2:) bindquote(strict) stripquote(yes) encoding(utf8)
	rename v1 naics2017
	rename v5 naics2022
	rename v3 action
	tostring naics2017 naics2022, replace
	drop if missing(naics2022) | missing(naics2017) | action == "REMOVE"
	keep naics2017 naics2022
	save "$rawdata/crosswalks/naics-2017-2022.dta", replace
restore

// Compute employment by industry for 2021 and 2022
preserve
	keep if version == "NAICS" & inrange(year, 2021, 2022)
	collapse (sum) total_emp=mthly_emplvl, by(industry_code year)
	reshape wide total_emp, i(industry_code) j(year)
	rename industry_code naics
	rename total_emp2021 E2021
	rename total_emp2022 E2022
	save "$work/02-disaggregate-qcew/indus-employment-2021-2022.dta", replace
restore

// Compute allocation matrix using RAS algorithm (biproportional fitting)
* For all i (2017 code), j (2022 code), we want to compute
* A[i,j] = fraction of employment in industry i (2017 code) switched to industry j (2022 code)
* such that : 
* for each i (2017 code): Σ A[i,j] = 1 and
* for each j (2022 code): Σ A[i,j] × E2021[i] = E2022[j]

preserve
	use "$rawdata/crosswalks/naics-2017-2022.dta", clear

	// Initial guess: uniform split
	bysort naics2017: gen num_successors = _N
	generate A_initial = 1 / num_successors

	// Merge with national employment
	rename naics2017 naics
	merge n:1 naics using "$work/02-disaggregate-qcew/indus-employment-2021-2022.dta", keep(master match) keepusing(E2021) nogenerate
	rename naics naics2017
	rename E2021 E2021_i

	rename naics2022 naics
	merge n:1 naics using "$work/02-disaggregate-qcew/indus-employment-2021-2022.dta", keep(master match) keepusing(E2022) nogenerate
	rename naics naics2022
	rename E2022 E2022_j

	// Fill missing with small value to avoid division by zero
	replace E2021_i = 1 if missing(E2021_i)
	replace E2022_j = 1 if missing(E2022_j)
	
	// RAS iterations
	generate A = A_initial
	local tolerance = 0.0001
	local max_iter = 100
	local converged = 0

	forvalues iter = 1/`max_iter' {
		
		generate A_prev = A
		
		// STEP S: Adjust columns to match 2022 employment
		// For each j (2022 code): Σ A[i,j] × E2021[i] = E2022[j]
		generate A_times_E2021 = A * E2021_i
		bysort naics2022: egen col_sum = total(A_times_E2021)
		generate s_factor = E2022_j / col_sum
		replace s_factor = 1 if missing(s_factor) | s_factor == 0
		replace A = A * s_factor
		drop A_times_E2021 col_sum s_factor

		// STEP R: Adjust rows to sum to 1
		// For each i (2017 code): Σ A[i,j] = 1
		bysort naics2017: egen row_sum = total(A)
		generate r_factor = 1 / row_sum
		replace A = A * r_factor
		drop row_sum r_factor
		
		// Check convergence
		generate diff = abs(A - A_prev)
		summarize diff, meanonly
		local max_diff = r(max)
		drop diff A_prev
		
		if `max_diff' < `tolerance' {
			di "RAS converged after `iter' iterations (max change = " %9.7f `max_diff' ")"
			local converged = 1
			continue, break
		}
		
		if mod(`iter', 10) == 0 {
			di "  Iteration `iter': max change = " %9.3f `max_diff'
		}
	}

	if `converged' == 0 {
		di "Warning: RAS did not converge after `max_iter' iterations"
	}
	
	// Save allocation matrix
	keep naics2017 naics2022 A
	save "$work/02-disaggregate-qcew/naics-2017-2022-allocation.dta", replace
restore

// Create synthetic 2021 observations using allocation matrix
preserve
	keep if version == "NAICS" & year == 2021
	rename industry_code naics2017

	// Expand to all 2022 successors using RAS matrix
	joinby naics2017 using "$work/02-disaggregate-qcew/naics-2017-2022-allocation.dta", unmatched(master)
	replace naics2022 = naics2017 if missing(naics2022)
	replace A = 1 if missing(A)
	drop _merge

	// Create weighted synthetic observations
	generate allocated_emp = A * mthly_emplvl
	generate allocated_wagebill = A * mthly_emplvl * avg_mthly_wages

	// Collapse to synthetic 2021 observations for each 2022 code
	collapse (sum) allocated_emp allocated_wagebill, by(version area_fips own_code naics2022 year month)
	generate avg_mthly_wages = allocated_wagebill / allocated_emp
	drop allocated_emp allocated_wagebill
	rename naics2022 industry_code
	
	save "$work/02-disaggregate-qcew/synthetic-2021.dta", replace
restore

// Compute MA for 2022 observations using synthetic 2021 observations
preserve
	keep if version == "NAICS" & year == 2022
	append using "$work/02-disaggregate-qcew/synthetic-2021.dta"
	
	gegen id_temp = group(version area_fips own_code industry_code)
	drop time
	generate time = ym(year, month)
	xtset id_temp time, monthly
	
	egen avg_mthly_wages_ma_new = filter(avg_mthly_wages), lags(0/11) normalize
	
	keep if year == 2022 & !missing(avg_mthly_wages_ma_new)
	keep version area_fips own_code industry_code year month avg_mthly_wages_ma_new
	save "$work/02-disaggregate-qcew/patch-2022.dta", replace
restore

// Apply patch where MA is missing
merge 1:1 version area_fips own_code industry_code year month using "$work/02-disaggregate-qcew/patch-2022.dta", keep(master match) nogenerate
    
count if needs_patch
local total = r(N)
count if needs_patch & !missing(avg_mthly_wages_ma_new)
di _n "Patched " r(N) " of " `total' " observations (" %4.1f 100*r(N)/`total' "%)"

generate is_patched = (needs_patch & !missing(avg_mthly_wages_ma_new))
replace avg_mthly_wages_ma = avg_mthly_wages_ma_new if is_patched

drop needs_patch avg_mthly_wages_ma_new

capture erase "$work/02-disaggregate-qcew/patch-2022.dta"
capture erase "$work/02-disaggregate-qcew/synthetic-2021.dta"
capture erase "$work/02-disaggregate-qcew/naics-2017-2022-allocation.dta"
capture erase "$work/02-disaggregate-qcew/indus-employment-2021-2022.dta"

// -------------------------------------------------------------------------- //
// Impute missing values, included created by the moving average
// -------------------------------------------------------------------------- //

generate log_avg_mthly_wages = log(avg_mthly_wages_ma)
generate is_imputed = missing(log_avg_mthly_wages)

foreach v in NAICS SIC {
    reghdfe log_avg_mthly_wages if version == "`v'" [aw=mthly_emplvl], verbose(4) coeflegend absorb(area_fips own_code industry_code time, savefe)
    // Create the constant
    generate __hdfe0__ = _b[_cons] if version == "`v'"
    // Extend fxed effects to observations with missing values
    gegen __hdfe1__ = firstnm(__hdfe1__) if version == "`v'", by(area_fips) replace
    gegen __hdfe2__ = firstnm(__hdfe2__) if version == "`v'", by(own_code) replace
    gegen __hdfe3__ = firstnm(__hdfe3__) if version == "`v'", by(industry_code) replace
    gegen __hdfe4__ = firstnm(__hdfe4__) if version == "`v'", by(time) replace
    // If fixed effect missing, assume zero
    forvalues i = 1/4 {
        replace __hdfe`i'__ = 0 if missing(__hdfe`i'__) & version == "`v'"
    }
    // Make prediction
    replace avg_mthly_wages_ma = exp(__hdfe0__ + __hdfe1__ + __hdfe2__ + __hdfe3__ + __hdfe4__) if missing(avg_mthly_wages_ma) & version == "`v'"
    drop __hdfe*
}

drop log_avg_mthly_wages
assert !missing(avg_mthly_wages_ma)

replace avg_mthly_wages = avg_mthly_wages_ma
drop avg_mthly_wages_ma

tsset, clear
drop time id

// -------------------------------------------------------------------------- //
// Save
// -------------------------------------------------------------------------- //

compress
save "$work/02-disaggregate-qcew/qcew-monthly.dta", replace