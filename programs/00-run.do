// -------------------------------------------------------------------------- //
// Master-file to run programs in the right order
// -------------------------------------------------------------------------- //

// -------------------------------------------------------------------------- //
// 01 - Data import
// -------------------------------------------------------------------------- //

// This section imports all data sources used as inputs to Real-Time Inequality. 


// Import NIPA aggregate income data (*)
// -------------------------------------
//
// BEA NIPA data [nipa]
// See: https://apps.bea.gov/iTable/iTable.cfm?reqid=19&step=4&isuri=1&nipa_table_list=1&categories=flatfiles
//
// The NIPA data is automatically downloaded and should not require manual
// changes, as long as series codes remain the same.

cap mkdir "$work/01-import-nipa"
do "$programs/01-import-nipa.do"


// Import BLS price data (*)
// -------------------------
//
// The BLS data is automatically downloaded and should not require manual
// changes, as long as series codes remain the same. 
// In case the automatic download fails, the codes provide instructions for 
// a manual download fallback. 
//
// BLS CPI [cu]
// See: https://download.bls.gov/pub/time.series/cu/

cap mkdir "$work/01-import-cu"
do "$programs/01-import-cu.do"

// Import BLS employment data (*)
// ------------------------------
//
// BLS Employment, Hours, and Earnings (National, NAICS) [ce]
// See: https://download.bls.gov/pub/time.series/ce/
//
// BLS State and Area Employment, Hours and Earnings [sm]
// See: https://download.bls.gov/pub/time.series/sm

cap mkdir "$work/01-import-ce"
cap mkdir "$work/01-import-sm"
do "$programs/01-import-ce.do"
do "$programs/01-import-sm.do"


// Import data on weekly unemployment insurance claims (*)
// -------------------------------------------------------
//
// Weekly Unemployment Insurance Claims (DOL) [ui]
// See: https://oui.doleta.gov/unemploy/claims.asp
// 
// The file $rawdata/ui-data/weekly-unemployment-report.xlsx must be
// updated manually. To do so:
//  - go to <https://oui.doleta.gov/unemploy/claims.asp>
//  - select "national", "XML" (not "spreadsheet") and the latest year
//  - convert the resulting XML file into XLSX
//    For that, you can place the xml file in $rawdata/ui-data/ and then run: 
//    python $rawdata/ui-data/ui_xml_to_xlsx.py
//    (auto-detects the XML and overwrites weekly-unemployment-report.xlsx)
//  - save the resulting file under 
//    $rawdata/ui-data/weekly-unemployment-report.xlsx
//  - make sure the cell selection in 01-import-ui.do is correct

cap mkdir "$work/01-import-ui"
do "$programs/01-import-ui.do"


// Import FED Financial Accounts
// -----------------------------
//
// FED Financial Accounts [fa]
// https://www.federalreserve.gov/releases/z1/release-dates.htm
//
// The FED data is automatically downloaded from the FED website.
// The URL at the begining of the 01-import-fa.do script should be updated in 
// order to import the most recent version of the financial accounts.
// No additional manual changes should be required, as long as series codes 
// remain the same.

cap mkdir "$work/01-import-fa"
do "$programs/01-import-fa.do"


// Import minimum wage data (*)
// ----------------------------
//
// State and Federal Minimum Wage from FRED [minwage]
// See: https://fred.stlouisfed.org/categories/33831
//
// The minimum wage data is imported from FRED and and should not require
// manual changes.
//
// Requesting a FRED API key is necessary for being able to scrap data 
// from FRED API: see <https://fred.stlouisfed.org/docs/api/api_key.html>. 
// Once obtained, the API key must be activated with the following command:
// set fredkey "my_key", permanently

cap mkdir "$work/01-import-minwage"
do "$programs/01-import-minwage.do"


