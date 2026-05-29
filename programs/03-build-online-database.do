// -------------------------------------------------------------------------- //
// Build the online database
// -------------------------------------------------------------------------- //

clear
local date_begin = ym(1976, 01)
local date_end   = $date_end

local concepts factor_income pretax_income disposable_income posttax_income wealth
local concept_princ  = "factor_income"
local concept_peinc  = "pretax_income"
local concept_dispo  = "disposable_income"
local concept_poinc  = "posttax_income"
local concept_hweal  = "wealth"

local src_factor_income = "princ"
local src_pretax_income = "peinc"
local src_disposable_income = "dispo"
local src_posttax_income = "poinc"
local src_wealth = "hweal"

local pops adult_equal_split working_age_equal_split adult_households

clear
tempfile result
save `result', replace emptyok

foreach pop in `pops' {
    foreach concept in `concepts' {

        local src = "`src_`concept''"
		
		if "`src'" == "hweal" {
			use "$work/03-tabulate-wealth/tabulation-hweal-`pop'.dta", clear
		}
		else {
			use "$work/03-tabulate-income/tabulation-`src'-`pop'.dta", clear
		}
		
        keep if inrange(ym(year, month), `date_begin', `date_end')

        // Group definitions depend on scale
        generate group = ""
        if "`src'" == "hweal" {
            replace group = "bot50"       if inrange(p, 0,       4999999)
            replace group = "mid40"       if inrange(p, 5000000, 8999999)
            replace group = "top10_1"     if inrange(p, 9000000, 9899999)
            replace group = "top1_01"     if inrange(p, 9900000, 9989999)
            replace group = "top01_001"   if inrange(p, 9990000, 9998999)
            replace group = "top001_0001" if inrange(p, 9999000, 9999899)
            replace group = "top0001"     if inrange(p, 9999900, 9999999)
        }
        else {
            replace group = "bot50"       if inrange(p, 0,     49999)
            replace group = "mid40"       if inrange(p, 50000, 89999)
            replace group = "top10_1"     if inrange(p, 90000, 98999)
            replace group = "top1_01"     if inrange(p, 99000, 99899)
            replace group = "top01_001"   if inrange(p, 99900, 99989)
            replace group = "top001_0001" if inrange(p, 99990, 99998)
            replace group = "top0001"     if inrange(p, 99999, 99999)
        }
        drop if group == ""

        // Collapse by group: mean value, threshold, population
        gcollapse (mean) `src' (min) threshold (rawsum) pop [iw=pop], by(year month group)
        generate value = `src' * pop
        drop `src'

        // Total row
        preserve
            gcollapse (sum) value pop, by(year month)
            generate group = "Total"
            tempfile tot
            save `tot'
        restore
        append using `tot'

        // Combine into nested groups
        greshape wide value pop threshold, i(year month) j(group) string
        generate valuetop10   = valuetop0001 + valuetop001_0001 + valuetop01_001 + valuetop1_01 + valuetop10_1
        generate valuetop1    = valuetop0001 + valuetop001_0001 + valuetop01_001 + valuetop1_01
        generate valuetop01   = valuetop0001 + valuetop001_0001 + valuetop01_001
        generate valuetop001  = valuetop0001 + valuetop001_0001
        generate poptop10     = poptop0001   + poptop001_0001   + poptop01_001   + poptop1_01   + poptop10_1
        generate poptop1      = poptop0001   + poptop001_0001   + poptop01_001   + poptop1_01
        generate poptop01     = poptop0001   + poptop001_0001   + poptop01_001
        generate poptop001    = poptop0001   + poptop001_0001
        generate thresholdtop10   = thresholdtop10_1
        generate thresholdtop1    = thresholdtop1_01
        generate thresholdtop01   = thresholdtop01_001
        generate thresholdtop001  = thresholdtop001_0001
        greshape long value pop threshold, i(year month) j(group) string

        replace group = "Bottom 50%"     if group == "bot50"
        replace group = "Middle 40%"     if group == "mid40"
        replace group = "Top 10%"        if group == "top10"
        replace group = "Top 1%"         if group == "top1"
        replace group = "Top 0.1%"       if group == "top01"
        replace group = "Top 0.01%"      if group == "top001"
        replace group = "Top 0.001%"       if group == "top0001"
        replace group = "Top 0.01%-0.001%" if group == "top001_0001"
        replace group = "Top 10%-1%"     if group == "top10_1"
        replace group = "Top 1%-0.1%"    if group == "top1_01"
        replace group = "Top 0.1%-0.01%" if group == "top01_001"

        generate unit   = "`pop'"
        generate income = "`concept'"

        append using `result'
        save `result', replace
    }
}

