// -------------------------------------------------------------------------- //
// Construct monthly database of wage income by bracket and demographic groups
// -------------------------------------------------------------------------- //

local date_begin = $date_begin
local date_end   = $date_end

foreach pop in working_age_individual working_age_equal_split {
	local outfile "$work/03-tabulate-wages/tabulation-wages-`pop'.dta"
	cap use `outfile', clear
	if (_rc == 0) {
		drop if ym(year, month) >= `date_begin'
		save `outfile', replace
	}
	else {
		clear
		save `outfile', replace emptyok
	}
}

quietly {
	// Loop over monthly microfiles
	forval t = `date_begin' / `date_end' {
		noisily di "* " %tm = `t'

		local year  = year(dofm(`t'))
		local month = month(dofm(`t'))

		// Loop over populations
		foreach pop in working_age_individual working_age_equal_split {
			
			use id weight age sex race educ flemp proprietors ///
				using "$microfiles/$update_id/dina-monthly-`year'm`month'.dta", clear

			keep if age < 65
			generate wage = flemp + 0.7*proprietors
			drop flemp proprietors

			// Recode education
			replace educ = 1 if educ <= 6
			replace educ = 2 if educ >= 7
			
			// Equal split if requested
			if ("`pop'" == "working_age_equal_split") {
				gegen wage = mean(wage), by(id) replace
			}

			generate employed = (wage > 0)
			
			local saved = 0
			while !`saved' {
				cap save "$work/03-tabulate-wages/tempfiles/current_pop.dta", replace
				if (_rc == 0) local saved = 1
				else sleep 2000
			}
			
			// Loop over demographic type
			if ("`pop'" == "working_age_equal_split") local demo_types overall
			else local demo_types overall race gender educ
			foreach demo_type in `demo_types' {

				use "$work/03-tabulate-wages/tempfiles/current_pop.dta", clear

				// Define demographic groups
				if "`demo_type'" == "overall" {
					generate group = "overall"
					local gvar group
				}
				else if "`demo_type'" == "race" {
					keep if inlist(race, 1, 2, 3)
					generate group = ""
					replace group = "white"    if race == 1
					replace group = "black"    if race == 2
					replace group = "hispanic" if race == 3
					local gvar race
				}
				else if "`demo_type'" == "gender" {
					generate group = ""
					replace group = "men"   if sex == 1
					replace group = "women" if sex == 2
					local gvar sex
				}
				else if "`demo_type'" == "educ" {
					keep if inlist(educ, 1, 2)
					generate group = ""
					replace group = "nocollege" if educ == 1
					replace group = "college"   if educ == 2
					local gvar educ
				}

				// Rank within group
				hashsort `gvar' wage
				by `gvar': generate rank = sum(weight)
				by `gvar': replace rank = (rank - weight/2)/rank[_N]

				// Coarse brackets within group
				generate bracket = ""
				replace bracket = "q1"       if inrange(rank, 0.00, 0.25)
				replace bracket = "q2"       if inrange(rank, 0.25, 0.50)
				replace bracket = "q3"       if inrange(rank, 0.50, 0.75)
				replace bracket = "top25_10" if inrange(rank, 0.75, 0.90)
				replace bracket = "top10_1"  if inrange(rank, 0.90, 0.99)
				replace bracket = "top1"     if rank > 0.99

				expand 2, generate(dup)
				replace bracket = "overall" if dup == 1
					
				// Bracket-level aggregation
				gcollapse (mean) wage employed (min) threshold=wage (rawsum) pop=weight [pw=weight], by(`gvar' bracket group)
				replace threshold = . if bracket == "overall"

				if "`gvar'" != "group" drop `gvar'
				generate year      = `year'
				generate month     = `month'
				generate unit      = "`pop'"
				generate demo_type = "`demo_type'"

				// Append and save
				append using "$work/03-tabulate-wages/tabulation-wages-`pop'.dta"
				local saved = 0
				while !`saved' {
					cap save "$work/03-tabulate-wages/tabulation-wages-`pop'.dta", replace
					if (_rc == 0) local saved = 1
					else sleep 2000
				}
					
			}
		}
	}
}
