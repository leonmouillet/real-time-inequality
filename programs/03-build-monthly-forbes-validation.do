// -------------------------------------------------------------------------- //
// Validation graphs for Forbes 400 dissagregation methods
// -------------------------------------------------------------------------- //

local ref_month 8

// Reference-month x-lines and x-labels for the validation period
// (July for 2020, August otherwise)
local ref_month_lines  ""
local ref_month_labels ""
forvalues y = 2020/2025 {
    local am    = cond(`y' == 2020, 7, `ref_month')
    local mname = cond(`am' == 7, "Jul", "Aug")
    local ref_month_lines  "`ref_month_lines' `=ym(`y', `am')'"
    local ref_month_labels `"`ref_month_labels' `=ym(`y', `am')' "`mname' `y'""'
}

// -------------------------------------------------------------------------- //
// Prepare data
// -------------------------------------------------------------------------- //

// RT: 2020+ individual data ranked within month
use "$work/03-build-monthly-forbes/forbes-monthly-micro-validation.dta", clear
keep if source == "realtime" & year >= 2020
generate wealth_rt = wealth
bysort year month (wealth_rt): generate rank_rt = _N - _n + 1
keep forbes_uri year month time wealth_rt rank_rt
duplicates drop forbes_uri year month, force
tempfile rt_traj
save `rt_traj'

// Annual per method: 2020+ individual data ranked within month
use "$work/03-build-monthly-forbes/forbes-monthly-micro-validation.dta", clear
keep if year >= 2020 & source != "realtime"
foreach m in m0 m1 m2 {
    preserve
        keep if source == "annual-`m'"
        bysort year month (wealth): generate rank_ann = _N - _n + 1
        keep forbes_uri name year month time wealth rank_ann
        tempfile ann_traj_`m'
        save `ann_traj_`m''
    restore
}

// RT aggregate: 2020+ top-N total wealth by month
use "$work/03-build-monthly-forbes/forbes-monthly-micro-validation.dta", clear
keep if source == "realtime" & year >= 2020
generate wealth_rt = wealth
bysort year month (wealth_rt): generate rank_rt = _N - _n + 1
foreach N in 400 200 20 {
    generate w_rt_`N' = cond(rank_rt <= `N', wealth_rt, 0)
}
gcollapse (sum) w_rt_400 w_rt_200 w_rt_20, by(time)
foreach N in 400 200 20 {
    replace w_rt_`N' = w_rt_`N' / 1e12
}
tempfile rt_topN
save `rt_topN'

// RT aggregate: full period
use "$work/03-build-monthly-forbes/forbes-monthly-micro-validation.dta", clear
keep if source == "realtime"
generate wealth_rt = wealth
bysort year month (wealth_rt): generate rank_rt = _N - _n + 1
foreach N in 400 200 20 {
    generate w_rt_`N' = cond(rank_rt <= `N', wealth_rt, 0)
}
gcollapse (sum) w_rt_400 w_rt_200 w_rt_20, by(time)
foreach N in 400 200 20 {
    replace w_rt_`N' = w_rt_`N' / 1e12
}
tempfile rt_topN_full
save `rt_topN_full'

// -------------------------------------------------------------------------- //
// Gross aggregates
// -------------------------------------------------------------------------- //

foreach m in m0 m1 m2 {
    local M = upper("`m'")

    // Validation period
    use "$work/03-build-monthly-forbes/forbes-monthly-micro-validation.dta", clear
    keep if source == "annual-`m'" & year >= 2020
    bysort year month (wealth): generate rank_ann = _N - _n + 1
    foreach N in 400 200 20 {
        generate w_ann_`N' = cond(rank_ann <= `N', wealth, 0)
    }
    gcollapse (sum) w_ann_400 w_ann_200 w_ann_20, by(time)
    foreach N in 400 200 20 {
        replace w_ann_`N' = w_ann_`N' / 1e12
    }
    merge 1:1 time using `rt_topN', nogenerate keep(match)
    sort time

    twoway ///
        (line w_ann_400 time, lcolor(navy)      lwidth(medium)) ///
        (line w_rt_400  time, lcolor(navy)      lwidth(medium) lpattern(dash)) ///
        (line w_ann_200 time, lcolor(dkgreen)   lwidth(medium)) ///
        (line w_rt_200  time, lcolor(dkgreen)   lwidth(medium) lpattern(dash)) ///
        (line w_ann_20  time, lcolor(maroon) lwidth(medium)) ///
        (line w_rt_20   time, lcolor(maroon) lwidth(medium) lpattern(dash)), ///
        legend(order(1 "Top 400 – Forbes 400" 2 "Top 400 – RT Forbes" ///
                     3 "Top 200 – Forbes 400" 4 "Top 200 – RT Forbes" ///
                     5 "Top 20 – Forbes 400"  6 "Top 20 – RT Forbes") ///
               position(6) ring(1) cols(2) size(small)) ///
        xline(`ref_month_lines', lpattern(dot) lcolor(gs10) lwidth(thin)) ///
        xlabel(`ref_month_labels') xtitle("") ytitle("Total wealth ($ tn)") ///
        title("Method `M' – Disaggregated Forbes 400 vs RT Forbes")
    graph export "$graphs/03-build-monthly-forbes-validation/gross-topN-`m'.pdf", replace

    // Full period
    use "$work/03-build-monthly-forbes/forbes-monthly-micro-validation.dta", clear
    keep if source == "annual-`m'"
    bysort year month (wealth): generate rank_ann = _N - _n + 1
    foreach N in 400 200 20 {
        generate w_ann_`N' = cond(rank_ann <= `N', wealth, 0)
    }
    gcollapse (sum) w_ann_400 w_ann_200 w_ann_20, by(time)
    foreach N in 400 200 20 {
        replace w_ann_`N' = w_ann_`N' / 1e12
    }
    sort time

    twoway ///
        (line w_ann_400 time, lcolor(navy)      lwidth(medium)) ///
        (line w_ann_200 time, lcolor(dkgreen)   lwidth(medium)) ///
        (line w_ann_20  time, lcolor(maroon) lwidth(medium)), ///
        legend(order(1 "Top 400" 2 "Top 200" 3 "Top 20") ///
               position(6) ring(1) cols(3) size(small)) ///
        xtitle("") ytitle("Total wealth ($ tn)") ///
		xlabel(`=ym(1985,1)'(120)`=ym(2025,1)') ///
        title("Method `M' – Disaggregated Forbes 400 series")
    graph export "$graphs/03-build-monthly-forbes-validation/gross-topN-full-`m'.pdf", replace
}

// -------------------------------------------------------------------------- //
// Relative gap and bias summary — all methods compared
// -------------------------------------------------------------------------- //

foreach m in m0 m1 m2 {
    use "$work/03-build-monthly-forbes/forbes-monthly-micro-validation.dta", clear
    keep if source == "annual-`m'" & year >= 2020
    bysort year month (wealth): generate rank_ann = _N - _n + 1
    foreach N in 400 200 20 {
        generate w_`m'_`N' = cond(rank_ann <= `N', wealth, 0)
    }
    gcollapse (sum) w_`m'_400 w_`m'_200 w_`m'_20, by(time)
    foreach N in 400 200 20 {
        replace w_`m'_`N' = w_`m'_`N' / 1e12
    }
    tempfile agg_`m'
    save `agg_`m''
}

use `agg_m0', clear
merge 1:1 time using `agg_m1', nogenerate
merge 1:1 time using `agg_m2', nogenerate
merge 1:1 time using `rt_topN', nogenerate keep(match)
sort time

foreach m in m0 m1 m2 {
    foreach N in 400 200 20 {
        generate gap_`m'_`N'    = (w_`m'_`N' - w_rt_`N') / w_rt_`N' * 100
        generate absgap_`m'_`N' = abs(gap_`m'_`N')
    }
}

// Relative gap time series — top 200 only, single panel
twoway ///
    (line gap_m0_200 time, lcolor(maroon) lwidth(medium)) ///
    (line gap_m1_200 time, lcolor(dkgreen)   lwidth(medium)) ///
    (line gap_m2_200 time, lcolor(navy)       lwidth(medium)), ///
    yline(0, lpattern(dot) lcolor(black) lwidth(thin)) ///
    xline(`ref_month_lines', lpattern(dot) lcolor(gs10) lwidth(thin)) ///
    legend(order(1 "M0" 2 "M1" 3 "M2") position(6) ring(1) cols(3)) ///
    xlabel(`ref_month_labels') ///
    ytitle("(Annual – RT) / RT × 100 (%)") xtitle("") ///
    title("Disaggregated Forbes 400 vs RT Forbes:" "Relative gap by method (Top 200, 2020–present)", size(small))
graph export "$graphs/03-build-monthly-forbes-validation/gap-series.pdf", replace

// Mean absolute |gap| by months since anchor — top 200 and top 20
preserve
    generate months_since = mod(month(dofm(time)) - `ref_month', 12)
    gcollapse (mean) absgap_m0_200 absgap_m1_200 absgap_m2_200 ///
                     absgap_m0_20  absgap_m1_20  absgap_m2_20, by(months_since)
    sort months_since

    local ymax_sa = 0
    foreach v of varlist absgap_m0_200 absgap_m1_200 absgap_m2_200 ///
                         absgap_m0_20  absgap_m1_20  absgap_m2_20 {
        summarize `v', meanonly
        if r(max) > `ymax_sa' local ymax_sa = r(max)
    }
    local ymax_sa = ceil(`ymax_sa' / 5) * 5

    foreach N in 200 20 {
        twoway ///
            (line absgap_m0_`N' months_since, lcolor(maroon) lwidth(medium)) ///
            (line absgap_m1_`N' months_since, lcolor(dkgreen)   lwidth(medium)) ///
            (line absgap_m2_`N' months_since, lcolor(navy)       lwidth(medium)), ///
            xline(0, lpattern(dot) lcolor(gs10) lwidth(thin)) ///
            legend(order(1 "M0" 2 "M1" 3 "M2") position(6) ring(1) cols(3)) ///
            xlabel(0 "Aug" 1 "Sep" 2 "Oct" 3 "Nov" 4 "Dec" ///
                   5 "Jan" 6 "Feb" 7 "Mar" 8 "Apr" 9 "May" 10 "Jun" 11 "Jul", ///
                   angle(45)) ///
            yscale(range(0 `ymax_sa')) ylabel(0(5)`ymax_sa') ///
            xtitle("Months since anchor") ytitle("Mean |gap| (%)") ///
            title("Top `N'") ///
            name(g2b_`N', replace) nodraw
    }

    graph combine g2b_200 g2b_20, cols(2) ///
        title("Disaggregated Forbes 400 vs RT Forbes:" "Mean absolute gap by months since anchor (2020–present)", size(small))
    graph export "$graphs/03-build-monthly-forbes-validation/gap-by-month.pdf", replace
restore

// Gap summary bar chart — mean gap and mean |gap|
foreach v of varlist gap_* absgap_* {
    summarize `v', meanonly
    local m_`v' = r(mean)
}

clear
set obs 9
generate str4 method    = ""
generate int  Nval       = .
generate      meangap   = .
generate      meanabsgap = .
generate int  x          = .

local k = 0
local xbase = 0
foreach N in 400 200 20 {
    local xbase = `xbase' + 1
    local j = 0
    foreach m in m0 m1 m2 {
        local k = `k' + 1
        local j = `j' + 1
        replace method     = "`m'"                    in `k'
        replace Nval       = `N'                      in `k'
        replace meangap    = `m_gap_`m'_`N''          in `k'
        replace meanabsgap = `m_absgap_`m'_`N''       in `k'
        replace x          = (`xbase' - 1) * 4 + `j' in `k'
    }
}

twoway ///
    (bar meangap x if method == "m0", color(maroon) barwidth(0.8)) ///
    (bar meangap x if method == "m1", color(dkgreen)   barwidth(0.8)) ///
    (bar meangap x if method == "m2", color(navy)       barwidth(0.8)), ///
    yline(0, lpattern(dot) lcolor(black) lwidth(thin)) ///
    yscale(range(0 .)) ///
    xlabel(2 "Top 400" 6 "Top 200" 10 "Top 20", noticks) xtitle("") ///
    ytitle("Mean relative gap (%)") ///
    legend(order(1 "M0" 2 "M1" 3 "M2") rows(1)) ///
    title("Mean relative gap (%)", size(small)) ///
    name(g3a, replace) nodraw

twoway ///
    (bar meanabsgap x if method == "m0", color(maroon) barwidth(0.8)) ///
    (bar meanabsgap x if method == "m1", color(dkgreen)   barwidth(0.8)) ///
    (bar meanabsgap x if method == "m2", color(navy)       barwidth(0.8)), ///
    yscale(range(0 .)) ///
    xlabel(2 "Top 400" 6 "Top 200" 10 "Top 20", noticks) xtitle("") ///
    ytitle("Mean absolute gap (%)") ///
    legend(order(1 "M0" 2 "M1" 3 "M2") rows(1)) ///
    title("Mean absolute gap (%)", size(small)) ///
    name(g3b, replace) nodraw

graph combine g3a g3b, cols(2) ///
    title("Disaggregated Forbes 400 vs RT Forbes:" "Gap summary (2020–present)", size(small))
graph export "$graphs/03-build-monthly-forbes-validation/gap-summary.pdf", replace

// -------------------------------------------------------------------------- //
// Individual gap distribution chart — matched top-200
// -------------------------------------------------------------------------- //

foreach m in m0 m1 m2 {
    use `ann_traj_`m'', clear
    merge 1:1 forbes_uri year month using `rt_traj', keep(match) nogenerate
    bysort time (wealth): generate rank_match = _N - _n + 1
    keep if rank_match <= 200
    generate bias = (wealth - wealth_rt) / wealth_rt * 100
    gcollapse (p10) p10=bias (p25) p25=bias (p50) p50=bias ///
              (p75) p75=bias (p90) p90=bias, by(time)
    sort time
    tempfile bias_dist_`m'
    save `bias_dist_`m''
}

local ymin =  9999
local ymax = -9999
foreach m in m0 m1 m2 {
    use `bias_dist_`m'', clear
    summarize p10
    if r(min) < `ymin' local ymin = r(min)
    summarize p90
    if r(max) > `ymax' local ymax = r(max)
}

local ymin = floor(`ymin' / 10) * 10
local ymax = ceil(`ymax'  / 10) * 10


foreach m in m0 m1 m2 {
    local M = upper("`m'")
    use `bias_dist_`m'', clear

    twoway ///
        (rarea p10 p90 time, color(navy%15)) ///
        (rarea p25 p75 time, color(navy%30)) ///
        (line  p50 time, lcolor(navy) lwidth(medium)), ///
        legend(order(1 "P10–P90" 2 "P25–P75" 3 "Median") ///
               position(6) ring(0) cols(3)) ///
        yline(0, lpattern(dot) lcolor(black) lwidth(thin)) ///
        xline(`ref_month_lines', lpattern(dot) lcolor(gs10) lwidth(thin)) ///
        xlabel(`ref_month_labels') yscale(range(`ymin' `ymax')) ///
        xtitle("") ytitle("(Annual – RT) / RT × 100 (%)") ///
        title("Method `M' – Individual gap distribution" "(matched top 200, 2020–present)", size(small))
    graph export "$graphs/03-build-monthly-forbes-validation/individual-gap-dist-`m'.pdf", replace
}

// -------------------------------------------------------------------------- //
// Classification coverage
// -------------------------------------------------------------------------- //

use "$work/03-build-monthly-forbes/ann-m2-tickers.dta", clear
keep if (month == `ref_month') | (year == 2020 & month == 7)

bysort year (wealth): generate rank_ann = _N - _n + 1

foreach N in 400 200 20 {
    generate w_total_`N'    = cond(rank_ann <= `N', wealth,         0)
    generate w_priv_`N'     = cond(rank_ann <= `N', private_wealth, 0)
    generate w_pub_tick_`N' = cond(rank_ann <= `N' &  uses_ticker_m2,                     public_wealth, 0)
    generate w_pub_wils_`N' = cond(rank_ann <= `N' & !uses_ticker_m2 & public_wealth > 0, public_wealth, 0)
    generate n_total_`N'    = cond(rank_ann <= `N', 1, 0)
    generate n_priv_`N'     = cond(rank_ann <= `N' & public_wealth == 0,              1, 0)
    generate n_pub_tick_`N' = cond(rank_ann <= `N' &  uses_ticker_m2,                    1, 0)
    generate n_pub_wils_`N' = cond(rank_ann <= `N' & !uses_ticker_m2 & public_wealth > 0, 1, 0)
}

gcollapse (sum) w_total_400 w_priv_400 w_pub_tick_400 w_pub_wils_400 ///
               w_total_200 w_priv_200 w_pub_tick_200 w_pub_wils_200 ///
               w_total_20  w_priv_20  w_pub_tick_20  w_pub_wils_20  ///
               n_total_400 n_priv_400 n_pub_tick_400 n_pub_wils_400 ///
               n_total_200 n_priv_200 n_pub_tick_200 n_pub_wils_200 ///
               n_total_20  n_priv_20  n_pub_tick_20  n_pub_wils_20, by(year)

foreach N in 400 200 20 {
    generate sh_priv_`N'     = w_priv_`N'     / w_total_`N' * 100
    generate sh_pub_wils_`N' = w_pub_wils_`N' / w_total_`N' * 100
    generate sh_pub_tick_`N' = w_pub_tick_`N' / w_total_`N' * 100
    generate cum1w_`N' = sh_priv_`N'
    generate cum2w_`N' = sh_priv_`N' + sh_pub_wils_`N'
    generate cum3w_`N' = cum2w_`N'   + sh_pub_tick_`N'
    generate cn_priv_`N'     = n_priv_`N'     / n_total_`N' * 100
    generate cn_pub_wils_`N' = n_pub_wils_`N' / n_total_`N' * 100
    generate cn_pub_tick_`N' = n_pub_tick_`N' / n_total_`N' * 100
    generate cum1n_`N' = cn_priv_`N'
    generate cum2n_`N' = cn_priv_`N' + cn_pub_wils_`N'
    generate cum3n_`N' = cum2n_`N'   + cn_pub_tick_`N'
}

sort year

// Wealth share
foreach N in 400 200 20 {
    twoway ///
        (area cum3w_`N' year, color(navy%70)     lwidth(none)) ///
        (area cum2w_`N' year, color(gs10)         lwidth(none)) ///
        (area cum1w_`N' year, color(maroon%70) lwidth(none)), ///
        legend(order(3 "Private or ambiguous" 2 "Public – Wilshire" ///
                     1 "Public – individual ticker") ///
               position(6) ring(0) cols(1) size(vsmall)) ///
        xtitle("") ytitle("") ///
        yscale(range(0 100)) ylabel(0(25)100) ///
        xlabel(1982(10)2025, angle(45)) ///
        title("Top `N'") ///
        name(g_covw_`N', replace) nodraw
}
graph combine g_covw_400 g_covw_200 g_covw_20, cols(3) ///
    title("M2 – Wealth breakdown by treatment", size(small)) ///
    l1title("Share of group wealth (%)") xsize(10) ysize(4)
graph export "$graphs/03-build-monthly-forbes-validation/classification-coverage-wealth.pdf", replace

// Count share
foreach N in 400 200 20 {
    twoway ///
        (area cum3n_`N' year, color(navy%70)     lwidth(none)) ///
        (area cum2n_`N' year, color(gs10)         lwidth(none)) ///
        (area cum1n_`N' year, color(maroon%70) lwidth(none)), ///
        legend(order(3 "Private or ambiguous" 2 "Public – Wilshire" ///
                     1 "Public – individual ticker") ///
               position(6) ring(0) cols(1) size(vsmall)) ///
        xtitle("") ytitle("") ///
        yscale(range(0 100)) ylabel(0(25)100) ///
        xlabel(1982(10)2025, angle(45)) ///
        title("Top `N'") ///
        name(g_covn_`N', replace) nodraw
}
graph combine g_covn_400 g_covn_200 g_covn_20, cols(3) ///
    title("M2 – Individual count breakdown by treatment", size(small)) ///
    l1title("Share of individuals (%)") xsize(10) ysize(4)
graph export "$graphs/03-build-monthly-forbes-validation/classification-coverage-count.pdf", replace

// -------------------------------------------------------------------------- //
// Individual trajectories
// -------------------------------------------------------------------------- //

foreach m in m0 m1 m2 {
    local M = upper("`m'")

    // Top-9 from matched individuals in 2020
    use `ann_traj_`m'', clear
    merge 1:1 forbes_uri year month using `rt_traj', keep(match) nogenerate
    keep if year == 2020
    gcollapse (mean) mean_w_2020 = wealth_rt, by(forbes_uri name)
    gsort -mean_w_2020
    keep if _n <= 9
    keep forbes_uri
    tempfile top9_`m'
    save `top9_`m''

    // Trajectory data for top-9
    use `ann_traj_`m'', clear
    merge 1:1 forbes_uri year month using `rt_traj', keep(match) nogenerate
    merge m:1 forbes_uri using `top9_`m'', keep(match) nogenerate

    generate wealth_bn    = wealth    / 1e9
    generate wealth_rt_bn = wealth_rt / 1e9

    sort name time
	twoway ///
			(line wealth_bn    time, lcolor(navy)      lwidth(medium)) ///
			(line wealth_rt_bn time, lcolor(maroon) lwidth(medium) lpattern(dash)), ///
			by(name, title("Method `M' – Disaggregated Forbes 400 vs RT Forbes" "trajectories (Top 9 individuals)", size(small)) ///
					 note("") compact yrescale) ///
			subtitle(, fcolor(white) lcolor(white) size(vsmall)) ///
			legend(order(1 "Annual `M'" 2 "RT") position(6) ring(0) cols(2)) ///
			xlabel(`=ym(2021,08)'(36)`=ym(2024,08)') ///
			xline(`ref_month_lines', lpattern(dot) lcolor(gs10) lwidth(thin)) ///
			xtitle("") ytitle("Wealth ($ bn)")
    graph export "$graphs/03-build-monthly-forbes-validation/traj-individuals-`m'.pdf", replace
}

// -------------------------------------------------------------------------- //
// Composition overlap and bias
// -------------------------------------------------------------------------- //

use `ann_traj_m2', clear
merge 1:1 forbes_uri year month using `rt_traj', nogenerate

replace rank_ann = 99999 if missing(rank_ann)
replace rank_rt  = 99999 if missing(rank_rt)

foreach N in 400 200 20 {
    generate byte in_both_n_`N' = (rank_ann <= `N' & rank_rt <= `N')
    generate byte in_ann_n_`N'  = (rank_ann <= `N')
    generate w_ann_`N'  = cond(rank_ann <= `N', wealth, 0)
    generate w_both_`N' = cond(rank_ann <= `N' & rank_rt <= `N', wealth, 0)
}

gcollapse (sum) in_both_n_400 in_both_n_200 in_both_n_20 ///
               in_ann_n_400  in_ann_n_200  in_ann_n_20  ///
               w_ann_400 w_ann_200 w_ann_20              ///
               w_both_400 w_both_200 w_both_20, by(time)

foreach N in 400 200 20 {
    generate sh_count_`N' = in_both_n_`N' / in_ann_n_`N' * 100
    generate sh_wealth_`N' = w_both_`N'   / w_ann_`N'    * 100
}

sort time
tempfile comp_overlap
save `comp_overlap'

// Fraction of annual top-N individuals also present in RT top-N, by month
use `comp_overlap', clear
twoway ///
    (line sh_count_400 time, lcolor(navy)     lwidth(medium)) ///
    (line sh_count_200 time, lcolor(dkgreen)  lwidth(medium)) ///
    (line sh_count_20  time, lcolor(maroon) lwidth(medium)), ///
    yline(100, lpattern(dot) lcolor(black) lwidth(thin)) ///
    xline(`ref_month_lines', lpattern(dot) lcolor(gs10) lwidth(thin)) ///
    legend(order(1 "Top 400" 2 "Top 200" 3 "Top 20") position(6) ring(0) cols(3)) ///
    xlabel(`ref_month_labels') ///
    yscale(range(0 .)) ylabel(0(20)100) ///
    ytitle("Share of annual top-N present in RT top-N (%)") xtitle("") ///
    title("M2 – Composition overlap between disaggregated" "Forbes 400 and RT Forbes (Count)", size(small))
graph export "$graphs/03-build-monthly-forbes-validation/comp-overlap-count-m2.pdf", replace

//  Fraction of annual top-N wealth belonging to matched individuals, by month
use `comp_overlap', clear
twoway ///
    (line sh_wealth_400 time, lcolor(navy)     lwidth(medium)) ///
    (line sh_wealth_200 time, lcolor(dkgreen)  lwidth(medium)) ///
    (line sh_wealth_20  time, lcolor(maroon) lwidth(medium)), ///
    yline(100, lpattern(dot) lcolor(black) lwidth(thin)) ///
    xline(`ref_month_lines', lpattern(dot) lcolor(gs10) lwidth(thin)) ///
    legend(order(1 "Top 400" 2 "Top 200" 3 "Top 20") position(6) ring(0) cols(3)) ///
    xlabel(`ref_month_labels') ///
    yscale(range(0 .)) ylabel(0(20)100) ///
    ytitle("Share of annual top-N wealth in RT top-N (%)") xtitle("") ///
    title("M2 – Composition overlap between disaggregated" "Forbes 400 and RT Forbes (Wealth share)", size(small))
graph export "$graphs/03-build-monthly-forbes-validation/comp-overlap-wealth-m2.pdf", replace

// Gross aggregate gap vs matched-only gap (top 200)
use `ann_traj_m2', clear
merge 1:1 forbes_uri year month using `rt_traj', keep(match) nogenerate

bysort year month (wealth):    generate rank_ann2 = _N - _n + 1
bysort year month (wealth_rt): generate rank_rt2  = _N - _n + 1

generate w_match_ann_200 = cond(rank_ann2 <= 200 & rank_rt2 <= 200, wealth,    0)
generate w_match_rt_200  = cond(rank_ann2 <= 200 & rank_rt2 <= 200, wealth_rt, 0)

gcollapse (sum) w_match_ann_200 w_match_rt_200, by(time)
foreach v in w_match_ann_200 w_match_rt_200 {
    replace `v' = `v' / 1e12
}
generate gap_match_200 = (w_match_ann_200 - w_match_rt_200) / w_match_rt_200 * 100

tempfile comp_match
save `comp_match'

use `agg_m2', clear
merge 1:1 time using `rt_topN', nogenerate keep(match)
generate gap_gross_200 = (w_m2_200 - w_rt_200) / w_rt_200 * 100
keep time gap_gross_200

merge 1:1 time using `comp_match', nogenerate
sort time

twoway ///
    (line gap_gross_200 time, lcolor(maroon) lwidth(medium)) ///
    (line gap_match_200 time, lcolor(navy)      lwidth(medium)), ///
    yline(0, lpattern(dot) lcolor(black) lwidth(thin)) ///
    xline(`ref_month_lines', lpattern(dot) lcolor(gs10) lwidth(thin)) ///
    legend(order(1 "Gross gap (all top 200)" 2 "Matched-only gap") ///
           position(6) ring(0) cols(2)) ///
    ytitle("(Annual M2 – RT) / RT × 100 (%)") xtitle("") ///
    title("M2 – Composition bias: gross vs matched gap" "(Top 200, 2020–present)", size(small))
graph export "$graphs/03-build-monthly-forbes-validation/comp-bias-m2.pdf", replace
