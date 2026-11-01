-- UDS Table 7 line i (all patients): hypertension (section B) and diabetes (section C).
-- Column codes: 2a / 3a = patients with the condition, 2b / 3b = charts reviewed (a sample,
-- or every patient for EHR-based reporting), 2c = blood pressure controlled, 3f = HbA1c > 9%.
-- The rate is numerator / charts reviewed, the way HRSA calculates it.
with t7 as (
    select * from {{ source('uds', 'table7_totals') }}
    where trim("BHCMISID") not in ('-', '')
)
select
    cast(reporting_year as integer)       as reporting_year,
    trim("BHCMISID")                      as bhcmisid,
    'hypertension_control'                as measure_id,
    {{ uds_number('"T7_Li_C2b"') }}       as denominator,
    {{ uds_number('"T7_Li_C2c"') }}       as numerator,
    {{ uds_number('"T7_Li_C2c"') }} / nullif({{ uds_number('"T7_Li_C2b"') }}, 0) as rate,
    {{ uds_status('"T7_Li_C2c"') }}       as numerator_status,
    {{ uds_status('"T7_Li_C2b"') }}       as denominator_status,
    {{ uds_number('"T7_Li_C2a"') }}       as patients_with_condition
from t7
union all
select
    cast(reporting_year as integer),
    trim("BHCMISID"),
    'diabetes_poor_control',
    {{ uds_number('"T7_Li_C3b"') }},
    {{ uds_number('"T7_Li_C3f"') }},
    {{ uds_number('"T7_Li_C3f"') }} / nullif({{ uds_number('"T7_Li_C3b"') }}, 0),
    {{ uds_status('"T7_Li_C3f"') }},
    {{ uds_status('"T7_Li_C3b"') }},
    {{ uds_number('"T7_Li_C3a"') }}
from t7
