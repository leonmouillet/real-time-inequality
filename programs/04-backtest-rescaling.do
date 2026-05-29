// -------------------------------------------------------------------------- //
// Backtest the method
// -------------------------------------------------------------------------- //

cap mkdir "$tables/04-backtest-rescaling"

clear
save "$work/04-backtest-rescaling/backtest-princ.dta", replace emptyok
save "$work/04-backtest-rescaling/backtest-peinc.dta", replace emptyok
save "$work/04-backtest-rescaling/backtest-dispo.dta", replace emptyok
save "$work/04-backtest-rescaling/backtest-poinc.dta", replace emptyok
save "$work/04-backtest-rescaling/backtest-hweal.dta", replace emptyok

// -------------------------------------------------------------------------- //
// Backtest, 1-year ahead
// -------------------------------------------------------------------------- //

local date_begin = ym(1976, 01)
local date_end   = ym(2024, 12)

quietly {
    foreach unit in /*"household" "individual"*/ "equal-split" {
        foreach v in princ peinc dispo poinc hweal {
            foreach t of numlist `date_begin' / `date_end' {
                local year = year(dofm(`t'))
                local month = month(dofm(`t'))

                noisily di "-> `year'm`month', `v', `unit'"

                use id weight `v' using "$work/03-build-monthly-microfiles-backtest-rescaling-1y/microfiles/dina-monthly-`year'm`month'.dta", clear

                if ("`unit'" == "equal-split") {
                    gegen `v' = mean(`v'), by(id) replace
                }
                else if ("`unit'" == "household") {
                    gcollapse (sum) `v' (mean) weight, by(id)
                }

                // Calculate rank
                sort `v'
                generate rank = sum(weight)
                replace rank = (rank - weight/2)/rank[_N]

                // Calcualte groups
                generate bracket = ""
                replace bracket = "bot50" if inrange(rank, 0.00, 0.50)
                replace bracket = "mid40" if inrange(rank, 0.50, 0.90)
                replace bracket = "next9" if inrange(rank, 0.90, 0.99)
                replace bracket = "top1"  if inrange(rank, 0.99, 1.00)

                gcollapse (sum) `v' [pw=weight], by(bracket)

                generate year = `year'
                generate month = `month'
                generate lag = 1
                generate unit = "`unit'"

                append using "$work/04-backtest-rescaling/backtest-`v'.dta"
				local saved = 0
				while !`saved' {
					cap save "$work/04-backtest-rescaling/backtest-`v'.dta", replace
					if (_rc == 0) local saved = 1
					else sleep 2000
				}
            }
        }
    }
}

// -------------------------------------------------------------------------- //
// Backtest, 2-year ahead
// -------------------------------------------------------------------------- //

local date_begin = ym(1976, 01)
local date_end   = ym(2024, 12)

quietly {
    foreach unit in /*"household" "individual"*/ "equal-split" {
        foreach v in princ peinc dispo poinc hweal {
            foreach t of numlist `date_begin' / `date_end' {
                local year = year(dofm(`t'))
                local month = month(dofm(`t'))

                noisily di "-> `year'm`month', `v', `unit'"

                use id weight `v' using "$work/03-build-monthly-microfiles-backtest-rescaling-2y/microfiles/dina-monthly-`year'm`month'.dta", clear

                if ("`unit'" == "equal-split") {
                    gegen `v' = mean(`v'), by(id) replace
                }
                else if ("`unit'" == "household") {
                    gcollapse (sum) `v' (mean) weight, by(id)
                }

                // Calculate rank
                sort `v'
                generate rank = sum(weight)
                replace rank = (rank - weight/2)/rank[_N]

                // Calcualte groups
                generate bracket = ""
                replace bracket = "bot50" if inrange(rank, 0.00, 0.50)
                replace bracket = "mid40" if inrange(rank, 0.50, 0.90)
                replace bracket = "next9" if inrange(rank, 0.90, 0.99)
                replace bracket = "top1"  if inrange(rank, 0.99, 1.00)

                gcollapse (sum) `v' [pw=weight], by(bracket)

                generate year = `year'
                generate month = `month'
                generate lag = 2
                generate unit = "`unit'"

                append using "$work/04-backtest-rescaling/backtest-`v'.dta"
				local saved = 0
				while !`saved' {
					cap save "$work/04-backtest-rescaling/backtest-`v'.dta", replace
					if (_rc == 0) local saved = 1
					else sleep 2000
				}
            }
        }
    }
}

// -------------------------------------------------------------------------- //
// Combine and prepare data
// -------------------------------------------------------------------------- //

// Reference
use "$work/04-backtest/dina-yearly-princ.dta", clear
merge 1:1 year bracket unit using "$work/04-backtest/dina-yearly-peinc.dta", nogenerate assert(match)
merge 1:1 year bracket unit using "$work/04-backtest/dina-yearly-dispo.dta", nogenerate assert(match)
merge 1:1 year bracket unit using "$work/04-backtest/dina-yearly-poinc.dta", nogenerate assert(match)
merge 1:1 year bracket unit using "$work/04-backtest/dina-yearly-hweal.dta", nogenerate assert(match)

renvars princ peinc dispo poinc hweal, prefix(average)
reshape long average, i(year unit bracket) j(income) string
generate lag = 99

expand 2, gen(new)
generate type = cond(new, "full", "rescaling")
drop new

tempfile ref
save "`ref'", replace

// Backtesting datasets (full)
use "$work/04-backtest/backtest-princ.dta", clear
merge 1:1 year month bracket unit lag using "$work/04-backtest/backtest-peinc.dta", nogenerate assert(match)
merge 1:1 year month bracket unit lag using "$work/04-backtest/backtest-dispo.dta", nogenerate assert(match)
merge 1:1 year month bracket unit lag using "$work/04-backtest/backtest-poinc.dta", nogenerate assert(match)
merge 1:1 year month bracket unit lag using "$work/04-backtest/backtest-hweal.dta", nogenerate assert(match)

renvars princ peinc dispo poinc hweal, prefix(average)
reshape long average, i(year month unit bracket lag) j(income) string
collapse (mean) average, by(year unit bracket income lag)

generate type = "full"

tempfile full
save "`full'", replace

// Backtesting datasets (rescaling)
use "$work/04-backtest-rescaling/backtest-princ.dta", clear
merge 1:1 year month bracket unit lag using "$work/04-backtest-rescaling/backtest-peinc.dta", nogenerate assert(match)
merge 1:1 year month bracket unit lag using "$work/04-backtest-rescaling/backtest-dispo.dta", nogenerate assert(match)
merge 1:1 year month bracket unit lag using "$work/04-backtest-rescaling/backtest-poinc.dta", nogenerate assert(match)
merge 1:1 year month bracket unit lag using "$work/04-backtest-rescaling/backtest-hweal.dta", nogenerate assert(match)

renvars princ peinc dispo poinc hweal, prefix(average)
reshape long average, i(year month unit bracket lag) j(income) string
collapse (mean) average, by(year unit bracket income lag)

generate type = "rescaling"

append using "`ref'"
append using "`full'"

// Convert to real
merge n:1 year using "$work/02-prepare-nipa/nipa-simplified-yearly.dta", nogenerate keep(match) keepusing(nipa_deflator)
replace average = average/nipa_deflator
drop nipa_deflator

// Calculate shares
gegen tot = total(average), by(year income unit lag type)
generate share = average/tot
drop tot

// Compute top10 = next9 + top1
preserve
    keep if inlist(bracket, "next9", "top1")
    gcollapse (sum) average share, by(year income unit lag type)
    generate bracket = "top10"
    tempfile top10_rows
    save "`top10_rows'"
restore
append using "`top10_rows'"

// Make as panel
gegen id = group(bracket income unit lag type)
tsset id year, yearly

// Calculate changes
generate chg1_share = 100*(share - L1.share)
generate chg2_share = 100*(share - L2.share)

generate chg1_average = 100*(average - L1.average)/L1.average
generate chg2_average = 100*(average - L2.average)/L2.average

drop id
reshape wide chg* average share, i(year bracket income unit type) j(lag)
foreach v of varlist *99 {
    local u = subinstr("`v'", "99", "", 1)
    generate ref_`u' = `v'
}
reshape long chg1_share chg2_share chg1_average chg2_average average share, i(year bracket income unit type) j(lag)

gegen id = group(bracket income unit lag type)
tsset id year, yearly

generate chgref1_share = 100*(share - L1.ref_share)
generate chgref2_share = 100*(share - L2.ref_share)

generate chgref1_average = 100*(average - L1.ref_average)/L1.ref_average
generate chgref2_average = 100*(average - L2.ref_average)/L2.ref_average

keep year bracket income unit chg* lag type
reshape wide chg*, i(year bracket income unit type) j(lag)

// Only show equal-split (results similar for all units)
keep if unit == "equal-split"

// Mark recession years
generate recession = 0
replace recession = 1 if inlist(year, 1980, 1981, 1982, 1990, 1991, 2001, 2008, 2009, 2020)
replace recession = 1 if inlist(year, 1983, 1992, 2002, 2010, 2021)

// Mark tax reform years
generate tax_reform = inlist(year, 1987, 1988, 1991, 1992, 1993, 2001, 2002, 2003, 2012, 2013)

// -------------------------------------------------------------------------- //
// Scatter plots
// -------------------------------------------------------------------------- //

// Compute RMSE
foreach br in bot50 mid40 next9 top1 top10 {
	foreach lag in 1 2 {
		foreach tp in full rescaling {
			gen _e2 = (chgref`lag'_average`lag' - chgref`lag'_average99)^2 ///
				if bracket == "`br'" & income == "princ" & type == "`tp'"
			summarize _e2, meanonly
			local `tp'_rmse_average_`br'_`lag'y : display %5.2f sqrt(r(mean))
			drop _e2
			gen _e2 = (chgref`lag'_share`lag' - chgref`lag'_share99)^2 ///
				if bracket == "`br'" & income == "princ" & type == "`tp'"
			summarize _e2, meanonly
			local `tp'_rmse_share_`br'_`lag'y : display %5.2f sqrt(r(mean))
			drop _e2
		}
	}
}

foreach br in bot50 mid40 next9 top1 top10 {
    if inlist("`br'", "bot50", "mid40", "next9") local taxfilt & !tax_reform
    else local taxfilt
    foreach lag in 1 2 {
        foreach vtype in average share {
            if "`vtype'" == "average" {
                local xtit       Predicted growth rate (%)
                local ytit       Actual growth rate (%)
            }
            else {
                local xtit       Predicted change (pp.)
                local ytit       Actual change (pp.)
            }
            local rmse_a `full_rmse_`vtype'_`br'_`lag'y'
            local rmse_b `rescaling_rmse_`vtype'_`br'_`lag'y'
            gr tw ///
                (line chgref`lag'_`vtype'99 chgref`lag'_`vtype'99 ///
                    if bracket == "`br'" & income == "princ" & unit == "equal-split" `taxfilt', ///
                    col(black) lw(medthick)) ///
                (scatter chgref`lag'_`vtype'99 chgref`lag'_`vtype'`lag' ///
                    if bracket == "`br'" & income == "princ" & unit == "equal-split" & type == "full", ///
                    col(ebblue) msym(O)) ///
                (scatter chgref`lag'_`vtype'99 chgref`lag'_`vtype'`lag' ///
                    if bracket == "`br'" & income == "princ" & unit == "equal-split" & type == "rescaling", ///
                    col(cranberry) msym(Oh)), ///
                aspectratio(1) xsize(4) ysize(4) scale(1.2) ///
                xtitle("`xtit'") ytitle("`ytit'") ///
				legend(order(- "RMSE (full method)    : `rmse_a' pp." - "RMSE (rescaling only): `rmse_b' pp.") ///
					symxsize(0) symysize(0) keygap(0) position(5) ring(0) region(fcolor(none) lwidth(none)) size(vsmall) cols(1))
            graph export "$graphs/04-backtest-rescaling/pred-`vtype'-`br'-`lag'y.pdf", replace
        }
    }
}

save "$work/04-backtest-rescaling/forecasts.dta", replace

// -------------------------------------------------------------------------- //
// Forecast errors & Diebold-Mariano tests: Full RTI vs. Rescaling RTI
// -------------------------------------------------------------------------- //

forvalues lag = 1/2 {
    use "$work/04-backtest-rescaling/forecasts.dta", clear

    keep year bracket income recession tax_reform type ///
        chgref`lag'_average`lag' chgref`lag'_average99 ///
        chgref`lag'_share`lag'   chgref`lag'_share99

    reshape wide chgref`lag'_average`lag' chgref`lag'_share`lag', ///
        i(year bracket income recession tax_reform) j(type) string
    rename chgref`lag'_average99 ref_average
    rename chgref`lag'_share99   ref_share

    // Full RTI forecast errors
    generate correct_sign = (sign(chgref`lag'_average`lag'full) == sign(ref_average)) ///
        if !missing(chgref`lag'_average`lag'full) & !missing(ref_average)
    generate fc_err = chgref`lag'_average`lag'full - ref_average

    generate correct_sign_shr = (sign(chgref`lag'_share`lag'full) == sign(ref_share)) ///
        if !missing(chgref`lag'_share`lag'full) & !missing(ref_share)
    generate fc_err_shr = chgref`lag'_share`lag'full - ref_share

    // Rescaling RTI forecast errors
    generate resc_correct_sign = (sign(chgref`lag'_average`lag'rescaling) == sign(ref_average)) ///
        if !missing(chgref`lag'_average`lag'rescaling) & !missing(ref_average)
    generate resc_fc_err = chgref`lag'_average`lag'rescaling - ref_average

    generate resc_correct_sign_shr = (sign(chgref`lag'_share`lag'rescaling) == sign(ref_share)) ///
        if !missing(chgref`lag'_share`lag'rescaling) & !missing(ref_share)
    generate resc_fc_err_shr = chgref`lag'_share`lag'rescaling - ref_share

    // DM loss differentials: Full RTI - Rescaling RTI
    generate d_avg = fc_err^2     - resc_fc_err^2
    generate d_shr = fc_err_shr^2 - resc_fc_err_shr^2

    // Diebold-Mariano tests (Harvey-Leybourne-Newbold small-sample correction)
    tempfile dm_all dm_notax dm_recession dm_combined

    foreach subset in all notax recession {
        preserve
            if "`subset'" == "notax"     keep if !tax_reform
            if "`subset'" == "recession" keep if recession

            gcollapse (mean)  d_mean_avg=d_avg d_mean_shr=d_shr ///
                      (sd)    d_sd_avg=d_avg   d_sd_shr=d_shr   ///
                      (count) d_n_avg=d_avg    d_n_shr=d_shr,   ///
                      by(bracket income)

            foreach m in avg shr {
                generate dm_stat = d_mean_`m' / (d_sd_`m' / sqrt(d_n_`m'))
                generate `subset'_dm_pval_`m' = 2 * ttail(d_n_`m' - 1, abs(dm_stat))
                generate `subset'_dm_stars_`m' = ""
                replace  `subset'_dm_stars_`m' = "*"   if `subset'_dm_pval_`m' < 0.10
                replace  `subset'_dm_stars_`m' = "**"  if `subset'_dm_pval_`m' < 0.05
                replace  `subset'_dm_stars_`m' = "***" if `subset'_dm_pval_`m' < 0.01
                generate `subset'_dm_diff_`m' = cond(d_mean_`m' < 0, "$+$", "$-$")
                drop dm_stat
            }

            keep bracket income *_dm_stars_* *_dm_pval_* *_dm_diff_*
            save "`dm_`subset''"
        restore
    }

    preserve
        use "`dm_all'", clear
        merge 1:1 bracket income using "`dm_notax'",     nogenerate assert(match)
        merge 1:1 bracket income using "`dm_recession'", nogenerate assert(match)
        save "`dm_combined'"
    restore

	
    // All years
    preserve
        gcollapse (sd) sd=ref_average (mean) mean_obs=ref_average mean_fc_err=fc_err (sd) sd_fc_err=fc_err (mean) resc_mean_fc_err=resc_fc_err (sd) resc_sd_fc_err=resc_fc_err (sd) sd_shr=ref_share (mean) mean_obs_shr=ref_share correct_sign_shr resc_correct_sign_shr mean_fc_err_shr=fc_err_shr (sd) sd_fc_err_shr=fc_err_shr (mean) resc_mean_fc_err_shr=resc_fc_err_shr (sd) resc_sd_fc_err_shr=resc_fc_err_shr, by(bracket income)
        generate fc_rmse      = sqrt(mean_fc_err^2      + sd_fc_err^2),      before(mean_fc_err)
        generate resc_fc_rmse = sqrt(resc_mean_fc_err^2 + resc_sd_fc_err^2), before(resc_mean_fc_err)
        generate fc_rmse_shr      = sqrt(mean_fc_err_shr^2      + sd_fc_err_shr^2),      before(mean_fc_err_shr)
        generate resc_fc_rmse_shr = sqrt(resc_mean_fc_err_shr^2 + resc_sd_fc_err_shr^2), before(resc_mean_fc_err_shr)
        renvars sd mean_obs fc_rmse mean_fc_err sd_fc_err resc_fc_rmse resc_mean_fc_err resc_sd_fc_err sd_shr mean_obs_shr correct_sign_shr resc_correct_sign_shr fc_rmse_shr mean_fc_err_shr sd_fc_err_shr resc_fc_rmse_shr resc_mean_fc_err_shr resc_sd_fc_err_shr, prefix(all_)
        tempfile fc_all
        save "`fc_all'"
    restore

    // Excluding tax reforms
    preserve
        gcollapse (sd) sd=ref_average (mean) mean_obs=ref_average mean_fc_err=fc_err (sd) sd_fc_err=fc_err (mean) resc_mean_fc_err=resc_fc_err (sd) resc_sd_fc_err=resc_fc_err (sd) sd_shr=ref_share (mean) mean_obs_shr=ref_share correct_sign_shr resc_correct_sign_shr mean_fc_err_shr=fc_err_shr (sd) sd_fc_err_shr=fc_err_shr (mean) resc_mean_fc_err_shr=resc_fc_err_shr (sd) resc_sd_fc_err_shr=resc_fc_err_shr if !tax_reform, by(bracket income)
        generate fc_rmse      = sqrt(mean_fc_err^2      + sd_fc_err^2),      before(mean_fc_err)
        generate resc_fc_rmse = sqrt(resc_mean_fc_err^2 + resc_sd_fc_err^2), before(resc_mean_fc_err)
        generate fc_rmse_shr      = sqrt(mean_fc_err_shr^2      + sd_fc_err_shr^2),      before(mean_fc_err_shr)
        generate resc_fc_rmse_shr = sqrt(resc_mean_fc_err_shr^2 + resc_sd_fc_err_shr^2), before(resc_mean_fc_err_shr)
        renvars sd mean_obs fc_rmse mean_fc_err sd_fc_err resc_fc_rmse resc_mean_fc_err resc_sd_fc_err sd_shr mean_obs_shr correct_sign_shr resc_correct_sign_shr fc_rmse_shr mean_fc_err_shr sd_fc_err_shr resc_fc_rmse_shr resc_mean_fc_err_shr resc_sd_fc_err_shr, prefix(notax_)
        tempfile fc_notax
        save "`fc_notax'"
    restore

    // Recessions
    preserve
        gcollapse (sd) sd=ref_average (mean) mean_obs=ref_average mean_fc_err=fc_err (sd) sd_fc_err=fc_err (mean) resc_mean_fc_err=resc_fc_err (sd) resc_sd_fc_err=resc_fc_err (sd) sd_shr=ref_share (mean) mean_obs_shr=ref_share correct_sign_shr resc_correct_sign_shr mean_fc_err_shr=fc_err_shr (sd) sd_fc_err_shr=fc_err_shr (mean) resc_mean_fc_err_shr=resc_fc_err_shr (sd) resc_sd_fc_err_shr=resc_fc_err_shr if recession, by(bracket income)
        generate fc_rmse      = sqrt(mean_fc_err^2      + sd_fc_err^2),      before(mean_fc_err)
        generate resc_fc_rmse = sqrt(resc_mean_fc_err^2 + resc_sd_fc_err^2), before(resc_mean_fc_err)
        generate fc_rmse_shr      = sqrt(mean_fc_err_shr^2      + sd_fc_err_shr^2),      before(mean_fc_err_shr)
        generate resc_fc_rmse_shr = sqrt(resc_mean_fc_err_shr^2 + resc_sd_fc_err_shr^2), before(resc_mean_fc_err_shr)
        renvars sd mean_obs fc_rmse mean_fc_err sd_fc_err resc_fc_rmse resc_mean_fc_err resc_sd_fc_err sd_shr mean_obs_shr correct_sign_shr resc_correct_sign_shr fc_rmse_shr mean_fc_err_shr sd_fc_err_shr resc_fc_rmse_shr resc_mean_fc_err_shr resc_sd_fc_err_shr, prefix(recession_)
        tempfile fc_recession
        save "`fc_recession'"
    restore

    use "`fc_all'", clear
    merge 1:1 bracket income using "`fc_notax'",    nogenerate assert(match)
    merge 1:1 bracket income using "`fc_recession'", nogenerate assert(match)
    merge 1:1 bracket income using "`dm_combined'", nogenerate assert(match)

    // R² = 1 - RMSE²/Var(obs)
    foreach prefix in all notax recession {
        generate `prefix'_fc_r2_avg    = 1 - (`prefix'_fc_rmse            / `prefix'_sd    )^2
        generate `prefix'_resc_r2_avg  = 1 - (`prefix'_resc_fc_rmse       / `prefix'_sd    )^2
        generate `prefix'_fc_r2_shr    = 1 - (`prefix'_fc_rmse_shr        / `prefix'_sd_shr)^2
        generate `prefix'_resc_r2_shr  = 1 - (`prefix'_resc_fc_rmse_shr   / `prefix'_sd_shr)^2
    }

    foreach v of varlist *_correct_sign_shr {
        generate _tmpfmt = strofreal(100*`v', "%02.0f") + "\%"
        drop `v'
        rename _tmpfmt `v'
    }

    foreach v of varlist *_sd *_mean_obs *_fc_rmse *_mean_fc_err *_sd_fc_err {
        generate `v'_str = strofreal(`v', "%02.1f") + "~pp.", after(`v')
        drop `v'
        rename `v'_str `v'
    }

    foreach v of varlist *_sd_shr *_mean_obs_shr *_fc_rmse_shr *_mean_fc_err_shr *_sd_fc_err_shr {
        generate _tmpfmt = strofreal(`v', "%04.2f") + "~pp."
        drop `v'
        rename _tmpfmt `v'
    }

    foreach v of varlist *_dm_pval_* {
        generate _tmpfmt = strofreal(`v', "%05.3f")
        drop `v'
        rename _tmpfmt `v'
    }

    foreach v of varlist *_fc_r2_avg *_resc_r2_avg *_fc_r2_shr *_resc_r2_shr {
        generate _tmpfmt = strofreal(`v', "%5.2f")
        drop `v'
        rename _tmpfmt `v'
    }

    generate income_order = .
    replace income_order = 1 if income == "princ"
    replace income_order = 2 if income == "peinc"
    replace income_order = 3 if income == "dispo"
    replace income_order = 4 if income == "poinc"
    replace income_order = 5 if income == "hweal"

	generate bracket_order = .
    replace bracket_order = 1 if bracket == "bot50"
    replace bracket_order = 2 if bracket == "mid40"
    replace bracket_order = 3 if bracket == "next9"
    replace bracket_order = 4 if bracket == "top10"
    replace bracket_order = 5 if bracket == "top1"

    drop if income == "hweal" & bracket == "bot50"
	drop if bracket == "top10"
    sort income_order bracket

    replace income = "\multirow{5}{*}{Factor Income}"     if income == "princ"
    replace income = "\multirow{5}{*}{Pretax Income}"     if income == "peinc"
    replace income = "\multirow{5}{*}{Disposable Income}" if income == "dispo"
    replace income = "\multirow{5}{*}{Post-tax Income}"   if income == "poinc"
    replace income = "\multirow{4}{*}{Wealth}"            if income == "hweal"

    by income_order: replace income = "" if _n > 1

    replace bracket = "Bottom 50\%" if bracket == "bot50"
    replace bracket = "Middle 40\%" if bracket == "mid40"
    replace bracket = "Next 9\%"    if bracket == "next9"
    replace bracket = "Top 1\%"     if bracket == "top1"
    replace bracket = "Top 10\%"    if bracket == "top10"

    generate vend = "\\"
    by income_order: replace vend = "\\ \midrule" if _n == _N
    replace vend = "\\" if _n == _N

    order income bracket

    // Table: all years, average growth
    listtab income bracket all_sd all_mean_obs all_fc_rmse all_fc_r2_avg all_mean_fc_err all_sd_fc_err ///
            all_resc_fc_rmse all_resc_r2_avg all_resc_mean_fc_err all_resc_sd_fc_err all_dm_pval_avg all_dm_stars_avg all_dm_diff_avg ///
        using "$tables/04-backtest-rescaling/backtest-table-avg-`lag'y.tex", replace ///
        delimiter(" & ") ///
        vend(vend) ///
        headlines("\begin{tabular}{llccccccccccccc}" "\toprule" ///
            " & & \multicolumn{2}{c}{Observed growth} & \multicolumn{4}{c}{Full RTI prediction} & \multicolumn{4}{c}{Rescaling RTI prediction} & \multicolumn{3}{c}{DM test} \\ \cmidrule(l){3-4} \cmidrule(l){5-8} \cmidrule(l){9-12} \cmidrule(l){13-15}" ///
            "Concept & Bracket & Std. Dev. & Mean & RMSE & \(R^2\) & Bias & Std. Dev. & RMSE & \(R^2\) & Bias & Std. Dev. & p-val. & & Diff \\ \midrule" ///
        ) ///
        footlines("\bottomrule \end{tabular}")

    // Table: excl. tax reforms, average growth
    listtab income bracket notax_sd notax_mean_obs notax_fc_rmse notax_fc_r2_avg notax_mean_fc_err notax_sd_fc_err ///
            notax_resc_fc_rmse notax_resc_r2_avg notax_resc_mean_fc_err notax_resc_sd_fc_err notax_dm_pval_avg notax_dm_stars_avg notax_dm_diff_avg ///
        using "$tables/04-backtest-rescaling/backtest-table-avg-`lag'y-notax.tex", replace ///
        delimiter(" & ") ///
        vend(vend) ///
        headlines("\begin{tabular}{llccccccccccccc}" "\toprule" ///
            " & & \multicolumn{2}{c}{Observed growth} & \multicolumn{4}{c}{Full RTI prediction} & \multicolumn{4}{c}{Rescaling RTI prediction} & \multicolumn{3}{c}{DM test} \\ \cmidrule(l){3-4} \cmidrule(l){5-8} \cmidrule(l){9-12} \cmidrule(l){13-15}" ///
            "Concept & Bracket & Std. Dev. & Mean & RMSE & \(R^2\) & Bias & Std. Dev. & RMSE & \(R^2\) & Bias & Std. Dev. & p-val. & & Diff \\ \midrule" ///
        ) ///
        footlines("\bottomrule \end{tabular}")

    // Table: recessions, average growth
    listtab income bracket recession_sd recession_mean_obs recession_fc_rmse recession_fc_r2_avg recession_mean_fc_err recession_sd_fc_err ///
            recession_resc_fc_rmse recession_resc_r2_avg recession_resc_mean_fc_err recession_resc_sd_fc_err recession_dm_pval_avg recession_dm_stars_avg recession_dm_diff_avg ///
        using "$tables/04-backtest-rescaling/backtest-table-avg-`lag'y-recession.tex", replace ///
        delimiter(" & ") ///
        vend(vend) ///
        headlines("\begin{tabular}{llccccccccccccc}" "\toprule" ///
            " & & \multicolumn{2}{c}{Observed growth} & \multicolumn{4}{c}{Full RTI prediction} & \multicolumn{4}{c}{Rescaling RTI prediction} & \multicolumn{3}{c}{DM test} \\ \cmidrule(l){3-4} \cmidrule(l){5-8} \cmidrule(l){9-12} \cmidrule(l){13-15}" ///
            "Concept & Bracket & Std. Dev. & Mean & RMSE & \(R^2\) & Bias & Std. Dev. & RMSE & \(R^2\) & Bias & Std. Dev. & p-val. & & Diff \\ \midrule" ///
        ) ///
        footlines("\bottomrule \end{tabular}")

    // Table: all years, share changes
    listtab income bracket all_sd_shr all_mean_obs_shr all_correct_sign_shr all_fc_rmse_shr all_fc_r2_shr all_mean_fc_err_shr all_sd_fc_err_shr ///
            all_resc_correct_sign_shr all_resc_fc_rmse_shr all_resc_r2_shr all_resc_mean_fc_err_shr all_resc_sd_fc_err_shr all_dm_pval_shr all_dm_stars_shr all_dm_diff_shr ///
        using "$tables/04-backtest-rescaling/backtest-table-share-`lag'y.tex", replace ///
        delimiter(" & ") ///
        vend(vend) ///
        headlines("\begin{tabular}{llccccccccccccccc}" "\toprule" ///
            " & & \multicolumn{2}{c}{Observed change} & \multicolumn{5}{c}{Full RTI prediction} & \multicolumn{5}{c}{Rescaling RTI prediction} & \multicolumn{3}{c}{DM test} \\ \cmidrule(l){3-4} \cmidrule(l){5-9} \cmidrule(l){10-14} \cmidrule(l){15-17}" ///
            "Concept & Bracket & Std. Dev. & Mean & \begin{tabular}[c]{@{}c@{}}Correct\\sign\end{tabular} & RMSE & \(R^2\) & Bias & Std. Dev. & \begin{tabular}[c]{@{}c@{}}Correct\\sign\end{tabular} & RMSE & \(R^2\) & Bias & Std. Dev. & p-val. & & Diff \\ \midrule" ///
        ) ///
        footlines("\bottomrule \end{tabular}")

    // Table: excl. tax reforms, share changes
    listtab income bracket notax_sd_shr notax_mean_obs_shr notax_correct_sign_shr notax_fc_rmse_shr notax_fc_r2_shr notax_mean_fc_err_shr notax_sd_fc_err_shr ///
            notax_resc_correct_sign_shr notax_resc_fc_rmse_shr notax_resc_r2_shr notax_resc_mean_fc_err_shr notax_resc_sd_fc_err_shr notax_dm_pval_shr notax_dm_stars_shr notax_dm_diff_shr ///
        using "$tables/04-backtest-rescaling/backtest-table-share-`lag'y-notax.tex", replace ///
        delimiter(" & ") ///
        vend(vend) ///
        headlines("\begin{tabular}{llccccccccccccccc}" "\toprule" ///
            " & & \multicolumn{2}{c}{Observed change} & \multicolumn{5}{c}{Full RTI prediction} & \multicolumn{5}{c}{Rescaling RTI prediction} & \multicolumn{3}{c}{DM test} \\ \cmidrule(l){3-4} \cmidrule(l){5-9} \cmidrule(l){10-14} \cmidrule(l){15-17}" ///
            "Concept & Bracket & Std. Dev. & Mean & \begin{tabular}[c]{@{}c@{}}Correct\\sign\end{tabular} & RMSE & \(R^2\) & Bias & Std. Dev. & \begin{tabular}[c]{@{}c@{}}Correct\\sign\end{tabular} & RMSE & \(R^2\) & Bias & Std. Dev. & p-val. & & Diff \\ \midrule" ///
        ) ///
        footlines("\bottomrule \end{tabular}")

    // Table: recessions, share changes
    listtab income bracket recession_sd_shr recession_mean_obs_shr recession_correct_sign_shr recession_fc_rmse_shr recession_fc_r2_shr recession_mean_fc_err_shr recession_sd_fc_err_shr ///
            recession_resc_correct_sign_shr recession_resc_fc_rmse_shr recession_resc_r2_shr recession_resc_mean_fc_err_shr recession_resc_sd_fc_err_shr recession_dm_pval_shr recession_dm_stars_shr recession_dm_diff_shr ///
        using "$tables/04-backtest-rescaling/backtest-table-share-`lag'y-recession.tex", replace ///
        delimiter(" & ") ///
        vend(vend) ///
        headlines("\begin{tabular}{llccccccccccccccc}" "\toprule" ///
            " & & \multicolumn{2}{c}{Observed change} & \multicolumn{5}{c}{Full RTI prediction} & \multicolumn{5}{c}{Rescaling RTI prediction} & \multicolumn{3}{c}{DM test} \\ \cmidrule(l){3-4} \cmidrule(l){5-9} \cmidrule(l){10-14} \cmidrule(l){15-17}" ///
            "Concept & Bracket & Std. Dev. & Mean & \begin{tabular}[c]{@{}c@{}}Correct\\sign\end{tabular} & RMSE & \(R^2\) & Bias & Std. Dev. & \begin{tabular}[c]{@{}c@{}}Correct\\sign\end{tabular} & RMSE & \(R^2\) & Bias & Std. Dev. & p-val. & & Diff \\ \midrule" ///
        ) ///
        footlines("\bottomrule \end{tabular}")
}
