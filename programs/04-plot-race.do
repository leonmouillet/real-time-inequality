// -------------------------------------------------------------------------- //
// Plot Black/White income and wealth gaps
// -------------------------------------------------------------------------- //

// adult_equal_split: hweal, pkinc, peinc (for race demo)
use "$work/03-tabulate-demographics/tabulation-demographics-adult_equal_split.dta", clear
keep if demo_type == "race" & inlist(group, "white", "black", "hispanic")
keep if ym(year, month) >= ym(1989, 01)
keep year month group hweal pkinc peinc
tempfile adult
save `adult'

// working_age_equal_split: wage
use "$work/03-tabulate-demographics/tabulation-demographics-working_age_equal_split.dta", clear
keep if demo_type == "race" & inlist(group, "white", "black", "hispanic")
keep if ym(year, month) >= ym(1989, 01)
keep year month group wage
merge 1:1 year month group using `adult', nogenerate

// Reshape wide by group
greshape wide hweal pkinc peinc wage, i(year month) j(group) string

generate quarter = quarter(dofm(ym(year, month)))
gcollapse (mean) hwealblack hwealwhite pkincblack pkincwhite peincblack peincwhite wageblack wagewhite, by(year quarter)

foreach c in wage hweal pkinc peinc {
    generate gap_`c' = 100*`c'black/`c'white
}
generate time = yq(year, quarter)
format time %tq

