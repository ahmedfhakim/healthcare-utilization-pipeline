-- HRSA's published rate should equal numerator / denominator when neither is suppressed.
{{ config(severity='warn') }}
select reporting_year, bhcmisid, measure_id, numerator, denominator, rate
from {{ ref('stg_uds__table6b_measures') }}
where numerator_status = 'reported' and denominator_status = 'reported'
  and denominator > 0 and rate is not null
  and abs(rate - numerator / denominator) > 0.001
