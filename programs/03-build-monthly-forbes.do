// -------------------------------------------------------------------------- //
// Build monthly Forbes micro data from 1982
// -------------------------------------------------------------------------- //
// 
// We need to disaggregate Forbes 400 annual data to monthly data 
// for years 1982-2020. We implement three disaggregation methods. 
// M2 is the production method.
//
// M0: Pure linear interpolation between annual anchors (constant outside span)
//
// M1: Uniform public/private split from RT data; private linearly interpolated,
//     public wealth scaled by Wilshire with individual slope correction so that
//     the annual projection lands exactly on the next Forbes anchor.
//
// M2: Individual-level public/private classification (forbes-classification.csv)
//     Public wealth: individual ticker price where available, Wilshire fallback
//     otherwise; both with slope correction for exact annual landing.
//     Private wealth: pure linear interpolation.

// -------------------------------------------------------------------------- //
// Load and clean real-time Forbes data
// -------------------------------------------------------------------------- //

import delimited "$rawdata/forbes-data/forbes.csv", clear varnames(1) case(lower)

// Forbes real-time list is worldwide
// US-resident individuals are identified by the 'state' variable

local us_states  `" "Alabama" "Alaska" "Arizona" "Arkansas" "California" "'
local us_states `"`us_states' "Colorado" "Connecticut" "Delaware" "Florida" "'
local us_states `"`us_states' "Georgia" "Hawaii" "Idaho" "Illinois" "Indiana" "'
local us_states `"`us_states' "Iowa" "Kansas" "Kentucky" "Louisiana" "Maine" "'
local us_states `"`us_states' "Maryland" "Massachusetts" "Michigan" "Minnesota" "'
local us_states `"`us_states' "Mississippi" "Missouri" "Montana" "Nebraska" "'
local us_states `"`us_states' "Nevada" "New Hampshire" "New Jersey" "New Mexico" "'
local us_states `"`us_states' "New York" "North Carolina" "North Dakota" "Ohio" "'
local us_states `"`us_states' "Oklahoma" "Oregon" "Pennsylvania" "Rhode Island" "'
local us_states `"`us_states' "South Carolina" "South Dakota" "Tennessee" "Texas" "'
local us_states `"`us_states' "Utah" "Vermont" "Virginia" "Washington" "'
local us_states `"`us_states' "West Virginia" "Wisconsin" "Wyoming" "'
local us_states `"`us_states' "District of Columbia" "'

generate byte us_resident = 0
foreach s of local us_states {
    replace us_resident = 1 if state == "`s'"
}
assert us_resident == 1 if inlist(state, "California", "New York", "Texas")

keep uri personname year month rank finalworth privateassetsworth state city ///
     birthdate us_resident
rename (uri personname finalworth privateassetsworth) ///
       (forbes_uri name worth_m private_m)

destring worth_m private_m year month rank birthdate, replace force

// Forbes intermittently blanks a person's location. When 'state' AND 'city'
// are both empty the row carries no residence information at all, so we carry
// the person's nearest known residence across the gap ('forbes_uri' is stable
// over time). A blank 'state' with a non-empty 'city' is a genuine move abroad
// (London, Singapore, Munich, ...) and is left excluded.

generate int t = year*12 + month
generate byte blank_loc = (trim(state) == "" & trim(city) == "")
generate byte us_known  = us_resident if trim(state) != ""
bysort forbes_uri (t): replace us_known = us_known[_n-1] if missing(us_known) & _n > 1
generate int negt = -t
bysort forbes_uri (negt): replace us_known = us_known[_n-1] if missing(us_known) & _n > 1
replace us_resident = us_known if blank_loc & !missing(us_known)

keep if us_resident == 1
drop us_resident us_known blank_loc t negt city
generate birth_year = year(dofC(birthdate + 315619200000)) if !missing(birthdate)
drop birthdate
keep if !missing(worth_m) & worth_m > 0
tempfile rt_clean
save `rt_clean'

// Global public/private share from RT data (used by M1)
use `rt_clean', clear
replace private_m = 0 if missing(private_m)
quietly summarize worth_m
local total_worth = r(sum)
quietly summarize private_m
local total_private = r(sum)
global forbes_private_share = `total_private' / `total_worth'
global forbes_public_share  = 1 - ${forbes_private_share}

