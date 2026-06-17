{{
    config(materialized='table')
}}

-- Time spine required by MetricFlow for time-based metric aggregations.
-- Generates one row per day from 2014-01-01 (earliest data in this project)
-- through today.

select
    date_day
from unnest(
    generate_date_array('2014-01-01', current_date(), interval 1 day)
) as date_day
