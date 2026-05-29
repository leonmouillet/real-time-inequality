"""
ui_xml_to_xlsx.py — Convert DOL UI Claims XML (r539cy) to XLSX.

Usage:
    python ui_xml_to_xlsx.py                    # auto-detect XML in script folder
    python ui_xml_to_xlsx.py "r539cy.xml"       # explicit XML path
"""

import sys, glob, os, xml.etree.ElementTree as ET, openpyxl

DIR    = os.path.dirname(os.path.abspath(__file__))
OUTPUT = os.path.join(DIR, "weekly-unemployment-report.xlsx")

def val(text, float_=False):
    if not text or text.strip() in ("", "\xa0"): return None
    t = text.strip().replace(",", "")
    try: return float(t) if float_ or "." in t else int(t)
    except ValueError: return None

xml_path = sys.argv[1] if len(sys.argv) > 1 else (
    sorted(glob.glob(os.path.join(DIR, "r539cy*.xml")), key=os.path.getmtime)[-1])

root  = ET.parse(xml_path).getroot()
weeks = root.findall("week")
print(f"rundate: {root.get('rundate')}  |  weeks: {len(weeks)}")

wb = openpyxl.Workbook()
ws = wb.active
ws.title = "UI Claims"
ws.append(["weekEnded",
           "InitialClaims_NSA","InitialClaims_SF","InitialClaims_SA","InitialClaims_SA4WK",
           "ContinuedClaims_NSA","ContinuedClaims_SF","ContinuedClaims_SA","ContinuedClaims_SA4WK",
           "IUR_NSA","IUR_SA","CoveredEmployment"])

for w in weeks:
    ws.append([
        w.find("weekEnded").text,
        val(w.find("InitialClaims/NSA").text),
        val(w.find("InitialClaims/SF").text,       float_=True),
        val(w.find("InitialClaims/SA").text),
        val(w.find("InitialClaims/SA4WK").text),
        val(w.find("ContinuedClaims/NSA").text),
        val(w.find("ContinuedClaims/SF").text,     float_=True),
        val(w.find("ContinuedClaims/SA").text),
        val(w.find("ContinuedClaims/SA4WK").text),
        val(w.find("IUR/NSA").text,                float_=True),
        val(w.find("IUR/SA").text,                 float_=True),
        val(w.find("CoveredEmployment").text),
    ])

wb.save(OUTPUT)
print(f"Saved: {OUTPUT}")
