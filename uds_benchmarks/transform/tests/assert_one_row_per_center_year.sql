select reporting_year, bhcmisid, count(*) from {{ ref('stg_uds__health_centers') }}
group by 1, 2 having count(*) > 1
