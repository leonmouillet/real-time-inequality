// -------------------------------------------------------------------------- //
// Produce summary tables of recent wealth dynamics by wealth group
// -------------------------------------------------------------------------- //

local xl "$tables/04-summary-tables-wealth/summary-tables-wealth.xlsx"
cap erase "`xl'"

local date_end = $date_end
local groups bot50 mid40 top10 top1 top01 top001

local pmin_bot50  = 0
local pmax_bot50  = 4999999
local pmin_mid40  = 5000000
local pmax_mid40  = 8999999
local pmin_top10  = 9000000
local pmax_top10  = 9999999
local pmin_top1   = 9900000
local pmax_top1   = 9999999
local pmin_top01  = 9990000
local pmax_top01  = 9999999
local pmin_top001 = 9999000
local pmax_top001 = 9999999
local pmin_total  = 0
local pmax_total  = 9999999

local popshare_bot50  = 0.50
local popshare_mid40  = 0.40
local popshare_top10  = 0.10
local popshare_top1   = 0.01
local popshare_top01  = 0.001
local popshare_top001 = 0.0001
local popshare_top001 = 0.0001
local popshare_total  = 1.0

local glabel_bot50   "Bottom 50%"
local glabel_mid40   "Middle 40%"
local glabel_top10   "Top 10%"
local glabel_top1    "Top 1%"
local glabel_top01   "Top 0.1%"
local glabel_top001  "Top 0.01%"
local glabel_total   "Total"

local decomp_hweal  housing_tenant housing_owner equ_scorp equ_nscorp business pensions fixed mortgage_tenant mortgage_owner nonmortage
local signs_hweal   1              1             1         1          1        1        1     -1              -1             -1

local label_hweal            "Net wealth"
local label_housing_tenant   "Housing (tenant-occupied)"
local label_housing_owner    "Housing (owner-occupied)"
local label_equ_scorp        "S-corporation equity"
local label_equ_nscorp       "Non-S-corporation equity"
local label_business         "Noncorporate equity"
local label_pensions         "Pension assets"
local label_fixed            "Fixed-income assets"
local label_mortgage_tenant  "Mortgages (tenant-occupied)"
local label_mortgage_owner   "Mortgages (owner-occupied)"
local label_nonmortage       "Non-mortgage debt"

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

// -------------------------------------------------------------------------- //
// One sheet per window
// -------------------------------------------------------------------------- //

local income hweal
local decomp `decomp_hweal'
local signs  `signs_hweal'
local ncomp  : word count `decomp'

use "$work/03-tabulate-income/tabulation-hweal-adult_equal_split.dta", clear

// Deflate
merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    keepusing(nipa_deflator) nogenerate keep(master match)
	
foreach v of varlist hweal `decomp' {
    replace `v' = `v' / nipa_deflator
}
drop nipa_deflator

// Cell weight: width on the 0-99999 percentile grid
sort year month p
by year month: generate n = cond(_n == _N, 1e7 - p, p[_n+1] - p)
generate t = ym(year, month)
quietly summarize t
local t_min = r(min)

// Monthly total mean wealth
preserve
    gcollapse (mean) total_inc = hweal [iw=n], by(t)
    tempfile totals
    save `totals'
restore

// Monthly group means
foreach g in `groups' {
    preserve
        keep if inrange(p, `pmin_`g'', `pmax_`g'')
        gcollapse (mean) hweal `decomp' [iw=n], by(t)
        foreach v of varlist hweal `decomp' {
            rename `v' `v'_`g'
        }
        tempfile grp_`g'
        save `grp_`g''
    restore
}

use `totals', clear
foreach g in `groups' {
    merge 1:1 t using `grp_`g'', nogenerate
    generate share_`g' = hweal_`g' * `popshare_`g'' / total_inc
}

