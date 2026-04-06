// -------------------------------------------------------------------------- //
// Build the online database for demographics groups
// -------------------------------------------------------------------------- //

local date_begin = $date_begin
local date_end   = $date_end

// adult_individual: factor_income, pretax_income, disposable_income, posttax_income, wealth
use "$work/03-tabulate-demographics/tabulation-demographics-adult_individual.dta", clear
keep year month group demo_type weight princ peinc dispo poinc hweal
rename (princ peinc dispo poinc hweal) ///
       (factor_income pretax_income disposable_income posttax_income wealth)
generate unit = "adult_individual"
tempfile f1
save `f1'

// working_age_individual: labor_income
use "$work/03-tabulate-demographics/tabulation-demographics-working_age_individual.dta", clear
keep year month group demo_type weight wage
rename wage labor_income
generate unit = "working_age_individual"
tempfile f2
save `f2'

// adult_equal_split: factor_income, pretax_income, disposable_income, posttax_income, wealth
use "$work/03-tabulate-demographics/tabulation-demographics-adult_equal_split.dta", clear
keep year month group demo_type weight princ peinc dispo poinc hweal
rename (princ peinc dispo poinc hweal) ///
       (factor_income pretax_income disposable_income posttax_income wealth)
generate unit = "adult_equal_split"
tempfile f3
save `f3'

// working_age_equal_split: labor_income
use "$work/03-tabulate-demographics/tabulation-demographics-working_age_equal_split.dta", clear
keep year month group demo_type weight wage
rename wage labor_income
generate unit = "working_age_equal_split"

append using `f1'
append using `f2'
append using `f3'

keep if inrange(ym(year, month), `date_begin', `date_end')
drop if demo_type == "educ"

replace group = "White"          if group == "white"
replace group = "Black"          if group == "black"
replace group = "Hispanic"       if group == "hispanic"
replace group = "Men"            if group == "men"
replace group = "Women"          if group == "women"
*replace group = "No college"     if group == "nocollege"
*replace group = "College"        if group == "college"
replace group = "White men"      if group == "white_men"
replace group = "White women"    if group == "white_women"
replace group = "Black men"      if group == "black_men"
replace group = "Black women"    if group == "black_women"
replace group = "Hispanic men"   if group == "hispanic_men"
replace group = "Hispanic women" if group == "hispanic_women"

tempfile base
save `base'

// Compute "Total" group as weighted average within each demo_type × unit
gcollapse (mean) factor_income pretax_income disposable_income posttax_income wealth labor_income ///
          (rawsum) weight [pw=weight], by(year month demo_type unit)
generate group = "Total"
append using `base'

// Convert means to totals (mean × population)
foreach c in factor_income pretax_income disposable_income posttax_income wealth labor_income {
    replace `c' = `c' * weight
}
rename weight population

// Add deflator
merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    keepusing(nipa_deflator) nogenerate keep(master match)
rename nipa_deflator deflator

// Aggregate monthly data to quarterly
gen quarter = ceil(month / 3)
replace month = quarter * 3 - 2  // the website expects a month variable, even though data is quarterly
drop quarter
gcollapse (mean) factor_income pretax_income disposable_income posttax_income wealth ///
          labor_income population deflator, ///
          by(year month unit demo_type group)

order year month unit demo_type group ///
    factor_income pretax_income disposable_income posttax_income wealth ///
    population deflator
sort year month demo_type group

export delimited "$website/$update_id/online-database-demographics.csv", replace
