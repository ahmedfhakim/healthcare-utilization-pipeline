import subprocess
import os
from dagster import asset, AssetExecutionContext, MaterializeResult, MetadataValue

PROJECT_ROOT = "/Users/ahmedhakim/healthcare-utilization-pipeline"


def _run_script(context: AssetExecutionContext, script_name: str) -> str:
    """Run an ingestion script and capture output."""
    script_path = os.path.join(PROJECT_ROOT, "scripts", script_name)
    result = subprocess.run(
        ["python3.11", script_path],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
    )
    context.log.info(result.stdout)
    if result.returncode != 0:
        context.log.error(result.stderr)
        raise Exception(f"{script_name} failed: {result.stderr}")
    return result.stdout


@asset(group_name="ingestion")
def cms_provider_payments(context: AssetExecutionContext) -> MaterializeResult:
    """Raw CMS Medicare provider payment data, ingested via REST API."""
    output = _run_script(context, "ingest_cms_providers.py")
    return MaterializeResult(
        metadata={"log_tail": MetadataValue.text(output[-500:])}
    )


@asset(group_name="ingestion")
def bls_cpi_healthcare(context: AssetExecutionContext) -> MaterializeResult:
    """BLS healthcare CPI data, ingested incrementally via REST API."""
    output = _run_script(context, "ingest_bls_cpi.py")
    return MaterializeResult(
        metadata={"log_tail": MetadataValue.text(output[-500:])}
    )


@asset(group_name="ingestion")
def cms_geographic_variation(context: AssetExecutionContext) -> MaterializeResult:
    """CMS Medicare geographic variation data, ingested via REST API."""
    output = _run_script(context, "ingest_cms_geographic.py")
    return MaterializeResult(
        metadata={"log_tail": MetadataValue.text(output[-500:])}
    )


@asset(
    group_name="transformation",
    deps=[cms_provider_payments, bls_cpi_healthcare, cms_geographic_variation],
)
def dbt_build(context: AssetExecutionContext) -> MaterializeResult:
    """Run the full dbt build: staging, intermediate, marts, and tests."""
    dbt_dir = os.path.join(PROJECT_ROOT, "healthcare_utilization")
    result = subprocess.run(
        ["dbt", "build"],
        cwd=dbt_dir,
        capture_output=True,
        text=True,
    )
    context.log.info(result.stdout)
    if result.returncode != 0:
        context.log.error(result.stderr)
        raise Exception(f"dbt build failed: {result.stderr}")
    return MaterializeResult(
        metadata={"log_tail": MetadataValue.text(result.stdout[-1000:])}
    )
