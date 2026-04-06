// ------------------------------------------------------------------------------------- //
// Do backtesting of the extrapolation (original time period, extrapolate from 01/2020)
// ------------------------------------------------------------------------------------- //

use if year >= 2019 using "$work/02-update-qcew/qcew-monthly-updated-backtesting.dta", clear

// Indicator for the backtesting period
generate bt = (year >= 2020)

// Last value before backtesting
generate last_mthly_emplvl_bt = mthly_emplvl if year == 2019 & month == 12
generate last_avg_mthly_wages_bt = avg_mthly_wages if year == 2019 & month == 12
sort id year month
by id: carryforward last_mthly_emplvl_bt last_avg_mthly_wages_bt, replace

// Cumulate to get prediction
by id: generate mthly_emplvl_bt = last_mthly_emplvl_bt*exp(sum(chg_mthly_emplvl_pred)) if bt
by id: generate avg_mthly_wages_bt = last_avg_mthly_wages_bt*exp(sum(chg_avg_mthly_wages_pred)) if bt

// Aggregate by quintile
drop bracket
replace avg_mthly_wages_bt = avg_mthly_wages if time < ym(2020, 01)
gquantiles bracket = avg_mthly_wages_bt [aw=mthly_emplvl], xtile nquantiles(4) by(year month)
replace avg_mthly_wages_bt = . if time < ym(2020, 01)
gcollapse (mean) mthly_emplvl mthly_emplvl_bt avg_mthly_wages avg_mthly_wages_bt [aw=mthly_emplvl], by(bracket year month)

// Make into an index and plot
generate time = ym(year, month)
format time %tm
sort bracket time
foreach v of varlist mthly_emplvl_bt avg_mthly_wages_bt mthly_emplvl avg_mthly_wages {
    generate ref = `v' if year == 2020 & month == 1
    gegen ref = min(ref), by(bracket) replace
    replace `v' = 100*`v'/ref
    drop ref
}

// Rescale wage growth (since wage income will be normalized)
gegen avg_wages_bt = mean(avg_mthly_wages_bt) [pw=mthly_emplvl_bt], by(time)
gegen avg_wages = mean(avg_mthly_wages) [pw=mthly_emplvl], by(time)
replace avg_mthly_wages_bt = avg_mthly_wages_bt/avg_wages_bt*avg_wages

generate quartile = ""
replace quartile = "1st quartile" if bracket == 1
replace quartile = "2nd quartile" if bracket == 2
replace quartile = "3rd quartile" if bracket == 3
replace quartile = "4th quartile" if bracket == 4

keep if inrange(time, ym(2019, 10), ym(2020, 06))

