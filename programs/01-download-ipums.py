"""
Download IPUMS extracts using IPUMS API.
Usage: python 01-download-ipums.py <rawdata_path>

Downloads:
  - CPS Basic Monthly  → <rawdata>/cps-monthly/cps-monthly.dat
  - CPS ASEC           → <rawdata>/cps-data/cps.dat
  - ACS/Census         → <rawdata>/acs-data/usa.dat
"""

import os, sys, json, time, gzip, shutil, urllib.request, urllib.error

API_KEY       = "59cba10d8a5da536fc06b59d909ddb44e13e46858c214f38b3538623"
RAWDATA       = sys.argv[1] if len(sys.argv) > 1 else "raw-data"
POLL_INTERVAL = 30
MAX_WAIT      = 3600

CPS_BASE  = "https://api.ipums.org"
USA_BASE  = "https://api.ipums.org"

# --- Extracts definition -----------------------------------------------------

EXTRACTS = [
    {
        "product":     "cps",
        "output_dir":  os.path.join(RAWDATA, "cps-monthly"),
        "output_name": "cps-monthly",
        "description": "Monthly CPS - Basic Monthly - Adults 20+",
        "dataFormat":  "fixed_width",
        "dataStructure": {"rectangular": {"on": "P"}},
        "sample_filter": lambda s: "ASEC" not in s["description"],
        "variables": {
            "YEAR": {}, "SERIAL": {}, "MONTH": {}, "HWTFINL": {}, "CPSID": {},
            "ASECFLAG": {}, "PERNUM": {}, "WTFINL": {}, "CPSIDP": {}, "CPSIDV": {},
            "EARNWEEK2": {}, "SEX": {}, "RACE": {}, "SPLOC": {}, "HISPAN": {},
            "EMPSTAT": {}, "EDUC": {}, "EARNWT": {}, "ELIGORG": {},
            "AGE": {"caseSelections": {"general": [str(a) for a in range(20, 100)]}},
        },
    },
    {
        "product":     "cps",
        "output_dir":  os.path.join(RAWDATA, "cps-data"),
        "output_name": "cps",
        "description": "CPS ASEC",
        "dataFormat":  "fixed_width",
        "dataStructure": {"rectangular": {"on": "P"}},
        "sample_filter": lambda s: "ASEC" in s["description"],
        "variables": {
            "YEAR": {}, "SERIAL": {}, "MONTH": {}, "CPSID": {}, "ASECFLAG": {},
            "HFLAG": {}, "ASECWTH": {}, "PERNUM": {}, "CPSIDP": {}, "ASECWT": {},
            "SEX": {}, "RACE": {}, "SPLOC": {}, "HISPAN": {}, "EMPSTAT": {}, "EDUC": {},
            "INCWAGE": {}, "INCBUS": {}, "INCFARM": {}, "INCSS": {}, "INCWELFR": {},
            "INCGOV": {}, "INCRETIR": {}, "INCDRT": {}, "INCINT": {}, "INCUNEMP": {},
            "INCWKCOM": {}, "INCVET": {}, "INCDIVID": {}, "INCRENT": {}, "INCRANN": {},
            "INCPENS": {},
            "AGE": {},
        },
    },
    {
        "product":     "usa",
        "output_dir":  os.path.join(RAWDATA, "acs-data"),
        "output_name": "usa",
        "description": "ACS/Census",
        "dataFormat":  "fixed_width",
        "dataStructure": {"rectangular": {"on": "P"}},
        "sample_filter": lambda s: (
            s["name"].startswith("us") and
            s["name"][2:6].isdigit() and
            int(s["name"][2:6]) >= 1970 and
            int(s["name"][2:6]) not in {2001, 2002, 2003, 2004, 2005} and
            s["name"].endswith("a")
        ),
        "variables": {
            "YEAR": {}, "SAMPLE": {}, "SERIAL": {}, "CBSERIAL": {}, "HHWT": {},
            "CLUSTER": {}, "STRATA": {}, "GQ": {}, "GQTYPE": {}, "PERNUM": {},
            "PERWT": {}, "SPLOC": {}, "SEX": {}, "RACE": {}, "HISPAN": {}, "EDUC": {},
            "EMPSTAT": {}, "INCWAGE": {}, "INCBUS": {}, "INCBUS00": {}, "INCFARM": {},
            "INCSS": {}, "INCWELFR": {}, "INCINVST": {}, "INCRETIR": {},
            "AGE": {},
            "GQ": {"caseSelections": {"general": ["3", "4"]}},
        },
    }
]

# --- API helpers -------------------------------------------------------------

def api(product, method, path, data=None):
    url = f"https://api.ipums.org{path}"
    headers = {"Authorization": API_KEY, "Content-Type": "application/json"}
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"API error {e.code}: {e.read().decode()}") from None

def fetch_samples(product):
    samples, page = [], 1
    while True:
        r = api(product, "GET", f"/metadata/{product}/samples?version=2&pageSize=500&pageNumber={page}")
        samples.extend(r["data"])
        if page * r["pageSize"] >= r["totalCount"]:
            break
        page += 1
    return samples

def submit_extract(product, extract_def, samples):
    return api(product, "POST", f"/extracts/?product={product}&version=2", {
        "description":   extract_def["description"],
        "dataFormat":    extract_def["dataFormat"],
        "dataStructure": extract_def["dataStructure"],
        "samples":       samples,
        "variables":     extract_def["variables"],
    })

def poll_until_complete(product, number):
    for _ in range(MAX_WAIT // POLL_INTERVAL):
        time.sleep(POLL_INTERVAL)
        status = api(product, "GET", f"/extracts/{number}?product={product}&version=2")
        if status["status"] == "completed":
            return status
        if status["status"] == "failed":
            raise RuntimeError(f"Extract #{number} failed")
    raise TimeoutError(f"Extract #{number} timed out")

def download_file(url, dest):
    req = urllib.request.Request(url, headers={"Authorization": API_KEY})
    with urllib.request.urlopen(req) as r, open(dest, "wb") as f:
        shutil.copyfileobj(r, f)

def download_extract(status, output_dir, output_name):
    os.makedirs(output_dir, exist_ok=True)
    links = status["downloadLinks"]
    dat_gz = os.path.join(output_dir, f"{output_name}.dat.gz")
    download_file(links["data"]["url"], dat_gz)
    with gzip.open(dat_gz, "rb") as f_in, open(os.path.join(output_dir, f"{output_name}.dat"), "wb") as f_out:
        shutil.copyfileobj(f_in, f_out)
    os.remove(dat_gz)

# --- Main --------------------------------------------------------------------

# Submit all extracts first, then wait for all in parallel
submitted = []
for ext in EXTRACTS:
    all_samples = fetch_samples(ext["product"])
    samples = {s["name"]: {} for s in all_samples if ext["sample_filter"](s)}
    print(f"[{ext['output_name']}] Submitting with {len(samples)} samples...")
    if not samples:
        print(f"[{ext['output_name']}] ERROR: no samples matched, skipping.")
        continue
    result = submit_extract(ext["product"], ext, samples)
    submitted.append((ext, result["number"]))
    print(f"[{ext['output_name']}] Extract #{result['number']} submitted.")

print("\nWaiting for completion...")
for ext, number in submitted:
    print(f"[{ext['output_name']}] Polling extract #{number}...")
    status = poll_until_complete(ext["product"], number)
    download_extract(status, ext["output_dir"], ext["output_name"])
    print(f"[{ext['output_name']}] Done -> {ext['output_dir']}/")
