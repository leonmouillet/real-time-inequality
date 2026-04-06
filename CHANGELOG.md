# RTI CHANGELOG

All notable changes to the RTI project are documented in this file.

---

## 2026-03-mouillet

### Fixed

- **01-import-cu.do, 01-import-ce.do, 01-import-sm.do**: Switched to Python-based data scraping executed from within Stata, and implemented a manual-download fallback in case automatic downloads fail in the future.
- **01-import-ssa.do**: In `00-run.do`, the command used to launch the script was switched from `rsource` to `shell`, using the `$rscript` argument (where `$rscript` specifies the path to the R executable and is defined in `00-setup.do`).
- **01-import-pop.do**: Replaced the `gunzip` shell command (not available on Windows) with an R-based command invoked via `shell $rscript -e`.
- **01-import-wealth-indexes.do**: As of June 2024, FRED removed all Wilshire Index data from public access. The project now relies on Yahoo Finance to download Wilshire 5000 data, which are automatically scraped using `01-scrape-yahoo.py` and stored in `$rawdata/yahoo-data/w5000.csv`. Because Yahoo Finance data only extend back to 1989, historical Wilshire data from FRED (stored in `$rawdata/fred-data/historical-fred-data.dta` and covering 1971 onward) are used for earlier periods. These historical series are extrapolated to recent months using Yahoo Finance data.

### Added

- **00-setup.do**: Added configuration sections defining the following global macros: `$root`, `$rscript` (used to run R scripts from Stata), `$pythonscript` (used to run Python scripts from Stata), `$last_year_dina`, `$date_begin`, `$date_end` (used throughout the code to reduce hard-coded dates), and `$update_id` (used for output versioning). These sections clearly separate parameters that must be modified manually based on the current computing and data environment.
- **01-scrape-yahoo.py**: New script for scraping the Wilshire 5000 index from Yahoo Finance.
- **01-download-ipums.py**: New Python script that automates IPUMS data extraction (Monthly CPS, Annual CPS/ASEC, ACS) via the IPUMS API, replacing manual downloads from the IPUMS web portal.
- **01-data-summary.do**: New script that, once all data imports are completed, reads all imported datasets and produces a detailed summary of data coverage by source. The summary is saved in `work-data/01-data-summary/data-summary.txt`. Based on observed data availability, the file reports the most recent month for which a monthly microfile can be produced, which can be used to adjust `$date_end` in `00-setup.do`. The summary is also used by `03-build-monthly-microfiles.do` to generate metadata describing the RTI outputs produced in the current update.
- **02-disaggregate-qcew.do**: Implemented adjustments to address two structural changes in QCEW data occurring in 2022. First, NAICS codes transitioned from NAICS 2017 to NAICS 2022, introducing missing values when computing moving averages for industries without direct crosswalks. These missing values are now patched using the NAICS 2017–2022 crosswalk and an Iterative Proportional Fitting (IPF) algorithm to ensure continuity between 2021 and 2022. Second, approximately 5 million public-sector workers became newly disclosed in 2022, potentially affecting data consistency. To preserve consistency, these public-sector workers are excluded from the data from 2022 onward.
- **02-update-qcew-backtesting.do**: Separated the backtesting sections previously embedded in `02-update-qcew.do` into a dedicated script. Added new backtesting figures using more recent time windows. Results indicate that QCEW extrapolation accuracy deteriorates in recent years, particularly at the top of the distribution.
- **03-build-monthly-forbes.do**: New script producing a monthly micro Forbes file covering all months from 1982 on, based on Forbes 400 data (1982–2019) and Forbes Realtime data (2020–). Accompanied by `03-build-monthly-forbes-validation.do` which produces validation graphs for the disaggregation of Forbes 400 data.
- **03-tabulate-wealth.do**: Previously in `03-decompose-components.do`. Specific tabulation script for wealth, with a finer grid than `03-tabulate-income.do` for capturing ultra-top wealth groups (top 0.0001%, top 0.00001%).
- **03-tabulate-demographics.do**: New script replacing `03-decompose-race.do` and `03-decompose-education.do`. Constructs monthly databases of average income and wealth by demographic group (race, gender, education, race × gender) for different income concepts (princ, peinc, dispo, poinc, wage, pkinc, hweal). Outputs one file per population.
- **03-tabulate-wages.do**: New script constructing a monthly database of wage income by income bracket and demographic group (race, gender, education), for both `working_age_individual` and `working_age_equal_split` units. Outputs `tabulation-wages-*.dta`, which serves as input to `03-build-online-database-labor.do` and `04-analyze-wage-growth.do`.
- **03-build-online-database-demographics.do**: New script producing `online-database-demographics.csv` for the website, covering income and wealth by demographic group. Reads from `03-tabulate-demographics.do`.
- **03-build-online-database-json.py**: New script converting all online-database CSV files to JSON format for the website. Reads `online-database.csv`, `online-database-labor.csv`, `online-database-popul-deflator.csv`, and `online-database-demographics.csv` from the update folder and writes corresponding JSON files to a `json/` subfolder.
- **03-build-online-database-excel.py**: New script creating the Excel file containing the full online database `full-online-database.xlsx` which can be downloaded from the website. The Excel file is composed of three separate sheets: wealth_income, labor, demographics.
- **04-plot-income.do, 04-plot-wealth.do**: New scripts producing income and wealth decomposition area charts. Previously inline in `03-decompose-components.do`.
- **04-plot-race.do, 04-plot-education.do, 04-plot-gender.do**: New scripts producing demographic gap figures. Read from `03-tabulate-demographics.do`. Previously inline in `03-decompose-race.do`, `03-decompose-education.do`, and `03-plot-gender-gaps.do`.
- **04-summary-tables-income.do, 04-summary-tables-wealth.do, 04-summary-tables-demographics.do**: New scripts producing Excel summary tables of recent income and wealth dynamics by percentile group and demographic group, with decomposition by income component.

