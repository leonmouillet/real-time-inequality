// -------------------------------------------------------------------------- //
// Setup local configuration, paths, packages, themes
// -------------------------------------------------------------------------- //

// This setup file sets local and data configuration, defines paths, installs 
// required packages, and sets plotting themes. It must be run once at the 
// beginning of each Stata session. The sections 'Setup local configuration' and 
// 'Setup data configuration' should be updated according to local computing 
// environment and current data availability. It can happen that some packages
// used in the project are not yet included in this setup file. If so, the 
// file should be updated to automate their installation.

clear all
set maxvar 10000


// -------------------------------------------------------------------------- //
// Setup local configuration
// -------------------------------------------------------------------------- //

// The following global macros must be set according to 
// local computing environment: 
//   - $root: root directory where the RTI project is located
//   - $rscript: path to the Rscript executable 
//	   (used to run R scripts from Stata)
//   - $pythonscript: path to the Python executable
//	   (used to run Python scripts from Stata)

global root 		"C:\Users\l.mouillet\Dropbox\SaezZucman2014\RealTime\repository\real-time-inequality"
global rscript 		"C:\Users\l.mouillet\AppData\Local\Programs\R\R-4.5.1\bin\Rscript.exe"
global pythonscript "C:\Python313\python.exe"

global IPUMS_api_key "59cba10d8a5da536fc06b59d909ddb44e13e46858c214f38b3538623"

// -------------------------------------------------------------------------- //
// Setup data configuration
// -------------------------------------------------------------------------- //

// The following global macros must be set according to current
// data availability: 
//   - $last_year_dina: last available DINA microfile
//   - $date_begin: first monthly microfile to be produced
//   - $date_end: last monthly microfile to be produced. It can be adjusted
//     based on observed data availability after all imports (see 
//     data-summary.txt produced by 01-data-summary.do).
//	 - $update_id: identifier of the current update work, used for versioning of 
//     the core RTI outputs in $work/03-build-monthly-microfiles/microfiles and 
//     $website. Use syntax "updater-YYYY-MM". 

global last_year_dina	2024
global date_begin 		ym(1976, 01)
global date_end 		ym(2025, 12)
global update_id 		"2026-02-mouillet"

assert $date_begin <= $date_end

// -------------------------------------------------------------------------- //
// Define paths
// -------------------------------------------------------------------------- //

global programs   "$root/programs"
global rawdata    "$root/raw-data"
global work       "$root/work-data"
global graphs     "$root/outputs/graphs"
global tables     "$root/outputs/tables"
global microfiles "$root/outputs/microfiles"
global website    "$root/outputs/website"

sysdir set PERSONAL "$programs"

// -------------------------------------------------------------------------- //
// Install Stata packages
// -------------------------------------------------------------------------- //

cap which gtools
if (_rc != 0) {
	ssc install gtools
}

cap which ftools
if (_rc != 0) {
	ssc install ftools
}

cap which grstyle
if (_rc != 0) {
	ssc install grstyle
}

cap which renvars
if (_rc != 0) {
	* ssc install renvars
	net install dm88_1, from(http://www.stata-journal.com/software/sj5-4)
}

cap which ereplace
if (_rc != 0) {
	ssc install ereplace
}

cap which enforce
if (_rc != 0) {
	ssc install enforce
}

cap which reghdfe
if (_rc != 0) {
	ssc install reghdfe
}

cap which _gwtmean
if (_rc != 0) {
	ssc install _gwtmean
}

cap which denton
if (_rc != 0) {
	ssc install denton
}

cap which carryforward
if (_rc != 0) {
	ssc install carryforward
}

cap which rsource
if (_rc != 0) {
	ssc install rsource
}

cap which egen
if (_rc != 0) {
    ssc install egenmore
}

cap which pshare
if (_rc != 0) {
    ssc install pshare
}

cap which listtab
if (_rc != 0) {
	ssc install listtab
}

// -------------------------------------------------------------------------- //
// Install Python packages
// -------------------------------------------------------------------------- //

shell pip install pandas numpy waybackpy yfinance matplotlib numba POT joblib requests


// -------------------------------------------------------------------------- //
// Set theme for plots
// -------------------------------------------------------------------------- //

set scheme s2color
grstyle init
grstyle color background white
grstyle anglestyle vertical_tick horizontal
grstyle yesno draw_major_hgrid yes
grstyle yesno grid_draw_min yes
grstyle yesno grid_draw_max yes
grstyle color grid                   gs13
grstyle color major_grid             gs13
grstyle color minor_grid             gs13
grstyle linewidth major_grid thin

grstyle linewidth foreground   vvthin
grstyle linewidth background   vvthin
grstyle linewidth grid         vvthin
grstyle linewidth major_grid   vvthin
grstyle linewidth minor_grid   vvthin
grstyle linewidth tick         vvthin
grstyle linewidth minortick    vvthin

grstyle yesno extend_grid_low        yes
grstyle yesno extend_grid_high       yes
grstyle yesno extend_minorgrid_low   yes
grstyle yesno extend_minorgrid_high  yes
grstyle yesno extend_majorgrid_low   yes
grstyle yesno extend_majorgrid_high  yes

grstyle clockdir legend_position     6
grstyle gsize legend_key_xsize       8
grstyle color legend_line            background
grstyle yesno legend_force_draw      yes

grstyle margin axis_title          medsmall

graph set window fontface default
