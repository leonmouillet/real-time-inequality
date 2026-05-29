// -------------------------------------------------------------------------- //
// Validation graphs for ultra-top wealth series
// -------------------------------------------------------------------------- //

local date_begin = ym(1976, 01)
local date_end   = $date_end

local grp1  "Top 0.0001%"
local grp2  "Top 0.00001%"
local unit1  adult_equal_split
local unit2  adult_households
local unit3  working_age_equal_split
local ulab1  "Equal Split"
local ulab2  "Households"
local ulab3  "Working-Age Equal Split"

local tmpdir = subinstr("`c(tmpdir)'", "\", "/", .)

use "$work/03-build-online-database/online-database-main.dta", clear
keep if group == "Total" & income == "wealth"
keep year month unit pop
greshape wide pop, i(year month) j(unit) string
rename popadult_equal_split        pop_aes
rename popadult_households         pop_ah
rename popworking_age_equal_split  pop_waes
tempfile pops
save `pops'

// Before-correction graphs (Forbes vs. microfiles, overlap 1982–1984)
use "$work/03-build-online-database/ultra-top-sources.dta", clear
keep if inlist(source, "Forbes", "Microfiles (raw)", "Microfiles (adjusted)")
generate t = ym(year, month)
format t %tm
replace value = value / 1e12
sort source group unit t
tempfile before_combined
save `before_combined'

use `before_combined', clear
forvalues ig = 1/2 {
    forvalues iu = 1/3 {
        twoway ///
            (line value t if source == "Forbes"     & group == "`grp`ig''" & unit == "`unit`iu''" ///
                & inrange(t, ym(1979,1), ym(1987,12)), lcolor(cranberry) lwidth(medium)) ///
            (line value t if source == "Microfiles (adjusted)" & group == "`grp`ig''" & unit == "`unit`iu''" ///
                & inrange(t, ym(1979,1), ym(1987,12)), lcolor(navy) lwidth(medium)) ///
			(line value t if source == "Microfiles (raw)" & group == "`grp`ig''" & unit == "`unit`iu''" ///
                & inrange(t, ym(1979,1), ym(1987,12)), lcolor(black) lwidth(msmall)) , ///
            xline(`=ym(1982,1)' `=ym(1984,12)', lpattern(dash) lcolor(gs10)) ///
            title("`grp`ig'' — `ulab`iu''", size(medsmall)) ///
            legend(order(1 "Forbes" 2 "Microfiles (Top400-adjusted)" 3 "Microfiles (raw)") rows(3) size(small)) ///
            xlabel(`=ym(1979,1)'(12)`=ym(1987,12)', angle(45) format(%tmCCYY)) ///
            xtitle("") ytitle("")
        graph save "`tmpdir'/vz`ig'`iu'.gph", replace
    }
    graph combine "`tmpdir'/vz`ig'1.gph" "`tmpdir'/vz`ig'2.gph" "`tmpdir'/vz`ig'3.gph", ///
        rows(1) cols(3) ycommon l1title("Wealth ($ trillions, nominal)", size(small)) ///
        name(row_zoom_`ig', replace) nodraw
}
graph combine row_zoom_1 row_zoom_2, rows(2) cols(1) ///
    title("Ultra-top wealth: Forbes vs. microfiles (before rescaling, 1979–1987)", size(medsmall))
graph export "$graphs/03-build-online-database-validation/ultra-top-valid-zoom.pdf", replace

// Ratio of sources (Forbes / microfiles, overlap 1982–1984)
use `before_combined', clear
keep if inrange(year, 1982, 1984)
keep year month unit group source value
rename value value_src
greshape wide value_src, i(year month unit group) j(source) string
rename value_srcForbes    value_forbes
rename value_srcMicrofiles__adjusted value_micro
rename value_srcMicrofiles__raw value_micro_raw
generate ratio_a = value_forbes / value_micro
generate ratio_r = value_forbes / value_micro_raw
generate t = ym(year, month)
format t %tm

forvalues ig = 1/2 {
    forvalues iu = 1/3 {
        twoway ///
            (line ratio_r t if group == "`grp`ig''" & unit == "`unit`iu''", ///
                lcolor(dkgreen) lwidth(medium)) ///
            (line ratio_a t if group == "`grp`ig''" & unit == "`unit`iu''", ///
                lcolor(maroon) lwidth(medium)) , ///
            yline(1, lpattern(dash) lcolor(gs10)) ///
            title("`grp`ig'' — `ulab`iu''", size(medsmall)) ///
            legend(order(1 "Forbes / Raw microfiles" 2 "Forbes / Adjusted microfiles") rows(3) size(small)) ///
			xtitle("") ytitle("") ylabel(, format(%9.2f))
        graph save "`tmpdir'/vr`ig'`iu'.gph", replace
    }
    graph combine "`tmpdir'/vr`ig'1.gph" "`tmpdir'/vr`ig'2.gph" "`tmpdir'/vr`ig'3.gph", ///
        rows(1) cols(3) name(row_ratio_`ig', replace) nodraw
}
graph combine row_ratio_1 row_ratio_2, rows(2) cols(1) ///
    title("Forbes / microfiles wealth ratio (before rescaling, 1982–1984)", size(medsmall))
graph export "$graphs/03-build-online-database-validation/ultra-top-valid-ratio.pdf", replace

// After-correction graphs (final spliced series: rescaled micro + Forbes)
use "$work/03-build-online-database/ultra-top-sources.dta", clear
keep if source == "Microfiles (rescaled)" | ///
        (source == "Forbes" & ym(year, month) >= ym(1982, 1))
generate t = ym(year, month)
format t %tm
replace value = value / 1e12
sort source group unit t
tempfile after_combined
save `after_combined'

use `after_combined', clear
forvalues ig = 1/2 {
    forvalues iu = 1/3 {
        twoway ///
            (line value t if source == "Microfiles (rescaled)" & group == "`grp`ig''" & unit == "`unit`iu''", ///
                lcolor(navy) lwidth(medthin) sort) ///
            (line value t if source == "Forbes" & group == "`grp`ig''" & unit == "`unit`iu''", ///
                lcolor(cranberry) lwidth(medthin) sort) , ///
            xline(`=ym(1982,1)', lpattern(dash) lcolor(gs10)) ///
            title("`grp`ig'' — `ulab`iu''", size(medsmall)) ///
            legend(order(1 "Microfiles (rescaled)" 2 "Forbes") rows(1) size(small)) ///
            xtitle("") ytitle("")
        graph save "`tmpdir'/vf`ig'`iu'.gph", replace
    }
    graph combine "`tmpdir'/vf`ig'1.gph" "`tmpdir'/vf`ig'2.gph" "`tmpdir'/vf`ig'3.gph", ///
        rows(1) cols(3) ycommon l1title("Wealth ($ trillions, nominal)", size(small)) ///
        name(row_full_`ig', replace) nodraw
}
graph combine row_full_1 row_full_2, rows(2) cols(1) ///
    title("Ultra-top wealth: final spliced series (microfiles + Forbes)", size(medsmall))
graph export "$graphs/03-build-online-database-validation/ultra-top-valid-full.pdf", replace

use `after_combined', clear
forvalues ig = 1/2 {
    forvalues iu = 1/3 {
        twoway ///
            (line value t if source == "Microfiles (rescaled)" & group == "`grp`ig''" & unit == "`unit`iu''" ///
                & inrange(t, ym(1979,1), ym(1987,12)), lcolor(navy) lwidth(medium) sort) ///
            (line value t if source == "Forbes" & group == "`grp`ig''" & unit == "`unit`iu''" ///
                & inrange(t, ym(1979,1), ym(1987,12)), lcolor(cranberry) lwidth(medium) sort) , ///
            xline(`=ym(1982,1)', lpattern(dash) lcolor(gs10)) ///
            title("`grp`ig'' — `ulab`iu''", size(medsmall)) ///
            legend(order(1 "Microfiles (rescaled)" 2 "Forbes") rows(1) size(small)) ///
            xlabel(`=ym(1979,1)'(12)`=ym(1987,12)', angle(45) format(%tmCCYY)) ///
            xtitle("") ytitle("")
        graph save "`tmpdir'/vza`ig'`iu'.gph", replace
    }
    graph combine "`tmpdir'/vza`ig'1.gph" "`tmpdir'/vza`ig'2.gph" "`tmpdir'/vza`ig'3.gph", ///
        rows(1) cols(3) ycommon l1title("Wealth ($ trillions, nominal)", size(small)) ///
        name(row_zoom_a_`ig', replace) nodraw
}
graph combine row_zoom_a_1 row_zoom_a_2, rows(2) cols(1) ///
    title("Ultra-top wealth: final spliced series (zoom 1979–1987)", size(medsmall))
graph export "$graphs/03-build-online-database-validation/ultra-top-valid-zoom-after.pdf", replace


// Population and cell count for ultra-top brackets
tempfile valid_ultra_pop
clear
save `valid_ultra_pop', emptyok

foreach pop_type in adult_equal_split adult_households working_age_equal_split {
    use "$work/03-tabulate-wealth/tabulation-hweal-`pop_type'.dta", clear
    keep if inrange(ym(year, month), `date_begin', `date_end')

    foreach frac_tag in f6 f7 {
        if "`frac_tag'" == "f6" {
            local gname "Top 0.0001%"
            local p_lo  9999990
        }
        else {
            local gname "Top 0.00001%"
            local p_lo  9999999
        }

        preserve
            keep if p >= `p_lo'
            gcollapse (sum) pop n_obs, by(year month)
            generate group = "`gname'"
            generate unit  = "`pop_type'"
            append using `valid_ultra_pop'
            save `valid_ultra_pop', replace
        restore
    }
}

use `valid_ultra_pop', clear
generate t = ym(year, month)
format t %tm

merge m:1 year month using `pops', nogenerate keep(match master)
generate pop_smooth = .
replace pop_smooth = round(pop_aes  * 0.000001)  if unit == "adult_equal_split"       & group == "Top 0.0001%"
replace pop_smooth = round(pop_ah   * 0.000001)  if unit == "adult_households"         & group == "Top 0.0001%"
replace pop_smooth = round(pop_waes * 0.000001)  if unit == "working_age_equal_split"  & group == "Top 0.0001%"
replace pop_smooth = round(pop_aes  * 0.0000001) if unit == "adult_equal_split"        & group == "Top 0.00001%"
replace pop_smooth = round(pop_ah   * 0.0000001) if unit == "adult_households"         & group == "Top 0.00001%"
replace pop_smooth = round(pop_waes * 0.0000001) if unit == "working_age_equal_split"  & group == "Top 0.00001%"
drop pop_aes pop_ah pop_waes

save `valid_ultra_pop', replace

forvalues ig = 1/2 {
    local gname = "`grp`ig''"
    local ftag  = cond(`ig' == 1, "f6", "f7")

    // --- Full period ---
    forvalues iu = 1/3 {
        local ytlab_nc = cond(`iu' == 1, "count", "")
        twoway (line n_obs t if group == "`gname'" & unit == "`unit`iu''", ///
                lcolor(cranberry) lwidth(medium)), ///
            title("`ulab`iu''", size(medsmall)) subtitle("Sample observations") ///
            xtitle("") ytitle("`ytlab_nc'", size(small)) ylabel(, format(%9.0f)) ///
            xlabel(`=ym(1976,1)'(60)`=ym(2025,1)', angle(45) format(%tmCCYY)) ///
            legend(off)
        graph save "`tmpdir'/vnc`ig'`iu'.gph", replace

        twoway ///
            (line pop_smooth t if group == "`gname'" & unit == "`unit`iu''", ///
                lcolor(navy) lwidth(medthick)) ///
            (line pop t if group == "`gname'" & unit == "`unit`iu''", ///
                lcolor(gs10) lwidth(thin)), ///
            title("`ulab`iu''", size(medsmall)) subtitle("Population") ///
            xtitle("") ytitle("") ylabel(, format(%9.1f)) ///
            xlabel(`=ym(1976,1)'(60)`=ym(2025,1)', angle(45) format(%tmCCYY)) ///
            legend(order(2 "Sum of weights (raw)" 1 "round(pop_tot * f)") rows(2) size(small))
        graph save "`tmpdir'/vpop`ig'`iu'.gph", replace
    }
    graph combine ///
        "`tmpdir'/vnc`ig'1.gph"  "`tmpdir'/vnc`ig'2.gph"  "`tmpdir'/vnc`ig'3.gph" ///
        "`tmpdir'/vpop`ig'1.gph" "`tmpdir'/vpop`ig'2.gph" "`tmpdir'/vpop`ig'3.gph", ///
        rows(2) cols(3) ///
        title("`gname' — population and cell coverage (full period)", size(medsmall))
    graph export "$graphs/03-build-online-database-validation/ultra-top-valid-pop-`ftag'.pdf", replace

    // --- Zoom 1976–1984 ---
    forvalues iu = 1/3 {
        local ytlab_nc = cond(`iu' == 1, "count", "")
        twoway (line n_obs t if group == "`gname'" & unit == "`unit`iu''" ///
                & inrange(t, ym(1976,1), ym(1984,12)), ///
                lcolor(cranberry) lwidth(medium)), ///
            title("`ulab`iu''", size(medsmall)) subtitle("Sample observations") ///
            xtitle("") ytitle("`ytlab_nc'", size(small)) ylabel(, format(%9.0f)) ///
            xlabel(`=ym(1976,1)'(12)`=ym(1984,12)', angle(45) format(%tmCCYY)) ///
            legend(off)
        graph save "`tmpdir'/vncz`ig'`iu'.gph", replace

        twoway ///
            (line pop_smooth t if group == "`gname'" & unit == "`unit`iu''" ///
                & inrange(t, ym(1976,1), ym(1984,12)), ///
                lcolor(navy) lwidth(medthick)) ///
            (line pop t if group == "`gname'" & unit == "`unit`iu''" ///
                & inrange(t, ym(1976,1), ym(1984,12)), ///
                lcolor(gs10) lwidth(thin)), ///
            title("`ulab`iu''", size(medsmall)) subtitle("Population") ///
            xtitle("") ytitle("") ylabel(, format(%9.1f)) ///
            xlabel(`=ym(1976,1)'(12)`=ym(1984,12)', angle(45) format(%tmCCYY)) ///
            legend(order(2 "Sum of weights (raw)" 1 "round(pop_tot * f)") rows(2) size(small))
        graph save "`tmpdir'/vpopz`ig'`iu'.gph", replace
    }
    graph combine ///
        "`tmpdir'/vncz`ig'1.gph"  "`tmpdir'/vncz`ig'2.gph"  "`tmpdir'/vncz`ig'3.gph" ///
        "`tmpdir'/vpopz`ig'1.gph" "`tmpdir'/vpopz`ig'2.gph" "`tmpdir'/vpopz`ig'3.gph", ///
        rows(2) cols(3) ///
        title("`gname' — population and cell coverage — zoom 1976–1984", size(medsmall))
    graph export "$graphs/03-build-online-database-validation/ultra-top-valid-pop-`ftag'-zoom.pdf", replace
	
    // --- Zoom 2010–present ---
    forvalues iu = 1/3 {
        local ytlab_nc = cond(`iu' == 1, "count", "")
        twoway (line n_obs t if group == "`gname'" & unit == "`unit`iu''" ///
                & inrange(t, ym(2010,1), ym(2025,12)), ///
                lcolor(cranberry) lwidth(medium)), ///
            title("`ulab`iu''", size(medsmall)) subtitle("Sample observations") ///
            xtitle("") ytitle("`ytlab_nc'", size(small)) ylabel(, format(%9.0f)) ///
            xlabel(`=ym(2010,1)'(12)`=ym(2025,12)', angle(45) format(%tmCCYY)) ///
            legend(off)
        graph save "`tmpdir'/vncz`ig'`iu'.gph", replace

        twoway ///
            (line pop_smooth t if group == "`gname'" & unit == "`unit`iu''" ///
                & inrange(t, ym(2010,1), ym(2025,12)), ///
                lcolor(navy) lwidth(medthick)) ///
            (line pop t if group == "`gname'" & unit == "`unit`iu''" ///
                & inrange(t, ym(2010,1), ym(2025,12)), ///
                lcolor(gs10) lwidth(thin)), ///
            title("`ulab`iu''", size(medsmall)) subtitle("Population") ///
            xtitle("") ytitle("") ylabel(, format(%9.1f)) ///
            xlabel(`=ym(2010,1)'(12)`=ym(2025,12)', angle(45) format(%tmCCYY)) ///
            legend(order(2 "Sum of weights (raw)" 1 "round(pop_tot * f)") rows(2) size(small))
        graph save "`tmpdir'/vpopz`ig'`iu'.gph", replace
    }
    graph combine ///
        "`tmpdir'/vncz`ig'1.gph"  "`tmpdir'/vncz`ig'2.gph"  "`tmpdir'/vncz`ig'3.gph" ///
        "`tmpdir'/vpopz`ig'1.gph" "`tmpdir'/vpopz`ig'2.gph" "`tmpdir'/vpopz`ig'3.gph", ///
        rows(2) cols(3) ///
        title("`gname' — population and cell coverage — zoom 2010–2025", size(medsmall))
    graph export "$graphs/03-build-online-database-validation/ultra-top-valid-pop-`ftag'-zoom-recent.pdf", replace
}