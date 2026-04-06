# ---------------------------------------------------------------------------- #
# Import real-time Forbes data
# ---------------------------------------------------------------------------- #

import waybackpy
import datetime
import calendar
import urllib
import json
import pandas as pd
import sys
import time
import ssl
import os

try:
    _create_unverified_https_context = ssl._create_unverified_context
except AttributeError:
    # Legacy Python that doesn't verify HTTPS certificates by default
    pass
else:
    # Handle target environment that doesn't support HTTPS verification
    ssl._create_default_https_context = _create_unverified_https_context

output_path = sys.argv[1]

# Load existing data if available
if os.path.exists(output_path):
    existing_data = pd.read_csv(output_path, index_col=0, low_memory=False)
    # Find the last (year, month) already in the data
    last_year = existing_data['year'].max()
    last_month = existing_data[existing_data['year'] == last_year]['month'].max()
    print(f"Existing data found up to {last_year}-{last_month:02d}")
else:
    existing_data = None
    last_year = 2019  # Start from 2020
    last_month = 12
    print("No existing data found, fetching all historical data")

# Import data end of every month from 2020 onwards
dates = []
for year in range(2020, datetime.date.today().year + 1):
    for month in range(1, 13):
        last_day = calendar.monthrange(year, month)[1]
        target_date = datetime.date(year, month, last_day)
        if target_date < datetime.date.today():
            if (year > last_year) or (year == last_year and month > last_month):
                dates.append((year, month, last_day))

if not dates:
    print("No new dates to fetch. Data is up to date.")
    sys.exit(0)

print(f"Fetching {len(dates)} month(s): {dates[0]} to {dates[-1]}")

# Scrap Forbes list closest to that day from the Wayback machine
user_agent = "Mozilla/5.0 (Windows NT 5.1; rv:40.0) Gecko/20100101 Firefox/40.0"
url = "https://www.forbes.com/forbesapi/person/rtb/0/position/true.json"
availability_api = waybackpy.WaybackMachineAvailabilityAPI(url, user_agent)

table_new = []
for date in dates:
    print(f"Fetching {date[0]}-{date[1]:02d}-{date[2]:02d}...")
    while True:
        try:
            archive_wayback = availability_api.near(year=date[0], month=date[1], day=date[2], hour=24)
            archive_url = archive_wayback.archive_url
            # Tweak URL to get raw JSON
            archive_url = archive_url[0:42] + "if_" + archive_url[42:len(archive_url)]
            response_wayback = urllib.request.urlopen(archive_url).read().decode()
            json_wayback = json.loads(response_wayback)
            # Download and flatten the table
            table_wayback = pd.json_normalize(json_wayback["personList"]["personsLists"])
            table_wayback["year"] = date[0]
            table_wayback["month"] = date[1]
        except Exception as e:
            print(e)
            print("error, retrying in 10s...")
            time.sleep(10)
        else:
            break
    table_new.append(table_wayback)

if table_new:
    new_data = pd.concat(table_new, ignore_index=True)
    if existing_data is not None:
        table_all = pd.concat([existing_data, new_data], ignore_index=True)
    else:
        table_all = new_data
    table_all.to_csv(output_path)
    print(f"Added {len(dates)} new month(s). Total rows: {len(table_all)}")
