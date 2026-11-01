# Healthcare Cost & Utilization Analytics

**Live Dashboard (Medicare cost analysis, Looker Studio):** https://datastudio.google.com/reporting/c2db7a18-9468-4a9b-bbef-95555ef8a678

**Live Dashboard (Health center quality benchmarks, HRSA UDS):** https://ahmedfhakim.github.io/healthcare-utilization-pipeline/ · [code and methods](uds_benchmarks/)
HRSA UDS clinical quality measures for all ~1,360 federally funded community health centers (2023–2025), each compared with the nation, its state, and a peer group of centers serving similar patients.

**Repository:** https://github.com/ahmedfhakim/healthcare-utilization-pipeline

## What This Is

Medicare publishes enormous volumes of provider payment, geographic spending, and
inflation data, but it arrives raw, unjoined, and disconnected from any business
question. This project builds the analytics infrastructure to change that. Using
real CMS Medicare provider payment data, CMS geographic variation data, and BLS
healthcare inflation data, all ingested via REST APIs, I designed and built an
end-to-end pipeline on BigQuery using dbt, MetricFlow, and Dagster, with a
3-page Looker Studio dashboard surfacing the results.

The pipeline covers $9.64B in Medicare payments across 106 specialties and 98,555
providers. A governed MetricFlow semantic layer defines 8 core metrics so that
total spend, cost concentration, and geographic variance mean the same thing
everywhere they're queried, whether through the dbt CLI, Looker Studio, or an
AI assistant. The entire pipeline (ingestion, transformation, and testing) is
orchestrated with Dagster and runs end to end in under 3 minutes.

## Health center quality benchmarks (UDS module)

Peer benchmarking for community health centers: each health center is compared with **peers serving similar patients** (urban/rural, share uninsured, size) on the clinical quality measures every HRSA-funded center reports in the Uniform Data System.

- **Data:** HRSA's UDS awardee workbooks, 2023–2025 (38 sheets each, every value stored as text with privacy-suppression markers)
- **Stack:** Python extract → Parquet (committed, 2.3 MB) → dbt on DuckDB (24 models, seeds and tests) → static dashboard on GitHub Pages, rebuilt by GitHub Actions on every change. Nothing to pay for, nothing to expire.
- **Headline finding:** health centers with the most uninsured patients screen 8.5 points fewer adults for colorectal cancer (41.0% vs. 49.5%) and 9.1 points fewer women for breast cancer, while screening done in the clinic (cervical, depression) doesn't fall. That's consistent with the cost of referred-out procedures.

Details, data-cleaning decisions and all findings: [`uds_benchmarks/README.md`](uds_benchmarks/README.md).

## Key Findings

- Thoracic Surgery ($301.76/service) and Cardiac Surgery ($297.36/service) are
  the two highest-cost specialties per service rendered, both more than 5x the
  dataset-wide average
- Florida has the highest Medicare spending relative to the national average,
  24.91% above the national standardized payment per beneficiary, followed by
  Oklahoma (21.83%), Mississippi (21.27%), and Louisiana (21.22%)
- Contrary to the assumption that healthcare inflation outpaces general
  inflation, Medical Care Commodities (drugs, equipment, supplies) has actually
  lagged behind general inflation since 2015, indexing at 115.51 vs. 141.39 for
  All Items CPI; Medical Care Services tracks closer to general inflation at 137.05

## Architecture

CMS Provider Payment API + CMS Geographic Variation API + BLS CPI API
  -> Python ingestion (incremental load logic)
  -> BigQuery raw schema
  -> dbt staging (3 models)
  -> dbt intermediate (3 models)
  -> dbt marts (5 models)
  -> MetricFlow semantic layer (8 governed metrics)
  -> Dagster orchestration (parallel ingestion, sequential transformation)
  -> Looker Studio dashboard (3 pages)

## Tech Stack

- dbt 1.11 + BigQuery
- MetricFlow (dbt semantic layer)
- Dagster (orchestration)
- Python (pandas, google-cloud-bigquery, requests)
- CMS Open Data API + BLS API
- Looker Studio
- GitHub Actions CI

## Data Sources

- CMS Medicare Physician & Other Practitioners by Provider, 2024 (100K provider
  records, 106 specialties, 58 states)
- CMS Medicare Geographic Variation by State, 2014-2024 (605 state-year records)
- BLS Consumer Price Index, healthcare series, 2015-present (incremental monthly load)

## Dashboard Pages

1. **Executive Overview** - total spend, provider counts, top specialties by cost, cost tier breakdown
2. **Geographic Variation** - state-level spend vs. national average, ranked
3. **Inflation Trends** - Medical Care CPI vs. All Items CPI, indexed to 2015, with YoY change

## Running Locally

1. Clone the repo
2. Create a Google Cloud project and enable the BigQuery API
3. Create a service account with BigQuery Admin role and download a JSON key
4. Register for a free BLS API key at data.bls.gov/registrationEngine
5. Create a .env file with GCP_PROJECT, BLS_API_KEY, GOOGLE_APPLICATION_CREDENTIALS
6. Install dependencies: pip install -r requirements.txt and pip install dbt-bigquery dbt-metricflow dagster dagster-webserver
7. Run ingestion: python scripts/ingest_cms_providers.py && python scripts/ingest_bls_cpi.py && python scripts/ingest_cms_geographic.py
8. Run the pipeline: cd healthcare_utilization && dbt build
9. Or run the full orchestrated pipeline: cd dagster_project && dagster dev, then materialize all assets from the UI
10. Open Looker Studio and connect to your BigQuery marts dataset
