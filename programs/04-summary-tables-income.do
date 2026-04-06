// -------------------------------------------------------------------------- //
// Produce summary tables of recent income dynamics by pretax income group
// -------------------------------------------------------------------------- //

local xl "$tables/04-summary-tables-income/summary-tables-income.xlsx"
cap erase "`xl'"

local date_end = $date_end
local concepts princ peinc dispo poinc
local groups bot50 mid40 top10 top1 top01 top001 total

local pmin_bot50  = 0
local pmax_bot50  = 49999
local pmin_mid40  = 50000
local pmax_mid40  = 89999
local pmin_top10  = 90000
local pmax_top10  = 99999
local pmin_top1   = 99000 
local pmax_top1   = 99999
local pmin_top01  = 99900
local pmax_top01  = 99999
local pmin_top001 = 99990
local pmax_top001 = 99999
local pmin_total  = 0
local pmax_total  = 99999

local popshare_bot50  = 0.50
local popshare_mid40  = 0.40
local popshare_top10  = 0.10
local popshare_top1   = 0.01
local popshare_top01  = 0.001
local popshare_top001 = 0.0001
local popshare_total  = 1.0

local glabel_bot50   "Bottom 50%"
local glabel_mid40   "Middle 40%"
local glabel_top10   "Top 10%"
local glabel_top1    "Top 1%"
local glabel_top01   "Top 0.1%"
local glabel_top001  "Top 0.01%"
local glabel_total   "Total"

local ilabel_princ  "Factor Income"
local ilabel_peinc  "Pre-tax Income"
local ilabel_dispo  "Disposable Income"
local ilabel_poinc  "Post-tax Income"

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


// -------------------------------------------------------------------------- //
// One sheet per income concept x window
// -------------------------------------------------------------------------- //

foreach income in `concepts' {

    use "$work/03-tabulate-income/tabulation-`income'-adult_equal_split.dta", clear

    merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
        keepusing(nipa_deflator) nogenerate keep(master match)

    local decomp `decomp_`income''
    local signs  `signs_`income''
    local ncomp  : word count `decomp'

    // Deflate and annualize
    foreach v of varlist `income' `decomp' {
        replace `v' = `v' / nipa_deflator / 12
    }
    drop nipa_deflator

    // Cell weight: width on the 0-99999 percentile grid
    sort year month p
    by year month: generate n = cond(_n == _N, 1e5 - p, p[_n+1] - p)
    generate t = ym(year, month)
    quietly summarize t
    local t_min = r(min)

    // Monthly total mean income (share denominator)
    preserve
        gcollapse (mean) total_inc = `income' [iw=n], by(t)
        tempfile totals
        save `totals'
    restore

    // Monthly group means
    foreach g in `groups' {
        preserve
            keep if inrange(p, `pmin_`g'', `pmax_`g'')
            gcollapse (mean) `income' `decomp' [iw=n], by(t)
            foreach v of varlist `income' `decomp' {
                rename `v' `v'_`g'
            }
            tempfile grp_`g'
            save `grp_`g''
        restore
    }

    use `totals', clear
    foreach g in `groups' {
        merge 1:1 t using `grp_`g'', nogenerate
        generate share_`g' = `income'_`g' * `popshare_`g'' / total_inc
    }

    tempfile monthly_panel
    save `monthly_panel'

    foreach w in 1q 1y 5y 10y {

        use `monthly_panel', clear

        local lag   = `lag_`w''
        local nyears = `nyears_`w''
        local t_pas = `date_end' - `lag'
        if (`t_pas' < `t_min') {
            di as text "Skipping `income'_`w': reference month (`=string(`t_pas', "%tm")') " ///
                "predates data start (`=string(`t_min', "%tm")')"
            continue
        }

        // Extract scalars for cur (date_end)
        preserve
            keep if t == `date_end'
            if _N == 0 {
                restore
                di as text "Skipping `income'_`w': date_end not in data"
                continue
            }
            foreach g in `groups' {
                scalar sc_cur_inc_`g' = `income'_`g'[1]
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
                di as text "Skipping `income'_`w': reference month (`=string(`t_pas', "%tm")') not in data"
                continue
            }
            foreach g in `groups' {
                scalar sc_pas_inc_`g' = `income'_`g'[1]
                scalar sc_pas_shr_`g' = share_`g'[1]
                forvalues ci = 1/`ncomp' {
                    local v = word("`decomp'", `ci')
                    scalar sc_pas_`v'_`g' = `v'_`g'[1]
                }
            }
        restore

        // Open sheet
        local sheet "`income'_`w'"
        putexcel set "`xl'", sheet("`sheet'") modify

        // Column headers
        putexcel A1 = "Group"
        putexcel B1 = "Income share (%)"
        putexcel C1 = "Share variation (ppt, total over period)"
        putexcel D1 = "Average income ($)"
        putexcel E1 = "Income Gain ($, total over period)"
        putexcel F1 = "Income Growth (%/yr)"
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
            local gain   = (`inc_cur' - `inc_pas')
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
        putexcel A`title_row' = "`ilabel_`income'' (individuals ranked by `income') - `wlabel_`w'' - From `pas_label' To `end_label'"

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

        noisily di "* Sheet `sheet' done"
    }
}
