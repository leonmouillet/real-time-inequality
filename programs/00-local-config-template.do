// -------------------------------------------------------------------------- //
// Local configuration — paths and API keys
// -------------------------------------------------------------------------- //
// Copy this file to 00-local-config.do and fill in your local settings.
// 00-local-config.do is gitignored and must never be committed.
//
// API keys:
//   IPUMS: https://account.ipums.org/api_keys
//   FRED:  https://fred.stlouisfed.org/docs/api/api_key.html

// Paths (must be set according to local computing environment)
global root         "YOUR_PROJECT_ROOT_PATH"
global rscript      "YOUR_RSCRIPT_PATH"
global pythonscript "YOUR_PYTHON_PATH"

// API keys
global IPUMS_api_key "YOUR_IPUMS_API_KEY"
global FRED_api_key  "YOUR_FRED_API_KEY"

set fredkey "$FRED_api_key", permanently
