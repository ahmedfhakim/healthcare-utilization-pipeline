-- UDS Table 4: who each health center serves, by income and insurance.
-- Column codes are T4_L<line>_C<column>: column a = ages 0-17, b = 18 and older.
-- Small counts (1-15) are suppressed as "--" and treated as 0 here. For a typical center
-- (median ~15,000 patients) that moves a percentage by a fraction of a point; for the
-- smallest centers it can move it by several points. suppressed_insurance_cells records how
-- many insurance counts were suppressed, so that uncertainty is visible.
with t4 as (
    select * from {{ source('uds', 'table4') }}
    where trim("BHCMISID") not in ('-', '')
),
n as (
    select
        cast(reporting_year as integer) as reporting_year,
        trim("BHCMISID")                as bhcmisid,
        {{ uds_number('"T4_L6_Ca"') }}  as total_patients,
        coalesce({{ uds_number('"T4_L1_Ca"') }}, 0) as income_0_100_fpl,
        coalesce({{ uds_number('"T4_L2_Ca"') }}, 0) as income_101_150_fpl,
        coalesce({{ uds_number('"T4_L3_Ca"') }}, 0) as income_151_200_fpl,
        coalesce({{ uds_number('"T4_L4_Ca"') }}, 0) as income_over_200_fpl,
        coalesce({{ uds_number('"T4_L7_Ca"') }}, 0)  + coalesce({{ uds_number('"T4_L7_Cb"') }}, 0)  as uninsured,
        coalesce({{ uds_number('"T4_L8_Ca"') }}, 0)  + coalesce({{ uds_number('"T4_L8_Cb"') }}, 0)  as medicaid_chip,
        coalesce({{ uds_number('"T4_L9_Ca"') }}, 0)  + coalesce({{ uds_number('"T4_L9_Cb"') }}, 0)  as medicare,
        coalesce({{ uds_number('"T4_L10_Ca"') }}, 0) + coalesce({{ uds_number('"T4_L10_Cb"') }}, 0) as other_public,
        coalesce({{ uds_number('"T4_L11_Ca"') }}, 0) + coalesce({{ uds_number('"T4_L11_Cb"') }}, 0) as private_insurance,
        0
        {%- for line in ['7', '8', '9', '10', '11'] %}{% for col in ['a', 'b'] %}
        + case when {{ uds_status('"T4_L' ~ line ~ '_C' ~ col ~ '"') }} = 'suppressed_1_to_15' then 1 else 0 end
        {%- endfor %}{% endfor %}                                  as suppressed_insurance_cells
    from t4
)
select
    *,
    uninsured         / nullif(total_patients, 0)                    as pct_uninsured,
    medicaid_chip     / nullif(total_patients, 0)                    as pct_medicaid_chip,
    medicare          / nullif(total_patients, 0)                    as pct_medicare,
    private_insurance / nullif(total_patients, 0)                    as pct_private,
    -- share at or below the poverty line, among patients whose income is known
    income_0_100_fpl / nullif(income_0_100_fpl + income_101_150_fpl + income_151_200_fpl + income_over_200_fpl, 0)
                                                                     as pct_at_or_below_poverty
from n
