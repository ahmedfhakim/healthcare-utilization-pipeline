-- Grain: one row per provider (NPI)
-- Source: CMS Medicare Physician & Other Practitioners by Provider, 2024
-- Note: totals are aggregated across all procedures performed by this provider
-- safe_cast handles suppressed/blank values in CMS data (privacy suppression for small counts)

with source as (
    select * from {{ source('healthcare_raw', 'cms_provider_payments') }}
),

renamed as (
    select
        -- identifiers
        cast(Rndrng_NPI as string)                            as provider_npi,
        cast(Rndrng_Prvdr_Last_Org_Name as string)            as provider_name,
        cast(Rndrng_Prvdr_Type as string)                     as specialty,
        cast(Rndrng_Prvdr_State_Abrvtn as string)             as provider_state,
        cast(Rndrng_Prvdr_City as string)                     as provider_city,
        cast(Rndrng_Prvdr_Mdcr_Prtcptg_Ind as string)         as medicare_participating,

        -- volume
        safe_cast(Tot_HCPCS_Cds as numeric)                   as total_procedure_codes,
        safe_cast(Tot_Benes as numeric)                       as total_beneficiaries,
        safe_cast(Tot_Srvcs as numeric)                       as total_services,

        -- payment amounts (aggregated across all services)
        safe_cast(Tot_Sbmtd_Chrg as numeric)                  as total_submitted_charge,
        safe_cast(Tot_Mdcr_Alowd_Amt as numeric)              as total_medicare_allowed,
        safe_cast(Tot_Mdcr_Pymt_Amt as numeric)               as total_medicare_payment,
        safe_cast(Tot_Mdcr_Stdzd_Amt as numeric)              as total_medicare_standardized,

        -- beneficiary population characteristics
        safe_cast(Bene_Avg_Age as numeric)                    as avg_patient_age,
        safe_cast(Bene_Avg_Risk_Scre as numeric)              as avg_risk_score,
        safe_cast(Bene_Dual_Cnt as numeric)                   as dual_eligible_count,

        -- chronic condition prevalence
        safe_cast(Bene_CC_PH_Diabetes_V2_Pct as numeric)      as pct_diabetes,
        safe_cast(Bene_CC_PH_Hypertension_V2_Pct as numeric)  as pct_hypertension,
        safe_cast(Bene_CC_PH_CKD_V2_Pct as numeric)           as pct_kidney_disease,
        safe_cast(Bene_CC_PH_COPD_V2_Pct as numeric)          as pct_copd,
        safe_cast(Bene_CC_PH_HF_NonIHD_V2_Pct as numeric)     as pct_heart_failure,
        safe_cast(Bene_CC_BH_Depress_V1_Pct as numeric)       as pct_depression,

        -- derived metrics
        round(
            safe_cast(Tot_Mdcr_Pymt_Amt as numeric)
            / nullif(safe_cast(Tot_Srvcs as numeric), 0),
        2)                                                    as avg_payment_per_service,

        round(
            safe_cast(Tot_Mdcr_Pymt_Amt as numeric)
            / nullif(safe_cast(Tot_Sbmtd_Chrg as numeric), 0) * 100,
        2)                                                    as payment_to_charge_pct

    from source
    where Rndrng_NPI is not null
        and Tot_Mdcr_Pymt_Amt is not null
)

select * from renamed
-- CI validation test
