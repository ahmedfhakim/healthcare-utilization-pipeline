{{
    config(materialized='table')
}}

-- Grain: one row per provider (NPI), filtered to meaningful volume
-- Business question: which providers cost significantly more or less than
-- their specialty peers, after accounting for patient risk?

with efficiency as (
    select * from {{ ref('int_provider_cost_efficiency') }}
)

select
    provider_npi,
    provider_name,
    specialty,
    provider_state,
    total_services,
    total_beneficiaries,
    total_medicare_payment,
    avg_payment_per_service,
    avg_risk_score,
    specialty_avg_payment_per_service,
    pct_above_specialty_avg,
    pct_risk_above_specialty_avg,

    case
        when pct_above_specialty_avg >= 50
             and pct_risk_above_specialty_avg < 20
            then 'High Cost - Not Risk Justified'
        when pct_above_specialty_avg >= 50
             and pct_risk_above_specialty_avg >= 20
            then 'High Cost - Risk Justified'
        when pct_above_specialty_avg <= -50
            then 'Low Cost Outlier'
        else 'Within Normal Range'
    end                                                       as outlier_category

from efficiency
