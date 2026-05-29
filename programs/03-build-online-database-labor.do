// -------------------------------------------------------------------------- //
// Build the online database for labor income
// -------------------------------------------------------------------------- //

use "$work/03-tabulate-wages/tabulation-wages-working_age_equal_split.dta", clear
append using "$work/03-tabulate-wages/tabulation-wages-working_age_individual.dta"

// Compute q4
preserve
    keep if inlist(bracket, "top25_10", "top10_1", "top1")
    gcollapse (mean) wage employed (min) threshold (rawsum) pop [pw=pop], by(year month group unit demo_type)
    generate bracket = "q4"
    tempfile q4
    save `q4'
restore
append using `q4'

// Compute top10
preserve
    keep if inlist(bracket, "top10_1", "top1")
    gcollapse (mean) wage employed (min) threshold (rawsum) pop [pw=pop], by(year month group unit demo_type)
    generate bracket = "top10"
    tempfile top10
    save `top10'
restore
append using `top10'

keep if demo_type == "overall"
drop group

generate value = wage * pop

// Rename brackets
replace bracket = "1st Quartile"  if bracket == "q1"
replace bracket = "2nd Quartile"  if bracket == "q2"
replace bracket = "3rd Quartile"  if bracket == "q3"
replace bracket = "4th Quartile"  if bracket == "q4"
replace bracket = "Top 10%"       if bracket == "top10"
replace bracket = "Top 1%"        if bracket == "top1"
replace bracket = "Top 10%-1%"    if bracket == "top10_1"
replace bracket = "Top 25%-10%"   if bracket == "top25_10"
replace bracket = "Total" 		  if bracket == "overall"
rename bracket group

// -------------------------------------------------------------------------- //
// Employment rate figure
// -------------------------------------------------------------------------- //

generate time = ym(year, month)
format time %tm
replace employed = 100*employed

/*
gr tw (line employed time if unit == "working_age_equal_split" & group == "1st Quartile", col(ebblue) lw(medthick)) ///
    (line employed time if unit == "working_age_individual"   & group == "1st Quartile", col(cranberry) lw(medthick)), ///
    xtitle("") ytitle("Employed (%)") yscale(range(0 100)) ylabel(0(10)100) ///
    xlabel(`=ym(1976, 01)'(48)`=ym(2024, 01)', alternate) legend(off) ///
    text(90 `=ym(1990, 01)' "Working-age adults" "(equal split among married)", col(ebblue)) ///
    text(40 `=ym(2002, 01)' "Working-age adults" "(individualized)", col(cranberry)) ///
    subtitle("Employment Rate of Bottom 25% Working-Age Adults") ///
    note("Our labor income statistics include all working-age adults including non-workers. All non-workers have zero labor income and" ///
        "hence are in the bottom 25%. This figure displays the employment rate of bottom 25% working-age adults (defined as having" ///
        "positive labor income). In the series working-age adults (individualized), direct individual earnings are used. The secular" ///
        "upper trend reflects the growing female labor force participation. In the series working-age adults (equal split among" ///
        "married), earnings are split equally within married couples. This eliminates the secular trend and makes such series more" ///
        "meaningful for long-term inequality comparisons.", size(vsmall))
graph export "$graphs/03-build-online-database-labor/employment-first-quartile.pdf", replace
*/

// -------------------------------------------------------------------------- //
// Fix glitch and export
// -------------------------------------------------------------------------- //

// Fix glitch in 1985/12
replace value = . if group == "Top 1%" & time == ym(1985, 12)
sort group unit time
by group unit: ipolate value time, gen(i)
replace value = i if group == "Top 1%" & time == ym(1985, 12)
drop i

// Harmonize pop across brackets
gegen pop = mean(pop), by(year month unit group) replace

// Finalize pop by bracket share
replace pop = 0.25*pop    if group == "1st Quartile"
replace pop = 0.25*pop    if group == "2nd Quartile"
replace pop = 0.25*pop    if group == "3rd Quartile"
replace pop = 0.25*pop    if group == "4th Quartile"
replace pop = 0.15*pop    if group == "Top 25%-10%"
replace pop = 0.10*pop    if group == "Top 10%"
replace pop = 0.01*pop    if group == "Top 1%"
replace pop = 0.09*pop    if group == "Top 10%-1%"
gegen pop = mean(pop), by(group year month unit) replace

generate income = "labor_income"
greshape wide value threshold, i(group year month unit pop) j(income) string
renvars value*, predrop(5)
rename thresholdlabor_income threshold_labor_income

drop employed

sort unit group year month
export delimited "$website/$update_id/online-database-labor.csv", replace