// Import DINA macro data
// ----------------------
//
// Distributional National Accounts Macro Data (PSZ) [dina-macro]
// See: https://gabriel-zucman.eu/usdina/
//
// The DINA macro data files DINA(Aggreg).xlsx and parameters.xlsx come from 
// the Excel files of the PSZ paper and should be updated whenever these files 
// are updated. Make sure they cover all years up to the year of the last DINA 
// micro file. Whenever these files are updated, the cellrange parameters of all
// the import commands in 01-import-dina-macro.do should be updated in order to 
// include macro data for new years. 

cap mkdir "$work/01-import-dina-macro"
do "$programs/01-import-dina-macro.do"


// Import DINA micro data
// ----------------------
//
// Distributional National Accounts Micro Data from (PSZ) [dina]
// See: https://gabriel-zucman.eu/usdina/
// 
// The DINA micro data files in $raw-data/dina-data/microfiles comes from the 
// PSZ paper and are to be updated whenever these files are updated. When a new 
// DINA micro file is added, the global macro $last_year_dina must be updated in 
// 00-setup.do. This will automatically update the range of years processed in 
// the main loop of 01-import-dina.do, so this code should not require any 
// manual change.

cap mkdir "$work/01-import-dina"
do "$programs/01-import-dina.do"


// Import social security wage data
// --------------------------------
//
// Social Security Administration data [ssa]
// See: https://www.ssa.gov/cgi-bin/netcomp.cgi
//
// This import is performed with a R script that can be run directly from Stata,
// using the command bellow.
// The SSA data is scraped automatically and updates should not require manual
// changes as long as the format online stay the same, except to adjust
// the last year processed in the main loop of the R script.
// To do so, check which data is available using the following link format:
// <https://www.ssa.gov/cgi-bin/netcomp.cgi?year={year}>
// and then adjust the last year appropriately.

cap mkdir "$work/01-import-ssa"
shell "$rscript" --vanilla "$programs/01-import-ssa.R" "$work"


// Import SEER population data
// ---------------------------
// 
// SEER Population Data [pop]
// See: https://seer.cancer.gov/popdata/download.html
//
// The SEER data is automatically downloaded, but the name of the file to be
// downloaded should be changed after each update to reflect the last
// year of the data.

cap mkdir "$work/01-import-pop"
do "$programs/01-import-pop.do"


// Import ICI data on the composition of pension funds
// ---------------------------------------------------
// 
// ICI data on the composition of pension funds [ici]
// See: https://www.ici.org/research/stats/retirement
//
// The ICI data must be downloaded manually. To do so:
//   - Go to <https://www.ici.org/research/stats/retirement>
//   - Download the most recent "U.S. Retirement Market" report (XLS file)
//   - Save the file into $rawdata/ici-data/ret_data.xls

cap mkdir "$work/01-import-ici"
do "$programs/01-import-ici.do"


// Import data on total amounts for various COVID relief programs
// --------------------------------------------------------------
// 
// BEA Effects of Selected Federal Pandemic Response Programs on 
// Personal Income [aid-covid]
// See: https://www.bea.gov/federal-recovery-programs-and-bea-statistics/covid-19-recovery
//
// The raw data file $raw-data/covid-aid-data/covid-aid-data.cvs must be 
// downloaded by hand from the BEA website. This data is no longer updated, 
// since the corresponding COVID programs are terminated. This code does not 
// need to be run at every update. 

cap mkdir "$work/01-import-aid-covid"
do "$programs/01-import-aid-covid.do"


// Import data on the Paycheck Protection Program (PPP) during COVID
// -----------------------------------------------------------------
//
// Paycheck Protection Program Microdata from the Small Business Administration [ppp-covid]
// See: <https://data.sba.gov/dataset/ppp-foia>.
//
// The raw data files in $raw-data/ppp-covid-data must be 
// downloaded by hand from the SBA website. This data is no longer updated, 
// since the corresponding COVID programs are terminated. This code does not 
// need to be run at every update. 


cap mkdir "$work/01-import-ppp-covid"
do "$programs/01-import-ppp-covid.do"


