-- Grain: reporting year x measure x uninsured quintile.
-- Do health centers that serve more uninsured patients score lower? Centers are split into
-- fifths by their share of uninsured patients (1 = fewest uninsured), and each fifth's
-- patients are pooled.
with q as (
    select *,
           ntile(5) over (partition by reporting_year, measure_id order by pct_uninsured) as uninsured_quintile
    from {{ ref('int_uds__measure_results') }}
    where rate is not null and denominator > 0 and pct_uninsured is not null
)
select
    reporting_year, measure_id, short_name, higher_is_better, uninsured_quintile,
    min(pct_uninsured)                                         as min_pct_uninsured,
    max(pct_uninsured)                                         as max_pct_uninsured,
    count(*)                                                   as centers,
    sum(numerator) / nullif(sum(denominator), 0)               as weighted_rate
from q
group by reporting_year, measure_id, short_name, higher_is_better, uninsured_quintile