tempfile monthly_panel
save `monthly_panel'

foreach w in 1q 1y 5y 10y {

    use `monthly_panel', clear

    local lag    = `lag_`w''
    local nyears = `nyears_`w''
    local t_pas  = `date_end' - `lag'

    if (`t_pas' < `t_min') {
        di as text "Skipping hweal_`w': reference month (`=string(`t_pas', "%tm")') " ///
            "predates data start (`=string(`t_min', "%tm")')"
        continue
    }

    // Extract scalars for cur (date_end)
    preserve
        keep if t == `date_end'
        if _N == 0 {
            restore
            di as text "Skipping hweal_`w': date_end not in data"
            continue
        }
        foreach g in `groups' {
            scalar sc_cur_inc_`g' = hweal_`g'[1]
            scalar sc_cur_shr_`g' = share_`g'[1]
            forvalues ci = 1/`ncomp' {
                local v = word("`decomp'", `ci')
                scalar sc_cur_`v'_`g' = `v'_`g'[1]
            }
        }
    restore

    // Extract scalars for pas (date_end - lag)
    preserve
        keep if t == `t_pas'
        if _N == 0 {
            restore
            di as text "Skipping hweal_`w': reference month (`=string(`t_pas', "%tm")') not in data"
            continue
        }
        foreach g in `groups' {
            scalar sc_pas_inc_`g' = hweal_`g'[1]
            scalar sc_pas_shr_`g' = share_`g'[1]
            forvalues ci = 1/`ncomp' {
                local v = word("`decomp'", `ci')
                scalar sc_pas_`v'_`g' = `v'_`g'[1]
            }
        }
    restore

    // Open sheet
    local sheet "hweal_`w'"
    putexcel set "`xl'", sheet("`sheet'") modify

    // Column headers
    putexcel A1 = "Group"
    putexcel B1 = "Wealth share (%)"
    putexcel C1 = "Share variation (ppt, total over period)"
    putexcel D1 = "Average wealth ($)"
    putexcel E1 = "Wealth Gain ($, total over period)"
    putexcel F1 = "Wealth Growth (%/yr)"
    putexcel G1 = "Residual (ppt)"

    forvalues ci = 1/`ncomp' {
        local v = word("`decomp'", `ci')
        local s = word("`signs'", `ci')
        if `s' ==  1 local sl "(+)"
        if `s' == -1 local sl "(-)"
        local col_letter = char(71 + `ci')
        putexcel `col_letter'1 = "`sl' `label_`v''"
    }

    // Data rows
    local row = 2
    foreach g in `groups' {

        local inc_cur = scalar(sc_cur_inc_`g')
        local inc_pas = scalar(sc_pas_inc_`g')
        local shr_cur = scalar(sc_cur_shr_`g')
        local shr_pas = scalar(sc_pas_shr_`g')

        local denom  = abs(`inc_pas')
        local growth = (`inc_cur' - `inc_pas') / `denom' / `nyears' * 100
        local gain   = (`inc_cur' - `inc_pas') / `nyears'
        local share  = `shr_cur' * 100
        local dshare = (`shr_cur' - `shr_pas') * 100

        local sum_contrib = 0
        forvalues ci = 1/`ncomp' {
            local v = word("`decomp'", `ci')
            local s = word("`signs'", `ci')
            local col_letter = char(71 + `ci')
            local contrib = `s' * (scalar(sc_cur_`v'_`g') - scalar(sc_pas_`v'_`g')) ///
                / `denom' / `nyears' * 100
            putexcel `col_letter'`row' = `contrib', nformat("0.00")
            local sum_contrib = `sum_contrib' + `contrib'
        }

        local resid = `growth' - `sum_contrib'

        putexcel A`row' = "`glabel_`g''"
        putexcel B`row' = `share',   nformat("0.00")
        putexcel C`row' = `dshare',  nformat("0.00")
        putexcel D`row' = `inc_cur', nformat("#,##0")
        putexcel E`row' = `gain',    nformat("#,##0")
        putexcel F`row' = `growth',  nformat("0.00")
        putexcel G`row' = `resid',   nformat("0.00")

        local row = `row' + 1
    }

    // Title below table
    local title_row = `row' + 1
    local pas_label = string(`t_pas',    "%tm")
    local end_label = string(`date_end', "%tm")
    putexcel A`title_row' = "Net Wealth (individuals ranked by wealth) - `wlabel_`w'' - From `pas_label' To `end_label'"

    // Scalar cleanup
    foreach period in cur pas {
        foreach g in `groups' {
            cap scalar drop sc_`period'_inc_`g' sc_`period'_shr_`g'
            forvalues ci = 1/`ncomp' {
                local v = word("`decomp'", `ci')
                cap scalar drop sc_`period'_`v'_`g'
            }
        }
    }

    noisily di "* Sheet hweal_`w' done"
}
