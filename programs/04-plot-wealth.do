// -------------------------------------------------------------------------- //
// Plot decomposition of wealth by broad wealth group
// -------------------------------------------------------------------------- //

local date_begin = ym(2000, 01)
local date_end   = $date_end

local label_hweal           "Net wealth"
local label_housing_tenant  "Housing (tenant-occupied)"
local label_housing_owner   "Housing (owner-occupied)"
local label_equ_scorp       "S-corporation equity"
local label_equ_nscorp      "Non-S-corporation equity"
local label_business        "Noncorporate equity"
local label_pensions        "Pension assets"
local label_fixed           "Fixed-income assets"
local label_mortgage_tenant "Mortgages (tenant-occupied)"
local label_mortgage_owner  "Mortgages (owner-occupied)"
local label_nonmortage      "Non-mortgage debt"

local decomposition_pos housing_tenant housing_owner equ_scorp equ_nscorp business pensions fixed
local decomposition_neg mortgage_tenant mortgage_owner nonmortage


foreach pop in adult_equal_split working_age_equal_split adult_households {

	use "$work/03-tabulate-wealth/tabulation-hweal-`pop'.dta", clear

	keep if inrange(ym(year, month), `date_begin', `date_end')

	merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
		nogenerate keepusing(nipa_deflator) keep(master match)

	sort year month p
	by year month: generate n = cond(_n == _N, 1e7 - p, p[_n+1] - p)

	generate bracket = ""
	replace bracket = "Bottom 50%" if inrange(p, 0,       4900000)
	replace bracket = "Middle 40%" if inrange(p, 5000000, 8900000)
	replace bracket = "Next 9%"    if inrange(p, 9000000, 9800000)
	replace bracket = "Top 1%"     if inrange(p, 9900000, 9999999)
	drop if bracket == ""

	gcollapse (mean) hweal `decomposition_pos' `decomposition_neg' ///
		(firstnm) nipa_deflator [pw=n], by(year month bracket)


	local vlist ""
	local v_prev ""

	foreach v of varlist `decomposition_neg' {
		if ("`v_prev'" == "") {
			generate decomp_`v' = -`v'/nipa_deflator
			label variable decomp_`v' "`label_`v''"
		}
		else {
			generate decomp_`v' = decomp_`v_prev' - `v'/nipa_deflator
			label variable decomp_`v' "`label_`v''"
		}
		local v_prev `v'
		local vlist decomp_`v' `vlist'
	}

	local v_prev ""
	foreach v of varlist `decomposition_pos' {
		if ("`v_prev'" == "") {
			generate decomp_`v' = `v'/nipa_deflator
			label variable decomp_`v' "`label_`v''"
		}
		else {
			generate decomp_`v' = decomp_`v_prev' + `v'/nipa_deflator
			label variable decomp_`v' "`label_`v''"
		}
		local v_prev `v'
		local vlist decomp_`v' `vlist'
	}

	generate time = ym(year, month)
	format time %tm

	replace hweal = hweal/nipa_deflator
	label variable hweal "`label_hweal'"

	foreach bracket in "Bottom 50%" "Middle 40%" "Next 9%" "Top 1%" {

		if      "`bracket'" == "Bottom 50%" local bslug "bot50"
		else if "`bracket'" == "Middle 40%" local bslug "mid40"
		else if "`bracket'" == "Next 9%"    local bslug "next9"
		else if "`bracket'" == "Top 1%"     local bslug "top1"

		gr tw ///
			(area `vlist' time if bracket == "`bracket'", lw(none..)) ///
			(con hweal time if bracket == "`bracket'", col(black) lw(medthick) msize(small) msym(Oh)), ///
			legend(pos(3) cols(1) size(tiny)) xtitle("") ytitle("USD (constant)") ///
			title("`bracket'") subtitle("`label_hweal'") aspectratio(1) ///
			xlabel(, labsize(small) angle(45)) ylabel(, labsize(small))
		graph export "$graphs/04-plot-wealth/tabulation-hweal-`pop'-`bslug'.pdf", replace
	}
}