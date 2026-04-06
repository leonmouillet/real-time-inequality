# Replication package for "Real-Time Inequality" (Blanchet, Saez and Zucman, 2023)

## Overview

The code in this replication package constructs the synthetic microfiles that can be used to replicate the inequality data available online at [realtimeinequality.org](https://realtimeinequality.org/) as well as the accompanying paper "Real-Time Inequality" (Blanchet, Saez and Zucman, 2023). It combines data from a large number of sources (detailed below). The master file and most of the code runs in Stata with some parts of the code written in R and in Python.

## Data Availability and Provenance Statements

### Statement about Rights

- [x] I certify that the author(s) of the manuscript have legitimate access to and permission to use the data used in this manuscript. 
- [x] I certify that the author(s) of the manuscript have documented permission to redistribute/publish the data contained within this replication package. Appropriate permission are documented in the [LICENSE.txt](LICENSE.txt) file.


### License

![Creative Commons Attribution 4.0 International Public License](https://img.shields.io/badge/License%20-CC%20BY%204.0-lightgrey.svg)

The data, tables and figures are licensed under the [Creative Commons Attribution 4.0 International (CC BY 4.0) license](https://creativecommons.org/licenses/by/4.0/). See [LICENSE.txt](LICENSE.txt) for details.

### Summary of Availability

- [x] All data **are** publicly available.
- [ ] Some data **cannot be made** publicly available.
- [ ] **No data can be made** publicly available.

*Note:* Some of the data (IRS public-use microfiles, IPUMS data) cannot be shared directly in the repository, but are accessible to researchers that request them. See below for details.

### Details on each Data Source

#### National Income and Product Accounts (NIPA) from the Bureau of Economic Analysis (BEA)

Data on National Income and Product Accounts (NIPA) is downloaded directly from the Bureau of Economic Analysis (BEA) using the "flat files" available at <https://apps.bea.gov/iTable/iTable.cfm?reqid=19&step=4&isuri=1&nipa_table_list=1&categories=flatfiles>. This data is in the public domain. It is automatically downloaded by the file `01-import-nipa.do` and stored in the repository under `work-data/01-import-nipa`.

#### Consumer Price Index for All Urban Consumers from the Bureau of Labor Statistics (BLS)

The CPI for All Urban Consumers is the most frequently update price index, and we use it to adjust BLS data for inflation in intermediary treatments. This data is in the public domain. It is downloaded directly from the BLS at <https://download.bls.gov/pub/time.series/cu/> by the file `01-import-cu.do` and stored in the repository under `work-data/01-import-cu`.

#### Employment, Hours and Earnings from the Bureau of Labor Statistics (BLS)

The data on Employment, Hours, and Earnings at the national (<https://download.bls.gov/pub/time.series/ce/>) and at the state and area levels (<https://download.bls.gov/pub/time.series/sm>) comes from the BLS. The data is in the public domain. It is automatically downloaded by `01-import-ce.do` (national) and `01-import-sm.do` (state and area) and is stored in the repository under `work-data/01-import-ce` and `work-data/01-import-sm`.

#### Weekly Unemployment Insurance Claims from the Department of Labor (DOL)

The data on weekly unemployment insurance claims comes from the Department of Labor. The data is in the public domain and available at <https://oui.doleta.gov/unemploy/claims.asp>. A copy of the data is provided in the repository at `raw-data/ui-data/weekly-unemployment-report.xlsx`. Otherwise it needs to be manually downloaded:

- go to <https://oui.doleta.gov/unemploy/claims.asp>
- select "national", "XML" (not "spreadsheet") and the latest year
- save the result as XLSX in ``raw-data/ui-data/weekly-unemployment-report.xlsx``

#### Financial Accounts from the Federal Reserve

The Financial Accounts data comes from the Federal Reserve (<https://www.federalreserve.gov/releases/z1/release-dates.htm>). The data is in the public domain. It is automatically downloaded by `01-import-fa.do` and is stored in the repository under `work-data/01-import-fa`.

#### State and Federal Minimum Wage from FRED

We use data on the state and federal minimum wages to identify outliers in the Quarterly Census of Employment and Wages. This data is in the public domain, is automatically downloaded from FRED (series `STTMINWG*` and `FEDMINNFRWG`) by `01-import-minwage.do`, and is stored in the repository under `work-data/01-import-minwage`.

#### Distributional National Accounts Data from Piketty, Saez and Zucman (2018)

The distributional national accounts data comes from [Piketty, Saez and Zucman (2018)](https://gabriel-zucman.eu/files/PSZ2018QJE.pdf) (and updated by the same authors). The aggregate data is publicly available online at <https://gabriel-zucman.eu/usdina/> and a copy is provided in this archive under `raw-data/dina-data`. The microdata is built on top the [public-use IRS microdata](https://www.nber.org/research/data/tax-model-file-documentation) which can be obtained from the NBER but cannot be redistributed directly. A stripped-down version of these microfiles, however, with fewer observations but a similar structure, can be obtained at <https://gabriel-zucman.eu/usdina/>. The DINA microdata needs to be included in the repository under `raw-data/dina-data/microfiles`.

#### Wage Statistics from the Social Security Administration

We use the yearly wage statistics from the Social Security Administration (SSA), available at <https://www.ssa.gov/cgi-bin/netcomp.cgi>. The data is in the public domain. It is automatically downloaded by `01-import-ssa.R` and is stored in the repository under `work-data/01-import-ssa`.

Additional historical data (on the number of wage earners only) was retrieved by hand from <https://www.ssa.gov/oact/cola/oldawidata.html> and <https://www.ssa.gov/oact/cola/awidevelop.html>. This data is only for the historical period and does not need to be updated. The data is in the Excel file `raw-data/ssa-data/number-wage-earners.xlsx` with is provided in the repository.

#### Population Data from the National Cancer Institute's Surveillance, Epidemiology an End Results Program (SEER)

We use population data by age from the National Cancer Institute's Surveillance, Epidemiology an End Results Program (SEER) (<https://seer.cancer.gov/popdata/download.html>). The data is in the public domain. It is automatically downloaded by `01-import-pop.do`, and is stored in the repository under `work-data/01-import-pop`.

#### Quarterly Retirement Market Data from the Investment Company Institute (ICI)

We use the ICI data to obtain the composition of pension funds. This data is publicly available. It is automatically downloaded from <https://www.ici.org/research/stats/retirement> and stored in the repository under `work-data/01-import-ici`.

#### Effects of Selected Federal Pandemic Response Programs on Personal Income from the Bureau of Economic Analysis (BEA)

The data on the total amounts for various COVID relief programs is obtained from the BEA at <https://www.bea.gov/federal-recovery-programs-and-bea-statistics/archive>. The data is in the public domain. It needs to be fetched by hand from the BEA's website. A copy of the data is provided in the repository under `raw-data/covid-aid-data`.

#### Paycheck Protection Program Microdata from the Small Business Administration

To obtain the microdata on PPP loans during COVID, we use the microdata from the Small Business Administration. The data is publicly available. It must be downloaded by hand from <https://data.sba.gov/dataset/ppp-foia> and included in the repository under `raw-data/ppp-covid-data`.

To match PPP loans to counties, with use the crosswalk between ZIP codes and counties provided by HUD (<https://www.huduser.gov/portal/datasets/usps_crosswalk.html>). This data is public and automatically downloaded by `01-import-ppp-covid.do`.

#### Quarterly Census of Employment and Wages (QCEW) from the Bureau of Labor Statistics (BLS)

The Quarterly Census of Employment and Wages comes from the BLS. The data is in the public domain. It is automatically downloaded from <https://www.bls.gov/cew/downloadable-data-files.htm> and stored in zipped form in the repository under `raw-data/qcew-data`.

#### Real-Time Billionaires List from Forbes

The Real-Time data on billionaires comes from Forbes. The data is publicly available. It is automatically scrapped from the [the Internet Archive](https://archive.org/) by the Python script `01-scrape-forbes.py` and stored in the repository under `raw-data/forbes-data`.

#### Wilshire 5000 Total Market Index (Wilshire Associates, via Yahoo Finance)

The Wilshire 5000 Total Market Index is obtained from Yahoo Finance (as of June 2024, FRED removed the `WILL5000IND` series from public access). Daily data is automatically scraped by `01-scrape-yahoo.py` and stored under `raw-data/yahoo-data/w5000.csv`. Historical data prior to 1989 comes from FRED and is stored under `raw-data/fred-data/historical-fred-data.dta`. Both series are merged and stored in the repository under `work-data/01-import-wealth-indexes`.

#### Case-Shiller National Home Price Index (via FRED)

The Case-Shiller National Home Price Index is obtained via FRED (series `CSUSHPISA`). The data is automatically downloaded by `01-import-wealth-indexes.do` and is stored in the repository under `work-data/01-import-wealth-indexes`.

#### Zillow Home Value Index (via FRED)

The Zillow Home Value Index is obtained via FRED (series `USAUCSFRCONDOSMSAMID`). The data is automatically downloaded by `01-import-wealth-indexes.do` and is stored in the repository under `work-data/01-import-wealth-indexes`.

#### Monthly Current Population Survey (Census Bureau, via IPUMS)

We obtain the Current Population Survey microdata from IPUMS. IPUMS does not allow for redistribution, except for the purpose of replication archives. The monthly CPS extract can be obtained from [IPUMS CPS](https://cps.ipums.org/cps/). It must be stored in the repository under `raw-data/cps-monthly/cps-monthly.dat`. The extract is made up of all the monthly samples, restricted to people 20 and older, and with the following variables:

| Variable | Label                                      |
|----------|--------------------------------------------|
| YEAR     | Survey year                                |
| SERIAL   | Household serial number                    |
| MONTH    | Month                                      |
| HWTFINL  | Household weight, Basic Monthly            |
| CPSID    | CPSID, household record                    |
| ASECFLAG | Flag for ASEC                              |
| PERNUM   | Person number in sample unit               |
| WTFINL   | Final Basic Weight                         |
| CPSIDP   | CPSID, person record                       |
| AGE      | Age                                        |
| SEX      | Sex                                        |
| RACE     | Race                                       |
| SPLOC    | Person number of spouse (from programming) |
| HISPAN   | Hispanic origin                            |
| EMPSTAT  | Employment status                          |
| EDUC     | Educational attainment recode              |
| EARNWT   | Earnings weight                            |
| EARNWEEK | Weekly earnings                            |
| ELIGORG  | (Earnings) eligibility flag                |

The `cps-monthly.dat` file is imported into Stata using `01-import-cps-monthly.do`.

#### American Community Survey/Census (Census Bureau, via IPUMS USA)

We obtain the ACS/Census microdata from IPUMS. IPUMS does not allow for redistribution, except for the purpose of replication archives. The monthly CPS extract can be obtained from [IPUMS USA](https://usa.ipums.org/usa/). It must be stored in the repository under `raw-data/acs-data/usa.dta`. The extract is made up of all the default samples for each year after 1970 with the following variables:

| Variable            | Label                                          |
|---------------------|------------------------------------------------|
| YEAR                | Census year                                    |
| SAMPLE              | IPUMS sample identifier                        |
| SERIAL              | Household serial number                        |
| CBSERIAL            | Original Census Bureau household serial number |
| HHWT                | Household weight                               |
| CLUSTER             | Household cluster for variance estimation      |
| STRATA              | Household strata for variance estimation       |
| GQ                  | Group quarters status                          |
| GQTYPE (general)    | Group quarters type [general version]          |
| GQTYPED (detailed)  | Group quarters type [detailed version]         |
| PERNUM              | Person number in sample unit                   |
| PERWT               | Person weight                                  |
| SPLOC               | Spouse's location in household                 |
| SEX                 | Sex                                            |
| AGE                 | Age                                            |
| RACE (general)      | Race [general version]                         |
| RACED (detailed)    | Race [detailed version]                        |
| HISPAN (general)    | Hispanic origin [general version]              |
| HISPAND (detailed)  | Hispanic origin [detailed version]             |
| EDUC (general)      | Educational attainment [general version]       |
| EDUCD (detailed)    | Educational attainment [detailed version]      |
| EMPSTAT (general)   | Employment status [general version]            |
| EMPSTATD (detailed) | Employment status [detailed version]           |
| INCWAGE             | Wage and salary income                         |
| INCBUS              | Non-farm business income                       |
| INCBUS00            | Business and farm income, 2000                 |
| INCFARM             | Farm income                                    |
| INCSS               | Social Security income                         |
| INCWELFR            | Welfare (public assistance) income             |
| INCINVST            | Interest, dividend, and rental income          |
| INCRETIR            | Retirement income                              |

The `usa.dat` file is imported into Stata using `01-import-transport-acs.do`.

#### Current Population Survey, Annual Social and Economic Supplement (Census Bureau, via IPUMS CPS)

We obtain the Current Population Survey microdata from IPUMS. IPUMS does not allow for redistribution, except for the purpose of replication archives. The monthly CPS extract can be obtained from [IPUMS CPS](https://cps.ipums.org/cps/). It must be stored in the repository under `raw-data/cps-data/cps.dta`. The extract is made up of all the ASEC samples with the following variables:

| Variable | Label                                                  |
|----------|--------------------------------------------------------|
| YEAR     | Survey year                                            |
| SERIAL   | Household serial number                                |
| MONTH    | Month                                                  |
| CPSID    | CPSID, household record                                |
| ASECFLAG | Flag for ASEC                                          |
| HFLAG    | Flag for the 3/8 file 2014                             |
| ASECWTH  | Annual Social and Economic Supplement Household weight |
| PERNUM   | Person number in sample unit                           |
| CPSIDP   | CPSID, person record                                   |
| ASECWT   | Annual Social and Economic Supplement Weight           |
| AGE      | Age                                                    |
| SEX      | Sex                                                    |
| RACE     | Race                                                   |
| SPLOC    | Person number of spouse (from programming)             |
| HISPAN   | Hispanic origin                                        |
| EMPSTAT  | Employment status                                      |
| EDUC     | Educational attainment recode                          |
| INCWAGE  | Wage and salary income                                 |
| INCBUS   | Non-farm business income                               |
| INCFARM  | Farm income                                            |
| INCSS    | Social Security income                                 |
| INCWELFR | Welfare (public assistance) income                     |
| INCGOV   | Income from other govt programs                        |
| INCRETIR | Retirement income                                      |
| INCDRT   | Income from dividends, rent, trusts                    |
| INCINT   | Income from interest                                   |
| INCUNEMP | Income from unemployment benefits                      |
| INCWKCOM | Income from worker's compensation                      |
| INCVET   | Income from veteran's benefits                         |
| INCDIVID | Income from dividends                                  |
| INCRENT  | Income from rent                                       |
| INCRANN  | Retirement income from annuities                       |
| INCPENS  | Pension income                                         |

#### Survey of Consumer Finances

The Survey of Consumer Finances microdata comes from the Federal Reserve. The data is public and can be downloaded from <https://www.federalreserve.gov/econres/scfindex.htm>. It is stored under `raw-data/scf-data`. We use both the "full" public dataset and the "extract" public data. The data is imported into Stata using `01-import-transport-scf.do`.

## Computational requirements

### Software Requirements

- Stata 16 or later
  - `gtools` (version 1.5.1)
  - `ftools` (version 2.37.0)
  - `grstyle` (version 1.1.0)
  - `renvars` (installed via `dm88_1` from the Stata Journal)
  - `ereplace` (version 1.0.3)
  - `enforce` (version 1.0)
  - `reghdfe` (version 5.7.3)
  - `_gwtmean` (version 1.0.0)
  - `denton` (version 1.2.1)
  - `carryforward`
  - `egenmore`
  - `pshare`
  - `listtab`
  - The program `00-setup.do` will install all dependencies, alongside setting appropriate paths, etc. It should be run first every time.
- Python 3.13
  - `POT` (Python Optimal Transport)
  - `numpy`
  - `scipy`
  - `pandas`
  - `numba`
  - `joblib`
  - `yfinance`
  - `waybackpy`
  - `matplotlib`
  - `requests`
- R 4.5.1
  - `pacman`
  - `gpinter`
  - `dplyr`
  - `magrittr`
  - `rvest`
  - `glue`
  - `stringr`
  - `readr`
  - `purrr`
  - `haven`
  - `ggplot2`
  - `FNN`
  - Each R file uses `pacman` to load packages, which automatically installs packages if necessary. The exception is for `gpinter`, which needs to be installed from its Github repository. See <https://github.com/world-inequality-database/gpinter>.

### Controlled Randomness

Random seeds are set at the beginning of the following programs:

- `03-build-monthly-microfiles.do`
- `03-build-monthly-microfiles-backtest-1y.do`
- `03-build-monthly-microfiles-backtest-2y.do`

### Memory and Runtime Requirements

#### Summary

Approximate time needed to reproduce the analyses on a standard 2022 desktop machine:

- [ ] <10 minutes
- [ ] 10-60 minutes
- [ ] 1-8 hours
- [ ] 8-24 hours
- [ ] 1-3 days
- [x] 3-14 days
- [ ] > 14 days
- [ ] Not feasible to run on a desktop machine, as described below.

#### Details

The code was last run on a **2,4 GHz 8-Core Intel Core i9 laptop with 64GB of RAM running MacOS version 11.6**.

Portions of the code (the optimal transport algorithms) were last run on a **8-core Intel i9-9900X CPU @ 3.50GHz computing server with 768GB of RAM running Ubuntu 20.04.1 LTS**. Computation took 2-3 days.

## Description of programs/code

- The folder `raw-data` contains the raw input data, primarily in cases where direct download/scraping is not possible or not justified, or in cases where data files are heavy (like the QCEW) and therefore downloading them over the internet every time is not desirable.
- The folder `work-data` contains intermediary data files that are produced by the code. It is divided into subfolders corresponding to each code file, and no intermediary data file may be changed by two distinct code files.
- The folder `outputs` contains all final outputs generated by the code, organized into four subfolders:
  - `outputs/graphs`: figures produced by the code, divided into subfolders by program.
  - `outputs/tables`: tables produced by the code, divided into subfolders by program.
  - `outputs/microfiles`: versioned synthetic microfiles produced by `03-build-monthly-microfiles.do`.
  - `outputs/website`: versioned data files used by the website, produced by the `03-build-online-database*.do` scripts.
- The folder `programs` contains all the code.
  - The codes named `programs/01-*` handle the retrieval of the raw data, either directly from the internet or from the folder `raw-data`.
  - The codes named `programs/02-*` handle preliminary treatments of the data.
  - The codes named `programs/03-*` produce the synthetic microfiles and related outputs.
  - The codes named `programs/04-*` produce the figures and tables used for the analysis.

### License for Code

![Modified BSD License](https://img.shields.io/badge/License-BSD-lightgrey.svg)

The code is licensed under the [Modified BSD License](https://opensource.org/licenses/BSD-3-Clause). See [LICENSE.txt](LICENSE.txt) for details.

## Instructions to Replicators

- Edit the local configuration section of `programs/00-setup.do` to set `$root`, `$rscript`, and `$pythonscript` for your computing environment.
- Run `programs/00-setup.do` once at the start of each Stata session to install dependencies and set paths.
- Run `programs/00-run.do`. 

### Details

- `programs/01-*`
  - The codes retrieve the data from the internet directly to the extent that it is possible.
  - Unless there have been changes in the structure of the data, they should run without any change for each update.
  - In some cases, the data needs to be manually updated in the `raw-data` folder at each update.
  - Instructions for each file are included in `00-run.do`.
  - Once all imports are completed, run `01-data-summary.do` to produce a summary of data coverage by source (`work-data/01-data-summary/data-summary.txt`). The summary reports the most recent month for which a monthly microfile can be produced, which can be used to set `$date_end` in `00-setup.do`.
- `programs/02-*`
  - The codes primarily generate data in the `work-data` folder that is used to generate the synthetic microfiles.
- `programs/03-*`
  - The codes produce the synthetic microfiles, including backtesting versions of the microfiles that use older tax data, and rescaling versions that only use information on macro aggregates.
  - Codes in that section also produce the databases that are used for the website <http://realtimeinequality.org/>. These files are stored in the folder `outputs/website`.
- `programs/04-*`
  - Use the microfiles and related outputs to create the tables and figures included in the paper (see below).

## List of tables and programs

The provided code reproduces:

- [x] All numbers provided in text in the paper
- [x] All tables and figures in the paper
- [ ] Selected tables and figures in the paper, as explained and justified below.

Note that program files are under `programs`, graphs are under `outputs/graphs`, and tables are under `outputs/tables`, each in a subfolder with the same name as the program file.

| Figure/Table # | Program                         | Output file                                        |
|----------------|---------------------------------|----------------------------------------------------|
| Figure 1a      | 02-match-dina-transport.do      | check-transport-gender-wage-earnings.pdf           |
| Figure 1b      | 02-match-dina-transport.do      | check-transport-blacks-hispanics-wage-earnings.pdf |
| Figure 1c      | 02-match-dina-transport.do      | check-transport-blacks-hispanics-income.pdf        |
| Figure 1d      | 02-match-dina-transport.do      | check-transport-blacks-hispanics-wealth.pdf        |
| Figure 2       | 02-create-monthly-wages.do      | flemp-dina-qcew-adjustements-3.pdf                 |
| Figure 3       | 02-create-monthly-wages.do      | flemp-dina-qcew.pdf                                |
| Figure 4a      | 04-backtest.do                  | pred-avg-bot50-1y.pdf                              |
| Figure 4b      | 04-backtest.do                  | pred-avg-bot50-2y.pdf                              |
| Figure 4c      | 04-backtest.do                  | pred-avg-mid40-1y.pdf                              |
| Figure 4d      | 04-backtest.do                  | pred-avg-mid40-2y.pdf                              |
| Figure 5a      | 04-backtest.do                  | pred-avg-top1.pdf                                  |
| Figure 5b      | 04-backtest.do                  | pred-avg-top1-2y.pdf                               |
| Figure 5c      | 04-backtest.do                  | pred-avg-next9-1y.pdf                              |
| Figure 5d      | 04-backtest.do                  | pred-avg-next9-2y.pdf                              |
| Figure 6a      | 04-plot-covid.do                | presentation-evolution-princ.pdf                   |
| Figure 6b      | 04-plot-covid.do                | bot50-recessions.pdf                               |
| Figure 7a      | 04-analyze-wage-growth.do       | employment.pdf                                     |
| Figure 7b      | 04-analyze-wage-growth.do       | employment-great-recession.pdf                     |
| Figure 7c      | 04-analyze-wage-growth.do       | wage-growth-covid.pdf                              |
| Figure 7d      | 04-analyze-wage-growth.do       | wage-growth-great-recession.pdf                    |
| Figure 8       | 04-gic-wages.do                 | gic-wages.pdf                                      |
| Figure 9       | 04-plot-covid.do                | presentation-bot50-step9.pdf                       |
| Figure 10      | 04-plot-covid.do                | presentation-evolution-hweal.pdf                   |
| Figure 11      | 04-plot-race.do                 | black-white-gaps-4.pdf                             |
| Figure 12      | 04-plot-race.do                 | index-peinc-race-cycles.pdf                        |
| Table 1        | n.a. (no data)                  |                                                    |
| Table 2        | 04-backtest.do                  | backtest-table-avg-1y.tex                          |
| Figure A1      | 02-prepare-nipa.do              | gdp-gdi-growth.pdf                                 |
| Figure A2      | 02-match-dina-transport.do      | rank-flwag-dina-cps.pdf                            |
| Figure A3      | 02-prepare-bls-employment.do    | employment-ssa-bls.pdf                             |
| Figure A4a     | 02-update-qcew-backtest.do      | extrapolation-bot50.pdf                            |
| Figure A4b     | 02-update-qcew-backtest.do      | extrapolation-top10.pdf                            |
| Figure A5a     | 02-prepare-dina.do              | volatility-profits-paper.pdf                       |
| Figure A5b     | 02-prepare-dina.do              | volatility-interest-paper.pdf                      |
| Figure A5c     | 02-prepare-dina.do              | volatility-rental-paper.pdf                        |
| Figure A5d     | 02-prepare-dina.do              | volatility-proprietors-paper.pdf                   |
| Figure A6a     | 04-backtest-rescaling.do        | pred-avg-bot50-1y.pdf                              |
| Figure A6b     | 04-backtest-rescaling.do        | pred-avg-top1-1y.pdf                               |
| Figure A7      | 04-plot-covid.do                | presentation-evolution-dispo.pdf                   |
| Figure A8      | 04-plot-covid.do                | presentation-bot50-step13.pdf                      |
| Figure A9      | 04-plot-race.do                 | black-white-gap-top10.pdf                          |
| Figure A10     | 04-plot-education.do            | college-premium-4.pdf                              |
| Figure A11     | 04-plot-gender.do               | index-peinc-gender-cycles.pdf                      |
| Table A1       | 04-backtest.do                  | backtest-table-avg-2y.tex                          |

## References

Steven Ruggles, Sarah Flood, Ronald Goeken, Megan Schouweiler and Matthew Sobek. IPUMS USA: Version 12.0 [dataset]. Minneapolis, MN: IPUMS, 2022. https://doi.org/10.18128/D010.V12.0

Sarah Flood, Miriam King, Renae Rodgers, Steven Ruggles, J. Robert Warren and Michael Westberry. Integrated Public Use Microdata Series, Current Population Survey: Version 9.0 [dataset]. Minneapolis, MN: IPUMS, 2021. https://doi.org/10.18128/D030.V9.0