import requests
import pandas as pd
from google.cloud import bigquery
from dotenv import load_dotenv
import os
import json
from datetime import datetime

load_dotenv("/Users/ahmedhakim/healthcare-utilization-pipeline/.env")
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

client = bigquery.Client(project=os.getenv("GCP_PROJECT"))
table_id = f"{os.getenv('GCP_PROJECT')}.healthcare_raw.bls_cpi_healthcare"

# Incremental logic — check what months are already loaded
try:
    query = f"SELECT MAX(period_date) as max_date FROM `{table_id}`"
    result = client.query(query).to_dataframe()
    last_loaded = result['max_date'][0]
    print(f"Incremental load — last loaded date: {last_loaded}")
except Exception:
    last_loaded = None
    print("No existing data — running full load from 2015")

# BLS series for healthcare CPI
series_ids = [
    "CUUR0000SAM",    # Medical care total
    "CUUR0000SA0",    # All items (comparison baseline)
    "CUUR0000SAM1",   # Medical care commodities (drugs, equipment)
    "CUUR0000SAM2",   # Medical care services (doctor visits, hospital)
]

series_names = {
    "CUUR0000SAM":  "Medical Care Total",
    "CUUR0000SA0":  "All Items",
    "CUUR0000SAM1": "Medical Care Commodities",
    "CUUR0000SAM2": "Medical Care Services",
}

print(f"\nPulling BLS CPI data for {len(series_ids)} series...")
print("Source: Bureau of Labor Statistics API")

response = requests.post(
    "https://api.bls.gov/publicAPI/v2/timeseries/data/",
    headers={"Content-Type": "application/json"},
    data=json.dumps({
        "seriesid": series_ids,
        "startyear": "2015",
        "endyear": str(datetime.now().year),
        "registrationkey": os.getenv("BLS_API_KEY"),
    })
)

data = response.json()

if data["status"] != "REQUEST_SUCCEEDED":
    print(f"BLS API error: {data['message']}")
    exit(1)

records = []
for series in data["Results"]["series"]:
    series_id = series["seriesID"]
    for item in series["data"]:
        month_str = item["period"].replace("M", "")
        period_date = f"{item['year']}-{month_str.zfill(2)}-01"
        records.append({
            "series_id": series_id,
            "series_name": series_names.get(series_id, series_id),
            "year": int(item["year"]),
            "period": item["period"],
            "period_date": period_date,
            "cpi_value": float(item["value"]) if item["value"] != '-' else None,
            "loaded_at": datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S'),
        })

df = pd.DataFrame(records)
df["period_date"] = pd.to_datetime(df["period_date"]).dt.date

# Incremental filter — only load new months
if last_loaded:
    df = df[df["period_date"] > last_loaded]
    print(f"New records to load: {len(df):,}")
else:
    print(f"Full load: {len(df):,} records across {df['series_id'].nunique()} series")

if len(df) == 0:
    print("No new data to load — already up to date")
else:
    schema = [
        bigquery.SchemaField("series_id", "STRING"),
        bigquery.SchemaField("series_name", "STRING"),
        bigquery.SchemaField("year", "INTEGER"),
        bigquery.SchemaField("period", "STRING"),
        bigquery.SchemaField("period_date", "DATE"),
        bigquery.SchemaField("cpi_value", "FLOAT"),
        bigquery.SchemaField("loaded_at", "STRING"),
    ]

    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_APPEND",
        schema=schema
    )

    print(f"Loading to BigQuery: {table_id}")
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()
    print(f"Successfully loaded {len(df):,} new rows")
    print(f"Date range: {df['period_date'].min()} to {df['period_date'].max()}")

print("Done.")