save "$work/03-build-online-database/online-database-main.dta", replace

// -------------------------------------------------------------------------- //
// Ultra-top wealth series (Top 0.0001% and Top 0.00001%)
// -------------------------------------------------------------------------- //

// Extract population references
use "$work/03-build-online-database/online-database-main.dta", clear
keep if group == "Total" & income == "wealth"
keep year month unit pop
greshape wide pop, i(year month) j(unit) string
rename popadult_equal_split        pop_aes
rename popadult_households         pop_ah
rename popworking_age_equal_split  pop_waes
tempfile pops
save `pops'

// Forbes series (1982–date_end)
tempfile ultra_forbes
clear
save `ultra_forbes', emptyok

use "$work/03-build-monthly-forbes/forbes-monthly-micro.dta", clear
keep year month wealth birth_year
keep if inrange(ym(year, month), ym(1982, 1), `date_end')

merge m:1 year month using `pops', keep(match master) nogenerate

gsort year month -wealth
bysort year month: generate rank_m = _n

foreach pop_type in adult_equal_split adult_households working_age_equal_split {

    if "`pop_type'" == "adult_households" {
        local pop_var pop_ah
        local factor  1
    }
    else if "`pop_type'" == "adult_equal_split" {
        local pop_var pop_aes
        local factor  2
    }
    else {
        local pop_var pop_waes
        local factor  2
    }

    tempfile forbes_src
    if "`pop_type'" == "working_age_equal_split" {
        preserve
            generate age_m = year - birth_year
            keep if age_m < 65 | missing(age_m)
            gsort year month -wealth
            drop rank_m
            bysort year month: generate rank_m = _n
            save `forbes_src'
        restore
    }
    else {
        save `forbes_src'
    }

    foreach frac_tag in f6 f7 {
        if "`frac_tag'" == "f6" {
            local f   0.000001
            local grp "Top 0.0001%"
        }
        else {
            local f   0.0000001
            local grp "Top 0.00001%"
        }

        preserve
            use `forbes_src', clear
            generate n_hh = round(`pop_var' * `f' / `factor')
            keep if rank_m <= n_hh
            generate pop = n_hh * `factor'
            gcollapse (sum) value=wealth (mean) pop=pop (min) threshold=wealth, by(year month)
			replace threshold = threshold / `factor'
            generate group  = "`grp'"
            generate unit   = "`pop_type'"
            generate income = "wealth"
            append using `ultra_forbes'
            save `ultra_forbes', replace
        restore
    }
}

// Microfiles series (1976–1984) from hweal decomposition files
// Mean wealth weighted by cell population, multiplied by fixed pop = round(total_pop * f)
tempfile ultra_micro
clear
save `ultra_micro', emptyok

foreach pop_type in adult_equal_split adult_households working_age_equal_split {

    if "`pop_type'" == "adult_households"        local pop_var pop_ah
    else if "`pop_type'" == "adult_equal_split"  local pop_var pop_aes
    else                                         local pop_var pop_waes

	use if inrange(ym(year, month), `date_begin', ym(1984, 12)) using ///
		"$work/03-tabulate-wealth/tabulation-hweal-`pop_type'.dta", clear
		
    foreach frac_tag in f6 f7 {
        if "`frac_tag'" == "f6" {
            local grp  "Top 0.0001%"
            local f    0.000001
            local p_lo 9999990
        }
        else {
            local grp  "Top 0.00001%"
            local f    0.0000001
            local p_lo 9999999
        }

        preserve
            keep if p >= `p_lo'
            gcollapse (mean) hweal hweal_raw (min) threshold [iw=pop], by(year month)
            merge m:1 year month using `pops', keep(match master) nogenerate
            generate pop   = round(`pop_var' * `f')
            generate value = hweal * pop
			generate value_raw = hweal_raw * pop
            keep year month value value_raw pop threshold
            generate group  = "`grp'"
            generate unit   = "`pop_type'"
            generate income = "wealth"
            append using `ultra_micro'
            save `ultra_micro', replace
        restore
    }
}

// Splice: rescaled microfiles through December 1981, Forbes from January 1982
use `ultra_forbes', clear
keep if year == 1982 & month == 1
rename value value_f
keep group unit value_f
tempfile ref_forbes
save `ref_forbes'

use `ultra_micro', clear
keep if year == 1982 & month == 1
keep group unit value
merge 1:1 group unit using `ref_forbes', nogenerate
generate scale = value_f / value
keep group unit scale
tempfile scales
save `scales'

use `ultra_micro', clear
merge m:1 group unit using `scales', nogenerate
replace value     = value     * scale
replace threshold = threshold * scale
drop scale value_raw
keep if ym(year, month) <= ym(1982, 1)
tempfile ultra_rescaled
save `ultra_rescaled'

// Comine top wealth sources
use `ultra_rescaled', clear
generate source = "Microfiles (rescaled)"
tempfile _rescaled_src
save `_rescaled_src'

use `ultra_micro', clear
drop value_raw
generate source = "Microfiles (adjusted)"
tempfile _micro_src
save `_micro_src'

use `ultra_micro', clear
replace value = value_raw
drop value_raw
generate source = "Microfiles (raw)"
tempfile _micro_src_raw
save `_micro_src_raw'

use `ultra_forbes', clear
generate source = "Forbes"
append using `_micro_src'
append using `_micro_src_raw'
append using `_rescaled_src'
save "$work/03-build-online-database/ultra-top-sources.dta", replace

// -------------------------------------------------------------------------- //
// Prepare database
// -------------------------------------------------------------------------- //

// Build combined dataset: spliced ultra-top series + main groups + band groups
use "$work/03-build-online-database/ultra-top-sources.dta", clear
keep if source == "Microfiles (rescaled)" | ///
        (source == "Forbes" & ym(year, month) > ym(1982, 1) )
drop source
append using "$work/03-build-online-database/online-database-main.dta"
tempfile result_prebands
save `result_prebands'

// Compute ultra-top band groups
use `result_prebands', clear
keep if income == "wealth" & inlist(group, "Top 0.001%", "Top 0.0001%", "Top 0.00001%")
keep year month unit group value pop threshold
generate gstub = ""
replace gstub = "g3" if group == "Top 0.001%"
replace gstub = "g2" if group == "Top 0.0001%"
replace gstub = "g1" if group == "Top 0.00001%"
drop group
greshape wide value pop threshold, i(year month unit) j(gstub) string
generate valueBand32     = valueg3 - valueg2
generate popBand32       = popg3   - popg2
generate thresholdBand32 = thresholdg3
generate valueBand21     = valueg2 - valueg1
generate popBand21       = popg2   - popg1
generate thresholdBand21 = thresholdg2
keep year month unit valueBand32 popBand32 thresholdBand32 valueBand21 popBand21 thresholdBand21

tempfile bands
preserve
    keep year month unit valueBand32 popBand32 thresholdBand32
    rename (valueBand32 popBand32 thresholdBand32) (value pop threshold)
    generate group  = "Top 0.001%-0.0001%"
    generate income = "wealth"
    save `bands'
restore
keep year month unit valueBand21 popBand21 thresholdBand21
rename (valueBand21 popBand21 thresholdBand21) (value pop threshold)
generate group  = "Top 0.0001%-0.00001%"
generate income = "wealth"
append using `bands'
append using `result_prebands'

// Reshape
gegen pop = mean(pop), by(group year month unit) replace
greshape wide value threshold, i(group year month unit pop) j(income) string
renvars value*, predrop(5)
foreach v in factor_income pretax_income disposable_income posttax_income wealth {
    rename threshold`v' threshold_`v'
}

merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    keepusing(nipa_deflator) nogenerate keep(master match)
rename nipa_deflator deflator
sort year month unit group

// -------------------------------------------------------------------------- //
// Run sanity checks
// -------------------------------------------------------------------------- //

preserve
    keep if inlist(group, "Bottom 50%", "Middle 40%", "Top 10%-1%", ///
        "Top 1%-0.1%", "Top 0.1%-0.01%", "Top 0.01%-0.001%", "Top 0.001%")
    generate byte grank = .
    replace grank = 1 if group == "Bottom 50%"
    replace grank = 2 if group == "Middle 40%"
    replace grank = 3 if group == "Top 10%-1%"
    replace grank = 4 if group == "Top 1%-0.1%"
    replace grank = 5 if group == "Top 0.1%-0.01%"
    replace grank = 6 if group == "Top 0.01%-0.001%"
    replace grank = 7 if group == "Top 0.001%"
	
    foreach concept in factor_income pretax_income disposable_income posttax_income {
        generate double mean_c   = `concept' / pop if pop > 0 & !missing(`concept')
        sort unit year month grank
        by unit year month: generate double mean_lag = mean_c[_n-1]
        assert threshold_`concept' < mean_c  | missing(mean_c)  | missing(threshold_`concept')
        assert threshold_`concept' > mean_lag | missing(mean_lag) | missing(threshold_`concept')
        drop mean_c mean_lag
    }
restore
preserve
    keep if inlist(group, "Top 10%", "Top 1%", "Top 0.1%", "Top 0.01%", "Top 0.001%")
    generate byte grank = .
    replace grank = 1 if group == "Top 10%"
    replace grank = 2 if group == "Top 1%"
    replace grank = 3 if group == "Top 0.1%"
    replace grank = 4 if group == "Top 0.01%"
    replace grank = 5 if group == "Top 0.001%"

    foreach concept in factor_income pretax_income disposable_income posttax_income {
        generate double mean_c   = `concept' / pop if pop > 0 & !missing(`concept')
        sort unit year month grank
        by unit year month: generate double mean_lag = mean_c[_n-1]
		by unit year month: generate double thresh_lag = threshold_`concept'[_n-1]
        assert mean_c > mean_lag | missing(mean_c) | missing(mean_lag)
        assert threshold_`concept' >  thresh_lag | missing(thresh_lag) | missing(threshold_`concept')
        drop mean_c mean_lag thresh_lag
    }
