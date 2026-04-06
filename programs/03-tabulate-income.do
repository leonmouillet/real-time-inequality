// -------------------------------------------------------------------------- //
// Build monthly tables of income by percentiles
// -------------------------------------------------------------------------- //

local date_begin = $date_begin
local date_end   = $date_end

foreach concept in peinc princ dispo poinc hweal {
	foreach pop in adult_equal_split working_age_equal_split adult_households {
		local outfile "$work/03-tabulate-income/tabulation-`concept'-`pop'.dta"
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
}

local all_vars peinc princ dispo poinc hweal govin uiben penben surplus contrib vet ///
			   othcash covidrelief prodsub covidsub othercontrib taxes estatetax corptax ///
			   prodtax npinc medicare medicaid otherkin colexp potax salestax flemp ///
			   proprietors rental profits fkfix fknmo housing_tenant housing_owner ///
			   equ_scorp equ_nscorp business pensions fixed mortgage_tenant mortgage_owner ///
			   nonmortage prisupgov prisupenprivate


// Loop over monthly microfiles
forval t = `date_begin' / `date_end' {
	quietly{
		noisily di "* " %tm = `t'
		local year = year(dofm(`t'))
		local month = month(dofm(`t'))

		// Loop over populations
		foreach pop in adult_equal_split working_age_equal_split adult_households {
			use year month id weight age `all_vars' using "$microfiles/$update_id/dina-monthly-`year'm`month'.dta", clear

			// Collapse to household level or split equally
			if ("`pop'" == "adult_households") {
				gcollapse (nansum) `all_vars' (mean) weight, by(year month id)
			}
			else {
				foreach v of varlist `all_vars' {
					gegen `v' = mean(`v'), by(id) replace
				}
				// Limit to working age if requested
				if ("`pop'" == "working_age_equal_split") keep if age < 65
			}

			local saved = 0
			while !`saved' {
				cap save "$work/03-tabulate-income/tempfiles/current_pop.dta", replace
				if (_rc == 0) local saved = 1
				else sleep 2000
			}

			// Loop over concepts
			foreach concept in peinc princ dispo poinc /*hweal*/ {

				use "$work/03-tabulate-income/tempfiles/current_pop.dta", clear

				if ("`concept'" == "princ") {
					replace govin = -govin
					local decomp flemp proprietors rental profits corptax fkfix prodtax npinc fknmo govin prodsub covidsub
				}
				else if ("`concept'" == "peinc") {
					local decomp princ uiben penben surplus contrib
				}
				else if ("`concept'" == "dispo") {
					replace peinc = peinc - surplus - govin
					local decomp peinc vet othcash covidrelief prodsub covidsub othercontrib taxes estatetax corptax prodtax npinc
				}
				else if ("`concept'" == "poinc") {
					replace prisupgov = prisupgov + govin + prisupenprivate
					local decomp dispo medicare medicaid otherkin colexp potax npinc prisupgov salestax
				}
				
				/*
				else if ("`concept'" == "hweal") {
					local decomp housing_tenant housing_owner equ_scorp equ_nscorp business pensions fixed mortgage_tenant mortgage_owner nonmortage
				}
				*/

				// Compute rank (sorted by concept)
				gsort `concept'
				gen rank = sum(weight)

				// Wealth: 1e7 scale for ultra-fine top resolution (top 0.0001% and top 0.00001%)
				// Other concepts: standard 1e5 scale
				if ("`concept'" == "hweal") {
					replace rank = 1e7*(rank - weight/2)/rank[_N]
					gegen p = cut(rank), at(0(100000)9900000 9910000(10000)9990000 9991000(1000)9999000 ///
					9999100(100)9999900 9999910(10)9999990 9999991(1)9999999 10000001)
				}
				else {
					replace rank = 1e5*(rank - weight/2)/rank[_N]
					gegen p = cut(rank), at(0(1000)99000 99100(100)99900 99910(10)99990 99991(1)99999 100001)
				}

				// Tabulate: mean components, min threshold, obs count, population
				generate one = 1
				gcollapse (mean) `concept' `decomp' ///
				          (min) threshold=`concept' (rawsum) n_obs=one ///
				          (rawsum) pop=weight [pw=weight], by(year month p)

				// Append and save
				append using "$work/03-tabulate-income/tabulation-`concept'-`pop'.dta"
				local saved = 0
				while !`saved' {
					cap save "$work/03-tabulate-income/tabulation-`concept'-`pop'.dta", replace
					if (_rc == 0) local saved = 1
					else sleep 2000
				}
			}
		}
	}
}
