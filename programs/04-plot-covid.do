// -------------------------------------------------------------------------- //
// Make graphs for COVID analysis
// -------------------------------------------------------------------------- //

// -------------------------------------------------------------------------- //
// Plot dynamics and decomposition of disposable income for the bottom 50%
// -------------------------------------------------------------------------- //

// Unit: working age adults equal split, ranked by individual factor income (pre-split)
// Plot: full decomposition of disposable income, starting from factor income
// Ad hoc tabulation procedure: we need to start from monthly microfiles

local vars_a princ poinc govin uiben penben contrib vet othcash covidrelief ///
    covidsub othercontrib taxes estatetax corptax prodtax medicare medicaid ///
    otherkin colexp prisupgov

tempfile tab_bot50
clear
save `tab_bot50', emptyok

forval t = `=ym(2019,6)' / `=ym(2023,3)' {
    local y = year(dofm(`t'))
    local m = month(dofm(`t'))

    use year month id weight age `vars_a' using ///
        "$microfiles/$update_id/dina-monthly-`y'm`m'.dta", clear

    // Save individual (pre-split) factor income for ranking
    generate princ_indiv = princ

    // Equal-split all display variables (NOT princ_indiv)
    foreach v of varlist `vars_a' {
        gegen `v' = mean(`v'), by(id) replace
    }

    // Keep working age
    keep if age < 65

    // Rank by individual princ, keep bottom 50%
    gsort princ_indiv
    generate cum_w = sum(weight)
    local total_w = cum_w[_N]
    keep if cum_w <= `total_w' * 0.50

    gcollapse (mean) `vars_a' [pw=weight], by(year month)
    generate bracket = "Bottom 50%"

    append using `tab_bot50'
    save `tab_bot50', replace
}

// Merge deflator and deflate
use `tab_bot50', clear
merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    nogenerate keepusing(nipa_deflator) keep(master match)
foreach v of varlist `vars_a' {
    replace `v' = `v'/12/nipa_deflator
}
generate time = ym(year, month)
format time %tm
save `tab_bot50', replace


use `tab_bot50', clear
keep if bracket == "Bottom 50%"

generate covidsub_min = princ
generate covidsub_max = princ + covidsub

generate uiben_min = covidsub_max
generate uiben_max = uiben_min + uiben

generate penben_min = uiben_max
generate penben_max = penben_min + penben - contrib

generate taxben_min = penben_max
generate taxben_max = taxben_min + vet + othcash - taxes - estatetax - corptax - othercontrib

generate covidrelief_min = taxben_max
generate covidrelief_max = covidrelief_min + covidrelief

generate medi_min = covidrelief_max
generate medi_max = medi_min + medicare + medicaid

generate oth_min = medi_max
generate oth_max = oth_min + otherkin + colexp

generate deficit_min = princ
generate deficit_max = princ + prisupgov - prodtax + govin
replace deficit_max = 0 if deficit_max < 0

