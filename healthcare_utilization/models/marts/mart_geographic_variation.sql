{{
    config(materialized='table')
}}

-- Grain: one row per state per year
-- Business question: how does Medicare spending and utilization vary by geography?
-- standardized_payment controls for regional cost-of-care differences;
-- actual payment reflects what Medicare truly spent including local prices

with geo as (
    select * from {{ ref('stg_cms_geographic') }}
),

national_avg as (
    select
        year,
        avg(payment_per_capita)                               as national_avg_payment,
        avg(standardized_payment_per_capita)                  as national_avg_standardized,
        avg(er_visits_per_1000)                               as national_avg_er_visits,
        avg(readmission_rate)                                 as national_avg_readmission_rate
    from geo
    group by year
)

select
    g.state_name,
    g.state_code,
    g.year,
    g.total_beneficiaries,
    g.payment_per_capita,
    g.standardized_payment_per_capita,
    g.inpatient_payment_per_capita,
    g.outpatient_payment_per_capita,
    g.er_visits_per_1000,
    g.readmission_rate,
    g.pct_with_inpatient_stay,
    n.national_avg_payment,
    n.national_avg_standardized,

    -- variance from national average (using standardized payment, the fairer comparison)
    round(g.standardized_payment_per_capita - n.national_avg_standardized, 2)
                                                              as standardized_payment_vs_national,

    round(
        (g.standardized_payment_per_capita - n.national_avg_standardized)
        / nullif(n.national_avg_standardized, 0) * 100,
    2)                                                        as pct_vs_national_avg,

    -- spend category
    case
        when g.standardized_payment_per_capita > n.national_avg_standardized * 1.1 then 'High Spend'
        when g.standardized_payment_per_capita < n.national_avg_standardized * 0.9 then 'Low Spend'
        else 'Near Average'
    end                                                       as spend_category

from geo g
left join national_avg n using (year)
