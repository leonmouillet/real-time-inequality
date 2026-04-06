// -------------------------------------------------------------------------- //
// Build monthly tables of income and wealth by demographics groups
// -------------------------------------------------------------------------- //

local date_begin = $date_begin
local date_end   = $date_end

foreach pop in adult_equal_split adult_individual working_age_equal_split working_age_individual {
	local outfile "$work/03-tabulate-demographics/tabulation-demographics-`pop'.dta"
	cap confirm file "`outfile'"
	if (_rc == 0) {
		use "`outfile'", clear
		drop if ym(year, month) >= `date_begin'
		save "`outfile'", replace
	}
	else {
		clear
		save "`outfile'", emptyok
	}
}

local all_vars princ peinc poinc dispo flemp proprietors rental corptax profits fkfix fknmo hweal

// Loop over monthly microfiles
foreach t of numlist `date_begin' / `date_end' {
	quietly {
		local year  = year(dofm(`t'))
		local month = month(dofm(`t'))

		// Loop over populations
		foreach pop in adult_equal_split adult_individual working_age_equal_split working_age_individual {
				use year month id weight age sex race educ `all_vars' using "$microfiles/$update_id/dina-monthly-`year'm`month'.dta", clear

			// Limit to working age if requested
			if ("`pop'" == "working_age_individual" | "`pop'" == "working_age_equal_split") keep if age < 65

			// Equal split if requested
			if ("`pop'" == "adult_equal_split" | "`pop'" == "working_age_equal_split") {
				foreach v of varlist `all_vars' {
					gegen `v' = mean(`v'), by(id) replace
				}
			}

			// Recode education: 1 = no college (educ <= 6), 2 = college (educ >= 7)
			replace educ = 1 if educ <= 6
			replace educ = 2 if educ >= 7

			// Code race × gender combination: race*10 + sex
			generate rg = race*10 + sex if inlist(race, 1, 2, 3)

			// Compute wage and capital income
			generate wage  = flemp + 0.7*proprietors
			generate pkinc = 0.3*proprietors + rental + corptax + profits + fkfix - fknmo

			local saved = 0
			while !`saved' {
				cap save "$work/03-tabulate-demographics/tempfiles/current_pop.dta", replace
				if (_rc == 0) local saved = 1
				else sleep 2000
			}

			// Loop over demographic types
			foreach demo_type in race gender educ race_gender {

				noisily di "* " %tm = `t' " - `pop' - `demo_type'"

				use "$work/03-tabulate-demographics/tempfiles/current_pop.dta", clear

				// Define demographic groups
				generate group = ""
				if "`demo_type'" == "race" {
					keep if inlist(race, 1, 2, 3)
					replace group = "white"    if race == 1
					replace group = "black"    if race == 2
					replace group = "hispanic" if race == 3
				}
				else if "`demo_type'" == "gender" {
					replace group = "men"   if sex == 1
					replace group = "women" if sex == 2
				}
				else if "`demo_type'" == "educ" {
					keep if inlist(educ, 1, 2)
					replace group = "nocollege" if educ == 1
					replace group = "college"   if educ == 2
				}
				else if "`demo_type'" == "race_gender" {
					keep if inlist(race, 1, 2, 3)
					replace group = "white_men"      if rg == 11
					replace group = "white_women"    if rg == 12
					replace group = "black_men"      if rg == 21
					replace group = "black_women"    if rg == 22
					replace group = "hispanic_men"   if rg == 31
					replace group = "hispanic_women" if rg == 32
				}

				// Overall aggregation within group
				gcollapse (mean) princ peinc poinc dispo pkinc hweal wage ///
				          (rawsum) weight [pw=weight], by(group)

				generate year      = `year'
				generate month     = `month'
				generate demo_type = "`demo_type'"

				// Append and save
				append using "$work/03-tabulate-demographics/tabulation-demographics-`pop'.dta"
				local saved = 0
				while !`saved' {
					cap save "$work/03-tabulate-demographics/tabulation-demographics-`pop'.dta", replace
					if (_rc == 0) local saved = 1
					else sleep 2000
				}
			}
		}
	}
}
