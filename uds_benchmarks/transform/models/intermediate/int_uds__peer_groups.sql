-- Peer groups: health centers that serve similar populations, so a center is compared with
-- centers that face similar barriers rather than with every center in the country.
-- Three dimensions, each defined within its own reporting year:
--   location   urban / rural (HRSA's flag)
--   uninsured  national tercile of the share of patients with no insurance
--   size       total patients: under 10k, 10k-30k, 30k+ for urban centers; under 10k and
--              10k+ for rural ones (only ~15 rural centers a year have 30k+ patients and many
--              uninsured, too few for a stable peer median)
with mix as (
    select
        p.reporting_year, p.bhcmisid, p.total_patients, p.pct_uninsured,
        h.urban_rural,
        ntile(3) over (partition by p.reporting_year order by p.pct_uninsured) as uninsured_tercile
    from {{ ref('stg_uds__patient_mix') }} p
    join {{ ref('stg_uds__health_centers') }} h
      on h.reporting_year = p.reporting_year and h.bhcmisid = p.bhcmisid
    where p.total_patients > 0
)
select
    reporting_year,
    bhcmisid,
    urban_rural,
    case uninsured_tercile when 1 then 'low uninsured' when 2 then 'mid uninsured' else 'high uninsured' end as uninsured_band,
    case when total_patients < 10000 then 'under 10k patients'
         when urban_rural = 'Rural' then '10k+ patients'
         when total_patients < 30000 then '10k-30k patients'
         else '30k+ patients' end                                     as size_band,
    urban_rural || ' · '
      || case uninsured_tercile when 1 then 'low uninsured' when 2 then 'mid uninsured' else 'high uninsured' end
      || ' · '
      || case when total_patients < 10000 then 'under 10k patients'
              when urban_rural = 'Rural' then '10k+ patients'
              when total_patients < 30000 then '10k-30k patients'
              else '30k+ patients' end                                as peer_group
from mix