gr tw (line gap_wage time, lw(medthick) col(ebblue)), ///
    yscale(range(0 100)) ylabel(0(10)100) xtitle("") ytitle("Black average / White average (%)") ///
    legend(off) xlabel(`=yq(1990, 1)'(20)`=yq(2025, 1)') scale(1.1) ///
    text(68 `=yq(2003, 1)' "Labor income (working-age population)", col(ebblue) size(small))
graph export "$graphs/04-plot-race/black-white-gaps-1.pdf", replace

gr tw (line gap_wage  time, lw(medthick) col(ebblue)) ///
    (line gap_hweal time, lw(medthick) col(purple)), ///
    yscale(range(0 100)) ylabel(0(10)100) xtitle("") ytitle("Black average / White average (%)") ///
    legend(off) xlabel(`=yq(1990, 1)'(20)`=yq(2025, 1)') scale(1.1) ///
    text(68 `=yq(2003, 1)' "Labor income (working-age population)", col(ebblue) size(small)) ///
    text(30 `=yq(2000, 1)' "Wealth", col(purple) size(small))
graph export "$graphs/04-plot-race/black-white-gaps-2.pdf", replace

gr tw (line gap_wage  time, lw(medthick) col(ebblue)) ///
    (line gap_hweal time, lw(medthick) col(purple)) ///
    (line gap_pkinc time, lw(medthick) col(orange)), ///
    yscale(range(0 100)) ylabel(0(10)100) xtitle("") ytitle("Black average / White average (%)") ///
    legend(off) xlabel(`=yq(1990, 1)'(20)`=yq(2025, 1)') scale(1.1) ///
    text(68 `=yq(2003, 1)' "Labor income (working-age population)", col(ebblue) size(small)) ///
    text(19 `=yq(1996, 1)' "Pretax capital income", col(orange) size(small)) ///
    text(30 `=yq(2000, 1)' "Wealth", col(purple) size(small))
graph export "$graphs/04-plot-race/black-white-gaps-3.pdf", replace

gr tw (line gap_wage  time, lw(medthick) col(ebblue)) ///
    (line gap_peinc time, lw(medthick) col(cranberry)) ///
    (line gap_hweal time, lw(medthick) col(purple)) ///
    (line gap_pkinc time, lw(medthick) col(orange)), ///
    yscale(range(0 100)) ylabel(0(10)100) xtitle("") ytitle("Black average / White average (%)") ///
    legend(off) xlabel(`=yq(1990, 1)'(20)`=yq(2025, 1)') scale(1.1) ///
    text(68 `=yq(2003, 1)' "Labor income (working-age population)", col(ebblue) size(small)) ///
    text(47 `=yq(2006, 1)' "Pretax income", col(cranberry) size(small)) ///
    text(19 `=yq(1996, 1)' "Pretax capital income", col(orange) size(small)) ///
    text(30 `=yq(2000, 1)' "Wealth", col(purple) size(small))
graph export "$graphs/04-plot-race/black-white-gaps-4.pdf", replace


// -------------------------------------------------------------------------- //
// Plot average peinc by race during recessions (indexed)
// -------------------------------------------------------------------------- //

use "$work/03-tabulate-demographics/tabulation-demographics-adult_equal_split.dta", clear
keep if demo_type == "race" & inlist(group, "white", "black", "hispanic")
keep if ym(year, month) >= ym(1989, 01) & ym(year, month) <= ym(2022, 06)
keep year month group peinc

merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    nogenerate keep(match) keepusing(nipa_deflator)
replace peinc = peinc/nipa_deflator
drop nipa_deflator

generate time = yq(year, quarter(dofm(ym(year, month))))
format time %tq
gcollapse (mean) peinc, by(time group)

generate year    = year(dofq(time))
generate quarter = quarter(dofq(time))

gegen ref = mean(peinc) if year == 2007, by(group)
gegen ref = max(ref), by(group) replace
generate peinc_base2006 = 100*peinc/ref
drop ref

generate cycle = ""
replace cycle = "Great Recession (2007-2016)" if inrange(year, 2007, 2016)
replace cycle = "COVID Recession (2020-2022)"  if inrange(year, 2020, 2022)
drop if cycle == ""

encode group, generate(race_num)
sort group cycle time
by group cycle: generate ref = peinc[1]
generate peinc_cycles = 100*peinc/ref

gr tw ///
    (con peinc_cycles time if group == "white",    lw(medthick) col(ebblue)   msym(Oh) msize(small)) ///
    (con peinc_cycles time if group == "black",    lw(medthick) col(cranberry) msym(Sh) msize(small)) ///
    (con peinc_cycles time if group == "hispanic", lw(medthick) col(green)    msym(Dh) msize(small)), ///
    by(cycle, xrescale note("") scale(1.3) imargin(0 10 0 0)) ///
    xtitle("") ytitle("Pretax income" "(constant USD, pre-recession peak = 100)") ///
    ylabel(90(5)110) xlabel(, labsize(small)) ysize(3) xsize(6) ///
    legend(rows(1) label(1 "Non-hispanic whites") label(2 "Blacks") label(3 "Hispanics"))
graph export "$graphs/04-plot-race/index-peinc-race-cycles.pdf", replace


// -------------------------------------------------------------------------- //
// Plot Black/White representation in top income/wealth brackets
// -------------------------------------------------------------------------- //

local date_begin_repr = ym(1989, 01)
local date_end_repr   = $date_end

tempfile race_repr
clear
save `race_repr', replace emptyok

foreach t of numlist `date_begin_repr' / `date_end_repr' {
    noisily di "* " %tm = `t'
    local year  = year(dofm(`t'))
    local month = month(dofm(`t'))

    foreach concept in flemp peinc hweal {

        use id weight race `concept' using "$microfiles/$update_id/dina-monthly-`year'm`month'.dta", clear

        if "`concept'" == "flemp" drop if `concept' < 0

        sort `concept'
        generate rank = sum(weight)
        replace rank = (rank - weight/2)/rank[_N]

        generate bracket = ""
        replace bracket = "bot90" if inrange(rank, 0, 0.90)
        replace bracket = "top10" if rank > 0.90
        drop if bracket == ""

        generate black = cond(race == 2, 1, 0)
        generate white = cond(race == 1, 1, 0)
        generate other = (!black & !white)

        gcollapse (mean) black white other [pw=weight], by(bracket)
        generate concept = "`concept'"
        generate year    = `year'
        generate month   = `month'

        append using `race_repr'
        local saved 0
        while !`saved' {
            cap save `race_repr', replace
            if (_rc == 0) {
                local saved 1
            }
            else {
                sleep 2000
            }
        }
    }
}

use `race_repr', clear
keep if ym(year, month) >= ym(1989, 01)

reshape wide black white other, i(year month concept) j(bracket) string

foreach v in black white other {
    generate `v'_total = 0.9*`v'bot90 + 0.1*`v'top10
    replace `v'bot90   = 100*`v'bot90
    replace `v'top10   = 100*`v'top10
    replace `v'_total  = 100*`v'_total
}

generate quarter = quarter(dofm(ym(year, month)))
collapse (mean) blacktop10 black_total, by(year quarter concept)
generate time = yq(year, quarter)
format time %tq

gr tw ///
    (line blacktop10 time if concept == "flemp"  & year >= 1989, col(ebblue)  lw(medthick) msym(Sh) msize(small)) ///
    (line blacktop10 time if concept == "peinc"  & year >= 1989, col(cranberry) lw(medthick) msym(Oh) msize(small)) ///
    (line blacktop10 black_total time if concept == "hweal" & year >= 1989, col(dkgreen black) lw(medthick..) msym(Dh O) msize(small..)), ///
    yscale(range(0 12)) ylabel(0(2)12) ytitle("Share of black population (%)") ///
    xlabel(`=yq(1989, 01)'(24)`=yq(2026, 01)') xtitle("") legend(off) ///
    text(11   `=yq(2000, 02)' "Full population",        col(black)    size(small)) ///
    text(7.0  `=yq(2000, 02)' "Top 10% wage earners",   col(ebblue)   size(small)) ///
    text(4.5  `=yq(1994, 02)' "Top 10% pretax income",  col(cranberry) size(small)) ///
    text(3.6  `=yq(2007, 02)' "Top 10% wealth",         col(dkgreen)  size(small))
graph export "$graphs/04-plot-race/black-white-gap-top10.pdf", replace
