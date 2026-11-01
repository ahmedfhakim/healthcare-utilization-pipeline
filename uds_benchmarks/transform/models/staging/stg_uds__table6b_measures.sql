-- UDS Table 6B, unpivoted: one row per health center x year x measure.
-- HRSA publishes each measure as three text columns (rate %, numerator #, denominator).
-- The column map below is the single place that ties HRSA's column names to a measure_id.
{% set measures = [
    ('childhood_immunization', '%ofPatientsImmunized', 'NumberofPatientsImmunized', 'TotalPatients2ndbirthdaymeasurementyear'),
    ('cervical_screening', '%ofPatientstestedPap', '#ofPatientstestedPap', 'TotalFemalePatients24-64Yearsage'),
    ('breast_screening', '%ofPatientswithMammogram', '#ofPatientswithMammogram', 'TotalFemalePatients52-74Yearsage'),
    ('colorectal_screening', '%ofAdultswithAppropriateScreeningforColorectalCancer', '#ofAdultswithAppropriateScreeningforColorectalCancer', 'TotalofAdults46-75ScreeningforColorectalCancer'),
    ('child_bmi_counseling', '%ChildrenandAdolescentswithDocumentedCounselingandBMIPercentile', '#ChildrenandAdolescentswithDocumentedCounselingandBMIPercentile', 'TotalPatientsAged3-17withCounselingandBMIPercentile'),
    ('adult_bmi_followup', '%AdultswithDocumentedBMIandFollow-upPlanIfWeightisOutsideParameters', '#AdultswithDocumentedBMIandFollow-upPlanIfWeightisOutsideParameters', 'TotalPatients18andoverwithDocumentedBMIandFollow-upPlanIfWeightisOutsideParameters'),
    ('tobacco_cessation', '%PatientsAssessedforTobaccoUseandProvidedInterventionIfaTobaccoUser', '#ofPatientsAssessedforTobaccoUseandProvidedInterventionIfaTobaccoUser', 'TotalPatients18andOlderAssessedforTobaccoUse'),
    ('statin_therapy', '%ofPatientsPrescribedOrOnStatinTherapy', '#ofPatientsPrescribedOrOnStatinTherapy', 'TotalPatients21AndOlderAtHighRiskOfCardiovascularEvents'),
    ('ivd_antiplatelet', '%ofAdults18andolderwithIVDwithDocumentationOfAspirinOrOtherAntiplateletTherapy', '#ofAdults18andolderwithIVDwithDocumentationOfAspirinOrOtherAntiplateletTherapy', 'TotalofAdults18andolderwithIVDorwithAMI,CABG,orPCIProcedure'),
    ('hiv_linkage', '%PatientsSeenWithin30DaysofFirstDiagnosisofHIV', '#ofPatientsSeenWithin30DaysofFirstDiagnosisofHIV', 'TotalPatientsFirstDiagnosedwithHIV'),
    ('hiv_screening', '%PatientsTestedforHIV', '#ofPatientsTestedforHIV', 'TotalPatientsAged15through65TestedforHIV'),
    ('depression_screening', '%PatientsScreenedforDepressionandFollowupPlanDocumentedasAppropriate', '#ofPatientsScreenedforDepressionandFollowupPlanDocumentedasAppropriate', 'TotalPatientsAged12andOlderScreenedforDepression'),
    ('depression_remission', '%PatientswhoReachedRemission', '#ofPatientswhoReachedRemission', 'TotalPatientsAged12andOlderwithMajorDepressionorDysthymia'),
    ('dental_sealants', '%PatientsAged6-9WithSealantsToFirstMolars', '#ofPatientsAged6-9WithSealantsToFirstMolars', 'TotalPatientsAged6-9withModeratetoHighRiskforCaries'),
    ('sud_initiation', '%PatientsAged13AndOlderWhoInitiatedNewSUDTreatment', '#ofPatientsAged13AndOlderWhoInitiatedNewSUDTreatment', 'TotalPatientsAged13AndOlderDiagnosedWithNewSUDEpisodeWhoInitiatedSUDTreatment'),
    ('sud_engagement', '%PatientsAged13AndOlderWhoEngagedInOngoingSUDTreatment', '#ofPatientsAged13AndOlderWhoEngagedInOngoingSUDTreatment', 'TotalPatientsAged13AndOlderWhoEngagedInOngoingSUDTreatment'),
] %}

with t6b as (
    select * from {{ source('uds', 'table6b') }}
    where trim("BHCMISID") not in ('-', '')
),

unpivoted as (
{%- for measure_id, pct, num, den in measures %}
    select
        cast(reporting_year as integer) as reporting_year,
        trim("BHCMISID")                as bhcmisid,
        '{{ measure_id }}'              as measure_id,
        "{{ pct }}"                     as rate_raw,
        "{{ num }}"                     as numerator_raw,
        "{{ den }}"                     as denominator_raw
    from t6b
    {%- if not loop.last %}
    union all
    {%- endif %}
{%- endfor %}
)

select
    reporting_year,
    bhcmisid,
    measure_id,
    {{ uds_number('denominator_raw') }}               as denominator,
    {{ uds_number('numerator_raw') }}                 as numerator,
    {{ uds_number('rate_raw') }} / 100.0              as rate,
    {{ uds_status('numerator_raw') }}                 as numerator_status,
    {{ uds_status('denominator_raw') }}               as denominator_status,
    {{ uds_status('rate_raw') }}                      as rate_status
from unpivoted
-- SUD measures start in 2025; earlier years have no such columns (NULL after union_by_name)
where rate_raw is not null or numerator_raw is not null or denominator_raw is not null