// -------------------------------------------------------------------------- //
// Download monthly ticker prices
// -------------------------------------------------------------------------- //

// Load individual classification
import delimited "$rawdata/forbes-data/forbes-classification.csv", ///
    clear varnames(1) stringcols(_all) case(lower)
keep name type ticker
duplicates drop name, force
rename (type ticker) (type_m2 ticker_m2)
tempfile classif
save `classif'

// Export unique public tickers for the Python price downloader
preserve
    keep if type_m2 == "public" & !missing(ticker_m2) & ticker_m2 != ""
    keep ticker_m2
    rename ticker_m2 ticker
    duplicates drop ticker, force
    export delimited "$work/03-build-monthly-forbes/public-tickers.csv", replace
restore

// Download monthly prices through Yahoo Finance
shell "$pythonscript" ///
    "$programs/03-build-monthly-forbes-scrape-yahoo.py" /// Python script
    "$work/03-build-monthly-forbes/public-tickers.csv" /// Input file: tickers information
    "$work/03-build-monthly-forbes/tickers-monthly.csv" // Output file: tickers values


import delimited "$work/03-build-monthly-forbes/tickers-monthly.csv", ///
	clear varnames(1) stringcols(1) case(lower)
destring year month price, replace force
rename (year month price) (year_m month_m price_m)
tempfile tick_monthly
save `tick_monthly'

// -------------------------------------------------------------------------- //
// Load and clean annual Forbes 400 data
// -------------------------------------------------------------------------- //

import delimited "$rawdata/forbes-data/forbes400_8225_all.csv", ///
    clear stringcols(2 3 4 11 12 13 14 15 16 17 18) case(lower)

// 'country' here is the country of residence, not citizenship
// The Forbes 400 universe is itself restricted to US citizens: no US-resident
// non-citizen appears anywhere in annual Forbes 400 data covering 1982-2025.
// So the annual criterion is 'US citizen AND US resident', which is the closest
// proxy the source allows for the residence universe used from 2020 onwards.

keep if country == "United States"

// id=96 ("Pierre Samuel Family du Pont", $8.5-9B, rank 1 in 1982-1984) is
// dropped as an outlier: it is a family-aggregate entry that disappears
// abruptly after 1984, creating a ~$9B step-break in the ultra-top series.
drop if id == 96

tostring id, gen(id_str) force
replace id_str = regexr(id_str, "\..*$", "")
generate str40 forbes_uri = "ann-" + id_str
drop id_str
replace forbes_uri = strtrim(forbes_id) if !missing(forbes_id) & strtrim(forbes_id) != ""
duplicates drop forbes_uri year, force

replace wealth = wealth / 1000 if year == 2005 | year == 2009
replace wealth = wealth * 1e6

bysort year (wealth): generate rank = _N - _n + 1

// Derive birth_year
destring age birthday_year imputed_birth_year_0 imputed_birth_year_1, replace force
generate double birth_year_raw = birthday_year
replace birth_year_raw = round((imputed_birth_year_0 + imputed_birth_year_1) / 2) ///
    if missing(birth_year_raw) & !missing(imputed_birth_year_0)
replace birth_year_raw = year - age ///
    if missing(birth_year_raw) & !missing(age)
// Consolidate across all observations of the same person (take earliest valid value)
gegen birth_year = min(birth_year_raw), by(forbes_uri)
drop birth_year_raw

keep forbes_uri name year wealth state rank birth_year

// Forbes measures wealth as late August / early September
// Forbes 2020 was a late-July snapshot
local ref_month 8
generate byte anchor_month = `ref_month'
replace anchor_month = 7 if year == 2020

// -------------------------------------------------------------------------- //
// Compute method-specific anchors
// -------------------------------------------------------------------------- //

// M2: merge individual classification
merge m:1 name using `classif', nogenerate keep(master match)
replace type_m2   = "private" if missing(type_m2)
replace ticker_m2 = ""        if missing(ticker_m2) | type_m2 != "public"
rename ticker_m2 ticker

