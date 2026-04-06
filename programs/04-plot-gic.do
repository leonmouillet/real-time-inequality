// -------------------------------------------------------------------------- //
// Plot growth incidence curves decomposed by income component
// -------------------------------------------------------------------------- //

local decomp_princ  flemp proprietors rental profits corptax fkfix prodtax npinc fknmo govin prodsub covidsub
local signs_princ   1     1            1      1       1       1     1       1     -1    -1    -1      -1
local decomp_peinc  princ uiben penben surplus contrib
local signs_peinc   1     1     1      1       -1
local decomp_dispo  peinc vet othcash covidrelief prodsub covidsub npinc othercontrib taxes estatetax corptax prodtax
local signs_dispo   1     1   1       1           1       1        -1    -1           -1    -1        -1      -1
local decomp_poinc  dispo medicare medicaid otherkin colexp npinc potax prisupgov salestax
local signs_poinc   1     1        1        1        1      1     1     1         -1

local label_princ "Factor national income"
local label_peinc "Pretax national income"
local label_poinc "Post-tax national income"
local label_dispo "Post-tax disposable income"
local label_flemp "Compensation of employees"
local label_contrib "Social contributions"
local label_uiben "Unemployment insurance benefits"
local label_penben "Pension + disability insurance benefits"
local label_surplus "Surplus/deficit of social insurance"
local label_proprietors "Proprietor's income"
local label_rental "Rental income"
local label_profits "Undistributed profits"
local label_fkfix "Interest income"
local label_govin "Government interest income"
local label_fknmo "Nonmortage interest payments"
local label_corptax "Corporate tax"
local label_prodtax "Production taxes"
local label_taxes "Current taxes on income and wealth"
local label_estatetax "Estate tax"
local label_othercontrib "Non social security contributions"
local label_vet "Veteran benefits"
local label_othcash "Other cash benefits"
local label_medicare "Medicare"
local label_medicaid "Medicaid"
local label_otherkin "Other in-kind transfers"
local label_colexp "Collective expenditures"
local label_prisupenprivate "Surplus/deficit of private insurance system"
local label_prisupgov "Surplus/deficit"
local label_covidrelief "COVID relief"
local label_covidsub "Paycheck Protection Program"
local label_prodsub "Production subsidies"
local label_npinc "Income of nonprofits"
local label_proptax "Property taxes"
local label_salestax "Sales taxes"

local lag_1q  = 3
local lag_1y  = 12
local lag_5y  = 60
local lag_10y = 120
local nyears_1q  = 0.25
local nyears_1y  = 1
local nyears_5y  = 5
local nyears_10y = 10
local wlabel_1q  "Last Quarter"
local wlabel_1y  "Last Year"
local wlabel_5y  "Last 5 Years"
local wlabel_10y "Last 10 Years"

local date_end = $date_end


