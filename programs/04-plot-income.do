// -------------------------------------------------------------------------- //
// Plot decomposition of income by broad income group
// -------------------------------------------------------------------------- //

local date_begin = ym(2000, 01)
local date_end   = $date_end

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
local label_salestax "Sales taxes"
local label_potax "Property tax (redistributed)"

local decomposition_pos_princ flemp proprietors rental profits corptax fkfix prodtax npinc
local decomposition_neg_princ fknmo govin prodsub covidsub
local decomposition_mid_princ ""

local decomposition_pos_peinc princ uiben penben
local decomposition_mid_peinc surplus
local decomposition_neg_peinc contrib

local decomposition_pos_dispo peinc vet othcash covidrelief prodsub covidsub
local decomposition_mid_dispo ""
local decomposition_neg_dispo othercontrib taxes estatetax corptax prodtax npinc

local decomposition_pos_poinc dispo medicare medicaid otherkin colexp potax npinc
local decomposition_mid_poinc prisupgov
local decomposition_neg_poinc salestax


foreach income in princ peinc dispo poinc {
    foreach pop in adult_equal_split working_age_equal_split adult_households {

        local decomposition_pos `decomposition_pos_`income''
        local decomposition_mid `decomposition_mid_`income''
        local decomposition_neg `decomposition_neg_`income''

        use "$work/03-tabulate-income/tabulation-`income'-`pop'.dta", clear

        keep if inrange(ym(year, month), `date_begin', `date_end')

        merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
            nogenerate keepusing(nipa_deflator) keep(master match)

        sort year month p
        by year month: generate n = cond(_n == _N, 1e5 - p, p[_n+1] - p)

        generate bracket = ""
        replace bracket = "Bottom 50%" if inrange(p, 00000, 49000)
        replace bracket = "Middle 40%" if inrange(p, 50000, 89000)
        replace bracket = "Next 9%"    if inrange(p, 90000, 98000)
        replace bracket = "Top 1%"     if inrange(p, 99000, 99999)
        drop if bracket == ""

        gcollapse (mean) `income' `decomposition_pos' `decomposition_mid' `decomposition_neg' ///
            (firstnm) nipa_deflator [pw=n], by(year month bracket)

        local vlist ""
        local v_prev ""

        if ("`decomposition_neg'" != "") {
            foreach v of varlist `decomposition_neg' {
                if ("`v_prev'" == "") {
                    if ("`decomposition_mid'" != "") {
                        generate decomp_`v' = min(0, `decomposition_mid'/nipa_deflator/12) - `v'/nipa_deflator/12
                    }
                    else {
                        generate decomp_`v' = -`v'/nipa_deflator/12
                    }
                    label variable decomp_`v' "`label_`v''"
                }
                else {
                    generate decomp_`v' = decomp_`v_prev' - `v'/nipa_deflator/12
                    label variable decomp_`v' "`label_`v''"
                }
                local v_prev `v'
                local vlist decomp_`v' `vlist'
            }
        }

        if ("`decomposition_mid'" != "") {
            generate decomp_`decomposition_mid' = `decomposition_mid'/nipa_deflator/12
            label variable decomp_`decomposition_mid' "`label_`decomposition_mid''"
            local vlist `vlist' decomp_`decomposition_mid'
        }

        local v_prev ""
        foreach v of varlist `decomposition_pos' {
            if ("`v_prev'" == "") {
                if ("`decomposition_mid'" != "") {
                    generate decomp_`v' = max(0, `decomposition_mid'/nipa_deflator/12) + `v'/nipa_deflator/12
                }
                else {
                    generate decomp_`v' = `v'/nipa_deflator/12
                }
                label variable decomp_`v' "`label_`v''"
            }
            else {
                generate decomp_`v' = decomp_`v_prev' + `v'/nipa_deflator/12
                label variable decomp_`v' "`label_`v''"
            }
            local v_prev `v'
            local vlist decomp_`v' `vlist'
        }

        generate time = ym(year, month)
        format time %tm

        replace `income' = `income'/nipa_deflator/12
        label variable `income' "`label_`income''"

        foreach bracket in "Bottom 50%" "Middle 40%" "Next 9%" "Top 1%" {

            if      "`bracket'" == "Bottom 50%" local bslug "bot50"
            else if "`bracket'" == "Middle 40%" local bslug "mid40"
            else if "`bracket'" == "Next 9%"    local bslug "next9"
            else if "`bracket'" == "Top 1%"     local bslug "top1"

            gr tw ///
                (area `vlist' time if bracket == "`bracket'", lw(none..)) ///
                (con `income' time if bracket == "`bracket'", col(black) lw(medthick) msize(small) msym(Oh)), ///
                legend(pos(3) cols(1) size(tiny)) xtitle("") ytitle("USD (constant)") ///
                title("`bracket'") subtitle("`label_`income''") aspectratio(1) ///
                xlabel(, labsize(small) angle(45)) ylabel(, labsize(small))
            graph export "$graphs/04-plot-income/tabulation-`income'-`pop'-`bslug'.pdf", replace
        }

        noisily di "* `income', `pop' done"
    }
}
