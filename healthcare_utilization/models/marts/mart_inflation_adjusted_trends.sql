{{
    config(materialized='table')
}}

-- Grain: one row per CPI series per month
-- Note: incremental loading happens at the ingestion layer (see
-- scripts/ingest_bls_cpi.py), which checks MAX(period_date) and only
-- pulls new months via an append-only load job. This mart rebuilds
-- from the already-incrementally-loaded raw table.
-- Business question: how much faster has medical inflation grown vs general inflation?

with cpi as (
    select * from {{ ref('int_cpi_baseline') }}
)

select
    series_id,
    series_name,
    period_date,
    year,
    cpi_value,
    baseline_value,
    index_vs_2015,

    round(cpi_value - lag(cpi_value) over (
        partition by series_id
        order by period_date
    ), 2)                                                     as mom_change,

    round(cpi_value - lag(cpi_value, 12) over (
        partition by series_id
        order by period_date
    ), 2)                                                     as yoy_change,

    round(
        (cpi_value - lag(cpi_value, 12) over (
            partition by series_id
            order by period_date
        )) / nullif(lag(cpi_value, 12) over (
            partition by series_id
            order by period_date
        ), 0) * 100,
    2)                                                        as yoy_pct_change

from cpi