// Import QCEW data
// ----------------
//
// BLS QCEW data [qcew]
// See: https://www.bls.gov/cew/downloadable-data-files.htm
//
// QCEW files are automatically downloaded, but the last year available
// must be updated in the code every year.
//
// QCEW files are very large, so we recommend only downloading the latest
// year every time. To do so, set year_begin and year_end at the begining of
// the script for defining the range of years to update. 

cap mkdir "$work/01-import-qcew"
do "$programs/01-import-qcew.do"


// Import Forbes data (*)
// ----------------------
//
// Real-Time Billionaires List (Forbes) [forbes]
// See: https://www.forbes.com/forbes-400/
// 
// The Forbes data is automatically scraped from the Wayback Machine, with a 
// Python script that can be run directly from Stata, using the command bellow.
// When it is possible, the script builds on the existing forbes.csv file and 
// only scrapes most recent data, if available. This part of the code should not
// require any manual change.

cap mkdir "$work/01-import-forbes"
python script "$programs/01-scrape-forbes.py", args("$rawdata/forbes-data/forbes.csv")
do "$programs/01-import-forbes.do"


// Import Wealth indexes (*)
// -------------------------
//
// Wilshire 5000 Total Market Index (Yahoo Finance), Case-Shiller National 
// Home Price Index and Zillow Home Value Index (FRED) [wealth-indexes]
// See: https://finance.yahoo.com/quote/%5EW5000/
//      https://fred.stlouisfed.org/series/CSUSHPINSA
//      https://fred.stlouisfed.org/series/USAUCSFRCONDOSMSAMID
//
// This part of the code should not require any manual change.
//
// The housing indexes are automatically downloaded directly from FRED.
//
// From June 2024, FRED has removed all Wilshire Index data from public access.
// We now rely on Yahoo Finance to dowload Wilshire 5000 data, 
// which is automatically scrapped with 01-scrape-yahoo.py and stored under
// $rawdata/yahoo-data/w5000.csv. Yahoo Finance W5000 serie only goes back to 
// 1989, so we also rely on FRED historical data, which is stored under 
// $rawdata/fred-data/historical-fred-data.dta and goes back to 1971. This 
// historical data is extrapolated to most recent months using Yahoo Finance data.

cap mkdir "$work/01-import-wealth-indexes"
cap mkdir "$graphs/01-import-wealth-indexes"

shell "$pythonscript" "$programs/01-scrape-yahoo.py" ///
    "$rawdata/fred-data/historical-fred-data.dta" ///
    "$rawdata/yahoo-data/w5000.csv" ///
    "$graphs/01-import-wealth-indexes/fred-yahoo-wilshire.pdf"

do "$programs/01-import-wealth-indexes.do"


// Import Monthly CPS data (*)
// ---------------------------
//
// Monthly Current Population Survey (Census Bureau) [cps-monthly] 
//
// The monthly CPS data extracts needs to be downloaded by hand from IPUMS CPS 
// every month. It is stored under raw-data/cps-monthly/cps-monthly.dat, and 
// then processed by 01-import-cps-monthly.do. This code should not require any
// manual change.
//
// Use the following procedure to obtain the correct data extract:
// 	- Go to https://cps.ipums.org/cps/ and create an account. 
//	- Samples selection. Unselect all yearly ASEC samples, select all Basic 
//    Monthly Samples. 
//	- Variables selection. Select the following variables only:
// 	  YEAR, SERIAL, MONTH, HWTFINL, CPSID, ASECFLAG, PERNUM, WTFINL, 
//    CPSIDP, CPSIDV, EARNWEEK2, AGE, SEX, RACE, SPLOC, HISPAN, EMPSTAT, EDUC, 
//    EARNWT, ELIGORG
// 	- Restrict sample to adult. Click on "Select Cases", select "Age" and then 
//    all age categories for people 20 and older. Submit case selection.
// 	- Submit extract, wait for processing and download data in .dat format.
//  - Store the output under raw-data/cps-monthly/cps-monthly.dat. 
//
// It is also possible to automatically download all required IPUMS extracts 
// (Monthly CPS, Annual CPS, and ACS) using the Python script 01-download-ipums.py, 
// rather than manually retrieving them through the IPUMS online portal.
// The script requires as input the path to the raw-data directory and can be 
// executed from the command line as follows:
//   python programs/01-download-ipums.py "<path-to-raw-data>"
// Upon execution, the script submits requests for the three extracts via the 
// IPUMS API, monitors their processing status, and downloads the resulting .dat files. 
// The files are saved to the following directories: raw-data/cps-monthly/, 
// raw-data/cps-data/, and raw-data/acs-data/. 
// To run the script, the variable IPUMS_api_key must be defined in the 
// configuration section and set to a valid IPUMS API key.

