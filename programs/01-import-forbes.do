// -------------------------------------------------------------------------- //
// Import the monthly Forbes data scraped using Python
// -------------------------------------------------------------------------- //

import delimited "$rawdata/forbes-data/forbes.csv", bindquote(strict) clear

keep year month uri state city finalworth

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

// Forbes intermittently blanks a person's location. When 'state' AND 'city'
// are both empty the row carries no residence information at all, so we carry
// the person's nearest known residence across the gap ('uri' is stable over
// time). A blank 'state' with a non-empty 'city' is a genuine move abroad
// (London, Singapore, Munich, ...) and is left excluded.

generate int t = year*12 + month
generate byte blank_loc = (trim(state) == "" & trim(city) == "")
generate byte us_known  = us_resident if trim(state) != ""
bysort uri (t): replace us_known = us_known[_n-1] if missing(us_known) & _n > 1
generate int negt = -t
bysort uri (negt): replace us_known = us_known[_n-1] if missing(us_known) & _n > 1
replace us_resident = us_known if blank_loc & !missing(us_known)
drop t negt blank_loc us_known

keep if us_resident == 1
drop us_resident state city

gsort year month -finalworth
by year month: generate rank = _n
keep if rank <= 400

replace finalworth = finalworth*1e6

gcollapse (sum) forbes_wealth=finalworth, by(year month)

save "$work/01-import-forbes/forbes400-monthly.dta", replace


