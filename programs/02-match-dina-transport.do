// -------------------------------------------------------------------------- //
// Match DINA with ASEC CPS files using the transport maps calculated
// on the server
// -------------------------------------------------------------------------- //


tempfile dina cps scf

foreach year of numlist 1975/$last_year_dina {
    di "--> `year'"
    quietly {

        // Prepare files to match
        use if year == `year' using "$work/02-add-ssa-wages/dina-ssa-full.dta", clear
        drop age
        rename id dina_id
        save "`dina'", replace
        
        use if year == `year' using "$work/01-import-transport-cps/cps-full.dta", clear
        rename id cps_id
        save "`cps'", replace
        
        if (`year' >= 1989) {
            use if year == `year' using "$work/01-import-transport-scf/scf-full.dta", clear
            rename id scf_id
            save "`scf'", replace
        }
        
        // Import transport map
        import delimited "$work/02-transport/match/match-`year'.csv", clear
        
        generate transport_id = _n
        generate year = `year'
                
        // Match with DINA
        joinby year dina_id using "`dina'", unmatched(both)
        assert _merge == 3
        drop _merge
        
        // Match with CPS
        joinby year cps_id using "`cps'"
        
        // Match with SCF, if possible
        capture confirm variable scf_id
        if (_rc == 0) {
            joinby year scf_id using "`scf'"
        }
                
        egen num_id = nvals(transport_id)
        
        // Identify if couple are mixed-sex or same-sex in CPS
        egen num_male = total(sex_cps == 2) if married == 1, by(transport_id)
        egen num_female = total(sex_cps == 1) if married == 1, by(transport_id)
        generate same_sex = (num_male == 0) | (num_female == 0) if (married == 1)
        
        // If this is a mixed-sex couple, match CPS on gender
        drop if (married == 1) & (same_sex == 0) & (female == 1 & sex_cps == 1)
        drop if (married == 1) & (same_sex == 0) & (female == 0 & sex_cps == 2)
        
        // And then match the SCF to the CPS individual gender (in the SCF
        // only records gender of reference person)
        capture confirm variable scf_id
        if (_rc == 0) {
            replace age_scf = age_spouse_scf if (sex_cps != sex_scf) & (married == 1) & (same_sex == 0)
            replace educ_scf = educ_spouse_scf if (sex_cps != sex_scf) & (married == 1) & (same_sex == 0)
            replace sex_scf = cond(sex_scf == 1, 2, 1) if (sex_cps != sex_scf) & (married == 1) & (same_sex == 0)
        }
        
        // If this is a same-sex couple, match on whoever is closest in terms of labor income
        set seed 19920902
        generate tiebreaker = uniform() if (same_sex == 1)
        generate distance = abs(flwag - cps_wage) if (same_sex == 1)
        sort transport_id distance tiebreaker
        // First observation is the first match
        by transport_id: generate transport_num = _n if (same_sex == 1)
        by transport_id: generate dina_num = female[1] if (same_sex == 1)
        by transport_id: generate cps_num = pernum[1] if (same_sex == 1)
        // The other observation has to be different from the first for both DINA and CPS
        drop if (transport_num > 1) & (same_sex == 1) & (married == 1) & ((female == dina_num) | (pernum == cps_num))
        drop transport_num dina_num cps_num num_male num_female tiebreaker distance
        
        egen num_id2 = nvals(transport_id)
        noisily assert num_id == num_id2
        
        // For SCF age, reference person is the one with the highest wage income
        capture confirm variable scf_id
        if (_rc == 0) {
            generate tiebreaker = uniform() if (same_sex == 1)
            sort transport_id flwag tiebreaker
            by transport_id: replace age_scf = age_spouse_scf if (same_sex == 1) & (_n == 2)
            by transport_id: replace educ_scf = educ_spouse_scf if (same_sex == 1) & (_n == 2)
            drop tiebreaker 
        }
        drop same_sex
        
        // Check there's two people per couple
        by transport_id: generate num_people = _N
        assert num_people == 2 if (married == 1)
        assert num_people == 1 if (married == 0)
        drop num_people
        
        // Check weights
        assert !missing(weight)
        
        gegen weight_chk = total(weight), by(dina_id)
        replace weight_chk = weight_chk/2 if married == 1
        assert reldif(weight_chk, dweght) < 1e-4
        
        // CPS-base wage split within couples
        egen totincwage = total(cps_wage) if married, by(transport_id)
        generate share_cps_wage = cps_wage/totincwage if married
        drop totincwage
        
        // Clean up
        drop cps_id //dina_id
        capture confirm variable scf_id
        if (_rc == 0) {
            drop scf_id
        }
        rename transport_id id
        drop dweght serial pernum sploc //cps_*
            
        capture confirm variable age_spouse_scf
        if (_rc == 0) {
            drop age_spouse_scf //scf_*
        }
        compress
        
        label drop _all
	
		// Determine if an observation is in the top
        generate is_top = 0
        foreach v of varlist princ peinc poinc hweal {
            hashsort `v'
            generate rank = sum(weight)
            replace rank = (rank - weight/2)/rank[_N]
            replace is_top = 1 if rank >= 0.95
            drop rank
        }
        
		// For observations in the top, use SCF after 1989, otherwise use CPS
        foreach v in race age educ sex {
            generate `v' = `v'_cps
			if `year' >= 1989 {
				replace `v' = `v'_scf if is_top & year >= 1989
			}
        }
        drop is_top
        
		// Simplify education
		replace educ = 1 if inlist(educ, 1, 2) // Less than high school
		replace educ = 3 if inlist(educ, 3, 4, 5) // Some high school
        
        // Age groups
        egen age_group = cut(age), at(20(5)75 999)
        
        compress
        
        tempfile match`year'
        save "`match`year''", replace
        local matchfiles `matchfiles' "`match`year''"
    }
}
clear
append using `matchfiles'
compress
save "$work/02-match-dina-transport/dina-transport-full.dta", replace

// -------------------------------------------------------------------------- //
// Check how well the ranks match in the dataset
// -------------------------------------------------------------------------- //

// -------------------------------------------------------------------------- //
// % of blacks/hispanics by wage earnings
// -------------------------------------------------------------------------- //

clear
tempfile data
save "`data'", replace emptyok
set seed 19920902