cap mkdir "$work/01-import-cps-monthly"
do "$programs/01-import-cps-monthly.do"


// Import ACS/Census data (for transport)
// --------------------------------------
//
// American Community Survey/Census (Census Bureau) [transport-acs]
// See: https://usa.ipums.org/usa/
// 
// The ACS/Census data must be downloaded by hand from IPUMS USA: 
// It is stored under raw-data/acs-data/usa.dat and then processed by 
// 01-import-transport-acs.do. The code creates files for intermediary years. 
// The local variable `last_year_acs' should be updated according to the most recent 
// data available.
//
// Use the following procedure to obtain the correct data extract:
// 	- Go to https://usa.ipums.org/usa/ and create an account. 
//	- Samples selection. In "USA SAMPLES" select the default samples for all
//    available years after 1970 (except 2001-2005 where group quarters are absent). 
//	- Variables selection. Select the following variables only:
// 	  YEAR, SAMPLE, SERIAL, CBSERIAL, HHWT, CLUSTER, STRATA, GQ, GQTYPE, 
//    PERNUM, PERWT, SPLOC, SEX, AGE, RACE, HISPAN, EDUC, EMPSTAT, INCWAGE, 
//    INCBUS, INCBUS00, INCFARM, INCSS, INCWELFR, INCINVST, INCRETIR
// 	- Restrict sample to group quarters households. Click on "Select Cases", 
//    select "GQ" and then GQ codes 3 (institutions) and 4 (other group quarters) only.
// 	- Submit extract, wait for processing and download data in .dat format.
//  - Store the output under raw-data/acs-data/usa.dat. 

cap mkdir "$work/01-import-transport-acs"
do "$programs/01-import-transport-acs.do"


// Import Yearly CPS data (for transport)
// --------------------------------------
//
// Current Population Survey, Annual Social and Economic Supplement 
// (Census Bureau) [transport-cps]
// 
// The CPS data extract needs to be downloaded by hand from IPUMS CPS. 
// It is stored under raw-data/cps-data/cps.dat and then processed by 
// 01-import-transport-cps.do. This code should not require any manual change.
//
// Use the following procedure to obtain the correct data extract:
// 	- Go to https://cps.ipums.org/cps/ and create an account. 
//	- Samples selection. Select all yearly ASEC samples and unselect all 
//    Basic Monthly Samples. 
//	- Variables selection. Select the following variables only:
// 	  YEAR, SERIAL, MONTH, CPSID, ASECFLAG, HFLAG, ASECWTH, PERNUM, CPSIDP, CPSIDV, ASECWT, 
// 	  AGE, SEX, RACE, SPLOC, HISPAN, EMPSTAT, EDUC, INCWAGE, INCBUS, INCFARM, INCSS,
//	  INCWELFR, INCGOV, INCRETIR, INCDRT, INCINT, INCUNEMP, INCWKCOM, INCVET, INCDIVID,
//    INCRENT, INCRANN, INCPENS
// 	- Submit extract, wait for processing and download data in .dat format.
//  - Store the output under raw-data/cps-data/cps.dat.

