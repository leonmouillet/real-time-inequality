// -------------------------------------------------------------------------- //
// Plot college premium
// -------------------------------------------------------------------------- //

local date_begin = ym(1989, 01)
local date_end   = ym(2025, 08)

// adult_equal_split: hweal, pkinc, peinc
use "$work/03-tabulate-demographics/tabulation-demographics-adult_equal_split.dta", clear
keep if demo_type == "educ" & inlist(group, "nocollege", "college")
keep if ym(year, month) >= `date_begin' & ym(year, month) <= `date_end'
keep year month group hweal pkinc peinc
tempfile adult
save `adult'

// working_age_equal_split: wage
use "$work/03-tabulate-demographics/tabulation-demographics-working_age_equal_split.dta", clear
keep if demo_type == "educ" & inlist(group, "nocollege", "college")
keep if ym(year, month) >= `date_begin' & ym(year, month) <= `date_end'
keep year month group wage
merge 1:1 year month group using `adult', nogenerate

// Reshape wide by group
greshape wide hweal pkinc peinc wage, i(year month) j(group) string

generate quarter = quarter(dofm(ym(year, month)))
gcollapse (mean) hwealcollege hwealnocollege pkinccollege pkincnocollege ///
                 peinccollege peincnocollege wagecollege wagenocollege, by(year quarter)

foreach c in hweal pkinc peinc wage {
    generate gap_`c' = 100*(`c'college/`c'nocollege - 1)
}
generate time = yq(year, quarter)
format time %tq

gr tw (line gap_wage time, lw(medthick) col(ebblue)), ///
    yscale(range(0 250)) ylabel(0(50)250) xtitle("") ///
    ytitle("College premium" "(% increase between no college and some college)") ///
    legend(off) xlabel(`=yq(1990, 1)'(20)`=yq(2025, 1)') scale(1.1) ///
    text(90 `=yq(2017, 1)' "Labor income" "(working-age population)", col(ebblue) size(small))
graph export "$graphs/04-plot-education/college-premium-1.pdf", replace

gr tw (line gap_wage  time, lw(medthick) col(ebblue)) ///
    (line gap_hweal time, lw(medthick) col(purple)), ///
    yscale(range(0 250)) ylabel(0(50)250) xtitle("") ///
    ytitle("College premium" "(% increase between no college and some college)") ///
    legend(off) xlabel(`=yq(1990, 1)'(20)`=yq(2025, 1)') scale(1.1) ///
    text(90  `=yq(2017, 1)' "Labor income" "(working-age population)", col(ebblue) size(small)) ///
    text(195 `=yq(2019, 1)' "Wealth", col(purple) size(small))
graph export "$graphs/04-plot-education/college-premium-2.pdf", replace

gr tw (line gap_wage  time, lw(medthick) col(ebblue)) ///
    (line gap_hweal time, lw(medthick) col(purple)) ///
    (line gap_pkinc time, lw(medthick) col(orange)), ///
    yscale(range(0 250)) ylabel(0(50)250) xtitle("") ///
    ytitle("College premium" "(% increase between no college and some college)") ///
    legend(off) xlabel(`=yq(1990, 1)'(20)`=yq(2025, 1)') scale(1.1) ///
    text(90  `=yq(2017, 1)' "Labor income" "(working-age population)", col(ebblue) size(small)) ///
    text(210 `=yq(2009, 1)' "Pretax capital income", col(orange) size(small)) ///
    text(195 `=yq(2019, 1)' "Wealth", col(purple) size(small))
graph export "$graphs/04-plot-education/college-premium-3.pdf", replace

gr tw (line gap_wage  time, lw(medthick) col(ebblue)) ///
    (line gap_peinc time, lw(medthick) col(cranberry)) ///
    (line gap_hweal time, lw(medthick) col(purple)) ///
    (line gap_pkinc time, lw(medthick) col(orange)), ///
    yscale(range(0 250)) ylabel(0(50)250) xtitle("") ///
    ytitle("College premium" "(% increase between no college and some college)") ///
    legend(off) xlabel(`=yq(1990, 1)'(20)`=yq(2025, 1)') scale(1.1) ///
    text(90  `=yq(2017, 1)' "Labor income" "(working-age population)", col(ebblue) size(small)) ///
    text(130 `=yq(2010, 1)' "Pretax income", col(cranberry) size(small)) ///
    text(210 `=yq(2009, 1)' "Pretax capital income", col(orange) size(small)) ///
    text(195 `=yq(2019, 1)' "Wealth", col(purple) size(small))
graph export "$graphs/04-plot-education/college-premium-4.pdf", replace
