// -------------------------------------------------------------------------- //
// Data coverage summary (read and report only)
// -------------------------------------------------------------------------- //


// Prepare output
clear
local report "$work/01-data-summary/data-summary.txt"
file open rep using "`report'", write replace text
file write rep ///
"Repository state (post-import, pre-processing)" _n ///
"Summary generated on: `c(current_date)'" _n _n _n

// -------------------------------------------------------------------------- //
// Monthly data sources
// -------------------------------------------------------------------------- //

file write rep "MONTHLY DATA SOURCES" _column(78) "LAST DATA" _n _n

* [nipa] (monthly)
use "$work/01-import-nipa/nipa-monthly-series.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local nipa_monthly_end = r(max)
local fname "work-data/01-import-nipa/nipa-monthly-series.dta"
file write rep "[nipa]" _column(18) "`fname'" _column(80) %tm (`nipa_monthly_end') _n

* [cu]
use "$work/01-import-cu/bls-cpi.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local cu_end = r(max)
local fname "work-data/01-import-cu/bls-cpi.dta"
file write rep "[cu]" _column(18) "`fname'" _column(80) %tm (`cu_end') _n

* [cps-monthly]
use "$work/01-import-cps-monthly/cps-monthly.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local cps_end = r(max)
local fname "work-data/01-import-cps-monthly/cps-monthly.dta"
file write rep "[cps-monthly]" _column(18) "`fname'" _column(80) %tm (`cps_end') _n

* [ce] (employment)
use "$work/01-import-ce/ce-employment.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local ce_emp_end = r(max)
local fname "work-data/01-import-ce/ce-employment.dta"
file write rep "[ce]" _column(18) "`fname'" _column(80) %tm (`ce_emp_end') _n

* [ce] (supersector)
use "$work/01-import-ce/ce-supersector.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local ce_sup_end = r(max)
local fname "work-data/01-import-ce/ce-supersector.dta"
file write rep "[ce]" _column(18) "`fname'" _column(80) %tm (`ce_sup_end') _n

* [sm]
use "$work/01-import-sm/sm-state-supersector.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local sm_end = r(max)
local fname "work-data/01-import-sm/sm-state-supersector.dta"
file write rep "[sm]" _column(18) "`fname'" _column(80) %tm (`sm_end') _n

* [ui]
use "$work/01-import-ui/ui-data.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local ui_end = r(max)
local fname "work-data/01-import-ui/ui-data.dta"
file write rep "[ui]" _column(18) "`fname'" _column(80) %tm (`ui_end') _n

* [wealth-indexes]
use "$work/01-import-wealth-indexes/wealth-indexes.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local wealth_end = r(max)
local fname "work-data/01-import-wealth-indexes/wealth-indexes.dta"
file write rep "[wealth-indexes]" _column(18) "`fname'" _column(80) %tm (`wealth_end') _n

* [forbes]
use "$work/01-import-forbes/forbes400-monthly.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local forbes_end = r(max)
local fname "work-data/01-import-forbes/forbes400-monthly.dta"
file write rep "[forbes]" _column(18) "`fname'" _column(80) %tm (`forbes_end') _n

* [minwage] (federal)
use "$work/01-import-minwage/fed-minimum-wage.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local fed_end = r(max)
local fname "work-data/01-import-minwage/fed-minimum-wage.dta"
file write rep "[minwage]" _column(18) "`fname'" _column(80) %tm (`fed_end') _n