cap mkdir "$work/01-import-transport-cps"
cap mkdir "$work/02-transport"
cap mkdir "$work/02-transport/cps"
do "$programs/01-import-transport-cps.do"


// Import SCF data (for transport)
// -------------------------------
//
// Survey of Consumer Finances (Federal Reserve) [transport-scf]
// See: https://www.federalreserve.gov/econres/scfindex.htm
//
// The SCF data must be downloaded from the Federal Reserve website
// <https://www.federalreserve.gov/econres/scfindex.htm> and stored under
// raw-data/scf-data. We use both the full public dataset and the extract
// public data. On the Fed website, choose "Main Survey Data" and "Stata Version".

// The SCF is a triennial survey. The script 01-import-transport-scf.do should run
// when a new survey wave is downloaded - in which case the local
// variable last_year_scf at the begining of the script should be updated - or when
// a new DINA file has been incorporated in the pipeline - in which case some
// synthetic SCF data can be created for the optimal transport stage.  

cap mkdir "$work/01-import-transport-scf"
cap mkdir "$work/02-transport/scf"
do "$programs/01-import-transport-scf.do"


// Produce summary of coverage by data sources
// -------------------------------------------

cap mkdir "$work/01-data-summary"
do "$programs/01-data-summary.do"


// -------------------------------------------------------------------------- //
// 02 - Preparation of the data
// -------------------------------------------------------------------------- //

// None of the code in this section should require manual change.
//
// Subsections marked with (*) correspond to the processing of timely data and
// must therefore be run at each update. The remaining subsections only need
// to be run when the corresponding input data have been updated.


// Prepare NIPA data (*)
// ----------------------

cap mkdir "$work/02-prepare-nipa"
cap mkdir "$graphs/02-prepare-nipa"
do "$programs/02-prepare-nipa.do"


// Prepare Financial Accounts data (*)
// ------------------------------------

cap mkdir "$work/02-prepare-fa"
do "$programs/02-prepare-fa.do"


// Prepare national population data (*)
// -------------------------------------

cap mkdir "$work/02-prepare-pop"
cap mkdir "$graphs/02-prepare-pop"
do "$programs/02-prepare-pop.do"


// Prepate BLS Employment data (*)
// --------------------------------

cap mkdir "$work/02-prepare-bls-employment"
cap mkdir "$graphs/02-prepare-bls-employment"
do "$programs/02-prepare-bls-employment.do"


// Adjust DINA files using SSA yearly employment and wages
// -------------------------------------------------------

// Notice that this script must be run as long as a new DINA file has been 
// incorporated in the pipeline. Even if the corresponding SSA data is not 
// available yet, some adjustment is made in the DINA data based on the 
// correspondence between SSA wage distributions and DINA wage distributions for 
// all years where both are available. 

cap mkdir "$work/02-add-ssa-wages"
shell "$rscript" --vanilla "$programs/02-add-ssa-wages.R" "$work"


// Perform match via optimal transport
// -----------------------------------

cap mkdir "$work/02-export-transport-dina"
cap mkdir "$work/02-transport/dina"
do "$programs/02-export-transport-dina.do"

cap mkdir "$graphs/02-transport-check-consistency"
do "$programs/02-transport-check-consistency.do"

// The command below launches the Python script for optimal transport in a
// separate terminal, making it run independently of the Stata workflow. 
// Stata then wait in a loop, periodically checking for the creation of a 
// sentinel file (`ot_done.txt`) that signals Python has finished processing.
// This setup enables the Stata workflow to continue seamlessly, allowing the 
// entire section to be executed in a single block.

local sentinel "$work/02-transport/ot_done.txt"
cap erase "`sentinel'"

cap mkdir "$work/02-transport/match"
winexec "$pythonscript" -u "$programs/02-transport.py" --start_year 2024 --end_year $last_year_dina --directory "$work/02-transport" --sentinel "`sentinel'" 	// Windows command
*shell "$pythonscript" -u "$programs/02-transport.py" --start_year 1975 --end_year $last_year_dina --directory "$work/02-transport" --sentinel "`sentinel'" &	// MacOS command

