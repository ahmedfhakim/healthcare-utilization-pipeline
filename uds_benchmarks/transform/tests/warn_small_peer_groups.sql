-- A peer median from very few centers isn't a stable benchmark.
{{ config(severity='warn') }}
select reporting_year, peer_group, count(*) as centers
from {{ ref('int_uds__peer_groups') }}
group by 1, 2 having count(*) < 20
