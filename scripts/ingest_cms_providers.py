import requests
import pandas as pd
from google.cloud import bigquery
from dotenv import load_dotenv
import os
import time

load_dotenv("/Users/ahmedhakim/healthcare-utilization-pipeline/.env")
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

client = bigquery.Client(project=os.getenv("GCP_PROJECT"))

print("Pulling CMS Medicare Physician & Other Practitioners data...")
print("Source: data.cms.gov - real 2024 Medicare payment data by provider NPI")
print("Dataset: Medicare Physician & Other Practitioners - by Provider")

URL = "https://data.cms.gov/data-api/v1/dataset/8889d81e-2ee7-448f-8713-f071038289b5/data"

all_records = []
offset = 0
batch_size = 5000
target_records = 100000

while len(all_records) < target_records:
    response = requests.get(URL, params={
        "size": batch_size,
        "offset": offset
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
    time.sleep(0.5)

df = pd.DataFrame(all_records)
print(f"\nTotal records: {len(df):,}")
print(f"Columns: {len(df.columns)}")
print(f"Specialties: {df['Rndrng_Prvdr_Type'].nunique():,}")
print(f"States: {df['Rndrng_Prvdr_State_Abrvtn'].nunique():,}")

# Load to BigQuery
table_id = f"{os.getenv('GCP_PROJECT')}.healthcare_raw.cms_provider_payments"

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