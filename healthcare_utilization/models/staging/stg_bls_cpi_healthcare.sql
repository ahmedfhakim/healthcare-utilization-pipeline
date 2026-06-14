-- Grain: one row per CPI series per month
-- Source: BLS Consumer Price Index API, 2015 to present
-- Used to inflation-adjust Medicare payment trends

with source as (
    select * from {{ source('healthcare_raw', 'bls_cpi_healthcare') }}
),

renamed as (
    select
        cast(series_id as string)                             as series_id,
        cast(series_name as string)                           as series_name,
        cast(year as integer)                                 as year,
        cast(period as string)                                as period,
        cast(period_date as date)                             as period_date,
        cast(cpi_value as numeric)                            as cpi_value,
        cast(loaded_at as string)                             as loaded_at

    from source
    where series_id is not null
        and period_date is not null
        and cpi_value is not null
)

select * from renamed