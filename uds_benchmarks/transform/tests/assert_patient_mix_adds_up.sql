-- Insurance categories (Table 4 lines 7-11) must add up to total patients. Each suppressed
-- cell ("--") hides 1-15 patients and is counted as 0, so the shortfall can be at most
-- 15 x the number of suppressed cells, and never negative.
select reporting_year, bhcmisid, total_patients, suppressed_insurance_cells,
       uninsured + medicaid_chip + medicare + other_public + private_insurance as insurance_sum
from {{ ref('stg_uds__patient_mix') }}
where total_patients > 0
  and (total_patients - (uninsured + medicaid_chip + medicare + other_public + private_insurance)) not between 0 and 15 * suppressed_insurance_cells
