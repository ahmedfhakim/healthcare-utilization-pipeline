select * from {{ ref('int_uds__measure_results') }}
where rate < 0 or rate > 1