foreach pop in adult_equal_split /*working_age_equal_split adult_households*/ {
	foreach window in 1q 1y 5y 10y {
		
		local lag    = `lag_`window''
		local nyears = `nyears_`window''
		local t_end  = `date_end'
		local t_pas  = `t_end' - `lag'
		local y1 = year(dofm(`t_pas'))
		local m1 = month(dofm(`t_pas'))
		local y2 = year(dofm(`t_end'))
		local m2 = month(dofm(`t_end'))
		
		
		foreach income in princ peinc dispo poinc {

			local decomp `decomp_`income''
			local signs  `signs_`income''
			local ncomp  : word count `decomp'

			// Build deduplicated variable list (peinc for ranking + income + components)
			local all_vars ""
			foreach v in peinc `income' `decomp_`income'' surplus govin prisupenprivate {
				local dup 0
				foreach u of local all_vars { 
					if "`v'" == "`u'" local dup 1
				}
				if !`dup' local all_vars `all_vars' `v'
			}

			// Load and process each period
			foreach period in 0 1 {
				local t = cond(`period' == 0, `t_pas', `t_end')
				local y = year(dofm(`t'))
				local m = month(dofm(`t'))

				use year month id weight age `all_vars' ///
					using "$microfiles/$update_id/dina-monthly-`y'm`m'.dta", clear

				if ("`pop'" == "working_age_equal_split") keep if age < 65
				if ("`pop'" == "adult_households") {
					gcollapse (sum) `all_vars' (rawsum) weight, by(year month id)
				}
				else {
					foreach v of local all_vars {
						gegen `v' = mean(`v'), by(id) replace
					}
				}

				// Rank by peinc
				sort peinc
				generate rank = sum(weight)
				replace rank = 1e5*(rank - weight/2)/rank[_N]
				egen p = cut(rank), at(0(10000)90000 99000 999999)

				gcollapse (mean) `all_vars' [pw=weight], by(p)

				// Same variable adjustments as 03-tabulate-income
				if ("`income'" == "princ") {
					replace govin = -govin
				}
				else if ("`income'" == "dispo") {
					replace peinc = peinc - surplus - govin
				}
				else if ("`income'" == "poinc") {
					replace prisupgov = prisupgov + govin + prisupenprivate
				}
			
				// Deflate
				generate year  = `y'
				generate month = `m'
				merge m:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
					keepusing(nipa_deflator) nogenerate keep(match)
				foreach v of local all_vars {
					replace `v' = `v' / nipa_deflator
				}
				drop year month nipa_deflator

				foreach v of local all_vars {
					rename `v' `v'`period'
				}

				if `period' == 0 { 
					tempfile period0
					save `period0'
				}
				else {
					merge 1:1 p using `period0', nogenerate
				}
			}

			// Signed contributions (exact accounting identity)
			forvalues ci = 1/`ncomp' {
				local v = word("`decomp'", `ci')
				local s = word("`signs'", `ci')
				generate contrib_`v' = `s' * (`v'1 - `v'0) / abs(`income'0) / `nyears' * 100
				label variable contrib_`v' "`label_`v''"
			}
			
			// Total income growth
			generate growth = (`income'1 - `income'0) / abs(`income'0) / `nyears' * 100
			
			// Check residual = growth - sum of contributions
			generate resid = growth
			forvalues ci = 1/`ncomp' {
				local v = word("`decomp'", `ci')
				replace resid = resid - contrib_`v'
			}
			assert abs(resid) < 1e-4
			drop resid

			// Stacking: pos upward, neg downward
			generate stack_lo = 0
			generate stack_hi = 0
			local tw_cmd ""
			local leg_order ""
			local i = 1

			forvalues ci = 1/`ncomp' {
				local v = word("`decomp'", `ci')
				generate bar_lo_`v' = cond(contrib_`v' >= 0, stack_hi, stack_lo + contrib_`v')
				generate bar_hi_`v' = cond(contrib_`v' >= 0, stack_hi + contrib_`v', stack_lo)
				replace stack_hi = stack_hi + max(0, contrib_`v')
				replace stack_lo = stack_lo + min(0, contrib_`v')
				local tw_cmd `"`tw_cmd' (rbar bar_lo_`v' bar_hi_`v' p, barw(9000) lw(none))"'
				local leg_order `"`leg_order' `i' "`label_`v''""'
				local i = `i' + 1
			}
			drop stack_lo stack_hi

			local tw_cmd `"`tw_cmd' (scatter growth p, col(black) msym(Oh) msize(small) connect(l) lw(medthick))"'
			local leg_order `"`leg_order' `i' "Total growth""'

			// Date labels
			local y1 = year(dofm(`t_pas'))
			local m1 = month(dofm(`t_pas'))
			local y2 = year(dofm(`t_end'))
			local m2 = month(dofm(`t_end'))
	
			gr tw `tw_cmd', ///
				title("`label_`income''", size(small)) ///
				xtitle("Percentiles (`pop', ranked by pre-tax national income)", size(vsmall)) ///
				ytitle("Annualized real income growth (%)", size(vsmall)) ///
				xlabel(0 "0-10%" 10000 "10-20%" 20000 "20-30%" 30000 "30-40%" 40000 "40-50%" ///
					50000 "50-60%" 60000 "60-70%" 70000 "70-80%" 80000 "80-90%" ///
					90000 "90-99%" 99000 "Top 1%", alternate labsize(tiny) angle(45)) ///
				ylabel(, labsize(tiny)) ///
				legend(order(`leg_order') pos(3) cols(1) size(tiny) symxsize(3) keygap(1) rowgap(0.5) ring(1)) ///
				aspectratio(0.8) ///
				plotregion(margin(zero)) graphregion(margin(small)) ///
				name(g_`income', replace) nodraw

		}
		
		graph combine g_princ g_peinc g_dispo g_poinc, ///
			cols(2) imargin(zero) ///
			xcommon ycommon ///
			title("`wlabel_`window'' (`m1'/`y1' to `m2'/`y2')", size(medium)) ///
			xsize(11.69) ysize(8.27) scale(0.75)

		graph export "$graphs/04-plot-gic/gic-`pop'-`window'.pdf", replace
		
	}
}