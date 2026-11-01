-- Grain: reporting year x measure. National patient-weighted rate and median center rate.
select
    reporting_year, measure_id, short_name, domain, higher_is_better,
    count(*)                                                   as centers,
    sum(denominator)                                           as patients_in_measure,
    sum(numerator) / nullif(sum(denominator), 0)               as weighted_rate,
    median(rate)                                               as median_center_rate
from {{ ref('int_uds__measure_results') }}
where rate is not null and denominator > 0
group by reporting_year, measure_id, short_name, domain, higher_is_better
