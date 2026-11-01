# Health center quality benchmarks (HRSA UDS)

How does each of the ~1,360 HRSA-funded community health centers perform on the clinical quality measures they report every year, compared with the nation, their state, and **centers that serve similar patients**?

**Live dashboard:** https://ahmedfhakim.github.io/healthcare-utilization-pipeline/ (published by GitHub Actions from `dashboard/site/index.html`)

## Data

HRSA's Uniform Data System (UDS) awardee files, 2023–2025: one Excel workbook per year, 38 sheets, 20–30 MB each ([data.hrsa.gov](https://data.hrsa.gov/data/download) → "Health Center Program Uniform Data System (UDS) Awardees and Look-Alikes" → Health Center Program Awardees, `H80-YYYY.xlsx`).

| Sheet | Used for |
|---|---|
| `HealthCenterInfo` | Name, city, state, urban/rural flag |
| `Table4` | Patients by income and insurance: total patients, % uninsured, % Medicaid |
| `Table6BClinicalmeasures` | 16 quality-of-care measures (screening, prevention, behavioral health, oral health) |
| `Table7_1`, `Table7_2` | Hypertension control and diabetes poor control, line i (all patients) |

Project-director names, phones and emails in `HealthCenterInfo` are deliberately not extracted.

## What the raw files throw at you

| Found | How it's handled |
|---|---|
| Every value is text, with three markers instead of numbers: `-` not reported, `--` a count of 1–15 suppressed for privacy, `---` confidential | One macro (`macros/uds_number.sql`) converts cells and records *why* a value is missing (`uds_status`) |
| Each sheet has a filler row of `-` under the header | Dropped in staging (`BHCMISID not in ('-', '')`) |
| Table 6B packs each measure into three columns with names like `TotalofAdults18andolderwithIVDorwithAMI,CABG,orPCIProcedure` | Unpivoted to one row per center × year × measure, from a single column map in `stg_uds__table6b_measures.sql` |
| Table 7's readable sheet (`Table7Clinicalmeasures`) is split by race and ethnicity with **no total row** | Used the coded wide sheets instead: `T7_Li_C2a/b/c` is line i (all patients), column 2 = hypertension. Verified: line i equals the sum of the Hispanic, non-Hispanic and unreported subtotals (4,741 = 950 + 3,560 + 231 for one center) |
| Funding-flag columns renamed in 2025 (`FundingHO` → `FundingHP`, `MHC` → `MSAW`, `PH` → `RPH`); one Table 4 column changes case | `read_parquet(..., union_by_name = true)` lines the years up; staging coalesces old and new names |
| Two substance-use treatment measures exist only from 2025 | Kept; flagged as new in the dashboard, no trend shown |
| Small insurance counts suppressed in Table 4 | Treated as 0 and counted (`suppressed_insurance_cells`). A test proves the gap to total patients is always between 0 and 15 × suppressed cells |
| National depression remission doubles in 2025 (15% → 30%) | Almost certainly a specification or reporting change, not real improvement. The dashboard warns against comparing years |
| Tables 5, 8A and 9D (visits, costs, revenue) are `---` (confidential) for health centers | Not used |

## Method

- **Rate** = numerator ÷ denominator as HRSA publishes it (for Table 7: controlled ÷ charts reviewed). A test confirms HRSA's published rate always matches its own counts.
- **Benchmarkable** only when the denominator is at least 30 patients (`min_denominator` var). Smaller results are shown but not ranked.
- **Peer groups** (per year): urban/rural × national third by share of patients uninsured × size (under 10k / 10k–30k / 30k+ patients; rural centers under 10k / 10k+, because only ~15 rural centers a year have 30k+ patients and many uninsured). Groups hold 48–143 centers.
- **Peer band**: top quarter / above median / below median / bottom quarter of the peer group, respecting direction (diabetes poor control is inverse).
- **Patients to peer median**: how many more patients would need to meet the measure (or leave the numerator, for diabetes) for a center to reach its peer median.
- **State and national rates are patient-weighted**: all patients pooled, the way HRSA reports national results.

## Findings (2025)

- **Screening that needs a referral out falls as the share of uninsured patients rises; screening done in the clinic doesn't.** Health centers with the most uninsured patients (fifth of centers, 29–100% uninsured) screen 41.0% of eligible adults for colorectal cancer, vs. 49.5% at centers with the fewest (0–7%). Breast cancer screening drops from 60.6% to 51.5%. Cervical screening, done in the clinic, is flat (56.8% vs. 58.9%), and depression screening goes *up* (73.0% → 79.7%). This is consistent with the cost of a colonoscopy or mammogram keeping uninsured patients from completing a referral (see the [referral price guide](https://github.com/ahmedfhakim/ma-hospital-prices#for-community-health-centers-a-referral-price-guide) in the hospital prices project), though the data can't prove the cause.
- **Massachusetts' 37 health centers beat the nation on cancer and HIV screening** (colorectal 53.0% vs. 45.9%, cervical 66.8% vs. 57.3%, HIV 68.2% vs. 57.8%) and on diabetes control (22.1% poorly controlled vs. 26.3%), but **trail on adult BMI follow-up (58.9% vs. 70.2%) and depression screening (66.4% vs. 76.0%)**.
- **Within Massachusetts, the gap to peers is concentrated.** For colorectal screening, three centers account for 2,363 of the 3,093 patients that separate below-median centers from their peer medians.
- **Nationally, hypertension control (65.7% → 69.1%) and colorectal screening (41.1% → 45.9%) improved every year from 2023 to 2025.**

Rates are as reported by health centers. Differences between centers reflect patient populations and documentation practices as well as quality of care.

## Run it

```bash
pip install -r uds_benchmarks/requirements.txt

# only if you change years: put H80-YYYY.xlsx files in uds_benchmarks/data/raw/, then
python uds_benchmarks/ingest_uds.py          # -> data/extract/*.parquet (committed, 2.3 MB)

cd uds_benchmarks/transform && dbt build --profiles-dir .   # 24 models, seeds and tests on DuckDB
cd ../.. && python uds_benchmarks/dashboard/build.py        # -> dashboard/site/index.html
```

The extract is committed, so the dbt build and dashboard run without downloading anything.

## Models

```
staging/       stg_uds__health_centers, stg_uds__patient_mix, stg_uds__table6b_measures, stg_uds__table7_measures
intermediate/  int_uds__peer_groups, int_uds__measure_results
marts/         mart_uds_center_benchmarks   center x year x measure vs nation, state and peers
               mart_uds_state_measures      state x year x measure, patient-weighted
               mart_uds_national_trend      year x measure
               mart_uds_uninsured_gradient  year x measure x uninsured quintile
               mart_uds_data_quality        suppression and coverage counts per year
```

Tests: one row per center-year and per center-year-measure, rates between 0 and 1, insurance categories reconcile to total patients within the suppression bound, HRSA's published rates match its counts (warn), peer groups of at least 20 centers (warn), valid measure IDs and peer bands.
