import requests
import pandas as pd
from google.cloud import bigquery
from dotenv import load_dotenv
import os
import time

load_dotenv("/Users/ahmedhakim/healthcare-utilization-pipeline/.env")
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

client = bigquery.Client(project=os.getenv("GCP_PROJECT"))

print("Pulling CMS Medicare Geographic Variation data...")
print("Source: data.cms.gov - Medicare spending and utilization by state")

URL = "https://data.cms.gov/data-api/v1/dataset/6219697b-8f6c-4164-bed4-cd9317c58ebc/data"

all_records = []
offset = 0
batch_size = 5000

while True:
    response = requests.get(URL, params={
        "size": batch_size,
        "offset": offset,
        # Filter to state level only — skip county and national rows
        "filter[BENE_GEO_LVL]": "State",
        "filter[BENE_AGE_LVL]": "All",
    })

    if response.status_code != 200:
        print(f"Error {response.status_code}: {response.text[:200]}")
        break

    data = response.json()

    if not data:
        print("No more data available")
        break

    all_records.extend(data)
    offset += batch_size
    print(f"  Pulled {len(all_records):,} records...")
    time.sleep(0.3)

    if len(data) < batch_size:
        break

df = pd.DataFrame(all_records)
print(f"\nTotal records: {len(df):,}")
print(f"Years: {sorted(df['YEAR'].unique())}")
print(f"States: {df['BENE_GEO_DESC'].nunique()}")
print(f"Columns: {len(df.columns)}")

# Select the most useful columns for analysis
cols_to_keep = [
    'YEAR', 'BENE_GEO_DESC', 'BENE_GEO_CD',
    'BENES_TOTAL_CNT',
    'TOT_MDCR_PYMT_AMT', 'TOT_MDCR_PYMT_PC',
    'TOT_MDCR_STDZD_PYMT_AMT', 'TOT_MDCR_STDZD_PYMT_PC',
    'IP_MDCR_PYMT_PC', 'IP_MDCR_STDZD_PYMT_PC',
    'OP_MDCR_PYMT_PC', 'OP_MDCR_STDZD_PYMT_PC',
    'ER_VISITS_PER_1000_BENES',
    'ACUTE_HOSP_READMSN_PCT',
    'BENES_IP_PCT',
    'MA_PRTCPTN_RATE',
    'BENE_AVG_AGE',
    'BENE_DUAL_PCT',
]

# Keep only columns that exist in the dataframe
cols_to_keep = [c for c in cols_to_keep if c in df.columns]
df = df[cols_to_keep]

# Load to BigQuery
table_id = f"{os.getenv('GCP_PROJECT')}.healthcare_raw.cms_geographic_variation"

job_config = bigquery.LoadJobConfig(
    write_disposition="WRITE_TRUNCATE",
    autodetect=True
)

print(f"\nLoading to BigQuery: {table_id}")
job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
job.result()

table = client.get_table(table_id)
print(f"Successfully loaded {table.num_rows:,} rows to {table_id}")
print("Done.")