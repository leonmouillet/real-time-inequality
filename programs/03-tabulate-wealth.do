// -------------------------------------------------------------------------- //
// Build monthly tables of wealth by percentiles
// -------------------------------------------------------------------------- //

clear all
local date_begin = $date_begin
local date_end   = $date_end

local all_vars hweal housing_tenant housing_owner equ_scorp equ_nscorp ///
			   business pensions fixed mortgage_tenant mortgage_owner nonmortage
			   
// Initialize Forbes data
frame create forbes_totals
frame forbes_totals: use "$work/03-build-monthly-forbes/forbes-monthly-totals.dta", clear

// Initialize output files
foreach pop in adult_equal_split working_age_equal_split adult_households {
	local outfile "$work/03-tabulate-wealth/tabulation-hweal-`pop'.dta"
	cap confirm file "`outfile'"
	if (_rc == 0) {
		use "`outfile'", clear
		drop if ym(year, month) >= `date_begin' & ym(year, month) <= `date_end'
		save "`outfile'", replace
	}
	else {
		clear
		save "`outfile'", emptyok
	}
}

// Pre-compute median of January-April 1982 scale factors for pre-1982 years
tempname post_mem
tempfile r_data
postfile `post_mem' r_top r_top_wa r_non using `r_data', replace
forval m = 1/4 {
    use age top400 hweal weight using "$microfiles/$update_id/dina-monthly-1982m`m'.dta", clear
    sum hweal [aw=weight] if top400, meanonly
    local t_400 = r(sum)
    sum hweal [aw=weight] if top400 & age < 65, meanonly
    local t_400_wa = r(sum)
    sum hweal [aw=weight] if !top400, meanonly
    local t_rest = r(sum)
    frame forbes_totals: sum forbes_all if year == 1982 & month == `m', meanonly
	local t_forbes = r(mean)
    frame forbes_totals: sum forbes_working_age if year == 1982 & month == `m', meanonly
	local t_forbes_wa = r(mean)
    post `post_mem' (`t_forbes' / `t_400') (`t_forbes_wa' / `t_400_wa') ((`t_400' + `t_rest' - `t_forbes') / `t_rest')
}
postclose `post_mem'
preserve
    use `r_data', clear
	summarize r_top, detail
	local scale_top400_1982 = r(p50)
	summarize r_top_wa, detail
	local scale_top400_wa_1982 = r(p50)
	summarize r_non, detail
	local scale_nontop400_1982 = r(p50)
restore
di `scale_top400_1982'
di `scale_top400_wa_1982'
di `scale_nontop400_1982'

// Loop over monthly microfiles
forval t = `date_begin' / `date_end' {
	noisily di "* " %tm = `t'
	local year  = year(dofm(`t'))
	local month = month(dofm(`t'))
	quietly {
		use year month id weight age top400 `all_vars' ///
			using "$microfiles/$update_id/dina-monthly-`year'm`month'.dta", clear
			
		gen hweal_raw = hweal // used in 03-build-online-database.do
		
		// Scale top400 to match total Forbes (aggregate kept constant)
		if `year' >= 1982 {
			summarize hweal [aw=weight] if top400, meanonly
			local tot_top400 = r(sum)
			summarize hweal [aw=weight] if !top400, meanonly
			local tot_nontop400 = r(sum)
			frame forbes_totals: levelsof forbes_all if year == `year' & month == `month', local(tot_forbes)
			local scale_top400 = `tot_forbes' / `tot_top400' 
			local scale_nontop400 = (`tot_top400' + `tot_nontop400' - `tot_forbes') / `tot_nontop400'
			foreach v of varlist `all_vars' {
				replace `v' = `v' * `scale_top400' if top400
				replace `v' = `v' * `scale_nontop400' if !top400
			}
		}
		else {
			foreach v of varlist `all_vars' {
				replace `v' = `v' * `scale_top400_1982' if top400
				replace `v' = `v' * `scale_nontop400_1982' if !top400
			}
		}
		
		// Loop over populations
		foreach pop in adult_equal_split working_age_equal_split adult_households {
			
			preserve
				if ("`pop'" == "working_age_equal_split") {
					keep if age < 65
					
					// Scale top400 to match total working age Forbes (aggregate allowed to change)
					if `year' >= 1982 {
						summarize hweal [aw=weight] if top400, meanonly
						local tot_top400_wa = r(sum)
						frame forbes_totals: levelsof forbes_working_age if year == `year' & month == `month', local(tot_forbes_wa)
						local scale_top400_wa = `tot_forbes_wa' / `tot_top400_wa'
						foreach v of varlist `all_vars' {
							replace `v' = `v' * `scale_top400_wa' if top400
						}
					}
					else {
						foreach v of varlist `all_vars' {
							replace `v' = `v' * `scale_top400_wa_1982' if top400
						}
					}
				}
				drop top400 age
				
				if ("`pop'" == "adult_households") {
					gcollapse (nansum) hweal_raw `all_vars' (mean) weight, by(year month id)
				}

				// Compute rank
				gsort hweal
				gen rank = sum(weight)
				replace rank = 1e7*(rank - weight/2)/rank[_N]
				gegen p = cut(rank), at(0(100000)9900000 9910000(10000)9990000 9991000(1000)9999000 ///
				9999100(100)9999900 9999910(10)9999990 9999991(1)9999999 10000001)

				// Tabulate: mean wealth components, min threshold, obs count, population
				generate one = 1
				gcollapse (mean) hweal_raw `all_vars' ///
						  (min) threshold=hweal (rawsum) n_obs=one ///
						  (rawsum) pop=weight [pw=weight], by(year month p)

				// Append and save
				append using "$work/03-tabulate-wealth/tabulation-hweal-`pop'.dta"
				local saved = 0
				while !`saved' {
					cap save "$work/03-tabulate-wealth/tabulation-hweal-`pop'.dta", replace
					if (_rc == 0) local saved = 1
					else sleep 2000
				}
			restore
		}
	}
}