### Changed

- **Folder structure**: Transport folder merged into the main folder structure (`work-data/02-transport`). New `outputs/` folder with subfolders `graphs/`, `tables/`, `website/`, and `microfiles/`.
- **01-import-forbes.do**: The script now builds on existing historical data and scrapes only newly available observations.
- **01-import-transport-acs.do**: Implemented more robust interpolation and extrapolation logic for missing years, ensuring data availability through the most recent DINA year.
- **01-import-ssa-wages.do**: Renamed to `01-import-ssa.do`.
- **Optimal transport**: The new optimal transport script (`02-transport.py`) supports parallel processing and adaptive wage stratification for large cells. Optimal transport can now be run on local machines with limited RAM using sequential processing and adaptive stratification. All related scripts and files are now integrated into the main folder structure rather than stored in a separate directory.
- **02-match-dina-transport.do**: Minor code refactoring (processing by decades, moving some operations outside loops) improved memory management and enabled reliable execution on machines with limited RAM.
- **02-add-ssa-wages.R**: The script now allows extrapolation of the SSA correction for years beyond `last_year_ssa`, in case DINA files are produced before SSA tabulations are released. The SSA/DINA ratio used to extrapolate the SSA correction is computed as the median over the very last SSA years (inspection of the ratio by percentile revealed a clear upward trend over recent years, particularly at the bottom of the distribution). Similarly, for years before `first_year_ssa`, the ratio is now computed as the median over the very first SSA years only.
- **02-update-qcew.do**: The script now imports only recent QCEW data (`keep if year >= 2015`), yielding identical extrapolation results while substantially reducing memory usage. During extrapolation, regressions now include NAICS-regime fixed effects (interacted with industry fixed effects) to account for the NAICS 2022 reclassification.
- **03-build-monthly-microfiles\*.do**: Replaced the `rsource` command with `shell $rscript` for running the R interpolation scripts `03-interpolate-qcew.R` and `03-interpolate-uiinc.R`.
- **03-build-monthly-microfiles.do**: Monthly microfiles are now automatically versioned in a subfolder named after the current update ID and accompanied by a `_metadata.txt` file describing the data sources used. The directory `work-data/03-build-monthly-microfiles` was moved to the `outputs/` folder and reorganized to separate outputs produced during the current update (`outputs/microfiles/`) from publicly available outputs (`outputs/microfiles/public/microfiles/`).
- **03-tabulate-income.do**: Previously called `03-decompose-components.do`. Refactored loop structure (time outer, concept × population inner) to load each microfile only once per month. Added households as a third population unit (`adult_equal_split`, `working_age_equal_split`, `adult_households`). Outputs one tabulation file per income concept × population, stored as `tabulation-`income'-`pop'.dta`. Individuals are ranked by concept. Added `pop` variable (rawsum of weights) to p-cell output. Incremental update pattern: drops months >= `date_begin` from existing files and appends new months.
- **03-build-online-database.do**: Now reads from `03-tabulate-income.do` and `03-tabulate-wealth.do` outputs instead of microfiles directly. Uses self-ranked tabulations. Now creates additional ultra-top wealth series from Forbes data prepared by `03-build-monthly-forbes.do`. Accompanied by `03-build-online-database-validation.do` which produces validation graphs for the production of ultra-top wealth series.
- **03-build-online-database-labor.do, 04-analyze-wage-growth.do**: Now read from `03-tabulate-wages.do` outputs instead of microfiles directly.
- **04-build-online-\*.do**: Tabulated data used by the website are now automatically versioned in a subfolder named after the current update ID.

### Removed

- **01-import-sec.do and 01-import-sec.R**: Legacy scripts inherited from earlier work (by Thomas Blanchet) that are no longer (not yet?) used.
- **03-decompose-race.do, 03-decompose-education.do**: Replaced by `03-tabulate-demographics.do`.
- **03-build-online-extrapolation.do**: Merged into `03-build-online-database.do`.
- **04-plot-bot50-recessions.do**: Merged into `04-plot-covid.do`.