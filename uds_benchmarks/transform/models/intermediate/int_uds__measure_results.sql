-- Every quality measure for every health center and year, with who the center serves.
with results as (
    select reporting_year, bhcmisid, measure_id, denominator, numerator, rate, numerator_status
    from {{ ref('stg_uds__table6b_measures') }}
    union all
    select reporting_year, bhcmisid, measure_id, denominator, numerator, rate, numerator_status
    from {{ ref('stg_uds__table7_measures') }}
)
select
    r.reporting_year,
    r.bhcmisid,
    h.health_center_name,
    h.city,
    h.state,
    h.urban_rural,
    pg.peer_group,
    pm.total_patients,
    pm.pct_uninsured,
    pm.pct_medicaid_chip,
    r.measure_id,
    m.short_name,
    m.domain,
    m.higher_is_better,
    r.denominator,
    -- when HRSA suppresses a small numerator ("--"), recover it from the published rate
    coalesce(r.numerator, r.rate * r.denominator)                      as numerator,
    r.rate,
    r.numerator_status = 'suppressed_1_to_15'                          as numerator_was_suppressed,
    coalesce(r.rate is not null and r.denominator >= {{ var('min_denominator') }}, false) as is_benchmarkable
from results r
join {{ ref('uds_measures') }} m             on m.measure_id = r.measure_id
join {{ ref('stg_uds__health_centers') }} h  on h.reporting_year = r.reporting_year and h.bhcmisid = r.bhcmisid
left join {{ ref('stg_uds__patient_mix') }} pm  on pm.reporting_year = r.reporting_year and pm.bhcmisid = r.bhcmisid
left join {{ ref('int_uds__peer_groups') }} pg  on pg.reporting_year = r.reporting_year and pg.bhcmisid = r.bhcmisid