generate byte _pub_m2    = (type_m2 == "public")
generate pub_anchor_m2   = wealth * _pub_m2
generate priv_anchor_m2  = wealth * (1 - _pub_m2)
drop _pub_m2 type_m2

// M1: global public/private split
generate pub_anchor_m1  = wealth * ${forbes_public_share}
generate priv_anchor_m1 = wealth * ${forbes_private_share}

// -------------------------------------------------------------------------- //
// Compute lead values for interpolation endpoints
// -------------------------------------------------------------------------- //

sort forbes_uri year
by forbes_uri: generate wealth_next     = wealth[_n+1]
by forbes_uri: generate pub_next_m1     = pub_anchor_m1[_n+1]
by forbes_uri: generate priv_next_m1    = priv_anchor_m1[_n+1]
by forbes_uri: generate pub_next_m2     = pub_anchor_m2[_n+1]
by forbes_uri: generate priv_next_m2    = priv_anchor_m2[_n+1]
by forbes_uri: generate year_next         = year[_n+1]
by forbes_uri: generate anchor_month_next = anchor_month[_n+1]
replace anchor_month_next = `ref_month' if missing(anchor_month_next)

// When no next anchor exists: stay constant
replace wealth_next   = wealth          if missing(wealth_next)
replace pub_next_m1   = pub_anchor_m1   if missing(pub_next_m1)
replace priv_next_m1  = priv_anchor_m1  if missing(priv_next_m1)
replace pub_next_m2   = pub_anchor_m2   if missing(pub_next_m2)
replace priv_next_m2  = priv_anchor_m2  if missing(priv_next_m2)

by forbes_uri: generate byte is_first = (_n == 1)
by forbes_uri: generate byte is_last  = (_n == _N)
generate n_interp = cond(is_last, 12, ym(year_next, anchor_month_next) - ym(year, anchor_month))

// -------------------------------------------------------------------------- //
// Compute reference-month prices for the slope correction
// -------------------------------------------------------------------------- //

// Wilshire: reference price at anchor month, by year
// anchor_month varies by year (7 for 2020, 8 otherwise)
tempfile anchor_lookup
preserve
    keep year anchor_month
    duplicates drop year, force
    save `anchor_lookup'
restore
preserve
    use "$work/01-import-wealth-indexes/wealth-indexes.dta", clear
    merge m:1 year using `anchor_lookup', keep(match) nogenerate
    keep if month == anchor_month
    keep year wilshire
    rename wilshire wilshire_ref
    tempfile w_ref
    save `w_ref'
restore
merge m:1 year using `w_ref', nogenerate keep(match master)

// Ticker: reference price at anchor month, by (ticker, year)
preserve
    use `tick_monthly', clear
    rename (year_m month_m) (year month)
    merge m:1 year using `anchor_lookup', keep(match master) nogenerate
    replace anchor_month = `ref_month' if missing(anchor_month)
    keep if month == anchor_month
    rename (year price_m) (year price_ref)
    drop month anchor_month
    tempfile tick_ref
    save `tick_ref'
restore
merge m:1 ticker year using `tick_ref', keepusing(price_ref) keep(master match) nogenerate

// Lead values: next anchor's reference prices
sort forbes_uri year
by forbes_uri: generate wilshire_ref_next = wilshire_ref[_n+1]
by forbes_uri: generate price_ref_next    = price_ref[_n+1]

// -------------------------------------------------------------------------- //
// Expand annual observations to monthly
// -------------------------------------------------------------------------- //

levelsof year, local(all_forbes_years)

