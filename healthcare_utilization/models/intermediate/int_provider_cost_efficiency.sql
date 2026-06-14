-- Grain: one row per provider (NPI)
-- Compares each provider's cost per service against their specialty average
-- Used by mart_provider_outliers to surface high-cost outliers

with providers as (
    select * from {{ ref('stg_cms_provider_payments') }}
),

specialty_avg as (
    select
        specialty,
        avg(avg_payment_per_service)                          as specialty_avg_payment_per_service,
        avg(avg_risk_score)                                   as specialty_avg_risk_score
    from providers
    where specialty is not null
    group by specialty
)

select
    p.provider_npi,
    p.provider_name,
    p.specialty,
    p.provider_state,
    p.total_services,
    p.total_beneficiaries,
    p.total_medicare_payment,
    p.avg_payment_per_service,
    p.avg_risk_score,
    s.specialty_avg_payment_per_service,
    s.specialty_avg_risk_score,

    -- how far this provider's cost deviates from specialty average
    round(
        (p.avg_payment_per_service - s.specialty_avg_payment_per_service)
        / nullif(s.specialty_avg_payment_per_service, 0) * 100,
    1)                                                        as pct_above_specialty_avg,

    -- risk-adjusted: is this provider seeing sicker patients than peers?
    round(
        (p.avg_risk_score - s.specialty_avg_risk_score)
        / nullif(s.specialty_avg_risk_score, 0) * 100,
    1)                                                        as pct_risk_above_specialty_avg

from providers p
left join specialty_avg s using (specialty)
where p.specialty is not null
    and p.total_services >= 20  -- exclude low-volume providers from outlier analysis
