-- Grain: one row per CPI series per month
-- Calculates index relative to 2015 baseline
-- Used by mart_inflation_adjusted_trends for real vs nominal comparison

with cpi as (
    select * from {{ ref('stg_bls_cpi_healthcare') }}
),

baseline_2015 as (
    select
        series_id,
        avg(cpi_value)                                        as baseline_value
    from cpi
    where year = 2015
    group by series_id
)

select
    c.series_id,
    c.series_name,
    c.period_date,
    c.year,
    c.cpi_value,
    b.baseline_value,
    round(c.cpi_value / nullif(b.baseline_value, 0) * 100, 2) as index_vs_2015

from cpi c
left join baseline_2015 b using (series_id)