while (1) {
    if (fileexists("`sentinel'")) continue, break
    sleep 30000
}


// Match the DINA data with CPS/SCF/ACS using the calculated transport maps
// ------------------------------------------------------------------------

cap mkdir "$work/02-match-dina-transport"
cap mkdir "$graphs/02-match-dina-transport"
do "$programs/02-match-dina-transport.do"

// Prepare DINA data
// -----------------

cap mkdir "$work/02-prepare-dina"
cap mkdir "$graphs/02-prepare-dina"
do "$programs/02-prepare-dina.do"


// Prepare series on UI benefits recipients (*)
// --------------------------------------------

cap mkdir "$work/02-prepare-ui"
cap mkdir "$graphs/02-prepare-ui"
do "$programs/02-prepare-ui.do"

// Prepare QCEW data (*)
// ---------------------

// Note: no need to run '02-disaggregate-qcew.do' unless the QCEW was updated
cap mkdir "$work/02-disaggregate-qcew"
do "$programs/02-disaggregate-qcew.do"

cap mkdir "$work/02-update-qcew"
cap mkdir "$work/02-update-qcew/backtesting-ces"
do "$programs/02-update-qcew.do"

cap mkdir "$graphs/02-update-qcew-backtest"
do "$programs/02-update-qcew-backtest.do"

cap mkdir "$work/02-tabulate-qcew"
do "$programs/02-tabulate-qcew.do"

cap mkdir "$work/02-adjust-seasonality-qcew"
cap mkdir "$graphs/02-adjust-seasonality-qcew"
do "$programs/02-adjust-seasonality-qcew.do"

// Prepare monthly CPS data (*)
// ----------------------------

cap mkdir "$work/02-cps-monthly-earnings"
do "$programs/02-cps-monthly-earnings.do"

cap mkdir "$work/02-cps-monthly-cells"
cap mkdir "$graphs/02-cps-monthly-cells"
do "$programs/02-cps-monthly-cells.do"

// Construct the monthly wage distribution (*)
// -------------------------------------------

cap mkdir "$work/02-create-monthly-wages"
cap mkdir "$graphs/02-create-monthly-wages"
do "$programs/02-create-monthly-wages.do"

// Distribute Paycheck Protection Program
// --------------------------------------

/*
cap mkdir "$work/02-distribute-ppp-covid"
cap mkdir "$graphs/02-distribute-ppp-covid"
do "$programs/02-distribute-ppp-covid.do"
*/

// -------------------------------------------------------------------------- //
// 03 - Build microfiles and online database
// -------------------------------------------------------------------------- //

// This section generates the core RTI outputs: the monthly microfiles and the
// database for the online visualizer. It also produces some monthly microfiles
// used exclusively for backtesting purposes. It should not require any manual 
// intervention. The range of years to be processed is adjusted automatically
// based on the global macros $date_end and $date_begin defined in 00-setup.do. 


// Monthly microfiles (*)
// ----------------------

cap mkdir "$work/03-build-monthly-microfiles"
cap mkdir "$microfiles/$update_id"
do "$programs/03-build-monthly-microfiles.do"

// Backtesting version of the microfiles
// -------------------------------------

/*
cap mkdir "$work/03-build-monthly-microfiles-backtest-1y"
cap mkdir "$work/03-build-monthly-microfiles-backtest-1y/microfiles"
do "$programs/03-build-monthly-microfiles-backtest-1y.do"

cap mkdir "$work/03-build-monthly-microfiles-backtest-2y"
cap mkdir "$work/03-build-monthly-microfiles-backtest-2y/microfiles"
do "$programs/03-build-monthly-microfiles-backtest-2y.do"

cap mkdir "$work/03-build-monthly-microfiles-backtest-rescaling-1y"
cap mkdir "$work/03-build-monthly-microfiles-backtest-rescaling-1y/microfiles"
do "$programs/03-build-monthly-microfiles-backtest-rescaling-1y.do"

cap mkdir "$work/03-build-monthly-microfiles-backtest-rescaling-2y"
cap mkdir "$work/03-build-monthly-microfiles-backtest-rescaling-2y/microfiles"
do "$programs/03-build-monthly-microfiles-backtest-rescaling-2y.do"
*/

