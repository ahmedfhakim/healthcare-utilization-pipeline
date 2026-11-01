-- What the raw files contained, and what the cleanup did with it, per reporting year.
with m as (
    select reporting_year, numerator_status as status from {{ ref('stg_uds__table6b_measures') }}
    union all
    select reporting_year, numerator_status from {{ ref('stg_uds__table7_measures') }}
),
r as (select * from {{ ref('int_uds__measure_results') }})
select reporting_year, 1 as check_order, 'Health centers reporting' as check_name,
       count(*) as value from {{ ref('stg_uds__health_centers') }} group by reporting_year
union all
select reporting_year, 2, 'Measure numerators suppressed ("--", 1-15 patients)', count_if(status = 'suppressed_1_to_15') from m group by reporting_year
union all
select reporting_year, 3, 'Numerators recovered from the published rate', count_if(numerator_was_suppressed and numerator is not null) from r group by reporting_year
union all
select reporting_year, 4, 'Measure results with no rate (not reported or zero patients)', count_if(rate is null) from r group by reporting_year
union all
select reporting_year, 5, 'Results below the minimum denominator (shown, not benchmarked)', count_if(rate is not null and not is_benchmarkable) from r group by reporting_year
union all
select reporting_year, 6, 'Benchmarkable results', count_if(is_benchmarkable) from r group by reporting_year
