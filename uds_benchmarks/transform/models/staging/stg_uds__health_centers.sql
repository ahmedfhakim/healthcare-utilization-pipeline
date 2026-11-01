-- One row per health center per reporting year.
select
    cast(reporting_year as integer)                                   as reporting_year,
    trim("BHCMISID")                                                  as bhcmisid,
    trim("GrantNumber")                                               as grant_number,
    trim("HealthCenterName")                                          as health_center_name,
    trim("HealthCenterCity")                                          as city,
    upper(trim("HealthCenterState"))                                  as state,
    left(trim("HealthCenterZIPCode"), 5)                              as zip5,
    nullif(trim("UrbanRuralFlag"), '-')                               as urban_rural,
    upper("FundingCHC") = 'TRUE'                                      as funded_community_health_center,
    -- HRSA renamed these flags in 2025: homeless HO -> HP, migrant MHC -> MSAW, public housing PH -> RPH
    upper(coalesce("FundingHP", "FundingHO")) = 'TRUE'                as funded_homeless,
    upper(coalesce("FundingMSAW", "FundingMHC")) = 'TRUE'             as funded_agricultural_workers,
    upper(coalesce("FundingRPH", "FundingPH")) = 'TRUE'               as funded_public_housing
from {{ source('uds', 'health_centers') }}
where trim("BHCMISID") not in ('-', '')
