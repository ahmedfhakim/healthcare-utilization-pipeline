-- Grain: state x reporting year x measure. "Patient-weighted" = all patients in the state's
-- health centers pooled together (sum of numerators / sum of denominators), the way HRSA
-- reports national rates. The median center rate is shown alongside it.
select
    reporting_year, state, measure_id, short_name, higher_is_better,
    count(*)                                                   as centers,
    sum(denominator)                                           as patients_in_measure,
    sum(numerator) / nullif(sum(denominator), 0)               as weighted_rate,
    median(rate)                                               as median_center_rate
from {{ ref('int_uds__measure_results') }}
where rate is not null and denominator > 0
group by reporting_year, state, measure_id, short_name, higher_is_better
