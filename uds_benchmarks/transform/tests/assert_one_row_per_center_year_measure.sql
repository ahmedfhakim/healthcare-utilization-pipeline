select reporting_year, bhcmisid, measure_id, count(*) from {{ ref('mart_uds_center_benchmarks') }}
group by 1, 2, 3 having count(*) > 1
