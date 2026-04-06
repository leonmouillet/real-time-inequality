// -------------------------------------------------------------------------- //
// Import housing and stock market price indexes to extrapolate wealth
// -------------------------------------------------------------------------- //

// Import Wilshire 5000 from rawdata folder
import delimited "$rawdata/yahoo-data/w5000.csv", clear varnames(1)
tempfile wilshire_data
save "`wilshire_data'"

// Import housing indexes from FRED
import fred "CSUSHPISA" "USAUCSFRCONDOSMSAMID", clear aggregate(monthly, eop)
generate year = year(daten)
generate month = month(daten)
collapse (mean) caseschiller=CSUSHPISA zillow=USAUCSFRCONDOSMSAMID, by(year month)

merge 1:1 year month using "`wilshire_data'", nogenerate

// Check consistency between Zillow and Case-Schiller
generate time = ym(year, month)
format time %tm
tsset time, monthly

generate chg_caseschiller = 100*(caseschiller - L.caseschiller)/L.caseschiller
generate chg_zillow = 100*(zillow - L.zillow)/L.zillow

quietly gr tw (sc chg_zillow chg_caseschiller, msize(small) col(ebblue)) ///
    (line chg_caseschiller chg_caseschiller, col(cranberry)), ///
    legend(off) xtitle("Case-Schiller (% change)") ytitle("Zillow (% change)") ///
    xlabel(-2(0.5)2) ylabel(-2(0.5)2)
graph export "$graphs/01-import-wealth-indexes/caseschiller-zillow.pdf", replace

// Extrapolate Schiller with Zillow
generate coef = zillow/caseschiller
sort time
carryforward coef, replace
replace caseschiller = zillow/coef if missing(caseschiller)
drop coef

// Save data
keep year month time caseschiller wilshire
order year month time caseschiller wilshire
save "$work/01-import-wealth-indexes/wealth-indexes.dta", replace
