{{
    config(materialized='table')
}}

-- Grain: one row per specialty
-- Business question: which specialties cost Medicare the most, and which
-- treat the sickest patient populations?

with specialties as (
    select * from {{ ref('int_specialty_benchmarks') }}
)

select
    date('2024-12-31')                                       as as_of_date,
    specialty,
    provider_count,
    total_services,
    total_beneficiaries,
    total_medicare_payment,
    total_submitted_charge,
    avg_payment_per_service,
    weighted_avg_payment_per_service,
    avg_payment_to_charge_pct,
    avg_patient_risk_score,
    avg_pct_diabetes,
    avg_pct_hypertension,
    avg_pct_heart_failure,
    avg_pct_kidney_disease,

    -- rankings
    rank() over (
        order by weighted_avg_payment_per_service desc
    )                                                         as cost_rank,

    rank() over (
        order by total_medicare_payment desc
    )                                                         as total_spend_rank,

    rank() over (
        order by avg_patient_risk_score desc
    )                                                         as patient_acuity_rank,

    -- cost tier segmentation
    case
        when weighted_avg_payment_per_service >= 200  then 'High Cost'
        when weighted_avg_payment_per_service >= 75   then 'Mid Cost'
        else 'Low Cost'
    end                                                       as cost_tier,

    -- pct of total Medicare spend in this dataset
    round(
        total_medicare_payment * 100.0
        / nullif(sum(total_medicare_payment) over (), 0),
    2)                                                        as pct_of_total_spend

from specialties