restore
preserve
    keep if inlist(group, "Bottom 50%", "Middle 40%", "Top 10%-1%", ///
        "Top 1%-0.1%", "Top 0.1%-0.01%", "Top 0.01%-0.001%") | ///
        inlist(group, "Top 0.001%-0.0001%", "Top 0.0001%-0.00001%", "Top 0.00001%")
    generate byte grank = .
    replace grank = 1 if group == "Bottom 50%"
    replace grank = 2 if group == "Middle 40%"
    replace grank = 3 if group == "Top 10%-1%"
    replace grank = 4 if group == "Top 1%-0.1%"
    replace grank = 5 if group == "Top 0.1%-0.01%"
    replace grank = 6 if group == "Top 0.01%-0.001%"
    replace grank = 7 if group == "Top 0.001%-0.0001%"
    replace grank = 8 if group == "Top 0.0001%-0.00001%"
    replace grank = 9 if group == "Top 0.00001%"

    generate double mean_c   = wealth / pop if pop > 0 & !missing(wealth)
    sort unit year month grank
    by unit year month: generate double mean_lag = mean_c[_n-1]
    assert threshold_wealth < mean_c  | missing(mean_c)  | missing(threshold_wealth)
    assert threshold_wealth > mean_lag | missing(mean_lag) | missing(threshold_wealth)
