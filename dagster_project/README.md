# Dagster Orchestration

Wraps the 3 ingestion scripts and the dbt build into a single pipeline using Dagster's asset model. Ingestion runs in parallel since none of the three sources depend on each other, then dbt_build kicks off once all three finish.

## Pipeline

cms_provider_payments, bls_cpi_healthcare, and cms_geographic_variation all run first and in parallel. dbt_build runs after, once all three have completed, and handles staging, intermediate, marts, and tests.

## Running locally

cd dagster_project
dagster dev

Then go to http://localhost:3000, open Assets, select all, hit Materialize selected.

## Schedule

There's a daily 6am schedule set up in definitions.py. The underlying CMS/BLS data only updates monthly or annually in reality, but the daily cron is there to show the orchestration pattern you'd actually use in production.
