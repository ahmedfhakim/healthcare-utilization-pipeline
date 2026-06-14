-- Grain: one row per state per year
-- Source: CMS Medicare Geographic Variation, 2014-2024
-- State-level Medicare spending and utilization
-- Note: CMS suppresses values for small geographies (e.g. territories) with '*'
--       safe_cast converts these to null, and we filter them out below

with source as (
    select * from {{ source('healthcare_raw', 'cms_geographic_variation') }}
),

renamed as (
    select
        -- geography and time
        cast(BENE_GEO_DESC as string)                         as state_name,
        cast(BENE_GEO_CD as string)                           as state_code,
        cast(YEAR as integer)                                 as year,

        -- population
        safe_cast(BENES_TOTAL_CNT as integer)                 as total_beneficiaries,
        safe_cast(BENE_AVG_AGE as numeric)                    as avg_beneficiary_age,
        safe_cast(BENE_DUAL_PCT as numeric)                   as pct_dual_eligible,
        safe_cast(MA_PRTCPTN_RATE as numeric)                 as ma_participation_rate,

        -- spending per capita
        safe_cast(TOT_MDCR_PYMT_PC as numeric)                as payment_per_capita,
        safe_cast(TOT_MDCR_STDZD_PYMT_PC as numeric)          as standardized_payment_per_capita,
        safe_cast(IP_MDCR_PYMT_PC as numeric)                 as inpatient_payment_per_capita,
        safe_cast(IP_MDCR_STDZD_PYMT_PC as numeric)           as inpatient_standardized_per_capita,
        safe_cast(OP_MDCR_PYMT_PC as numeric)                 as outpatient_payment_per_capita,
        safe_cast(OP_MDCR_STDZD_PYMT_PC as numeric)           as outpatient_standardized_per_capita,

        -- utilization and quality
        safe_cast(ER_VISITS_PER_1000_BENES as numeric)        as er_visits_per_1000,
        safe_cast(ACUTE_HOSP_READMSN_PCT as numeric)          as readmission_rate,
        safe_cast(BENES_IP_PCT as numeric)                    as pct_with_inpatient_stay

    from source
    where BENE_GEO_CD is not null
        and BENE_GEO_DESC != 'National'
)

select * from renamed
where payment_per_capita is not null
