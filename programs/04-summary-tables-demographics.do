// ------------------------------------------------------------------------------------ //
// Produce summary tables of recent income and wealth dynamics by demographic group
// ------------------------------------------------------------------------------------ //

local xl "$tables/04-summary-tables-demographics/summary-tables-demographics.xlsx"
cap erase "`xl'"

local date_end = $date_end
local concepts princ peinc dispo poinc wage pkinc hweal
local demo_types race gender educ race_gender

local groups_race        white black hispanic
local groups_gender      men women
local groups_educ        nocollege college
local groups_race_gender white_men white_women black_men black_women hispanic_men hispanic_women

local glabel_white         "White"
local glabel_black         "Black"
local glabel_hispanic      "Hispanic"
local glabel_men           "Men"
local glabel_women         "Women"
local glabel_nocollege     "No college"
local glabel_college       "College"
local glabel_white_men     "White men"
local glabel_white_women   "White women"
local glabel_black_men     "Black men"
local glabel_black_women   "Black women"
local glabel_hispanic_men  "Hispanic men"
local glabel_hispanic_women "Hispanic women"

local dtlabel_race         "By Race"
local dtlabel_gender       "By Gender"
local dtlabel_educ         "By Education"
local dtlabel_race_gender  "By Race x Gender"

local clabel_princ  "Factor income"
local clabel_peinc  "Pre-tax income"
local clabel_dispo  "Disposable income"
local clabel_poinc  "Post-tax income"
local clabel_wage   "Labor income (age<65)"
local clabel_pkinc  "Capital income (age<65)"
local clabel_hweal  "Net wealth"

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


// adult_equal_split: princ, peinc, dispo, poinc, pkinc, hweal
use "$work/03-tabulate-demographics/tabulation-demographics-adult_equal_split.dta", clear
keep year month group demo_type princ peinc dispo poinc pkinc hweal
tempfile adult
save `adult'

// working_age_equal_split: wage
use "$work/03-tabulate-demographics/tabulation-demographics-working_age_equal_split.dta", clear
keep year month group demo_type wage
merge 1:1 year month group demo_type using `adult', nogenerate

merge n:1 year month using "$work/02-prepare-nipa/nipa-simplified-monthly.dta", ///
    keepusing(nipa_deflator) nogenerate keep(master match)

foreach c in princ peinc dispo poinc pkinc wage {
    replace `c' = `c' / nipa_deflator / 12
}
replace hweal = hweal / nipa_deflator
drop nipa_deflator

rename (princ peinc dispo poinc pkinc hweal wage) ///
       (mean_incomeprinc mean_incomepeinc mean_incomedispo mean_incomepoinc ///
        mean_incomepkinc mean_incomehweal mean_incomewage)

generate t = ym(year, month)
quietly summarize t
local t_min = r(min)

tempfile panel
save `panel'


// -------------------------------------------------------------------------- //
// One sheet per demo_type x window
// -------------------------------------------------------------------------- //

foreach demo_type in `demo_types' {

    local groups `groups_`demo_type''
    local ngroups : word count `groups'

    use `panel', clear
    keep if demo_type == "`demo_type'"

    tempfile monthly_panel_`demo_type'
    save `monthly_panel_`demo_type''

    foreach w in 1q 1y 5y 10y {

        use `monthly_panel_`demo_type'', clear

        local lag    = `lag_`w''
        local nyears = `nyears_`w''
        local t_pas  = `date_end' - `lag'

        if (`t_pas' < `t_min') {
            di as text "Skipping `demo_type'_`w': reference month (`=string(`t_pas', "%tm")') predates data start"
            continue
        }

        // Extract scalars at date_end
        preserve
            keep if t == `date_end'
            if _N == 0 {
                restore
                di as text "Skipping `demo_type'_`w': date_end not in data"
                continue
            }
            foreach g in `groups' {
                foreach c in `concepts' {
                    quietly summarize mean_income`c' if group == "`g'"
                    scalar sc_cur_`c'_`g' = r(mean)
                }
            }
        restore

        // Extract scalars at date_end - lag
        preserve
            keep if t == `t_pas'
            if _N == 0 {
                restore
                di as text "Skipping `demo_type'_`w': reference month (`=string(`t_pas', "%tm")') not in data"
                continue
            }
            foreach g in `groups' {
                foreach c in `concepts' {
                    quietly summarize mean_income`c' if group == "`g'"
                    scalar sc_pas_`c'_`g' = r(mean)
                }
            }
        restore

        // Open sheet
        local sheet "`demo_type'_`w'"
        putexcel set "`xl'", sheet("`sheet'") modify

        // Column headers: row 1 = concept name (spanning), row 2 = metric
        putexcel A1 = "Group"
        putexcel A2 = ""

        local col = 2
        foreach c in `concepts' {
            local col1 = char(64 + `col')
            local col2 = char(64 + `col' + 1)
            local col3 = char(64 + `col' + 2)
			putexcel `col1'1:`col3'1 = "`clabel_`c''", merge hcenter
            putexcel `col1'2 = "Average ($)"
            putexcel `col2'2 = "Gain ($, total over period)"
            putexcel `col3'2 = "Growth (%/yr)"
            local col = `col' + 3
        }

        // Data rows (start at row 3)
        local row = 3
        foreach g in `groups' {

            putexcel A`row' = "`glabel_`g''"

            local col = 2
            foreach c in `concepts' {
                local inc_cur = scalar(sc_cur_`c'_`g')
                local inc_pas = scalar(sc_pas_`c'_`g')

                local avg    = `inc_cur'
                local gain   = `inc_cur' - `inc_pas'
                local growth = (`inc_cur' - `inc_pas') / abs(`inc_pas') / `nyears' * 100

                local col1 = char(64 + `col')
                local col2 = char(64 + `col' + 1)
                local col3 = char(64 + `col' + 2)

                putexcel `col1'`row' = `avg',    nformat("#,##0")
                putexcel `col2'`row' = `gain',   nformat("#,##0")
                putexcel `col3'`row' = `growth', nformat("0.00")

                local col = `col' + 3
            }

            local row = `row' + 1
        }

        // Title below table
        local title_row = `row' + 1
        local pas_label = string(`t_pas',    "%tm")
        local end_label = string(`date_end', "%tm")
        putexcel A`title_row' = "`dtlabel_`demo_type'' - `wlabel_`w'' - From `pas_label' To `end_label'"

        // Scalar cleanup
        foreach period in cur pas {
            foreach g in `groups' {
                foreach c in `concepts' {
                    cap scalar drop sc_`period'_`c'_`g'
                }
            }
        }

        noisily di "* Sheet `sheet' done"
    }
}