restore
preserve
    keep if inlist(group, "Top 10%", "Top 1%", "Top 0.1%", "Top 0.01%") | ///
            inlist(group, "Top 0.001%", "Top 0.0001%", "Top 0.00001%")
    keep if !missing(wealth)
    generate byte grank = .
    replace grank = 1 if group == "Top 10%"
    replace grank = 2 if group == "Top 1%"
    replace grank = 3 if group == "Top 0.1%"
    replace grank = 4 if group == "Top 0.01%"
    replace grank = 5 if group == "Top 0.001%"
    replace grank = 6 if group == "Top 0.0001%"
    replace grank = 7 if group == "Top 0.00001%"

    generate double mean_c = wealth / pop if pop > 0
    sort unit year month grank
    by unit year month: generate double mean_lag   = mean_c[_n-1]
    by unit year month: generate double thresh_lag = threshold_wealth[_n-1]
    assert mean_c > mean_lag | missing(mean_c) | missing(mean_lag)
    assert threshold_wealth > thresh_lag | missing(thresh_lag) | missing(threshold_wealth)
restore

// -------------------------------------------------------------------------- //
// Export databases
// -------------------------------------------------------------------------- //

export delimited "$website/$update_id/online-database.csv", replace

// Population + deflator file
keep if group == "Total"
keep year month unit pop deflator
greshape wide pop, i(year month) j(unit) string

rename popadult_equal_split pop_adults
rename popadult_households pop_households
rename popworking_age_equal_split pop_working_age

export delimited "$website/$update_id/online-database-popul-deflator.csv", replace


// -------------------------------------------------------------------------- //
// Export wealth extrapolation base values
// -------------------------------------------------------------------------- //

