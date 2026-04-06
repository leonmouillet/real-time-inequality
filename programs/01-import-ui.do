// -------------------------------------------------------------------------- //
// Import data on UI claims
// -------------------------------------------------------------------------- //

import excel "$rawdata/ui-data/weekly-unemployment-report.xlsx", clear cellrange(A2) allstring // Pick cell corresponding to begining of data

generate time = date(A, "MDY") // Pick column letter corresponding to weekEnded variable
format time %td

destring B, generate(ui_claims) // Pick column letter corresponding to Initial Claims NSA variable

keep time ui_claims
drop if missing(time)
drop if missing(ui_claims)

generate year = year(time)
generate month = month(time)

// Aggregate by month
gcollapse (mean) ui_claims, by(year month)

// Save
save "$work/01-import-ui/ui-data.dta", replace