// Forbes monthly microfile for top wealth series
// ----------------------------------------------

cap mkdir "$work/03-build-monthly-forbes"
do "$programs/03-build-monthly-forbes.do"

// Decompositions
// --------------

cap mkdir "$work/03-tabulate-income"
do "$programs/03-tabulate-income.do"

cap mkdir "$work/03-tabulate-wealth"
do "$programs/03-tabulate-wealth.do"

cap mkdir "$work/03-tabulate-wages"
do "$programs/03-tabulate-wages.do"

cap mkdir "$work/03-tabulate-demographics"
do "$programs/03-tabulate-demographics.do"

// Online database (*)
// -------------------

// The three programs below write intermediate CSVs under $work. The payload
// script then turns them into the files the website consumes, and is the only
// thing that writes into $website/$update_id — so that folder is an exact
// image of the website's public/temp_data/ and can be copied over as a whole.

cap mkdir "$work/03-build-online-database"
do "$programs/03-build-online-database.do"

cap mkdir "$work/03-build-online-database-labor"
cap mkdir "$graphs/03-build-online-database-labor"
do "$programs/03-build-online-database-labor.do"

cap mkdir "$work/03-build-online-database-demographics"
do "$programs/03-build-online-database-demographics.do"

cap mkdir "$website/$update_id"
local date_end_num = $date_end
shell "$pythonscript" "$programs/03-build-website-payload.py" ///
    "$work" "$website/$update_id" "$update_id" `date_end_num'

// -------------------------------------------------------------------------- //
// 04 - Report the results
// -------------------------------------------------------------------------- //

// This section produces the backtesting results and the graphs used in 
// the analysis for the Real-Time Inequality paper. The codes should not 
// require any change and can be run in a single block.  They do not need 
// to be executed at each update.

// Summary of outputs
// ------------------

cap mkdir "$tables/04-summary-tables-income"
do "$programs/04-summary-tables-income.do"

cap mkdir "$tables/04-summary-tables-wealth"
do "$programs/04-summary-tables-wealth.do"

cap mkdir "$tables/04-summary-tables-demographics"
do "$programs/04-summary-tables-demographics.do" 

cap mkdir "$graphs/04-plot-income"
do "$programs/04-plot-income.do"

cap mkdir "$graphs/04-plot-wealth"
do "$programs/04-plot-wealth.do"

cap mkdir "$graphs/04-plot-shares"
do "$programs/04-plot-shares.do"

cap mkdir "$graphs/04-plot-gic"
do "$programs/04-plot-gic.do"


// Backtests
// ---------


cap mkdir "$work/04-backtest"
cap mkdir "$graphs/04-backtest"
cap mkdir "$tables/04-backtest"
do "$programs/04-backtest.do"

cap mkdir "$work/04-backtest-rescaling"
cap mkdir "$graphs/04-backtest-rescaling"
cap mkdir "$tables/04-backtest-rescaling"
do "$programs/04-backtest-rescaling.do"
*/

// Graphs for the paper
// --------------------------

cap mkdir "$graphs/04-plot-gender"
do "$programs/04-plot-gender.do"

cap mkdir "$graphs/04-plot-race"
do "$programs/04-plot-race.do"

cap mkdir "$graphs/04-plot-education"
do "$programs/04-plot-education.do"

cap mkdir "$graphs/04-plot-covid"
do "$programs/04-plot-covid.do"

cap mkdir "$graphs/04-analyze-wage-growth"
do "$programs/04-analyze-wage-growth.do"