local base_year  = year(dofm(`date_end'))
local base_month = month(dofm(`date_end'))

// Compute top400 wealth from microfiles
use "$work/03-build-monthly-forbes/forbes-monthly-totals.dta", clear
quietly sum forbes_all if year == `base_year' & month == `base_month', meanonly
local forbes_all_total = r(mean)
quietly sum forbes_working_age if year == `base_year' & month == `base_month', meanonly
local forbes_wa_total = r(mean)


tempfile top400_comps
clear
save `top400_comps', emptyok
foreach pop in adult_equal_split adult_households working_age_equal_split {

    use year month id weight age top400 hweal housing_tenant housing_owner equ_scorp equ_nscorp ///
        using "$microfiles/$update_id/dina-monthly-`base_year'm`base_month'.dta", clear

    if "`pop'" == "adult_households" {
        gcollapse (sum) hweal housing_tenant housing_owner equ_scorp equ_nscorp ///
                  (mean) weight (max) top400, by(id)
    }
    else if "`pop'" == "working_age_equal_split" {
        keep if age < 65
    }
    keep if top400 == 1

    // Probability-weighted component sums (consistent with decomp-file aggregation)
    gcollapse (sum) hweal housing_tenant housing_owner equ_scorp equ_nscorp ///
              (rawsum) population=weight [pw=weight]

    if "`pop'" == "working_age_equal_split" {
        local forbes_unit = `forbes_wa_total'
    }
    else {
        local forbes_unit = `forbes_all_total'
    }

    // Distribute Forbes total proportionally to raw component shares
    generate housing      = `forbes_unit' * (housing_tenant + housing_owner) / hweal
    generate equity       = `forbes_unit' * (equ_scorp + equ_nscorp) / hweal
    generate other_wealth = `forbes_unit' - housing - equity
    keep housing equity other_wealth population
    generate bracket = "top400"
    generate unit    = "`pop'"
    append using `top400_comps'
    save `top400_comps', replace
}

// Get brackets wealth from tabulation files
tempfile extrap_db
clear
save `extrap_db', emptyok
foreach pop in adult_equal_split adult_households working_age_equal_split {

    use if year == `base_year' & month == `base_month' ///
        using "$work/03-tabulate-wealth/tabulation-hweal-`pop'.dta", clear

    generate housing_sum      = (housing_tenant + housing_owner) * pop
    generate equity_sum       = (equ_scorp + equ_nscorp) * pop
    generate other_wealth_sum = hweal * pop - housing_sum - equity_sum

    generate bracket = ""
    replace bracket = "bot50"       if inrange(p, 0,       4999999)
    replace bracket = "mid40"       if inrange(p, 5000000, 8999999)
    replace bracket = "top10_1"     if inrange(p, 9000000, 9899999)
    replace bracket = "top1_01"     if inrange(p, 9900000, 9989999)
    replace bracket = "top01_001"   if inrange(p, 9990000, 9998999)
    replace bracket = "top001_0001" if inrange(p, 9999000, 9999899)
    replace bracket = "top0001"     if p >= 9999900
    drop if bracket == ""

    gcollapse (sum) housing_sum equity_sum other_wealth_sum (rawsum) population=pop, by(bracket)
    rename (housing_sum equity_sum other_wealth_sum) (housing equity other_wealth)
    generate unit = "`pop'"

    append using `extrap_db'
    save `extrap_db', replace
}

// Derive top0001_400 = top0001 − top400
use `extrap_db', clear
keep if bracket == "top0001"
drop bracket
rename (housing equity other_wealth population) (h1 e1 o1 p1)
merge 1:1 unit using `top400_comps', keepusing(housing equity other_wealth population) nogenerate

keep unit h1 e1 o1 p1 housing equity other_wealth population
generate housing_new      = h1 - housing
generate equity_new       = e1 - equity
generate other_wealth_new = o1 - other_wealth
generate population_new   = p1 - population
keep unit housing_new equity_new other_wealth_new population_new
rename (housing_new equity_new other_wealth_new population_new) ///
       (housing equity other_wealth population)
generate bracket = "top0001_400"
tempfile top0001_400
save `top0001_400'

// Assemble and export
use `extrap_db', clear
drop if bracket == "top0001"
append using `top400_comps'
append using `top0001_400'

generate byte bracket_order = .
replace bracket_order = 1 if bracket == "bot50"
replace bracket_order = 2 if bracket == "mid40"
replace bracket_order = 3 if bracket == "top10_1"
replace bracket_order = 4 if bracket == "top1_01"
replace bracket_order = 5 if bracket == "top01_001"
replace bracket_order = 6 if bracket == "top001_0001"
replace bracket_order = 7 if bracket == "top0001_400"
replace bracket_order = 8 if bracket == "top400"

sort unit bracket_order
drop bracket_order
order bracket housing equity other_wealth population unit

export delimited "$website/$update_id/wealth-extrapolation-data.csv", replace

// -------------------------------------------------------------------------- //
// Validation graphs for ultra-top wealth series
// -------------------------------------------------------------------------- //

cap mkdir "$graphs/03-build-online-database-validation"
do "$programs/03-build-online-database-validation.do"