foreach v in flwag cps_wage scf_wage {
    
    // Process by decades (for RAM managment)
    foreach decade in 1975 1985 1995 2005 2015 {
        local end_year = min(`decade' + 9, $last_year_dina)
        
        use year id weight age race `v' ///
            if inrange(year, `decade', `end_year') ///
            using "$work/02-match-dina-transport/dina-transport-full.dta", clear

		gegen `v' = mean(`v'), by(year id) replace
		
		// Alternative: higher than full-time minimum wage (no difference)
		*merge n:1 year using "$work/01-import-minwage/fed-minimum-wage-yearly.dta", nogenerate keep(match)
		*keep if cps_wage > 40*52*fed_minw
		
		//keep if `v' > 0
		keep if age < 65
		
		generate tiebreaker = uniform()
		sort year `v' tiebreaker
		by year: generate rank = sum(weight)
		by year: replace rank = (rank - weight/2)/rank[_N]
		drop tiebreaker
		
		generate bracket = ""
		replace bracket = "bot50" if inrange(rank, 0.0, 0.5)
		replace bracket = "mid40" if inrange(rank, 0.5, 0.9)
		replace bracket = "top10" if inrange(rank, 0.9, 1.0)
		
		generate nonwhite = inlist(race, 2, 3)
		
		gcollapse (sum) pop=weight, by(year bracket nonwhite)
		gegen tot = total(pop), by(year bracket)
		generate frac =  pop/tot
		drop pop tot
		
		generate var = "`v'"
		append using "`data'"
		save "`data'", replace
	}
}

drop if var == "scf_wage"
reshape wide frac, i(year nonwhite bracket) j(var) string

gr tw (con fracflwag fraccps_wage year if nonwhite == 1 & bracket == "bot50", lw(medthick..) col(ebblue cranberry*0.8 cranberry*1.2) msym(Oh Th Sh)) ///
    (con fracflwag fraccps_wage year if nonwhite == 1 & bracket == "top10", lw(medthick..) col(ebblue cranberry*0.8 cranberry*1.2) msym(Oh Th Sh)), ///
    yscale(range(0, 0.35)) ylabel(0 "0%" 0.05 "5%" 0.1 "10%" 0.15 "15%" 0.2 "20%" 0.25 "25%" 0.3 "30%" 0.35 "35%" 0.4 "40%") ytitle("% of blacks & hispanics") ///
    xlabel(1975(5)2020, alternate) xtitle("") ///
    text(0.05 1985 "Top 10%") text(0.275 1985 "Bottom 50%") ///
    legend(pos(6) rows(1) label(1 "DINA (matched)") label(2 "CPS") order(1 2))
graph export "$graphs/02-match-dina-transport/check-transport-blacks-hispanics-wage-earnings.pdf", replace

// -------------------------------------------------------------------------- //
// Gender by wage earnings
// -------------------------------------------------------------------------- //

clear
tempfile data
save "`data'", replace emptyok
set seed 19920902

foreach v in flwag cps_wage scf_wage {
    
    foreach decade in 1975 1985 1995 2005 2015 {
        local end_year = min(`decade' + 9, $last_year_dina)
        
        use year id weight age female `v' ///
            if inrange(year, `decade', `end_year') ///
            using "$work/02-match-dina-transport/dina-transport-full.dta", clear
        
		*merge n:1 year using "$work/01-import-minwage/fed-minimum-wage-yearly.dta", nogenerate keep(match)
		*keep if cps_wage > 40*52*fed_minw
		
		keep if age < 65
		
		generate tiebreaker = uniform()
		sort year `v' tiebreaker
		by year: generate rank = sum(weight)
		by year: replace rank = (rank - weight/2)/rank[_N]
		drop tiebreaker
		
		generate bracket = ""
		replace bracket = "bot50" if inrange(rank, 0.0, 0.5)
		replace bracket = "mid40" if inrange(rank, 0.5, 0.9)
		replace bracket = "top10" if inrange(rank, 0.9, 1.0)
		
		gcollapse (sum) pop=weight, by(year bracket female)
		gegen tot = total(pop), by(year bracket)
		generate frac =  pop/tot
		drop pop tot
		
		generate var = "`v'"
		append using "`data'"
		save "`data'", replace
	}
}

drop if var == "scf_wage" & year < 1989
reshape wide frac, i(year female bracket) j(var) string

gr tw (con fracflwag fraccps_wage year if female == 1 & bracket == "bot50", lw(medthick..) col(ebblue cranberry*0.8 cranberry*1.2) msym(Oh Th Sh)) ///
    (con fracflwag fraccps_wage year if female == 1 & bracket == "top10", lw(medthick..) col(ebblue cranberry*0.8 cranberry*1.2) msym(Oh Th Sh)), ///
    yscale(range(0 0.8)) ylabel(0 "0%" 0.1 "10%" 0.2 "20%" 0.3 "30%" 0.4 "40%" 0.5 "50%" 0.6 "60%" 0.7 "70%" 0.8 "80%") ytitle("% of women") ///
    xlabel(1975(5)2020, alternate) xtitle("") ///
    text(0.05 1985 "Top 10%") text(0.72 1985 "Bottom 50%") ///
    legend(pos(6) rows(1) label(1 "DINA (matched)") label(2 "CPS") order(1 2))
graph export "$graphs/02-match-dina-transport/check-transport-gender-wage-earnings.pdf", replace

// -------------------------------------------------------------------------- //
// % of blacks/hispanics by income
// -------------------------------------------------------------------------- //

clear
tempfile data
save "`data'", replace emptyok
set seed 19920902

foreach v in dina_income cps_income scf_income {
    
    foreach decade in 1975 1985 1995 2005 2015 {
        local end_year = min(`decade' + 9, $last_year_dina)
        
        use year id weight race ///
            fiwag peninc fibus fiint fidiv firen ///
            ssinc_di divet diwco uiinc ssinc_oa difoo dicao fikgi ///
            cps_wage cps_pens cps_bus cps_int cps_drt ///
            scf_wage scf_pens_ss scf_bus scf_intdivrt ///
            if inrange(year, `decade', `end_year') ///
            using "$work/02-match-dina-transport/dina-transport-full.dta", clear
    
		generate dina_wage  = fiwag - peninc
		generate dina_pens  = peninc
		generate dina_bus   = max(fibus, 0)
		generate dina_int   = fiint
		generate dina_drt   = fidiv + max(firen, 0)
		generate dina_gov   = ssinc_di + divet + diwco + uiinc
		generate dina_ss    = ssinc_oa
		generate dina_welfr = difoo + dicao
		
		generate dina_pens_ss  = dina_pens + dina_ss
		generate dina_intdivrt = fiint + fidiv + max(firen, 0)
		generate dina_kg       = fikgi    
			
		generate dina_income = dina_wage + dina_pens_ss + dina_bus + dina_intdivrt
		generate cps_income = cps_wage + cps_pens + cps_bus + cps_int + cps_drt
		generate scf_income = scf_wage + scf_pens_ss + scf_bus + scf_intdivrt

		gegen `v' = mean(`v'), by(year id) replace
		
		generate tiebreaker = uniform()
		sort year `v' tiebreaker
		by year: generate rank = sum(weight)
		by year: replace rank = (rank - weight/2)/rank[_N]
		drop tiebreaker
		
		generate bracket = ""
		replace bracket = "bot50" if inrange(rank, 0.0, 0.5)
		replace bracket = "mid40" if inrange(rank, 0.5, 0.9)
		replace bracket = "top10" if inrange(rank, 0.9, 1.0)
		
		generate nonwhite = inlist(race, 2, 3)
		
		gcollapse (sum) pop=weight, by(year bracket nonwhite)
		gegen tot = total(pop), by(year bracket)
		generate frac =  pop/tot
		drop pop tot
		
		generate var = "`v'"
		append using "`data'"
		save "`data'", replace
	}
}

drop if var == "scf_income" & year < 1989
drop if var == "scf_income" & mod(year - 1989, 3) != 0
reshape wide frac, i(year nonwhite bracket) j(var) string

gr tw (con fracdina_income fraccps_income fracscf_income year if nonwhite == 1 & bracket == "bot50", lw(medthick..) col(ebblue cranberry*0.8 cranberry*1.2) msym(Oh Th Sh)) ///
    (con fracdina_income fraccps_income fracscf_income year if nonwhite == 1 & bracket == "top10", lw(medthick..) col(ebblue cranberry*0.8 cranberry*1.2) msym(Oh Th Sh)), ///
    yscale(range(0, 0.4)) ylabel(0 "0%" 0.05 "5%" 0.1 "10%" 0.15 "15%" 0.2 "20%" 0.25 "25%" 0.3 "30%" 0.35 "35%" 0.4 "40%") ytitle("% of blacks & hispanics") ///
    xlabel(1975(5)2020, alternate) xtitle("") ///
    text(0.025 1985 "Top 10%") text(0.27 1985 "Bottom 50%") ///
    legend(pos(6) rows(1) label(1 "DINA (matched)") label(2 "CPS") label(3 "SCF") order(1 2 3))
graph export "$graphs/02-match-dina-transport/check-transport-blacks-hispanics-income.pdf", replace


// -------------------------------------------------------------------------- //
// % of blacks/hispanics by wealth
// -------------------------------------------------------------------------- //

clear
tempfile data
save "`data'", replace emptyok
set seed 19920902

foreach v in hweal scf_wealth {
    
    foreach decade in 1975 1985 1995 2005 2015 {
        local end_year = min(`decade' + 9, $last_year_dina)
        
        use year id weight race hweal ///
            scf_wfinbus scf_whou scf_wdeb ///
            if inrange(year, `decade', `end_year') ///
            using "$work/02-match-dina-transport/dina-transport-full.dta", clear
    
		generate scf_wealth = scf_wfinbus + scf_whou - scf_wdeb

		gegen `v' = mean(`v'), by(year id) replace
		
		generate tiebreaker = uniform()
		sort year `v' tiebreaker
		by year: generate rank = sum(weight)
		by year: replace rank = (rank - weight/2)/rank[_N]
		drop tiebreaker
		
		generate bracket = ""
		replace bracket = "bot50" if inrange(rank, 0.0, 0.5)
		replace bracket = "mid40" if inrange(rank, 0.5, 0.9)
		replace bracket = "top10" if inrange(rank, 0.9, 1.0)
		
		generate nonwhite = inlist(race, 2, 3)
		
		gcollapse (sum) pop=weight, by(year bracket nonwhite)
		gegen tot = total(pop), by(year bracket)
		generate frac =  pop/tot
		drop pop tot
		
		generate var = "`v'"
		append using "`data'"
		save "`data'", replace
	}
}

drop if var == "scf_wealth" & year < 1989
drop if var == "scf_wealth" & mod(year - 1989, 3) != 0
reshape wide frac, i(year nonwhite bracket) j(var) string

gr tw (con frachweal fracscf_wealth year if nonwhite == 1 & bracket == "bot50", lw(medthick..) col(ebblue cranberry*1.2) msym(Oh Sh)) ///
    (con frachweal fracscf_wealth year if nonwhite == 1 & bracket == "top10", lw(medthick..) col(ebblue cranberry*1.2) msym(Oh Sh)), ///
    yscale(range(0, 0.4)) ylabel(0 "0%" 0.05 "5%" 0.1 "10%" 0.15 "15%" 0.2 "20%" 0.25 "25%" 0.3 "30%" 0.35 "35%" 0.4 "40%") ytitle("% of blacks & hispanics") ///
    xlabel(1975(5)2020, alternate) xtitle("") ///
    text(0.025 1985 "Top 10%") text(0.27 1985 "Bottom 50%") ///
    legend(pos(6) rows(1) label(1 "DINA (matched)") label(2 "SCF") order(1 2))
graph export "$graphs/02-match-dina-transport/check-transport-blacks-hispanics-wealth.pdf", replace

// -------------------------------------------------------------------------- //
// How well the ranks match
// -------------------------------------------------------------------------- //

use year id weight flwag cps_wage scf_wage ///
    using "$work/02-match-dina-transport/dina-transport-full.dta", clear
	
gcollapse (sum) flwag cps_wage scf_wage (mean) weight, by(year id)

foreach v of varlist flwag cps_wage scf_wage {
    // Alternative: higher than full-time minimum wage (no difference)
    merge n:1 year using "$work/01-import-minwage/fed-minimum-wage-yearly.dta", nogenerate keep(match)
    keep if flwag > 2*40*52*fed_minw
    //keep if flwag > 0
    
    //gegen `v' = mean(`v'), by(year id) replace
    
    generate tiebreaker = uniform()
    sort year `v' tiebreaker
    by year: generate rank_`v' = sum(weight)
    by year: replace rank_`v' = 100*(rank_`v' - weight/2)/rank_`v'[_N]
    drop tiebreaker
}

egen perc_flwag = cut(rank_flwag), at(0/99 999)
replace perc_flwag = perc_flwag + 1
replace rank_scf_wage = . if year < 1989

gcollapse (mean) mean_cps=rank_cps_wage mean_scf=rank_scf_wage ///
    (p5) p5_cps=rank_cps_wage p5_scf=rank_scf_wage ///
    (p95) p95_cps=rank_cps_wage p95_scf=rank_scf_wage ///
    [pw=weight], by(year perc_flwag)
    
gcollapse (mean) mean_* p5_* p95_*, by(perc_flwag)
 
gr tw (line perc_flwag perc_flwag, color(gs10) lw(medthick) lp(dash)) ///
    (rarea p5_cps p95_cps perc_flwag, color(ebblue%30) lw(none)) ///
    (line mean_cps perc_flwag, lw(thick) lc(ebblue)), ///
    xtitle("DINA wage percentile") ///
    aspectratio(1) legend(pos(3) cols(1) label(1 "45deg line") ///
        label(3 "mean CPS rank") label(2 "90% interval") order(1 3 2))
graph export "$graphs/02-match-dina-transport/rank-flwag-dina-cps.pdf", replace
 
gr tw (line perc_flwag perc_flwag, color(gs10) lw(medthick) lp(dash)) ///
    (rarea p5_scf p95_scf perc_flwag, color(cranberry%30) lw(none)) ///
    (line mean_scf perc_flwag, lw(thick) lc(cranberry)), ///
    xtitle("DINA wage percentile") ///
    aspectratio(1) legend(pos(3) cols(1) label(1 "45deg line") ///
        label(3 "mean SCF rank") label(2 "90% interval") order(1 3 2))
graph export "$graphs/02-match-dina-transport/rank-flwag-dina-scf.pdf", replace

// Same for wealth
use year id weight hweal scf_whou scf_wfinbus scf_wdeb ///
    using "$work/02-match-dina-transport/dina-transport-full.dta", clear
	
generate scf_wealth = scf_whou + scf_wfinbus - scf_wdeb

gcollapse (sum) hweal scf_wealth (sum) weight, by(year id)

foreach v of varlist hweal scf_wealth {
    gegen `v' = mean(`v'), by(year id) replace
    
    generate tiebreaker = uniform()
    sort year `v' tiebreaker
    by year: generate rank_`v' = sum(weight)
    by year: replace rank_`v' = 100*(rank_`v' - weight/2)/rank_`v'[_N]
    drop tiebreaker
}

egen perc_hweal = cut(rank_hweal), at(0/99 999)
replace perc_hweal = perc_hweal + 1
replace rank_scf_wealth = . if year < 1989

gcollapse (mean) mean_scf=rank_scf_wealth  ///
    (p5) p5_scf=rank_scf_wealth ///
    (p95) p95_scf=rank_scf_wealth ///
    [pw=weight], by(year perc_hweal)
    
gcollapse (mean) mean_* p5_* p95_*, by(perc_hweal)
 
gr tw (line perc_hweal perc_hweal, color(gs10) lw(medthick) lp(dash)) ///
    (rarea p5_scf p95_scf perc_hweal, color(cranberry%30) lw(none)) ///
    (line mean_scf perc_hweal, lw(thick) lc(cranberry)), ///
    xtitle("DINA wealth percentile") ///
    aspectratio(1) legend(pos(3) cols(1) label(1 "45deg line") ///
        label(3 "mean SCF rank") label(2 "90% interval") order(1 3 2))
graph export "$graphs/02-match-dina-transport/rank-hweal-dina-scf.pdf", replace
