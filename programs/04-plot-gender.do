// -------------------------------------------------------------------------- //
// Plot the evolution of gender gaps
// -------------------------------------------------------------------------- //

local date_begin = ym(2006, 01)
local date_end   = ym(2025, 08)

// -------------------------------------------------------------------------- //
// Build gender × income data
// -------------------------------------------------------------------------- //

tempfile gender_brackets
clear
save `gender_brackets', replace emptyok

foreach t of numlist `date_begin' / `date_end' {
    quietly {
        local year  = year(dofm(`t'))
        local month = month(dofm(`t'))

        noisily di "* " %tm = `t'

        use year month weight sex peinc using ///
            "$microfiles/$update_id/dina-monthly-`year'm`month'.dta", clear

        generate group = ""
        replace group = "men"   if sex == 1
        replace group = "women" if sex == 2

        // Rank within group
        hashsort group peinc
        by group: generate rank = sum(weight)
        by group: replace rank = (rank - weight/2)/rank[_N]

        // Coarse brackets within group
        generate bracket = ""
        replace bracket = "bot50" if inrange(rank, 0.00, 0.50)
        replace bracket = "mid40" if inrange(rank, 0.50, 0.90)
        replace bracket = "next9" if inrange(rank, 0.90, 0.99)
        replace bracket = "top1"  if rank > 0.99
        drop if bracket == ""

        expand 2, generate(dup)
        replace bracket = "overall" if dup == 1

        gcollapse (mean) mean_income=peinc (rawsum) weight [pw=weight], by(group bracket)

        generate year      = `year'
        generate month     = `month'
        generate demo_type = "gender"
        generate concept   = "peinc"

        append using `gender_brackets'
        local saved = 0
        while !`saved' {
            cap save `gender_brackets', replace
            if (_rc == 0) local saved = 1
            else sleep 2000
        }
    }
}

use `gender_brackets', clear

keep if demo_type == "gender"
keep if concept   == "peinc"
keep if inlist(group, "men", "women")
keep if ym(year, month) >= `date_begin'
keep if ym(year, month) <= `date_end'

// Combine next9 and top1 into top10
preserve
    keep if inlist(bracket, "next9", "top1")
    gcollapse (mean) mean_income [pw=weight], by(year month group demo_type concept)
    generate bracket = "top10"
    tempfile top10
    save `top10'
restore
keep if inlist(bracket, "bot50", "mid40", "overall")
append using `top10'

// Correct for inflation
merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    nogenerate keep(master match) keepusing(nipa_deflator)
replace mean_income = mean_income/nipa_deflator
drop nipa_deflator

generate time = ym(year, month)
format time %tm

tempfile gender_data
save `gender_data'

// -------------------------------------------------------------------------- //
// Average pretax income by gender
// -------------------------------------------------------------------------- //

use `gender_data', clear
keep if bracket == "overall"

generate quarter = quarter(dofm(time))
collapse (mean) mean_income, by(year quarter group)
generate time = yq(year, quarter)
format time %tq

gr tw ///
    (line mean_income time if group == "men",   lw(medthick) col(ebblue)   msym(Oh) msize(small)) ///
    (line mean_income time if group == "women", lw(medthick) col(cranberry) msym(Sh) msize(small)), ///
    xtitle("") ytitle("Annualized pretax income" "(constant USD)") ylabel(0(1e4)1e5, format(%9.0gc)) ///
    legend(rows(1) label(1 "Males") label(2 "Females")) ///
    title("Average Pretax Income") subtitle("by gender")
graph export "$graphs/04-plot-gender/avg-peinc-gender.pdf", replace

// Index to 2006
sort group time
by group: generate ref = mean_income[1]
generate peinc_base2006 = 100*mean_income/ref
drop ref

gr tw ///
    (line peinc_base2006 time if group == "men",   lw(medthick) col(ebblue)   msym(Oh) msize(small)) ///
    (line peinc_base2006 time if group == "women", lw(medthick) col(cranberry) msym(Sh) msize(small)), ///
    xtitle("") ytitle("Pretax income" "(constant USD, 2006 = 100)") ylabel(90(5)120) ///
    legend(rows(1) label(1 "Males") label(2 "Females")) ///
    title("Average Pretax Income") subtitle("by gender")
graph export "$graphs/04-plot-gender/index-peinc-gender.pdf", replace

// Recession cycles
generate cycle = ""
replace cycle = "Great Recession (2007-2016)" if inrange(year, 2007, 2016)
replace cycle = "Covid Recession (2020-2021)"  if inrange(yq(year, quarter), yq(2020, 01), yq(2022, 02))
drop if cycle == ""

sort group cycle time
by group cycle: generate ref = cond(cycle == "Great Recession (2007-2016)", mean_income[4], mean_income[1])
generate peinc_cycles = 100*mean_income/ref

gr tw ///
    (con peinc_cycles time if group == "men",   lw(medthick) col(ebblue)   msym(Oh) msize(small)) ///
    (con peinc_cycles time if group == "women", lw(medthick) col(cranberry) msym(Sh) msize(small)), ///
    by(cycle, xrescale note("") scale(1.3) imargin(0 10 0 0)) ///
    xtitle("") ytitle("Pretax income" "(constant USD, pre-recession peak = 100)") ///
    xlabel(, labsize(small)) legend(rows(1) label(1 "Men") label(2 "Women")) ysize(3) xsize(6)
graph export "$graphs/04-plot-gender/index-peinc-gender-cycles.pdf", replace

// -------------------------------------------------------------------------- //
// Average pretax income by gender × bracket
// -------------------------------------------------------------------------- //

use `gender_data', clear
keep if inlist(bracket, "bot50", "top10")

gr tw ///
    (line mean_income time if group == "men"   & bracket == "bot50", lw(medthick) col(ebblue)   msym(Oh) msize(small)) ///
    (line mean_income time if group == "women" & bracket == "bot50", lw(medthick) col(cranberry) msym(Sh) msize(small)), ///
    xtitle("") ytitle("Annualized pretax income" "(constant USD)") ylabel(0(5e3)2.5e4, format(%9.0gc)) ///
    legend(rows(1) label(1 "Males") label(2 "Females")) ///
    title("Average Pretax Income") subtitle("by gender, bottom 50%")
graph export "$graphs/04-plot-gender/bot50-peinc-gender.pdf", replace

gr tw ///
    (line mean_income time if group == "men"   & bracket == "top10", lw(medthick) col(ebblue)   msym(Oh) msize(small)) ///
    (line mean_income time if group == "women" & bracket == "top10", lw(medthick) col(cranberry) msym(Sh) msize(small)), ///
    xtitle("") ytitle("Annualized pretax income" "(constant USD)") ylabel(0(5e4)5e5, format(%9.0gc)) ///
    legend(rows(1) label(1 "Males") label(2 "Females")) ///
    title("Average Pretax Income") subtitle("by gender, top 10%")
graph export "$graphs/04-plot-gender/top10-peinc-gender.pdf", replace

// Index to 2006 by bracket
sort bracket group time
by bracket group: generate ref = (mean_income[1] + mean_income[2] + mean_income[3] + mean_income[4])/4
generate peinc_base2006 = 100*mean_income/ref
drop ref

gr tw ///
    (line peinc_base2006 time if group == "men"   & bracket == "bot50", lw(medthick) col(ebblue)   msym(Oh) msize(small)) ///
    (line peinc_base2006 time if group == "women" & bracket == "bot50", lw(medthick) col(cranberry) msym(Sh) msize(small)), ///
    xtitle("") ytitle("Pretax income" "(constant USD, 2006 = 100)") ylabel(85(5)140) ///
    legend(rows(1) label(1 "Males") label(2 "Females")) ///
    title("Average Pretax Income") subtitle("by gender, bottom 50%")
graph export "$graphs/04-plot-gender/index-bot50-peinc-gender.pdf", replace

gr tw ///
    (line peinc_base2006 time if group == "men"   & bracket == "top10", lw(medthick) col(ebblue)   msym(Oh) msize(small)) ///
    (line peinc_base2006 time if group == "women" & bracket == "top10", lw(medthick) col(cranberry) msym(Sh) msize(small)), ///
    xtitle("") ytitle("Pretax income" "(constant USD, 2006 = 100)") ylabel(85(5)125) ///
    legend(rows(1) label(1 "Males") label(2 "Females")) ///
    title("Average Pretax Income") subtitle("by gender, top 10%")
graph export "$graphs/04-plot-gender/index-top10-peinc-gender.pdf", replace

// Recession cycles by bracket
generate cycle = ""
replace cycle = "Great Recession (2007-2016)" if inrange(year(dofm(time)), 2007, 2016)
replace cycle = "COVID Recession (2020-2021)"  if inrange(year(dofm(time)), 2020, 2022)
drop if cycle == ""

sort bracket group cycle time
by bracket group cycle: generate ref = cond(cycle == "Great Recession (2007-2016)", ///
    (mean_income[10] + mean_income[11] + mean_income[12])/3, (mean_income[1] + mean_income[2])/2)
generate peinc_cycles = 100*mean_income/ref

gr tw ///
    (line peinc_cycles time if group == "men"   & bracket == "bot50", lw(medthick) col(ebblue)   msym(Oh) msize(small)) ///
    (line peinc_cycles time if group == "women" & bracket == "bot50", lw(medthick) col(cranberry) msym(Sh) msize(small)), ///
    by(cycle, xrescale title("Average Pretax Income") subtitle("by gender, bottom 50%") note("")) ///
    xtitle("") ytitle("Pretax income" "(constant USD, pre-recession peak = 100)") ylabel(75(5)110) ///
    legend(rows(1) label(1 "Males") label(2 "Females"))
graph export "$graphs/04-plot-gender/index-bot50-peinc-gender-cycles.pdf", replace

gr tw ///
    (line peinc_cycles time if group == "men"   & bracket == "top10", lw(medthick) col(ebblue)   msym(Oh) msize(small)) ///
    (line peinc_cycles time if group == "women" & bracket == "top10", lw(medthick) col(cranberry) msym(Sh) msize(small)), ///
    by(cycle, xrescale title("Average Pretax Income") subtitle("by gender, top 10%") note("")) ///
    xtitle("") ytitle("Pretax income" "(constant USD, pre-recession peak = 100)") ylabel(80(5)110) ///
    legend(rows(1) label(1 "Males") label(2 "Females"))
graph export "$graphs/04-plot-gender/index-top10-peinc-gender-cycles.pdf", replace
