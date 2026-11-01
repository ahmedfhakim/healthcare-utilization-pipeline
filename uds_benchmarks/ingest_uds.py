"""
Extract the parts of HRSA's UDS awardee workbooks this project uses into small Parquet files.

HRSA publishes one Excel workbook per year (H80-YYYY.xlsx, ~20-30 MB, 38 sheets) at
https://data.hrsa.gov/data/download -> "Health Center Program Uniform Data System (UDS)
Awardees and Look-Alikes" -> Health Center Program Awardees.

Download the years you want into uds_benchmarks/data/raw/ (git-ignored), then:

    python uds_benchmarks/ingest_uds.py

Output (committed, a few MB): uds_benchmarks/data/extract/<table>_<year>.parquet

Every value stays TEXT exactly as HRSA published it, including the suppression markers
("-" not reported, "--" count of 1-15 suppressed for privacy, "---" confidential).
Interpreting them is dbt's job, in one place (macros/uds_number.sql).

Not extracted on purpose: project director names, phone numbers and emails
(HealthCenterInfo), which a public portfolio repo has no reason to republish.
"""
import re
import sys
from pathlib import Path

import pandas as pd

HERE = Path(__file__).resolve().parent
RAW = HERE / "data" / "raw"
OUT = HERE / "data" / "extract"

HEALTH_CENTER_COLUMNS = [
    "BHCMISID", "GrantNumber", "ReportingYear", "HealthCenterName", "HealthCenterCity",
    "HealthCenterState", "HealthCenterZIPCode", "UrbanRuralFlag", "FundingCHC",
    # special-population funding flags were renamed in 2025 (HO->HP, MHC->MSAW, PH->RPH);
    # keep whichever the year has and reconcile them in staging
    "FundingHO", "FundingMHC", "FundingPH", "FundingHP", "FundingMSAW", "FundingRPH",
]


def read(path: Path, sheet: str) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name=sheet, dtype=str, keep_default_na=False)
    return df.rename(columns=lambda c: str(c).strip())


def extract_year(path: Path) -> dict[str, pd.DataFrame]:
    year = re.search(r"(\d{4})", path.stem).group(1)

    hc = read(path, "HealthCenterInfo")
    hc = hc[[c for c in HEALTH_CENTER_COLUMNS if c in hc.columns]]

    t4 = read(path, "Table4")
    t4.columns = [c if not c.lower().startswith("t4_l10a_other") else "T4_L10a_other" for c in t4.columns]

    t6b = read(path, "Table6BClinicalmeasures")

    # Table 7 line "i" is the all-patients total (lines 1a-1g/2a-2g are by ethnicity/race,
    # line h is "unreported"). Section B (hypertension) is in Table7_1, section C (diabetes)
    # in Table7_2.
    t71 = read(path, "Table7_1")
    t72 = read(path, "Table7_2")
    keep1 = ["BHCMISID", "GrantNumber"] + [c for c in t71.columns if c.startswith("T7_Li_C2")]
    keep2 = ["BHCMISID"] + [c for c in t72.columns if c.startswith("T7_Li_C3")]
    t7 = t71[keep1].merge(t72[keep2], on="BHCMISID", how="outer")

    out = {"health_centers": hc, "table4": t4, "table6b": t6b, "table7_totals": t7}
    for df in out.values():
        df.insert(0, "reporting_year", year)
    return out


def main() -> int:
    files = sorted(RAW.glob("H80-*.xlsx"))
    if not files:
        print(f"No H80-*.xlsx files in {RAW}. Download them from https://data.hrsa.gov/data/download")
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    for f in files:
        tables = extract_year(f)
        year = tables["health_centers"]["reporting_year"].iloc[0]
        for name, df in tables.items():
            dest = OUT / f"{name}_{year}.parquet"
            df.to_parquet(dest, index=False)
        sizes = ", ".join(f"{n} {len(d):,}" for n, d in tables.items())
        print(f"{f.name}: {sizes} rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