// Exit segment: covers the period after individuals last Forbes year
// Normal (Y+1 has Forbes data):  Aug(Y) → Dec(Y)         [5 months, within-year]
// Gap bridge (Y+1 missing):      Aug(Y) → Jul(Y+1)       [12 months]
tempfile seg_exit
preserve
    keep if is_last
    if _N > 0 {
        generate byte next_year_in_forbes = 0
        foreach y of local all_forbes_years {
            replace next_year_in_forbes = 1 if year + 1 == `y'
        }
        generate ext = cond(next_year_in_forbes, 13 - anchor_month, 12)
        drop next_year_in_forbes
        expand 12
        bysort forbes_uri year: generate seq = _n - 1
        keep if seq < ext
        generate time    = ym(year, anchor_month) + seq
        generate year_m  = year(dofm(time))
        generate month_m = month(dofm(time))
        generate alpha   = 0
        drop ext
    }
    else {
        foreach v in seq time year_m month_m alpha {
            generate `v' = .
        }
    }
    save `seg_exit'
restore

// Entry segment: covers the period before individuals first Forbes year
// Normal (Y−1 has Forbes data):  Jan(Y) → Jul(Y)          [7 months, within-year]
// Gap bridge (Y−1 missing):      Aug(Y−1) → Jul(Y)        [12 months]
tempfile seg_entry
preserve
    keep if is_first
    if _N > 0 {
        generate byte prev_year_in_forbes = 0
        foreach y of local all_forbes_years {
            replace prev_year_in_forbes = 1 if year - 1 == `y'
        }

        generate ext        = cond(prev_year_in_forbes, anchor_month - 1, 12)
        generate start_time = cond(prev_year_in_forbes, ym(year, 1),  ym(year - 1, `ref_month'))
        drop prev_year_in_forbes
        expand 12
        bysort forbes_uri year: generate seq = _n
        keep if seq <= ext
        generate time    = start_time + seq - 1
        generate year_m  = year(dofm(time))
        generate month_m = month(dofm(time))
        generate alpha   = 0
        drop ext start_time
    }
    else {
        foreach v in seq time year_m month_m alpha {
            generate `v' = .
        }
    }
    save `seg_entry'
restore

// Main segments: anchor_month(year_t) → anchor_month(year_t+1)−1
keep if !is_last
expand n_interp
bysort forbes_uri year: generate seq = _n - 1
generate time    = ym(year, anchor_month) + seq
generate year_m  = year(dofm(time))
generate month_m = month(dofm(time))
generate alpha   = seq / n_interp

append using `seg_exit'
append using `seg_entry'

keep if time >= ym(1982, 1) & time <= ym(2025, 12)

// -------------------------------------------------------------------------- //
// Merge monthly Wilshire and ticker prices
// -------------------------------------------------------------------------- //

// Monthly Wilshire
rename year    year_ann
rename year_m  year
rename month_m month
merge m:1 year month using "$work/01-import-wealth-indexes/wealth-indexes.dta", ///
    keepusing(wilshire) keep(match master) nogenerate
rename year    year_m
rename month   month_m
rename year_ann year
rename wilshire wilshire_m

// Monthly ticker prices
merge m:1 ticker year_m month_m using `tick_monthly', ///
    keepusing(price_m) keep(master match) nogenerate

// -------------------------------------------------------------------------- //
// Compute monthly wealth under each method
// -------------------------------------------------------------------------- //

generate g_wilshire = wilshire_ref_next / wilshire_ref

// M0: pure linear interpolation
generate wealth_m0 = wealth + alpha * (wealth_next - wealth)
generate priv_m0   = wealth_m0
generate pub_m0    = 0

// M1: global split + Wilshire + slope correction
generate priv_m1       = priv_anchor_m1 + alpha * (priv_next_m1 - priv_anchor_m1)
generate g_forbes_m1   = pub_next_m1 / pub_anchor_m1
generate correction_m1 = 1 + alpha * (g_forbes_m1 / g_wilshire - 1)
replace  correction_m1 = 1 if missing(correction_m1)
generate pub_m1        = pub_anchor_m1 * (wilshire_m / wilshire_ref) * correction_m1
generate wealth_m1     = priv_m1 + pub_m1

// M2: individual classification + ticker/Wilshire + slope correction
generate priv_m2       = priv_anchor_m2 + alpha * (priv_next_m2 - priv_anchor_m2)
generate g_ticker_m2   = price_ref_next / price_ref
generate g_base_m2     = cond(!missing(ticker) & ticker != "" & ///
                              !missing(g_ticker_m2) & g_ticker_m2 > 0, g_ticker_m2, g_wilshire)