// Start from factor national income
gr tw (con princ time, lw(medthick) col(black) msym(Oh)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "{bf:Factor national income}" "{it:(matching national income)}") ///
        order(1 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step1.pdf", replace

// + PPP
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "{bf:Factor national income}" "{it:(matching national income)}") ///
        order(1 2 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step2.pdf", replace

// = subsidized factor income
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(3 "{bf:Subsidized factor national income}") ///
        order(3 1 2 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step3.pdf", replace

// + UI
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (rarea uiben_min uiben_max time, col(cranberry*1.2) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    xtitle("") xsize(6) ysize(3) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "Unemployment insurance benefits") ///
        label(3 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(4 "{bf:Subsidized factor national income}") ///
        order(2 4 1 3 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step4.pdf", replace

// + other social insurance
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (rarea uiben_min uiben_max time, col(cranberry*1.2) lw(none)) ///
    (rarea penben_min penben_max time, col(cranberry*0.8) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "Unemployment insurance benefits") ///
        label(3 "Other benefits (net)" "{it:(pensions & DI, minus contributions)}") ///
        label(4 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(5 "{bf:Subsidized factor national income}") ///
        order(3 2 5 1 4 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step5.pdf", replace

// = pretax income
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (rarea uiben_min uiben_max time, col(cranberry*1.2) lw(none)) ///
    (rarea penben_min penben_max time, col(cranberry*0.8) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)) ///
    (con penben_max time, lw(medthick) col(black) msym(Th)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "Unemployment insurance benefits") ///
        label(3 "Other benefits (net)" "{it:(pensions & DI, minus contributions)}") ///
        label(4 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(5 "{bf:Subsidized factor national income}") ///
        label(6 "{bf:Subsidized pretax national income}") ///
        order(6 3 2 5 1 4 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step6.pdf", replace

// + regular cash transfers
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (rarea uiben_min uiben_max time, col(cranberry*1.2) lw(none)) ///
    (rarea penben_min penben_max time, col(cranberry*0.8) lw(none)) ///
    (rarea taxben_min taxben_max time, col(green*0.8) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)) ///
    (con penben_max time, lw(medthick) col(black) msym(Th)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "Unemployment insurance benefits") ///
        label(3 "Other benefits (net)" "{it:(pensions & DI, minus contributions)}") ///
        label(4 "Regular cash transfers" "{it:(net of taxes)}") ///
        label(5 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(6 "{bf:Subsidized factor national income}") ///
        label(7 "{bf:Subsidized pretax national income}") ///
        order(4 7 3 2 6 1 5 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step7.pdf", replace

// + COVID relief
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (rarea uiben_min uiben_max time, col(cranberry*1.2) lw(none)) ///
    (rarea penben_min penben_max time, col(cranberry*0.8) lw(none)) ///
    (rarea taxben_min taxben_max time, col(green*0.8) lw(none)) ///
    (rarea covidrelief_min covidrelief_max time, col(green*1.2) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)) ///
    (con penben_max time, lw(medthick) col(black) msym(Th)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "Unemployment insurance benefits") ///
        label(3 "Other benefits (net)" "{it:(pensions & DI, minus contributions)}") ///
        label(4 "Regular cash transfers" "{it:(net of taxes)}") ///
        label(5 "COVID stimulus checks") ///
        label(6 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(7 "{bf:Subsidized factor national income}") ///
        label(8 "{bf:Subsidized pretax national income}") ///
        order(5 4 8 3 2 7 1 6 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step8.pdf", replace

// = post-tax disposable
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (rarea uiben_min uiben_max time, col(cranberry*1.2) lw(none)) ///
    (rarea penben_min penben_max time, col(cranberry*0.8) lw(none)) ///
    (rarea taxben_min taxben_max time, col(green*0.8) lw(none)) ///
    (rarea covidrelief_min covidrelief_max time, col(green*1.2) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)) ///
    (con penben_max time, lw(medthick) col(black) msym(Th)) ///
    (con covidrelief_max time, lw(medthick) col(black) msym(Dh)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "Unemployment insurance benefits") ///
        label(3 "Other benefits (net)" "{it:(pensions & DI, minus contributions)}") ///
        label(4 "Regular cash transfers" "{it:(net of taxes)}") ///
        label(5 "COVID stimulus checks") ///
        label(6 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(7 "{bf:Subsidized factor national income}") ///
        label(8 "{bf:Subsidized pretax national income}") ///
        label(9 "{bf:Post-tax disposable income}") ///
        order(9 5 4 8 3 2 7 1 6 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step9.pdf", replace

// + medicare/medicaid
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (rarea uiben_min uiben_max time, col(cranberry*1.2) lw(none)) ///
    (rarea penben_min penben_max time, col(cranberry*0.8) lw(none)) ///
    (rarea taxben_min taxben_max time, col(green*0.8) lw(none)) ///
    (rarea covidrelief_min covidrelief_max time, col(green*1.2) lw(none)) ///
    (rarea medi_min medi_max time, col(dkorange*1.2) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)) ///
    (con penben_max time, lw(medthick) col(black) msym(Th)) ///
    (con covidrelief_max time, lw(medthick) col(black) msym(Dh)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "Unemployment insurance benefits") ///
        label(3 "Other benefits (net)" "{it:(pensions & DI, minus contributions)}") ///
        label(4 "Regular cash transfers" "{it:(net of taxes)}") ///
        label(5 "COVID stimulus checks") ///
        label(6 "Medicaid and Medicare") ///
        label(7 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(8 "{bf:Subsidized factor national income}") ///
        label(9 "{bf:Subsidized pretax national income}") ///
        label(10 "{bf:Post-tax disposable income}") ///
        order(6 10 5 4 9 3 2 8 1 7 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step10.pdf", replace

// + other spending
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (rarea uiben_min uiben_max time, col(cranberry*1.2) lw(none)) ///
    (rarea penben_min penben_max time, col(cranberry*0.8) lw(none)) ///
    (rarea taxben_min taxben_max time, col(green*0.8) lw(none)) ///
    (rarea covidrelief_min covidrelief_max time, col(green*1.2) lw(none)) ///
    (rarea medi_min medi_max time, col(dkorange*1.2) lw(none)) ///
    (rarea oth_min oth_max time, col(dkorange*0.8) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)) ///
    (con penben_max time, lw(medthick) col(black) msym(Th)) ///
    (con covidrelief_max time, lw(medthick) col(black) msym(Dh)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "Unemployment insurance benefits") ///
        label(3 "Other benefits (net)" "{it:(pensions & DI, minus contributions)}") ///
        label(4 "Regular cash transfers" "{it:(net of taxes)}") ///
        label(5 "COVID stimulus checks") ///
        label(6 "Medicaid and Medicare") ///
        label(7 "Other government spending") ///
        label(8 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(9 "{bf:Subsidized factor national income}") ///
        label(10 "{bf:Subsidized pretax national income}") ///
        label(11 "{bf:Post-tax disposable income}") ///
        order(7 6 11 5 4 10 3 2 9 1 8 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step11.pdf", replace

// - deficit
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (rarea uiben_min uiben_max time, col(cranberry*1.2) lw(none)) ///
    (rarea penben_min penben_max time, col(cranberry*0.8) lw(none)) ///
    (rarea taxben_min taxben_max time, col(green*0.8) lw(none)) ///
    (rarea covidrelief_min covidrelief_max time, col(green*1.2) lw(none)) ///
    (rarea medi_min medi_max time, col(dkorange*1.2) lw(none)) ///
    (rarea oth_min oth_max time, col(dkorange*0.8) lw(none)) ///
    (rarea deficit_min deficit_max time, col(gs12) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)) ///
    (con penben_max time, lw(medthick) col(black) msym(Th)) ///
    (con covidrelief_max time, lw(medthick) col(black) msym(Dh)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "Unemployment insurance benefits") ///
        label(3 "Other benefits (net)" "{it:(pensions & DI, minus contributions)}") ///
        label(4 "Regular cash transfers" "{it:(net of taxes)}") ///
        label(5 "COVID stimulus checks") ///
        label(6 "Medicaid and Medicare") ///
        label(7 "Other government spending") ///
        label(8 "Government deficit") ///
        label(9 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(10 "{bf:Subsidized factor national income}") ///
        label(11 "{bf:Subsidized pretax national income}") ///
        label(12 "{bf:Post-tax disposable income}") ///
        order(8 7 6 12 5 4 11 3 2 10 1 9 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step12.pdf", replace

// = post-tax national
gr tw (rarea covidsub_min covidsub_max time, col(ebblue) lw(none)) ///
    (rarea uiben_min uiben_max time, col(cranberry*1.2) lw(none)) ///
    (rarea penben_min penben_max time, col(cranberry*0.8) lw(none)) ///
    (rarea taxben_min taxben_max time, col(green*0.8) lw(none)) ///
    (rarea covidrelief_min covidrelief_max time, col(green*1.2) lw(none)) ///
    (rarea medi_min medi_max time, col(dkorange*1.2) lw(none)) ///
    (rarea oth_min oth_max time, col(dkorange*0.8) lw(none)) ///
    (rarea deficit_min deficit_max time, col(gs12) lw(none)) ///
    (con princ time, lw(medthick) col(black) msym(Oh)) ///
    (con covidsub_max time, lw(medthick) col(black) msym(Sh)) ///
    (con penben_max time, lw(medthick) col(black) msym(Th)) ///
    (con covidrelief_max time, lw(medthick) col(black) msym(Dh)) ///
    (con poinc time, lw(medthick) col(black) msym(O)), ///
    ylabel(, format(%9.0gc)) ytitle("Monthly income per adult (constant USD)") ///
    yscale(range(0 6200)) ylabel(0(500)6000) ///
    xtitle("") xsize(6) ysize(3) xlabel(`=ym(2019, 6)'(6)`=ym(2022, 12)', alternate) ///
    legend(pos(4) cols(1) region(margin(0 0 10 0)) ///
        label(1 "Paycheck Protection Program") ///
        label(2 "Unemployment insurance benefits") ///
        label(3 "Other benefits (net)" "{it:(pensions & DI, minus contributions)}") ///
        label(4 "Regular cash transfers" "{it:(net of taxes)}") ///
        label(5 "COVID stimulus checks") ///
        label(6 "Medicaid and Medicare") ///
        label(7 "Other government spending") ///
        label(8 "Government deficit") ///
        label(9 "{bf:Factor national income}" "{it:(matching national income)}") ///
        label(10 "{bf:Subsidized factor national income}") ///
        label(11 "{bf:Subsidized pretax national income}") ///
        label(12 "{bf:Post-tax disposable income}") ///
        label(13 "{bf:Post-tax national income}" "{it:(matching national income)}") ///
        order(13 8 7 6 12 5 4 11 3 2 10 1 9 - "{dup 60: }") ///
    )
graph export "$graphs/04-plot-covid/presentation-bot50-step13.pdf", replace


// -------------------------------------------------------------------------- //
// Compare evolution of factor income
// -------------------------------------------------------------------------- //

// Unit: adult equal split, ranked by factor income equal split
// Plot: factor income
// Standard tabulation procedure: we can use the tabulations from 03-tabulate-income.do

use "$work/03-tabulate-income/tabulation-princ-adult_equal_split.dta", clear

merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    nogenerate keepusing(nipa_deflator) keep(master match) assert(match using)

sort year month p
by year month: generate n = cond(_n == _N, 1e5 - p, p[_n + 1] - p)

generate bracket = ""
replace bracket = "Bottom 50%" if inrange(p, 00000, 49000)
replace bracket = "Middle 40%" if inrange(p, 50000, 89000)
replace bracket = "Next 9%"    if inrange(p, 90000, 98000)
replace bracket = "Top 1%"     if inrange(p, 99000, 99999)

gcollapse (mean) princ (firstnm) nipa_deflator [pw=n], by(year month bracket)

generate time = ym(year, month)
format time %tm
replace princ = princ/12/nipa_deflator
sort bracket time

preserve
    keep if inrange(ym(year, month), ym(2007, 7), ym(2017, 07))

    by bracket: generate princ0 = princ[1]
    by bracket: replace princ = 100*princ/princ0

    gr tw (con princ time if bracket == "Bottom 50%", lw(medthick) msym(Oh) col(ebblue)) ///
        (con princ time if bracket == "Middle 40%", lw(medthick) msym(Sh) col(cranberry)) ///
        (con princ time if bracket == "Next 9%", lw(medthick) msym(Th) col(green)) ///
        (con princ time if bracket == "Top 1%", lw(medthick) msym(Dh) col(dkorange)), ///
        ytitle("Average income per adult (constant)" "07/2007 = 100") xlabel(`=ym(2007, 07)'(24)`=ym(2017, 07)') ///
        xtitle("") xsize(6) ysize(4) scale(1.2) yscale(range(70 110)) ylabel(70(10)110) ///
        legend(ring(0) bplacement(5) cols(1) ///
            label(1 "Bottom 50%") ///
            label(2 "Middle 40%") ///
            label(3 "Next 9%") ///
            label(4 "Top 1%") ///
            order(4 3 2 1) ///
        )
    graph export "$graphs/04-plot-covid/presentation-evolution-princ-great-recession.pdf", replace
restore

keep if ym(year, month) >= ym(2019, 07)
keep if ym(year, month) <= ym(2022, 09)

by bracket: generate princ0 = princ[1]
by bracket: replace princ = 100*princ/princ0

gr tw (con princ time if bracket == "Bottom 50%", lw(medthick) msym(Oh) col(ebblue)) ///
    (con princ time if bracket == "Middle 40%", lw(medthick) msym(Sh) col(cranberry)) ///
    (con princ time if bracket == "Next 9%", lw(medthick) msym(Th) col(green)) ///
    (con princ time if bracket == "Top 1%", lw(medthick) msym(Dh) col(dkorange)), ///
    ylabel(70(10)110) ///
    ytitle("Average income per adult (constant)" "07/2019 = 100") xlabel(`=ym(2019, 7)'(6)`=ym(2022, 7)', labsize(small)) ///
    xtitle("") xsize(6) ysize(4) scale(1.2) ///
    legend(ring(0) bplacement(5) cols(1) ///
        label(1 "Bottom 50%") ///
        label(2 "Middle 40%") ///
        label(3 "Next 9%") ///
        label(4 "Top 1%") ///
        order(4 3 2 1) ///
    )
graph export "$graphs/04-plot-covid/presentation-evolution-princ.pdf", replace

// -------------------------------------------------------------------------- //
// Compare evolution of disposable income
// -------------------------------------------------------------------------- //

// Unit: adults equal split, ranked by princ equal-split
// Plot: disposable income
// Ad hoc tabulation procedure: we need to start from monthly microfiles

tempfile tab_dispo
clear
save `tab_dispo', emptyok

forval t = `=ym(2019,6)' / `=ym(2022,9)' {
    local y = year(dofm(`t'))
    local m = month(dofm(`t'))

    use year month id weight princ dispo using ///
        "$microfiles/$update_id/dina-monthly-`y'm`m'.dta", clear

    // Equal-split
    gegen princ = mean(princ), by(id) replace
    gegen dispo = mean(dispo), by(id) replace

    // Rank by princ (equal-split), assign brackets directly
    gsort princ
    generate cum_w = sum(weight)
    local total_w = cum_w[_N]
    generate bracket = ""
    replace bracket = "Bottom 50%" if cum_w / `total_w' <= 0.50
    replace bracket = "Middle 40%" if cum_w / `total_w' > 0.50 & cum_w / `total_w' <= 0.90
    replace bracket = "Next 9%"    if cum_w / `total_w' > 0.90 & cum_w / `total_w' <= 0.99
    replace bracket = "Top 1%"     if cum_w / `total_w' > 0.99
    drop if bracket == ""

    gcollapse (mean) princ dispo [pw=weight], by(year month bracket)

    append using `tab_dispo'
    save `tab_dispo', replace
}

// Merge deflator and deflate
use `tab_dispo', clear
merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    nogenerate keepusing(nipa_deflator) keep(master match)
replace princ = princ/12/nipa_deflator
replace dispo  = dispo/12/nipa_deflator
generate time = ym(year, month)
format time %tm
sort bracket time

keep if ym(year, month) >= ym(2019, 07)
keep if ym(year, month) <= ym(2022, 09)

by bracket: generate dispo0 = dispo[1]
by bracket: replace dispo = 100*dispo/dispo0

gr tw (con dispo time if bracket == "Bottom 50%", lw(medthick) msym(Oh) col(ebblue)) ///
    (con dispo time if bracket == "Middle 40%", lw(medthick) msym(Sh) col(cranberry)) ///
    (con dispo time if bracket == "Next 9%", lw(medthick) msym(Th) col(green)) ///
    (con dispo time if bracket == "Top 1%", lw(medthick) msym(Dh) col(dkorange)), ///
    ytitle("Average income per adult (constant)" "07/2019 = 100") xlabel(`=ym(2019, 7)'(6)`=ym(2022, 7)', labsize(small)) ///
    xtitle("") xsize(6) ysize(4) scale(1.2) ///
    legend(pos(6) rows(1) ///
        label(1 "Bottom 50%") ///
        label(2 "Middle 40%") ///
        label(3 "Next 9%") ///
        label(4 "Top 1%") ///
        order(4 3 2 1) ///
    )
graph export "$graphs/04-plot-covid/presentation-evolution-dispo.pdf", replace

// -------------------------------------------------------------------------- //
// Compare evolution of average wealth
// -------------------------------------------------------------------------- //

use "$work/03-tabulate-income/tabulation-hweal-adult_equal_split.dta", clear

keep if ym(year, month) >= ym(2019, 07)
keep if ym(year, month) <= ym(2023, 07)

merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    nogenerate keepusing(nipa_deflator) keep(master match) assert(match using)

sort year month p
by year month: generate n = cond(_n == _N, 1e7 - p, p[_n + 1] - p)

generate bracket = ""
replace bracket = "bot50" if inrange(p, 0,       4900000)
replace bracket = "mid40" if inrange(p, 5000000, 8900000)
replace bracket = "top10" if inrange(p, 9000000, 9800000)
replace bracket = "top1"  if inrange(p, 9900000, 9980000)
replace bracket = "top01" if inrange(p, 9990000, 9999999)

gcollapse (sum) hweal (mean) nipa_deflator [pw=n], by(year month bracket)

generate time = ym(year, month)
format time %tm

foreach v of varlist hweal {
    replace `v' = `v'/nipa_deflator
}

reshape wide hweal, i(time year month) j(bracket) string

replace hwealtop1 = hwealtop1 + hwealtop01
replace hwealtop10 = hwealtop10 + hwealtop1

sort time

preserve
    foreach v of varlist hweal* {
        generate `v'ini = `v'[1]
        replace `v' = 100*`v'/`v'ini
    }

    gr tw (con hwealmid40 time, lw(medthick) msym(Oh) col(ebblue)) ///
        (con hwealtop10 time, lw(medthick) msym(Sh) col(cranberry)) ///
        (con hwealtop1 time, lw(medthick) msym(Th) col(green)) ///
        (con hwealtop01 time, lw(medthick) msym(Dh) col(dkorange)), ///
        ytitle("Average wealth per adult (constant USD)" "07/2019 = 100") ///
        xtitle("") xsize(6) ysize(4) scale(1.2) xscale(range(`=ym(2019, 6)' `=ym(2023, 6)')) xlabel(`=ym(2019, 6)'(6)`=ym(2023, 6)', alternate) ///
        legend(ring(0) bplacement(5) bmargin(0 5 1 0) cols(1) ///
            label(1 "Middle 40%") ///
            label(2 "Top 10%") ///
            label(3 "Top 1%") ///
            label(4 "Top 0.1%") ///
            order(4 3 2 1) ///
        )
    graph export "$graphs/04-plot-covid/presentation-evolution-hweal.pdf", replace
restore

// -------------------------------------------------------------------------- //
// Plot the dynamics of bottom 50% income during each recession
// -------------------------------------------------------------------------- //

use "$work/03-tabulate-income/tabulation-princ-working_age_equal_split.dta", clear
merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    nogenerate keepusing(nipa_deflator) keep(master match) assert(match using)
replace princ = princ/nipa_deflator

// Calculate bracket averages
sort year month p
by year month: generate n = cond(_n == _N, 1e5 - p, p[_n + 1] - p)

preserve
    keep if p < 50000
    gcollapse (mean) princ_bot50=princ [pw=n], by(year month)
    tempfile bot50
    save "`bot50'", replace
restore
gcollapse (mean) princ_total=princ [pw=n], by(year month)
merge 1:1 year month using "`bot50'", nogenerate keep(match)

generate time = ym(year, month)
format time %tm

// Normalize at the beginning of each recession
keep if ym(year, month) >= ym(2007, 12)
generate period = (ym(year, month) >= ym(2020, 02))
generate elapsed = ym(year, month) - ym(2007, 12) if period == 0
replace elapsed = ym(year, month) - ym(2020, 02) if period == 1
keep if elapsed <= 120

keep year month princ_bot50 princ_total time elapsed period
reshape wide year month princ_bot50 princ_total time, i(elapsed) j(period)

foreach v of varlist princ* {
    generate init = `v'[1]
    replace `v' = 100*`v'/init
    drop init
}

gr tw (line princ_bot500 princ_bot501 princ_total0 princ_total1 elapsed, ///
        lw(medthick..) lcol(ebblue ebblue cranberry cranberry) lp(solid dash solid dash)), ///
    legend(off) ///
    xlabel(0(12)120) xtitle("Months after recession started") ///
    ytitle("Real average factor income per working-age adult" "(Index, 100 in the month preceding the recession)") ///
    yline(100, lcol(black)) ///
    text(83.5 40 "Bottom 50%" "(Great recession)", col(ebblue) size(small)) ///
    text(108 90 "Working-age adults" "(Great recession)", col(cranberry) size(small)) ///
    text(77 6 "Bottom 50%" "(COVID recession)", col(ebblue) size(small) justification(left) placement(right)) ///
    text(105.5 20 "Working-age adults" "(COVID recession)", col(cranberry) size(small) justification(left) placement(right))
gr export "$graphs/04-plot-covid/bot50-recessions.pdf", replace
