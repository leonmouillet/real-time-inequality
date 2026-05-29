// -------------------------------------------------------------------------- //
// Analyse the evolution of wage growth during the last two recessions
// -------------------------------------------------------------------------- //

global pre2008_peak    = ym(2007, 12)
global post2008_recov  = ym(2017, 12)
global preCOVID_peak   = ym(2020, 02)
global postCOVID_recov = ym(2022, 06)


// -------------------------------------------------------------------------- //
// Evolution of employment
// -------------------------------------------------------------------------- //

import fred PAYEMS, clear
generate year  = year(daten)
generate month = month(daten)
generate nonfarm_emp = 1000*PAYEMS
keep year month nonfarm_emp
keep if year >= 2006

merge 1:1 year month using "$work/02-prepare-pop/pop-data-monthly.dta", ///
    keep(match) keepusing(monthly_working_age) nogenerate
generate emprate = 100*nonfarm_emp/monthly_working_age

generate time = ym(year, month)
format time %tm

gr tw (line emprate time if inrange(time, ym(2019, 1), ym(2023, 01)), lw(medthick) col(ebblue)) ///
	(pcarrowi 78.4 `=$preCOVID_peak + 1' 78.4 `=$postCOVID_recov - 1', lw(thin) col(black)) ///
	(pcarrowi 78.4 `=$postCOVID_recov - 1' 78.4 `=$preCOVID_peak + 1', lw(thin) col(black)) ///
    (sc emprate time if inlist(time, $preCOVID_peak, $postCOVID_recov), col(cranberry)), ///
    text(79 `=$preCOVID_peak' "02/20", placement(top) size(small)) ///
    text(79 `=$postCOVID_recov' "06/22", placement(top) size(small)) ///
    text(78.2 `=($postCOVID_recov + $preCOVID_peak)/2' "2 years and 4 months", placement(s)) ///
    legend(off) ytitle("Employment to working-age population ratio (%)") ///
    xtitle("") xlabel(`=ym(2019,1)'(12)`=ym(2023,1)', labsize(small)) ylabel(67(1)79) scale(1.2)
graph export "$graphs/04-analyze-wage-growth/employment.pdf", replace

gr tw (line emprate time if inrange(time, ym(2007, 1), ym(2019, 1)), lw(medthick) col(ebblue)) ///
	(pcarrowi 76.1 `=$pre2008_peak + 4' 76.1 `=$post2008_recov - 4', lw(thin) col(black)) ///
	(pcarrowi 76.1 `=$post2008_recov - 4' 76.1 `=$pre2008_peak + 4', lw(thin) col(black)) ///
	(sc emprate time if inlist(time, $pre2008_peak, $post2008_recov), col(cranberry)), ///
	text(76.5 `=$pre2008_peak + 4' "12/2007", placement(n) size(small)) ///
	text(76.5 `=$post2008_recov - 6' "12/2017", placement(n) size(small)) ///
	text(76 `=($post2008_recov + $pre2008_peak)/2' "10 years", placement(bottom) justification(right)) ///
	legend(off) ytitle("Employment to working-age population ratio (%)") ///
	xtitle("") xlabel(`=ym(2008, 1)'(24)`=ym(2018, 01)', labsize(small)) ylabel(67(1)79) scale(1.2)
graph export "$graphs/04-analyze-wage-growth/employment-great-recession.pdf", replace

gr tw (line emprate time, lw(medthick) col(ebblue)) (sc emprate time if inlist(time, $pre2008_peak), col(cranberry)), ///
    legend(off) ytitle("Employment to working-age population ratio (%)") ///
    xtitle("") xlabel(`=ym(2006, 1)'(48)`=ym(2026, 1)') ///
    text(77 `=$pre2008_peak + 4' "Great recession" "begins" "in 12/2007", placement(right) justification(left) size(*0.8))
graph export "$graphs/04-analyze-wage-growth/employment-2.pdf", replace

gr tw (line emprate time, lw(medthick) col(ebblue)) (sc emprate time if inlist(time, $pre2008_peak), col(cranberry)) ///
    (pcarrowi 76.1 `=$pre2008_peak + 4' 76.1 `=$post2008_recov - 4', lw(medthick) col(black)), ///
    legend(off) ytitle("Employment to working-age population ratio (%)") ///
    xtitle("") xlabel(`=ym(2006, 1)'(48)`=ym(2026, 1)') ///
    text(77 `=$pre2008_peak + 4' "Great recession" "begins" "in 12/2007", placement(right) justification(left) size(*0.8)) ///
    text(76 `=($post2008_recov + $pre2008_peak)/2' "10 years", placement(bottom) justification(right))
graph export "$graphs/04-analyze-wage-growth/employment-3.pdf", replace

gr tw (line emprate time, lw(medthick) col(ebblue)) (sc emprate time if inlist(time, $pre2008_peak, $post2008_recov), col(cranberry)) ///
    (pcarrowi 76.1 `=$pre2008_peak + 4' 76.1 `=$post2008_recov - 4', lw(medthick) col(black)), ///
    legend(off) ytitle("Employment to working-age population ratio (%)") ///
    xtitle("") xlabel(`=ym(2006, 1)'(48)`=ym(2026, 1)') ///
    text(77 `=$pre2008_peak + 4' "Great recession" "begins" "in 12/2007", placement(right) justification(left) size(*0.8)) ///
    text(77 `=$post2008_recov - 4' "Pre-recession level" "reached again" "in 12/2017", placement(left) justification(right) size(*0.8)) ///
    text(76 `=($post2008_recov + $pre2008_peak)/2' "10 years", placement(bottom) justification(right))
graph export "$graphs/04-analyze-wage-growth/employment-4.pdf", replace

gr tw (line emprate time, lw(medthick) col(ebblue)) (sc emprate time if inlist(time, $pre2008_peak, $post2008_recov, $preCOVID_peak, $postCOVID_recov), col(cranberry)) ///
    (pcarrowi 76.1 `=$pre2008_peak + 4' 76.1 `=$post2008_recov - 4', lw(medthick) col(black)) ///
    (pcarrowi 78.4 `=$preCOVID_peak + 3' 78.4 `=$postCOVID_recov - 3', lw(medthick) col(black)), ///
    legend(off) ytitle("Employment to working-age population ratio (%)") ///
    xtitle("") xlabel(`=ym(2006, 1)'(48)`=ym(2026, 1)') ///
    text(77.0 `=$pre2008_peak + 4' "Great recession" "begins" "in 12/2007", placement(right) justification(left) size(*0.8)) ///
    text(77.0 `=$post2008_recov - 4' "Pre-recession level" "reached again" "in 12/2017", placement(left) justification(right) size(*0.8)) ///
    text(76.0 `=($post2008_recov + $pre2008_peak)/2' "10 years", placement(bottom) justification(right)) ///
    text(78.5 `=$preCOVID_peak - 2' "02/20", placement(nw)) ///
    text(78.5 `=$postCOVID_recov + 2' "06/22", placement(ne)) ///
    text(78.0 `=($postCOVID_recov + $preCOVID_peak)/2' "2 years and 4 months", placement(bottom) justification(right))
graph export "$graphs/04-analyze-wage-growth/employment-5.pdf", replace

// -------------------------------------------------------------------------- //
// Load wages database
// -------------------------------------------------------------------------- //

use "$work/03-tabulate-wages/tabulation-wages-working_age_individual.dta", clear

preserve
    keep if inlist(bracket, "top25_10", "top10_1", "top1")
    gcollapse (mean) wage employed (rawsum) pop [pw=pop], by(year month group unit demo_type)
    generate bracket = "q4"
    tempfile q4
    save `q4'
restore
append using `q4'

merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    keepusing(nipa_deflator) nogenerate keep(match)
replace wage = wage/nipa_deflator

keep if ym(year, month) >= ym(2007, 01)

generate time = ym(year, month)
format time %tm

// -------------------------------------------------------------------------- //
// Total wage growth: 2nd quartile, overall
// -------------------------------------------------------------------------- //

preserve
    keep if demo_type == "overall" & bracket == "q2"
    gcollapse (mean) wage [pw=pop], by(year month time)

    summarize wage if time == $pre2008_peak
    global wage_pre2008_peak = r(mean)
    summarize wage if time == $post2008_recov
    global wage_post2008_recov = r(mean)
    global wage_growth_post2008 = strofreal(100*((${wage_post2008_recov}/${wage_pre2008_peak})^(1/((${post2008_recov} - ${pre2008_peak})/12)) - 1), "%03.2f")

    summarize wage if time == $preCOVID_peak
    global wage_preCOVID_peak = r(mean)
    summarize wage if time == $postCOVID_recov
    global wage_postCOVID_recov = r(mean)
    global wage_growth_postCOVID = strofreal(100*((${wage_postCOVID_recov}/${wage_preCOVID_peak})^(1/((${postCOVID_recov} - ${preCOVID_peak})/12)) - 1), "%03.2f")

    gr tw (line wage time, lw(medthick) col(ebblue)), ///
        legend(off) ytitle("Average real labor income (constant USD)") yscale(range(24000 35000)) ylabel(, format(%9.0gc)) ///
        xtitle("") xlabel(`=ym(2006, 1)'(48)`=ym(2022, 1)')
    graph export "$graphs/04-analyze-wage-growth/wages-1.pdf", replace

    gr tw (line wage time, lw(medthick) col(ebblue)) (sc wage time if inlist(time, $pre2008_peak, $post2008_recov, $preCOVID_peak, $postCOVID_recov), col(cranberry)) ///
        (pcarrowi 30000 `=ym(2011, 1)' `=${wage_pre2008_peak} + 300' `=${pre2008_peak} + 1', lw(medthick) col(cranberry)) ///
        (pcarrowi 30000 `=ym(2014, 4)' `=${wage_post2008_recov} + 300' `=${post2008_recov} - 1', lw(medthick) col(cranberry)), ///
        legend(off) ytitle("Average real labor income (constant USD)") yscale(range(24000 32000)) ylabel(, format(%9.0gc)) ///
        xtitle("") xlabel(`=ym(2006, 1)'(48)`=ym(2022, 1)') ///
        text(31000 `=($pre2008_peak + $post2008_recov)/2' "Identical working-age" "employment rates", col(cranberry) justification(center))
    graph export "$graphs/04-analyze-wage-growth/wages-2.pdf", replace

    gr tw (line wage time, lw(medthick) col(ebblue)) (sc wage time if inlist(time, $pre2008_peak, $post2008_recov, $preCOVID_peak, $postCOVID_recov), col(cranberry)) ///
        (pcarrowi 30000 `=ym(2011, 1)' `=${wage_pre2008_peak} + 300' `=${pre2008_peak} + 1', lw(medthick) col(cranberry)) ///
        (pcarrowi 30000 `=ym(2014, 4)' `=${wage_post2008_recov} + 300' `=${post2008_recov} - 1', lw(medthick) col(cranberry)) ///
        (pcarrowi ${wage_pre2008_peak} `=$pre2008_peak + 4' ${wage_post2008_recov} `=$post2008_recov - 4', lw(medthick) col(black)), ///
        legend(off) ytitle("Average real labor income (constant USD)") yscale(range(24000 32000)) ylabel(, format(%9.0gc)) ///
        xtitle("") xlabel(`=ym(2006, 1)'(48)`=ym(2022, 1)') ///
        text(`=(${wage_post2008_recov} + ${wage_pre2008_peak})/2 + 700' `=($pre2008_peak + $post2008_recov)/2 + 3' ///
            "Annualized growth {bf:+${wage_growth_post2008}%}", placement(n) justification(center)) ///
        text(31000 `=($pre2008_peak + $post2008_recov)/2' "Identical working-age" "employment rates", col(cranberry) justification(center))
    graph export "$graphs/04-analyze-wage-growth/wages-3.pdf", replace

    gr tw (line wage time, lw(medthick) col(ebblue)) (sc wage time if inlist(time, $pre2008_peak, $post2008_recov, $preCOVID_peak, $postCOVID_recov), col(cranberry)) ///
        (pcarrowi 30000 `=ym(2011, 1)' `=${wage_pre2008_peak} + 300' `=${pre2008_peak} + 1', lw(medthick) col(cranberry)) ///
        (pcarrowi 30000 `=ym(2014, 4)' `=${wage_post2008_recov} + 300' `=${post2008_recov} - 1', lw(medthick) col(cranberry)) ///
        (pcarrowi ${wage_pre2008_peak} `=$pre2008_peak + 4' ${wage_post2008_recov} `=$post2008_recov - 4', lw(medthick) col(black)) ///
        (pcarrowi `=${wage_preCOVID_peak} + 200' `=$preCOVID_peak + 3' `=${wage_postCOVID_recov} - 200' `=$postCOVID_recov - 4', lw(medthick) col(black)), ///
        legend(off) ytitle("Average real labor income (constant USD)") yscale(range(24000 32000)) ylabel(, format(%9.0gc)) ///
        xtitle("") xlabel(`=ym(2006, 1)'(48)`=ym(2022, 1)') ///
        text(`=(${wage_post2008_recov} + ${wage_pre2008_peak})/2 + 700' `=($pre2008_peak + $post2008_recov)/2 + 3' ///
            "Annualized growth {bf:+${wage_growth_post2008}%}", placement(n) justification(center)) ///
        text(`=(${wage_postCOVID_recov} + ${wage_preCOVID_peak})/2 + 1000' `=($preCOVID_peak + $postCOVID_recov)/2' ///
            "Annualized" "growth" "{bf:+${wage_growth_postCOVID}%}", placement(n) justification(center)) ///
        text(31000 `=($pre2008_peak + $post2008_recov)/2' "Identical working-age" "employment rates", col(cranberry) justification(center))
    graph export "$graphs/04-analyze-wage-growth/wages-4.pdf", replace
restore

// -------------------------------------------------------------------------- //
// Bar chart by quartile
// -------------------------------------------------------------------------- //

preserve
    keep if demo_type == "overall"
    keep if inlist(bracket, "overall", "q2", "q3", "q4")

	generate marker = .
	replace marker = 1 if time == $pre2008_peak
	replace marker = 2 if time == $post2008_recov
	replace marker = 3 if time == $preCOVID_peak
	replace marker = 4 if time == $postCOVID_recov
	drop if missing(marker)

	keep bracket marker time wage
	reshape wide time wage, i(bracket) j(marker)

	generate growth2008  = 100*((wage2/wage1)^(1/((time2 - time1)/12)) - 1)
	generate growthCOVID = 100*((wage4/wage3)^(1/((time4 - time3)/12)) - 1)

	generate group = ""
	replace group = "2nd quartile" if bracket == "q2"
	replace group = "3rd quartile" if bracket == "q3"
	replace group = "4th quartile" if bracket == "q4"
	replace group = "Total"        if bracket == "overall"
	
	list
	
	tempfile quartile_data
	save `quartile_data'
	
    replace growth2008  = . if inlist(bracket, "q3", "q4", "overall")
    replace growthCOVID = . if inlist(bracket, "q3", "q4", "overall")
    gr bar growth2008 growthCOVID, bar(1, col(cranberry)) bar(2, col(ebblue)) ///
        ytitle("Annualized real labor income growth (%)") bargap(20) ///
        over(group) ylabel(, format(%02.1f)) ///
        legend(label(1 "Great recession & recovery") label(2 "COVID recession & recovery"))
    graph export "$graphs/04-analyze-wage-growth/wages-quartiles-1.pdf", replace

	use `quartile_data', clear
    replace growth2008  = . if inlist(bracket, "q4", "overall")
    replace growthCOVID = . if inlist(bracket, "q4", "overall")
    gr bar growth2008 growthCOVID, bar(1, col(cranberry)) bar(2, col(ebblue)) ///
        ytitle("Annualized real labor income growth (%)") bargap(20) ///
        over(group) ylabel(, format(%02.1f)) ///
        legend(label(1 "Great recession & recovery") label(2 "COVID recession & recovery"))
    graph export "$graphs/04-analyze-wage-growth/wages-quartiles-2.pdf", replace

	use `quartile_data', clear
    replace growth2008  = . if inlist(bracket, "overall")
    replace growthCOVID = . if inlist(bracket, "overall")
    gr bar growth2008 growthCOVID, bar(1, col(cranberry)) bar(2, col(ebblue)) ///
        ytitle("Annualized real labor income growth (%)") bargap(20) ///
        over(group) ylabel(, format(%02.1f)) ///
        legend(label(1 "Great recession & recovery") label(2 "COVID recession & recovery"))
    graph export "$graphs/04-analyze-wage-growth/wages-quartiles-3.pdf", replace

	use `quartile_data', clear
	gr bar growth2008 growthCOVID, bar(1, col(cranberry)) bar(2, col(ebblue)) ///
		ytitle("Annualized real labor income growth (%)") bargap(20) ///
		over(group) ylabel(, format(%02.1f)) ///
		legend(label(1 "Great recession & recovery") label(2 "COVID recession & recovery"))
	graph export "$graphs/04-analyze-wage-growth/wages-quartiles-4.pdf", replace
restore

// -------------------------------------------------------------------------- //
// Wage growth by race
// -------------------------------------------------------------------------- //

preserve
    keep if demo_type == "race" & bracket == "overall"

    gcollapse (mean) wage employed [pw=pop], by(group year month time)

    generate quarter = quarter(dofm(time))
    gcollapse (mean) wage employed, by(group year quarter)
    generate time = yq(year, quarter)
    format time %tq

    sort group time
    gegen ref = mean(wage) if year == 2007, by(group)
    gegen ref = max(ref), by(group) replace
    generate wage_base2007 = 100*wage/ref
    drop ref

	gr tw (line wage_base2007 time if group == "white",    lw(medthick) col(ebblue))   ///
		(line wage_base2007 time if group == "black",      lw(medthick) col(cranberry)) ///
		(line wage_base2007 time if group == "hispanic",   lw(medthick) col(green)),    ///
		xtitle("") xlabel(192(16)255) ytitle("Labor income (working-age population)" "Constant USD (2007 = 100)") ylabel(85(5)130) ///
		legend(off) ///
		text(92  `=yq(2015, 1)' "Blacks",    col(cranberry)) ///
		text(100 `=yq(2011, 1)' "Whites",    col(ebblue))    ///
		text(113 `=yq(2016, 1)' "Hispanics", col(green))
	graph export "$graphs/04-analyze-wage-growth/growth-rates-race.pdf", replace
restore

// -------------------------------------------------------------------------- //
// Wage growth by gender
// -------------------------------------------------------------------------- //

preserve
    keep if demo_type == "gender" & bracket == "overall"

    gcollapse (mean) wage employed [pw=pop], by(group year month time)

    generate quarter = quarter(dofm(time))
    gcollapse (mean) wage employed, by(group year quarter)
    generate time = yq(year, quarter)
    format time %tq

    sort group time
    gegen ref = mean(wage) if year == 2007, by(group)
    gegen ref = max(ref), by(group) replace
    generate wage_base2007 = 100*wage/ref
    drop ref

    gr tw (line wage_base2007 time if group == "men", lw(medthick) col(ebblue)) ///
        (line wage_base2007 time if group == "women", lw(medthick) col(cranberry)), ///
        xtitle("") xlabel(192(16)255) ytitle("Labor income (working-age population)" "Constant USD (2007 = 100)") ylabel(85(5)130) ///
        legend(off) ///
        text(90 `=yq(2010, 2)' "Men", col(ebblue)) ///
        text(113 `=yq(2017, 1)' "Women", col(cranberry))
    graph export "$graphs/04-analyze-wage-growth/growth-rates-sex.pdf", replace
restore

// -------------------------------------------------------------------------- //
// Growth rates table by race and gender
// -------------------------------------------------------------------------- //

preserve
    keep if inlist(demo_type, "race", "gender") & bracket == "overall"

	gcollapse (mean) wage employed [pw=pop], by(demo_type group year month time)

	gegen gid = group(demo_type group), missing
	tsset gid time, monthly
	tssmooth ma wage = wage, replace window(1 1 1)

	generate emprate_peak2008 = employed if time == $pre2008_peak
	gegen emprate_peak2008 = max(emprate_peak2008), by(gid) replace
	generate above_peak2008 = (employed >= emprate_peak2008) & (time > ($pre2008_peak + 12))
	gsort gid -above_peak2008 time
	by gid: generate is_2008recov = above_peak2008 & (_n == 1)

	generate emprate_peakCOVID = employed if time == ym(2022, 02)
	gegen emprate_peakCOVID = max(emprate_peakCOVID), by(gid) replace
	generate above_peakCOVID = (employed >= emprate_peakCOVID) & (time < ym(2020, 03)) & (time > ($pre2008_peak + 12))
	gsort gid -above_peakCOVID time
	by gid: generate is_COVIDpeak = above_peakCOVID & (_n == 1)

	generate marker = .
	replace marker = 1 if time == $pre2008_peak
	replace marker = 2 if is_2008recov
	replace marker = 3 if is_COVIDpeak
	replace marker = 4 if time == ym(2022, 02)
	keep if !missing(marker)

	keep gid demo_type group marker time wage
	reshape wide time wage, i(gid demo_type group) j(marker)

	generate growth2008  = 100*((wage2/wage1)^(1/((time2 - time1)/12)) - 1)
	generate growthCOVID = 100*((wage4/wage3)^(1/((time4 - time3)/12)) - 1)

	generate group_str = ""
	replace group_str = "Whites"    if group == "white"
	replace group_str = "Blacks"    if group == "black"
	replace group_str = "Hispanics" if group == "hispanic"
	replace group_str = "Men"       if group == "men"
	replace group_str = "Women"     if group == "women"

	generate group_order = 1 if group == "white"
	replace  group_order = 2 if group == "black"
	replace  group_order = 3 if group == "hispanic"
	replace  group_order = 4 if group == "men"
	replace  group_order = 5 if group == "women"

	generate categ = "Race/Ethnicity" if demo_type == "race"
	replace  categ = "Gender"         if demo_type == "gender"

	gr bar growth2008 growthCOVID, bar(1, col(cranberry)) bar(2, col(ebblue)) ///
		ytitle("Annualized real labor income growth (%)") bargap(20) ///
		over(group_str, sort(group_order)) over(categ) nofill ///
		legend(label(1 "Great recession & recovery") label(2 "COVID recession & recovery")) ///
		//text(0.8  3    "9 years" "11 months",  size(small) col(cranberry)) ///
		//text(2.1  12   "2 years" "3 months",   size(small) col(ebblue))    ///
		//text(1.3  22   "10 years" "4 months",  size(small) col(cranberry)) ///
		//text(3.05 30.5 "2 years" "10 months",  size(small) col(ebblue))    ///
		//text(1.15 49   "11 years" "11 months", size(small) col(cranberry)) ///
		//text(1.7  58   "3 years" "7 month",    size(small) col(ebblue))    ///
		//text(0.45 67.5 "8 years" "10 months",  size(small) col(cranberry)) ///
		//text(2    76   "2 years" "4 months",   size(small) col(ebblue))    ///
		//text(1.45 87   "10 years" "1 month",   size(small) col(cranberry)) ///
		//text(2.95 95   "2 years" "2 months",   size(small) col(ebblue))
	graph export "$graphs/04-analyze-wage-growth/growth-rates-race-gender.pdf", replace
restore

// -------------------------------------------------------------------------- //
// Wage levels by quartile + top 1% (COVID and Great Recession)
// -------------------------------------------------------------------------- //

preserve
    keep if demo_type == "overall" & inlist(bracket, "q2", "q3", "q4", "top1")

    // Recode bracket to numeric for reshape
    generate bnum = .
    replace bnum = 2  if bracket == "q2"
    replace bnum = 3  if bracket == "q3"
    replace bnum = 4  if bracket == "q4"
    replace bnum = 99 if bracket == "top1"

    tempfile wagelevels
	save `wagelevels'

	// COVID period
	use `wagelevels', clear
	keep if inrange(time, ym(2020, 2), ym(2022, 06))
	tsset bnum time, monthly
	by bnum: generate wage0 = wage[1]
	replace wage = 100*wage/wage0
	keep year month time bnum wage
	reshape wide wage, i(year month time) j(bnum)
	gr tw line wage* time, lw(medthick..) legend(off) lcol(ebblue cranberry orange purple) scale(1.2) ///
		yline(100, lpattern(dot) lcolor(black)) ///
		ytitle("Average real labor income" "Index (2019m1 = 100)") xtitle("") ///
		xlabel(`=ym(2020,1)'(6)`=ym(2022, 7)', labsize(small))  ///
		text(86   `=ym(2020, 11)' "2nd quartile", size(small) col(ebblue))    ///
		text(97   `=ym(2022, 1)'  "3rd quartile", size(small) col(cranberry)) ///
		text(106  `=ym(2021, 9)'  "4th quartile", size(small) col(orange))    ///
		text(116.5 `=ym(2021, 7)' "Top 1%",       size(small) col(purple))
	gr export "$graphs/04-analyze-wage-growth/wage-growth-covid.pdf", replace

	// Great recession period
	use `wagelevels', clear
	keep if inrange(time, ym(2007, 12), ym(2017, 12))
	tsset bnum time, monthly
	by bnum: generate wage0 = wage[1]
	replace wage = 100*wage/wage0
	keep year month time bnum wage
	reshape wide wage, i(year month time) j(bnum)
	gr tw line wage* time, lw(medthick..) legend(off) lcol(ebblue cranberry orange purple) scale(1.2) ///
		yline(100, lpattern(dot) lcolor(black)) ///
		ytitle("Average real labor income" "Index (2007m12 = 100)") xtitle("") ///
		xlabel(`=ym(2008, 01)'(24)`=ym(2018, 01)') ///
		ylabel(80(10)120) ///
		text(90   `=ym(2015, 11)' "2nd quartile", size(small) col(ebblue))    ///
		text(93   `=ym(2013, 1)'  "3rd quartile", size(small) col(cranberry)) ///
		text(107.5 `=ym(2016, 6)' "4th quartile", size(small) col(orange))    ///
		text(86   `=ym(2010, 5)'  "Top 1%",       size(small) col(purple))
	gr export "$graphs/04-analyze-wage-growth/wage-growth-great-recession.pdf", replace
restore

// -------------------------------------------------------------------------- //
// Wage distribution snapshots during COVID
// -------------------------------------------------------------------------- //

preserve

    local nsnap = 5
    local snap_years  "2020 2020 2020 2021 2022"
    local snap_months "2    4    11   6    6"
    local c1 "black" 
    local c2 "cranberry"
    local c3 "orange" 
    local c4 "dkgreen"
    local c5 "ebblue"

    // NIPA deflators for each snapshot
    use "$work/02-prepare-nipa/nipa-simplified-monthly.dta", clear
    forval j = 1/`nsnap' {
        local yr : word `j' of `snap_years'
        local mo : word `j' of `snap_months'
        summarize nipa_deflator if year == `yr' & month == `mo', meanonly
        global distrib_defl`j' = r(mean)
    }

    // Kernel densities and non-employment shares, one snapshot at a time
    clear
    tempfile kde_all
    save `kde_all', emptyok replace

    forval j = 1/`nsnap' {
        local yr : word `j' of `snap_years'
        local mo : word `j' of `snap_months'
		
		// Load microfiles, working-age individuals only
        use weight age flemp proprietors if age < 65 ///
            using "$microfiles/$update_id/dina-monthly-`yr'm`mo'.dta", clear

		// Compute wage
        generate double wage = (flemp + 0.7 * proprietors) / ${distrib_defl`j'}

        // Kernel density of log10(1 + wage)
        generate double lwage = log10(1 + wage)
        kdensity lwage [aw=weight], generate(xk dk) nograph bwidth(0.15) n(400)
        keep in 1/400
        keep xk dk

        generate byte   snap   = `j'
        append using `kde_all'
        save `kde_all', replace
    }

    // 2×2 panel figure
    use `kde_all', clear
    sort snap xk
    local monthnames "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"
    local mo1    : word 1 of `snap_months'
    local yr1    : word 1 of `snap_years'
    local mname1 : word `mo1' of `monthnames'

    forval k = 2/`nsnap' {
        local yr    : word `k' of `snap_years'
        local mo    : word `k' of `snap_months'
        local mname : word `mo' of `monthnames'

        gr tw ///
            (line dk xk if snap==1   & inrange(xk, 3, 6), col(`c1')    lw(thin)) ///
            (line dk xk if snap==`k' & inrange(xk, 3, 6), col(`c`k'')  lw(thin)), ///
            xscale(range(3 6)) yscale(range(0 .)) ///
            xlabel(3 "1,000" 4 "10,000" 5 "100,000" 6 "1M", labsize(vsmall)) ///
            xtitle("") ytitle("") ///
            legend(order(1 "`mname1' `yr1'" 2 "`mname' `yr'") ///
                   ring(1) pos(6) cols(2) size(vsmall) region(lw(none))) ///
            name(g_panel`k', replace)
    }
    gr combine g_panel2 g_panel3 g_panel4 g_panel5, ///
        cols(2) ycommon xcommon imargin(small) ///
        l1title("Density (share of working-age population)", size(small)) ///
        b1title("Annual wage earnings (constant USD, log scale)", size(small)) ///
        xsize(8) ysize(7)
    graph export "$graphs/04-analyze-wage-growth/wage-distribution-snapshots.pdf", replace

restore


// -------------------------------------------------------------------------- //
// Growth incidence curve over COVID and Great Recession
// -------------------------------------------------------------------------- //

clear
tempfile gic
save `gic', replace emptyok

local j = 1
foreach t in $pre2008_peak $post2008_recov $preCOVID_peak $postCOVID_recov {
    local year = year(dofm(`t'))
    local month = month(dofm(`t'))
    
    use id weight age flemp proprietors if age < 65 using "$microfiles/$update_id/dina-monthly-`year'm`month'.dta", clear
    
    // Calculate wage income
    generate wage = flemp + 0.7*proprietors
    
    //gegen wage = mean(wage), by(id) replace
    
    // Get rank
    sort wage
    generate rank = sum(weight)
    replace rank = 1e5*(rank - weight/2)/rank[_N]

    egen p = cut(rank), at(0(5000)95000 99000 999999)
    
    gcollapse (mean) wage [pw=weight], by(p)
    
    generate year = `year'
    generate month = `month'
    generate j = `j'
    
    append using `gic'
    save `gic', replace
    
    local j = `j' + 1
}

merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", keepusing(nipa_deflator) nogenerate keep(match)

replace wage = wage/nipa_deflator

keep p wage j
reshape wide wage, i(p) j(j)

generate growth_2008 = 100*((wage2/wage1)^(12/(${post2008_recov} - ${pre2008_peak})) - 1)
generate growth_covid = 100*((wage4/wage3)^(12/(${postCOVID_recov} - ${preCOVID_peak})) - 1)

gr tw (con growth_2008 p if p >= 25000, col(ebblue) lw(medthick) msym(Sh)) ///
    (con growth_covid p if p >= 25000, col(cranberry) lw(medthick) msym(Oh)), ///
    xtitle("Percentiles (working-age population)") ytitle("Annualized real labor income growth (%)") ///
    ylabel(-2(1)3, format(%01.0f)) xlabel(25000 "25-30%" 30000 "30-35%" 35000 "35-40%" ///
        40000 "40-45%" 45000 "45-50%" 50000 "50-55%" 55000 "55-60%" 60000 "60-65%" ///
        65000 "65-70%" 70000 "70-75%" 75000 "75-80%" 80000 "80-85%" 85000 "85-90%" ///
        90000 "90-95%" 95000 "95-99%" 99000 "Top 1%", alternate labsize(small)) ///
    legend(off) ///
    text(1.5 40000 "COVID recession" "and recovery" "(02/2020 to 06/2022)", col(cranberry) size(small)) ///
    text(1.3 75000 "Great recession" "and recovery" "(12/2007 to 12/2017)", col(ebblue) size(small))
graph export "$graphs/04-analyze-wage-growth/gic-wages.pdf", replace