* [minwage] (state)
use "$work/01-import-minwage/state-minimum-wage.dta", clear
gen __ym = ym(year, month)
summarize __ym, meanonly
local state_end = r(max)
local fname "work-data/01-import-minwage/state-minimum-wage.dta"
file write rep "[minwage]" _column(18) "`fname'" _column(80) %tm (`state_end') _n

// Determine limiting DATE_END
// Minimum of all end dates for monthly sources 
// (excluding Forbes data which is not limiting)

local DATE_END = `nipa_monthly_end'
foreach v in `cu_end' `cps_end' `ce_emp_end' `ce_sup_end' `sm_end' `ui_end' `wealth_end' `fed_minwage_end' `state_minwage_end' { 
		if (`v' < `DATE_END') local DATE_END = `v'
}

local DATE_END_TXT = string(`DATE_END', "%tm")
file write rep _n "LIMITING MONTH FOR RTI MICROFILES (maximum value for date_end):" _column(80) ///
" `DATE_END_TXT'" _n _n _n

if $date_end > `DATE_END' {
    di as error "ERROR: global date_end (set in 00-setup.do) exceeds data availability"
    exit 198
}

// -------------------------------------------------------------------------- //
// Quarterly / Annual / Supra-annual data sources
// -------------------------------------------------------------------------- //

file write rep "QUARTERLY / ANNUAL / SUPRA-ANNUAL DATA SOURCES" _column(78) "LAST DATA" _n _n

* [nipa] (quarterly)
use "$work/01-import-nipa/nipa-quarterly-series.dta", clear
gen __yq = yq(year, quarter)
summarize __yq, meanonly
local nipa_quarterly_end = r(max)
local fname "work-data/01-import-nipa/nipa-quarterly-series.dta"
file write rep "[nipa]" _column(18) "`fname'" _column(81) %tq (`nipa_quarterly_end') _n

keep if series_code == "A051RC"
summarize __yq, meanonly
local nipa_profits_end = r(max)
local fname "corporate profits (series_code A051RC)"
file write rep " " _column(18) "`fname'" _column(81) %tq (`nipa_profits_end') _n

* [qcew]
use "$work/01-import-qcew/qcew-raw.dta", clear
gen __yq = yq(year, qtr)
summarize __yq, meanonly
local qcew_end = r(max)
local fname "work-data/01-import-qcew/qcew-raw.dta"
file write rep "[qcew]" _column(18) "`fname'" _column(81) %tq (`qcew_end') _n

* [fa]
use "$work/01-import-fa/fa.dta", clear
gen __yq = yq(year, quarter)
summarize __yq, meanonly
local fa_end = r(max)
local fname "work-data/01-import-fa/fa.dta"
file write rep "[fa]" _column(18) "`fname'" _column(81) %tq (`fa_end') _n

* [dina-macro]
use "$work/01-import-dina-macro/dina-macro-parameters.dta", clear
gen __yr = year
summarize __yr, meanonly
local dina_macro_end = r(max)
local fname "work-data/01-import-dina-macro/dina-macro-parameters.dta"
file write rep "[dina-macro]" _column(18) "`fname'" _column(83) %ty (`dina_macro_end') _n

* [dina] 
use "$work/01-import-dina/dina-full.dta", clear
gen __yr = year
summarize __yr, meanonly
local dina_end = r(max)
local fname "work-data/01-import-dina/dina-full.dta"
file write rep "[dina]" _column(18) "`fname'" _column(83) %ty (`dina_end') _n

* [ssa]
use "$work/01-import-ssa/ssa-tables.dta", clear
gen __yr = year
summarize __yr, meanonly
local ssa_end = r(max)
local fname "work-data/01-import-ssa/ssa-tables.dta"
file write rep "[ssa]" _column(18) "`fname'" _column(83) %ty (`ssa_end') _n

* [transport-acs]
use "$work/01-import-transport-acs/acs-gq-data.dta", clear
gen __yr = year
summarize __yr, meanonly
local acs_end = r(max)
local fname "work-data/01-import-transport-acs/acs-gq-data.dta"
file write rep "[transport-acs]" _column(18) "`fname'" _column(83) %ty (`acs_end') _n

* [transport-cps]
use "$work/01-import-transport-cps/cps-full.dta", clear
gen __yr = year
summarize __yr, meanonly
local cps_tr_end = r(max)
local fname "work-data/01-import-transport-cps/cps-full.dta"
file write rep "[transport-cps]" _column(18) "`fname'" _column(83) %ty (`cps_tr_end') _n

* [transport-scf]
use "$work/01-import-transport-scf/scf-full.dta", clear
gen __yr = year
summarize __yr, meanonly
local scf_end = r(max)
local fname "work-data/01-import-transport-scf/scf-full.dta"
file write rep "[transport-scf]" _column(18) "`fname'" _column(83) %ty (`scf_end') _n

* [ici] 
use "$work/01-import-ici/ici-data-flows.dta", clear
gen __yr = year
summarize __yr, meanonly
local ici_end = r(max)
local fname "work-data/01-import-ici/ici-data-flows.dta"
file write rep "[ici]" _column(18) "`fname'" _column(83) %ty (`ici_end') _n

* [pop]
use "$work/01-import-pop/pop-data-national.dta", clear
gen __yr = year
summarize __yr, meanonly
local pop_end = r(max)
local fname "work-data/01-import-pop/pop-data-national.dta"
file write rep "[pop]" _column(18) "`fname'" _column(83) %ty (`pop_end') _n

file close rep