gr tw con mthly_emplvl mthly_emplvl_bt time, by(quartile, note("")) ///
    ytitle("Employment level (01/2020 = 100)") xtitle("") xlabel(`=ym(2019, 11)'(2)`=ym(2020, 6)', labsize(small)) ///
    lw(medthick..) col(ebblue cranberry) msize(small) msym(Oh Sh) ///
    legend(label(1 "True") label(2 "Extrapolated after 01/2020"))
graph export "$graphs/02-update-qcew-backtest/extrapolation-backtest-employment-2020.pdf", replace
    
gr tw con avg_mthly_wages avg_mthly_wages_bt time, by(quartile, note("")) ///
    ytitle("Average wage (01/2020 = 100)") xtitle("") xlabel(`=ym(2019, 11)'(2)`=ym(2020, 6)', labsize(small)) ///
    lw(medthick..) col(ebblue cranberry) msize(small) msym(Oh Sh) ///
    legend(label(1 "True") label(2 "Extrapolated after 01/2020"))
graph export "$graphs/02-update-qcew-backtest/extrapolation-backtest-wage-2020.pdf", replace


// -------------------------------------------------------------------------- //
// Do backtesting of the extrapolation (extrapolate from 01/2021)
// -------------------------------------------------------------------------- //

use if year >= 2020 using "$work/02-update-qcew/qcew-monthly-updated-backtesting.dta", clear

// Indicator for the backtesting period
generate bt = (year >= 2021)

// Last value before backtesting
generate last_mthly_emplvl_bt = mthly_emplvl if year == 2020 & month == 12
generate last_avg_mthly_wages_bt = avg_mthly_wages if year == 2020 & month == 12
sort id year month
by id: carryforward last_mthly_emplvl_bt last_avg_mthly_wages_bt, replace

// Cumulate to get prediction
by id: generate mthly_emplvl_bt = last_mthly_emplvl_bt*exp(sum(chg_mthly_emplvl_pred)) if bt
by id: generate avg_mthly_wages_bt = last_avg_mthly_wages_bt*exp(sum(chg_avg_mthly_wages_pred)) if bt

// Aggregate by quintile
drop bracket
replace avg_mthly_wages_bt = avg_mthly_wages if time < ym(2021, 01)
gquantiles bracket = avg_mthly_wages_bt [aw=mthly_emplvl], xtile nquantiles(4) by(year month)
replace avg_mthly_wages_bt = . if time < ym(2021, 01)
gcollapse (mean) mthly_emplvl mthly_emplvl_bt avg_mthly_wages avg_mthly_wages_bt [aw=mthly_emplvl], by(bracket year month)

// Make into an index and plot
generate time = ym(year, month)
format time %tm
sort bracket time
foreach v of varlist mthly_emplvl_bt avg_mthly_wages_bt mthly_emplvl avg_mthly_wages {
    generate ref = `v' if year == 2021 & month == 1
    gegen ref = min(ref), by(bracket) replace
    replace `v' = 100*`v'/ref
    drop ref
}

// Rescale wage growth (since wage income will be normalized)
gegen avg_wages_bt = mean(avg_mthly_wages_bt) [pw=mthly_emplvl_bt], by(time)
gegen avg_wages = mean(avg_mthly_wages) [pw=mthly_emplvl], by(time)
replace avg_mthly_wages_bt = avg_mthly_wages_bt/avg_wages_bt*avg_wages

generate quartile = ""
replace quartile = "1st quartile" if bracket == 1
replace quartile = "2nd quartile" if bracket == 2
replace quartile = "3rd quartile" if bracket == 3
replace quartile = "4th quartile" if bracket == 4

keep if inrange(time, ym(2020, 10), ym(2021, 06))

gr tw con mthly_emplvl mthly_emplvl_bt time, by(quartile, note("")) ///
    ytitle("Employment level (01/2021 = 100)") xtitle("") xlabel(`=ym(2020, 11)'(2)`=ym(2021, 6)', labsize(small)) ///
    lw(medthick..) col(ebblue cranberry) msize(small) msym(Oh Sh) ///
    legend(label(1 "True") label(2 "Extrapolated after 01/2021"))
graph export "$graphs/02-update-qcew-backtest/extrapolation-backtest-employment-2021.pdf", replace
    
gr tw con avg_mthly_wages avg_mthly_wages_bt time, by(quartile, note("")) ///
    ytitle("Average wage (01/2021 = 100)") xtitle("") xlabel(`=ym(2020, 11)'(2)`=ym(2021, 6)', labsize(small)) ///
    lw(medthick..) col(ebblue cranberry) msize(small) msym(Oh Sh) ///
    legend(label(1 "True") label(2 "Extrapolated after 01/2021"))
graph export "$graphs/02-update-qcew-backtest/extrapolation-backtest-wage-2021.pdf", replace


// -------------------------------------------------------------------------- //
// Do backtesting of the extrapolation (extrapolate from 01/2022)
// -------------------------------------------------------------------------- //

use if year >= 2021 using "$work/02-update-qcew/qcew-monthly-updated-backtesting.dta", clear

// Indicator for the backtesting period
generate bt = (year >= 2022)

// Last value before backtesting
generate last_mthly_emplvl_bt = mthly_emplvl if year == 2021 & month == 12
generate last_avg_mthly_wages_bt = avg_mthly_wages if year == 2021 & month == 12
sort id year month
by id: carryforward last_mthly_emplvl_bt last_avg_mthly_wages_bt, replace

// Cumulate to get prediction
by id: generate mthly_emplvl_bt = last_mthly_emplvl_bt*exp(sum(chg_mthly_emplvl_pred)) if bt
by id: generate avg_mthly_wages_bt = last_avg_mthly_wages_bt*exp(sum(chg_avg_mthly_wages_pred)) if bt

// Aggregate by quintile
drop bracket
replace avg_mthly_wages_bt = avg_mthly_wages if time < ym(2022, 01)
gquantiles bracket = avg_mthly_wages_bt [aw=mthly_emplvl], xtile nquantiles(4) by(year month)
replace avg_mthly_wages_bt = . if time < ym(2022, 01)
gcollapse (mean) mthly_emplvl mthly_emplvl_bt avg_mthly_wages avg_mthly_wages_bt [aw=mthly_emplvl], by(bracket year month)

// Make into an index and plot
generate time = ym(year, month)
format time %tm
sort bracket time
foreach v of varlist mthly_emplvl_bt avg_mthly_wages_bt mthly_emplvl avg_mthly_wages {
    generate ref = `v' if year == 2022 & month == 1
    gegen ref = min(ref), by(bracket) replace
    replace `v' = 100*`v'/ref
    drop ref
}

// Rescale wage growth (since wage income will be normalized)
gegen avg_wages_bt = mean(avg_mthly_wages_bt) [pw=mthly_emplvl_bt], by(time)
gegen avg_wages = mean(avg_mthly_wages) [pw=mthly_emplvl], by(time)
replace avg_mthly_wages_bt = avg_mthly_wages_bt/avg_wages_bt*avg_wages

generate quartile = ""
replace quartile = "1st quartile" if bracket == 1
replace quartile = "2nd quartile" if bracket == 2
replace quartile = "3rd quartile" if bracket == 3
replace quartile = "4th quartile" if bracket == 4

keep if inrange(time, ym(2021, 10), ym(2022, 06))

gr tw con mthly_emplvl mthly_emplvl_bt time, by(quartile, note("")) ///
    ytitle("Employment level (01/2022 = 100)") xtitle("") xlabel(`=ym(2021, 11)'(2)`=ym(2022, 6)', labsize(small)) ///
    lw(medthick..) col(ebblue cranberry) msize(small) msym(Oh Sh) ///
    legend(label(1 "True") label(2 "Extrapolated after 01/2022"))
graph export "$graphs/02-update-qcew-backtest/extrapolation-backtest-employment-2022.pdf", replace
    
gr tw con avg_mthly_wages avg_mthly_wages_bt time, by(quartile, note("")) ///
    ytitle("Average wage (01/2022 = 100)") xtitle("") xlabel(`=ym(2021, 11)'(2)`=ym(2022, 6)', labsize(small)) ///
    lw(medthick..) col(ebblue cranberry) msize(small) msym(Oh Sh) ///
    legend(label(1 "True") label(2 "Extrapolated after 01/2022"))
graph export "$graphs/02-update-qcew-backtest/extrapolation-backtest-wage-2022.pdf", replace


// -------------------------------------------------------------------------- //
// Do backtesting of the extrapolation (extrapolate from 01/2023)
// -------------------------------------------------------------------------- //

use if year >= 2022 using "$work/02-update-qcew/qcew-monthly-updated-backtesting.dta", clear

// Indicator for the backtesting period
generate bt = (year >= 2023)

// Last value before backtesting
generate last_mthly_emplvl_bt = mthly_emplvl if year == 2022 & month == 12
generate last_avg_mthly_wages_bt = avg_mthly_wages if year == 2022 & month == 12
sort id year month
by id: carryforward last_mthly_emplvl_bt last_avg_mthly_wages_bt, replace

// Cumulate to get prediction
by id: generate mthly_emplvl_bt = last_mthly_emplvl_bt*exp(sum(chg_mthly_emplvl_pred)) if bt
by id: generate avg_mthly_wages_bt = last_avg_mthly_wages_bt*exp(sum(chg_avg_mthly_wages_pred)) if bt

// Aggregate by quintile
drop bracket
replace avg_mthly_wages_bt = avg_mthly_wages if time < ym(2023, 01)
gquantiles bracket = avg_mthly_wages_bt [aw=mthly_emplvl], xtile nquantiles(4) by(year month)
replace avg_mthly_wages_bt = . if time < ym(2023, 01)
gcollapse (mean) mthly_emplvl mthly_emplvl_bt avg_mthly_wages avg_mthly_wages_bt [aw=mthly_emplvl], by(bracket year month)

// Make into an index and plot
generate time = ym(year, month)
format time %tm
sort bracket time
foreach v of varlist mthly_emplvl_bt avg_mthly_wages_bt mthly_emplvl avg_mthly_wages {
    generate ref = `v' if year == 2023 & month == 1
    gegen ref = min(ref), by(bracket) replace
    replace `v' = 100*`v'/ref
    drop ref
}

// Rescale wage growth (since wage income will be normalized)
gegen avg_wages_bt = mean(avg_mthly_wages_bt) [pw=mthly_emplvl_bt], by(time)
gegen avg_wages = mean(avg_mthly_wages) [pw=mthly_emplvl], by(time)
replace avg_mthly_wages_bt = avg_mthly_wages_bt/avg_wages_bt*avg_wages

generate quartile = ""
replace quartile = "1st quartile" if bracket == 1
replace quartile = "2nd quartile" if bracket == 2
replace quartile = "3rd quartile" if bracket == 3
replace quartile = "4th quartile" if bracket == 4

keep if inrange(time, ym(2022, 10), ym(2023, 06))

gr tw con mthly_emplvl mthly_emplvl_bt time, by(quartile, note("")) ///
    ytitle("Employment level (01/2023 = 100)") xtitle("") xlabel(`=ym(2022, 11)'(2)`=ym(2023, 6)', labsize(small)) ///
    lw(medthick..) col(ebblue cranberry) msize(small) msym(Oh Sh) ///
    legend(label(1 "True") label(2 "Extrapolated after 01/2023"))
graph export "$graphs/02-update-qcew-backtest/extrapolation-backtest-employment-2023.pdf", replace
    
gr tw con avg_mthly_wages avg_mthly_wages_bt time, by(quartile, note("")) ///
    ytitle("Average wage (01/2023 = 100)") xtitle("") xlabel(`=ym(2022, 11)'(2)`=ym(2023, 6)', labsize(small)) ///
    lw(medthick..) col(ebblue cranberry) msize(small) msym(Oh Sh) ///
    legend(label(1 "True") label(2 "Extrapolated after 01/2023"))
graph export "$graphs/02-update-qcew-backtest/extrapolation-backtest-wage-2023.pdf", replace


// -------------------------------------------------------------------------- //
// Do backtesting of the extrapolation (extrapolate from 01/2024)
// -------------------------------------------------------------------------- //

use if year >= 2023 using "$work/02-update-qcew/qcew-monthly-updated-backtesting.dta", clear

// Indicator for the backtesting period
generate bt = (year >= 2024)

// Last value before backtesting
generate last_mthly_emplvl_bt = mthly_emplvl if year == 2023 & month == 12
generate last_avg_mthly_wages_bt = avg_mthly_wages if year == 2023 & month == 12
sort id year month
by id: carryforward last_mthly_emplvl_bt last_avg_mthly_wages_bt, replace

// Cumulate to get prediction
by id: generate mthly_emplvl_bt = last_mthly_emplvl_bt*exp(sum(chg_mthly_emplvl_pred)) if bt
by id: generate avg_mthly_wages_bt = last_avg_mthly_wages_bt*exp(sum(chg_avg_mthly_wages_pred)) if bt

// Aggregate by quintile
drop bracket
replace avg_mthly_wages_bt = avg_mthly_wages if time < ym(2024, 01)
gquantiles bracket = avg_mthly_wages_bt [aw=mthly_emplvl], xtile nquantiles(4) by(year month)
replace avg_mthly_wages_bt = . if time < ym(2024, 01)
gcollapse (mean) mthly_emplvl mthly_emplvl_bt avg_mthly_wages avg_mthly_wages_bt [aw=mthly_emplvl], by(bracket year month)

// Make into an index and plot
generate time = ym(year, month)
format time %tm
sort bracket time
foreach v of varlist mthly_emplvl_bt avg_mthly_wages_bt mthly_emplvl avg_mthly_wages {
    generate ref = `v' if year == 2024 & month == 1
    gegen ref = min(ref), by(bracket) replace
    replace `v' = 100*`v'/ref
    drop ref
}

// Rescale wage growth (since wage income will be normalized)
gegen avg_wages_bt = mean(avg_mthly_wages_bt) [pw=mthly_emplvl_bt], by(time)
gegen avg_wages = mean(avg_mthly_wages) [pw=mthly_emplvl], by(time)
replace avg_mthly_wages_bt = avg_mthly_wages_bt/avg_wages_bt*avg_wages

generate quartile = ""
replace quartile = "1st quartile" if bracket == 1
replace quartile = "2nd quartile" if bracket == 2
replace quartile = "3rd quartile" if bracket == 3
replace quartile = "4th quartile" if bracket == 4

keep if inrange(time, ym(2023, 10), ym(2024, 06))

gr tw con mthly_emplvl mthly_emplvl_bt time, by(quartile, note("")) ///
    ytitle("Employment level (01/2024 = 100)") xtitle("") xlabel(`=ym(2023, 11)'(2)`=ym(2024, 6)', labsize(small)) ///
    lw(medthick..) col(ebblue cranberry) msize(small) msym(Oh Sh) ///
    legend(label(1 "True") label(2 "Extrapolated after 01/2024"))
graph export "$graphs/02-update-qcew-backtest/extrapolation-backtest-employment-2024.pdf", replace
    
gr tw con avg_mthly_wages avg_mthly_wages_bt time, by(quartile, note("")) ///
    ytitle("Average wage (01/2024 = 100)") xtitle("") xlabel(`=ym(2023, 11)'(2)`=ym(2024, 6)', labsize(small)) ///
    lw(medthick..) col(ebblue cranberry) msize(small) msym(Oh Sh) ///
    legend(label(1 "True") label(2 "Extrapolated after 01/2024"))
graph export "$graphs/02-update-qcew-backtest/extrapolation-backtest-wage-2024.pdf", replace

// -------------------------------------------------------------------------- //
// Perform systematic backtesting of CES extrapolation (original time period)
// -------------------------------------------------------------------------- //

local date_begin = ym(2018, 09)
local date_end = ym(2021, 09)

quietly {
    foreach t of numlist `date_begin' (3) `date_end' {
        
        use id year month time mthly_emplvl avg_mthly_wages chg_mthly_emplvl_pred chg_avg_mthly_wages_pred ///
            if inrange(time, `t', `t' + 6) using "$work/02-update-qcew/qcew-monthly-updated-backtesting.dta", clear
        
        local year = year(dofm(`t'))
        local month = month(dofm(`t'))
        
        // Last value before backtesting
        generate last_mthly_emplvl_bt = mthly_emplvl if time == `t'
        generate last_avg_mthly_wages_bt = avg_mthly_wages if time == `t'
        //sort id year month
        by id: carryforward last_mthly_emplvl_bt last_avg_mthly_wages_bt, replace

        // Cumulate to get prediction
        replace chg_mthly_emplvl_pred = 0 if time == `t'
        replace chg_avg_mthly_wages_pred = 0 if time == `t'
        by id: generate mthly_emplvl_bt`t' = last_mthly_emplvl_bt*exp(sum(chg_mthly_emplvl_pred))
        by id: generate avg_mthly_wages_bt`t' = last_avg_mthly_wages_bt*exp(sum(chg_avg_mthly_wages_pred))

        drop last_mthly_emplvl_bt last_avg_mthly_wages_bt chg_mthly_emplvl_pred chg_avg_mthly_wages_pred
        
        compress
        save "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting`t'.dta", replace
        
        noisily di "* `year'm`month'"
    }
}

clear

use if version == "NAICS" & inrange(ym(year, month), `date_begin', `date_end' + 6) ///
    using "$work/02-update-qcew/qcew-monthly-updated.dta", clear

// Tabulate
hashsort year month avg_mthly_wages

by year month: generate rank = sum(mthly_emplvl)
by year month: replace rank = 1e5*(rank - mthly_emplvl/2)/rank[_N]

egen p = cut(rank), at(0(1000)99000 100001)

gcollapse (mean) avg_mthly_wages [aw=mthly_emplvl], by(year month p)

save "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting-tabulations.dta", replace

foreach t of numlist `date_begin' (3) `date_end' {
    use "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting`t'.dta", clear
    
    // Tabulate
    hashsort year month avg_mthly_wages_bt`t'

    by year month: generate rank = sum(mthly_emplvl_bt`t')
    by year month: replace rank = 1e5*(rank - mthly_emplvl_bt`t'/2)/rank[_N]

    egen p = cut(rank), at(0(1000)99000 100001)

    gcollapse (mean) avg_mthly_wages=avg_mthly_wages_bt`t' [aw=mthly_emplvl_bt`t'], by(year month p)
    
    generate bt = `t'
    format bt %tm
    
    append using "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting-tabulations.dta"
    save "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting-tabulations.dta", replace
}

use "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting-tabulations.dta", clear

generate time = ym(year, month)
format time %tm

hashsort bt year month

gegen total = total(avg_mthly_wages), by(bt year month)
generate share = 100*avg_mthly_wages/total

generate bracket = ""
replace bracket = "bot50" if inrange(p, 0, 49000)
replace bracket = "top10" if inrange(p, 90000, 100000)

gcollapse (sum) share if inrange(ym(year, month), `=ym(2018, 09)', `=ym(2021, 12)'), by(year month time bt bracket)

gr tw (line share time if missing(bt) & bracket == "bot50", col(ebblue) lw(thick)) ///
    (line share time if bt == `=ym(2018, 09)' & bracket == "bot50", col(gs10) lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2018, 12)' & bracket == "bot50", /*col(cranberry*1.4)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2019, 03)' & bracket == "bot50", /*col(cranberry*1.4)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2019, 06)' & bracket == "bot50", /*col(cranberry*0.6)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2019, 09)' & bracket == "bot50", /*col(cranberry*1.4)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2019, 12)' & bracket == "bot50", /*col(cranberry*0.6)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2020, 03)' & bracket == "bot50", /*col(cranberry*1.4)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2020, 06)' & bracket == "bot50", /*col(cranberry*0.6)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2020, 09)' & bracket == "bot50", /*col(cranberry*1.4)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2020, 12)' & bracket == "bot50", /*col(cranberry*0.6)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2021, 03)' & bracket == "bot50", /*col(cranberry*1.4)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2021, 06)' & bracket == "bot50", /*col(cranberry*0.6)*/ lw(thick) lp(dash)), ///
    xtitle("") ytitle("Bottom 50% wage income share in QCEW (%)") ///
    xlabel(`=ym(2018, 09)'(6)`=ym(2021, 12)') ///
    legend(label(1 "QCEW") label(2 "Extrapolation from CES") order(1 2))
graph export "$graphs/02-update-qcew-backtest/extrapolation-bot50.pdf", replace

gr tw (line share time if missing(bt) & bracket == "top10", col(ebblue) lw(thick)) ///
    (line share time if bt == `=ym(2018, 09)' & bracket == "top10", col(gs10) lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2018, 12)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2019, 03)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2019, 06)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2019, 09)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2019, 12)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2020, 03)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2020, 06)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2020, 09)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2020, 12)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2021, 03)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2021, 06)' & bracket == "top10", /*col(cranberry)*/ lw(thick) lp(dash)), ///
    xtitle("") ytitle("Top 10% wage income share in QCEW (%)") ///
    xlabel(`=ym(2018, 09)'(6)`=ym(2021, 12)') ///
    legend(label(1 "QCEW") label(2 "Extrapolation from CES") order(1 2)) 
graph export "$graphs/02-update-qcew-backtest/extrapolation-top10.pdf", replace


// ---------------------------------------------------------------------------------------- //
// Perform systematic backtesting of CES extrapolation (same with more recent time period)
// ---------------------------------------------------------------------------------------- //

local date_begin = ym(2022, 01)
local date_end   = ym(2024, 10)

quietly {
    foreach t of numlist `date_begin' (3) `date_end' {
        
        use id year month time mthly_emplvl avg_mthly_wages chg_mthly_emplvl_pred chg_avg_mthly_wages_pred ///
            if inrange(time, `t', `t' + 6) using "$work/02-update-qcew/qcew-monthly-updated-backtesting.dta", clear
        
        local year = year(dofm(`t'))
        local month = month(dofm(`t'))
        
        // Last value before backtesting
        generate last_mthly_emplvl_bt = mthly_emplvl if time == `t'
        generate last_avg_mthly_wages_bt = avg_mthly_wages if time == `t'
        //sort id year month
        by id: carryforward last_mthly_emplvl_bt last_avg_mthly_wages_bt, replace

        // Cumulate to get prediction
        replace chg_mthly_emplvl_pred = 0 if time == `t'
        replace chg_avg_mthly_wages_pred = 0 if time == `t'
        by id: generate mthly_emplvl_bt`t' = last_mthly_emplvl_bt*exp(sum(chg_mthly_emplvl_pred))
        by id: generate avg_mthly_wages_bt`t' = last_avg_mthly_wages_bt*exp(sum(chg_avg_mthly_wages_pred))

        drop last_mthly_emplvl_bt last_avg_mthly_wages_bt chg_mthly_emplvl_pred chg_avg_mthly_wages_pred
        
        compress
        save "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting`t'.dta", replace
        
        noisily di "* `year'm`month'"
    }
}

clear

use if version == "NAICS" & inrange(ym(year, month), `date_begin', `date_end' + 6) ///
    using "$work/02-update-qcew/qcew-monthly-updated.dta", clear

// Tabulate
hashsort year month avg_mthly_wages

by year month: generate rank = sum(mthly_emplvl)
by year month: replace rank = 1e5*(rank - mthly_emplvl/2)/rank[_N]

egen p = cut(rank), at(0(1000)99000 100001)

gcollapse (mean) avg_mthly_wages [aw=mthly_emplvl], by(year month p)

save "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting-tabulations-recent.dta", replace

foreach t of numlist `date_begin' (3) `date_end' {
    use "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting`t'.dta", clear
    
    // Tabulate
    hashsort year month avg_mthly_wages_bt`t'

    by year month: generate rank = sum(mthly_emplvl_bt`t')
    by year month: replace rank = 1e5*(rank - mthly_emplvl_bt`t'/2)/rank[_N]

    egen p = cut(rank), at(0(1000)99000 100001)

    gcollapse (mean) avg_mthly_wages=avg_mthly_wages_bt`t' [aw=mthly_emplvl_bt`t'], by(year month p)
    
    generate bt = `t'
    format bt %tm
    
    append using "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting-tabulations-recent.dta"
    save "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting-tabulations-recent.dta", replace
}

use "$work/02-update-qcew/backtesting-ces/qcew-ces-backtesting-tabulations-recent.dta", clear

generate time = ym(year, month)
format time %tm

hashsort bt year month

gegen total = total(avg_mthly_wages), by(bt year month)
generate share = 100*avg_mthly_wages/total

generate bracket = ""
replace bracket = "bot50" if inrange(p, 0, 49000)
replace bracket = "top10" if inrange(p, 90000, 100000)

gcollapse (sum) share if inrange(ym(year, month), `=ym(2018, 12)', `=ym(2024, 12)'), by(year month time bt bracket)

gr tw (line share time if missing(bt) & bracket == "bot50", col(ebblue) lw(thick)) ///
    (line share time if bt == `=ym(2022, 01)' & bracket == "bot50", col(gs10) lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2022, 04)' & bracket == "bot50", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2022, 07)' & bracket == "bot50", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2022, 10)' & bracket == "bot50", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2023, 01)' & bracket == "bot50", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2023, 04)' & bracket == "bot50", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2023, 07)' & bracket == "bot50", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2023, 10)' & bracket == "bot50", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2024, 01)' & bracket == "bot50", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2024, 04)' & bracket == "bot50", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2024, 07)' & bracket == "bot50", lw(thick) lp(dash)), ///
    xtitle("") ytitle("Bottom 50% wage income share in QCEW (%)") ///
    xlabel(`=ym(2022, 1)'(6)`=ym(2024, 10)') ///
    legend(label(1 "QCEW") label(2 "Extrapolation from CES") order(1 2))
graph export "$graphs/02-update-qcew-backtest/extrapolation-bot50-recent.pdf", replace

gr tw (line share time if missing(bt) & bracket == "top10", col(ebblue) lw(thick)) ///
    (line share time if bt == `=ym(2022, 01)' & bracket == "top10", col(gs10) lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2022, 04)' & bracket == "top10", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2022, 07)' & bracket == "top10", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2022, 10)' & bracket == "top10", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2023, 01)' & bracket == "top10", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2023, 04)' & bracket == "top10", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2023, 07)' & bracket == "top10", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2023, 10)' & bracket == "top10", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2024, 01)' & bracket == "top10", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2024, 04)' & bracket == "top10", lw(thick) lp(dash)) ///
    (line share time if bt == `=ym(2024, 07)' & bracket == "top10", lw(thick) lp(dash)), ///
    xtitle("") ytitle("Top 10% wage income share in QCEW (%)") ///
    xlabel(`=ym(2022, 1)'(6)`=ym(2024, 10)') ///
    legend(label(1 "QCEW") label(2 "Extrapolation from CES") order(1 2)) 
graph export "$graphs/02-update-qcew-backtest/extrapolation-top10-recent.pdf", replace