generate g_forbes_m2   = pub_next_m2 / pub_anchor_m2
generate correction_m2 = 1 + alpha * (g_forbes_m2 / g_base_m2 - 1)
replace  correction_m2 = 1 if missing(correction_m2)
// Wilshire base for all public individuals
generate pub_m2 = pub_anchor_m2 * (wilshire_m / wilshire_ref) * correction_m2
// Override with individual ticker where prices are available
replace pub_m2 = pub_anchor_m2 * (price_m / price_ref) * correction_m2 ///
    if !missing(ticker) & ticker != "" & !missing(price_m) & !missing(price_ref) ///
       & price_ref > 0
generate wealth_m2 = priv_m2 + pub_m2

// -------------------------------------------------------------------------- //
// Create final monthly microfile
// -------------------------------------------------------------------------- //

// Save M2 ticker classification for coverage graphs
preserve
    generate byte uses_ticker_m2 = (!missing(ticker) & ticker != "" & ///
        !missing(price_ref) & price_ref > 0 & pub_anchor_m2 > 0)
    drop year
    rename (year_m month_m) (year month)
    keep forbes_uri name year month rank state birth_year ///
        wealth_m2 priv_m2 pub_m2 ticker uses_ticker_m2
    rename (wealth_m2 priv_m2 pub_m2) (wealth private_wealth public_wealth)
    generate source = "annual-m2"
    save "$work/03-build-monthly-forbes/ann-m2-tickers.dta", replace
restore

// Split into three method-specific tempfiles
drop year    // anchor year no longer needed; replace with monthly year
rename (year_m month_m) (year month)

keep forbes_uri name year month rank state birth_year ///
    wealth_m0 priv_m0 pub_m0 ///
    wealth_m1 priv_m1 pub_m1 ///
    wealth_m2 priv_m2 pub_m2

foreach m in m0 m1 m2 {
    preserve
        rename (wealth_`m' priv_`m' pub_`m') (wealth private_wealth public_wealth)
        keep forbes_uri name year month rank state birth_year wealth private_wealth public_wealth
        generate source = "annual-`m'"
        tempfile ann_`m'
        save `ann_`m''
    restore
}

// Process real-time Forbes data
use `rt_clean', clear
generate wealth         = worth_m * 1e6
generate private_wealth = cond(!missing(private_m), ///
    private_m * 1e6, worth_m * 1e6 * ${forbes_private_share})
generate public_wealth  = wealth - private_wealth
generate source = "realtime"
keep forbes_uri name year month rank state birth_year wealth private_wealth public_wealth source

// Assemble and save
append using `ann_m0'
append using `ann_m1'
append using `ann_m2'

generate time = ym(year, month)
format time %tm

sort source time forbes_uri
order time year month source forbes_uri name rank birth_year wealth private_wealth public_wealth state

// Validation file: all sources, all years, all individuals
save "$work/03-build-monthly-forbes/forbes-monthly-micro-validation.dta", replace

// Production file: annual-m2 (pre-2020) + realtime (2020+), top 400 per month
keep if (source == "annual-m2" & year < 2020) | (source == "realtime" & year >= 2020)
replace source = "annual" if source == "annual-m2"
bysort year month (wealth): generate rank_m = _N - _n + 1
keep if rank_m <= 400
drop rank_m
sort source time forbes_uri
order time year month source forbes_uri name rank birth_year wealth private_wealth public_wealth state
save "$work/03-build-monthly-forbes/forbes-monthly-micro.dta", replace

// -------------------------------------------------------------------------- //
// Create monthly series
// -------------------------------------------------------------------------- //

preserve
    collapse (sum) forbes_all = wealth (count) obs_all = wealth, by(year month)
    tempfile all
    save `all'
restore

keep if (year - birth_year) < 65 | missing(birth_year)
collapse (sum) forbes_working_age = wealth (count) obs_working_age = wealth, by(year month)
merge 1:1 year month using `all'
drop _merge
save "$work/03-build-monthly-forbes/forbes-monthly-totals.dta", replace

// -------------------------------------------------------------------------- //
// Produce validation graph for disaggregation of Forbes 400
// -------------------------------------------------------------------------- //

cap mkdir "$graphs/03-build-monthly-forbes-validation"
do "$programs/03-build-monthly-forbes-validation.do"