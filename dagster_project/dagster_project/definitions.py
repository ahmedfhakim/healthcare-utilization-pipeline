from dagster import Definitions, define_asset_job, ScheduleDefinition, AssetSelection
from dagster_project.assets import (
    cms_provider_payments,
    bls_cpi_healthcare,
    cms_geographic_variation,
    dbt_build,
)

# Job: materializes all assets in dependency order —
# 3 ingestion assets run, then dbt_build runs once all three complete
healthcare_pipeline_job = define_asset_job(
    name="healthcare_pipeline_job",
    selection=AssetSelection.all(),
)

# Schedule: runs daily at 6am, mirroring how CMS/BLS data actually updates
# (monthly/annual in practice, but daily schedule demonstrates production pattern)
daily_schedule = ScheduleDefinition(
    job=healthcare_pipeline_job,
    cron_schedule="0 6 * * *",
)

defs = Definitions(
    assets=[
        cms_provider_payments,
        bls_cpi_healthcare,
        cms_geographic_variation,
        dbt_build,
    ],
    jobs=[healthcare_pipeline_job],
    schedules=[daily_schedule],
)
