-- Grain: one row per specialty
-- Aggregates provider-level payment data to specialty level
-- Used by mart_specialty_cost_benchmarks for ranking and comparison

with providers as (
    select * from {{ ref('stg_cms_provider_payments') }}
)

select
    specialty,
    count(distinct provider_npi)                              as provider_count,
    sum(total_services)                                       as total_services,
    sum(total_beneficiaries)                                  as total_beneficiaries,
    sum(total_medicare_payment)                               as total_medicare_payment,
    sum(total_submitted_charge)                               as total_submitted_charge,

    round(avg(avg_payment_per_service), 2)                    as avg_payment_per_service,
    round(avg(payment_to_charge_pct), 2)                      as avg_payment_to_charge_pct,
    round(avg(avg_risk_score), 3)                             as avg_patient_risk_score,

    -- weighted average payment per service (weighted by volume)
    round(
        sum(total_medicare_payment)
        / nullif(sum(total_services), 0),
    2)                                                        as weighted_avg_payment_per_service,

    -- average chronic condition prevalence across providers in this specialty
    round(avg(pct_diabetes), 1)                               as avg_pct_diabetes,
    round(avg(pct_hypertension), 1)                           as avg_pct_hypertension,
    round(avg(pct_heart_failure), 1)                          as avg_pct_heart_failure,
    round(avg(pct_kidney_disease), 1)                         as avg_pct_kidney_disease

from providers
where specialty is not null
group by specialty
