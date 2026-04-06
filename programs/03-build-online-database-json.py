"""
CSV to JSON converter for RTI website.
Usage: python 03-build-online-database-json.py <path_to_website_update_folder>
"""

import pandas as pd
import json
import sys
import os


def csv_to_json(csv_path, json_path):
    try:
        df = pd.read_csv(csv_path)
        json_str = df.to_json(orient='records')
        records = json.loads(json_str)
        output = {"data": records}
        with open(json_path, 'w') as f:
            json.dump(output, f, separators=(',', ':'))
        return True
    except Exception as e:
        print(f"Error converting {csv_path}: {str(e)}")
        return False


def main():
    if len(sys.argv) != 2:
        print("Usage: python 03-build-online-database-json.py <path_to_website_update_folder>")
        return 1
    
    base_path = sys.argv[1]
    json_folder = os.path.join(base_path, "json")
    
    os.makedirs(json_folder, exist_ok=True)
    
    files = [
        'online-database.csv',
        'online-database-labor.csv',
        'online-database-popul-deflator.csv',
        'online-database-demographics.csv',
    ]
    
    for filename in files:
        csv_path = os.path.join(base_path, filename)
        json_filename = filename.replace('.csv', '.json')
        json_path = os.path.join(json_folder, json_filename)
        if os.path.exists(csv_path):
            csv_to_json(csv_path, json_path)


if __name__ == "__main__":
    sys.exit(main())