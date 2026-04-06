// -------------------------------------------------------------------------- //
// Plot income shares
// -------------------------------------------------------------------------- //

local date_begin = ym(2020, 01)
local date_end   = $date_end

local pmin_bot50 = 0
local pmax_bot50 = 49999
local pmin_mid40 = 50000
local pmax_mid40 = 89999
local pmin_next9 = 90000
local pmax_next9 = 98999
local pmin_top1  = 99000
local pmax_top1  = 99999

local popshare_bot50 = 0.50
local popshare_mid40 = 0.40
local popshare_next9 = 0.09
local popshare_top1  = 0.01

local glabel_bot50 "Bottom 50%"
local glabel_mid40 "Middle 40%"
local glabel_next9 "Next 9%"
local glabel_top1  "Top 1%"

local label_princ "Factor national income"
local label_peinc "Pretax national income"
local label_dispo "Post-tax disposable income"
local label_poinc "Post-tax national income"
local label_hweal "Wealth"

local col_bot50 ebblue
local col_mid40 dkgreen
local col_next9 orange
local col_top1  cranberry

foreach pop in adult_equal_split /*working_age_equal_split*/ {
	foreach concept in princ /*peinc dispo poinc hweal*/ {

		use "$work/03-tabulate-income/tabulation-`concept'-`pop'.dta", clear

		keep if inrange(ym(year, month), `date_begin', `date_end')

		// Cell weight = grid width
		sort year month p
		by year month: generate n = cond(_n == _N, 1e5 - p, p[_n+1] - p)

		// Total mean income (denominator for shares)
		preserve
			gcollapse (mean) total = `concept' [iw=n], by(year month)
			tempfile totals
			save `totals'
		restore

		// Group means
		foreach g in bot50 mid40 next9 top1 {
			preserve
				keep if inrange(p, `pmin_`g'', `pmax_`g'')
				gcollapse (mean) mean_`g' = `concept' [iw=n], by(year month)
				tempfile grp_`g'
				save `grp_`g''
			restore
		}

		use `totals', clear
		foreach g in bot50 mid40 next9 top1 {
			merge 1:1 year month using `grp_`g'', nogenerate
			generate share_`g' = 100 * mean_`g' * `popshare_`g'' / total
		}

		generate time = ym(year, month)
		format time %tm

		// Smooth to quarterly
		*generate quarter = quarter(dofm(time))
		*gcollapse (mean) share_bot50 share_mid40 share_next9 share_top1, by(year quarter)
		*generate time = yq(year, quarter)
		*format time %tq

		label variable share_bot50 "`glabel_bot50'"
		label variable share_mid40 "`glabel_mid40'"
		label variable share_next9 "`glabel_next9'"
		label variable share_top1  "`glabel_top1'"
		
		gr tw ///
			(line share_bot50 time, lw(medthick) col(`col_bot50')) ///
			(line share_mid40 time, lw(medthick) col(`col_mid40')) ///
			(line share_next9 time, lw(medthick) col(`col_next9')) ///
			(line share_top1  time, lw(medthick) col(`col_top1')),  ///
			xtitle("") ytitle("Income share (%)") ///
			title("`label_`concept''") subtitle("`pop'") ///
			legend(rows(2) label(1 "`glabel_bot50'") label(2 "`glabel_mid40'") ///
				   label(3 "`glabel_next9'") label(4 "`glabel_top1'") pos(6)) ///
			xlabel(, labsize(small)) ylabel(, format(%02.0f))

		graph export "$graphs/04-plot-shares/shares-`concept'-`pop'.pdf", replace

		noisily di "* `concept', `pop' done"
	}
}