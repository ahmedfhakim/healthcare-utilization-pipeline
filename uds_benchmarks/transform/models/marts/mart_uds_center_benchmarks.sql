-- Grain: health center x reporting year x measure.
-- How each health center compares with the nation, its state and its peer group, with
-- "patients to peer median": how many more patients would need to meet the measure (or,
-- for the inverse diabetes measure, leave the numerator) to reach the peer group's median.
with r as (
    select * from {{ ref('int_uds__measure_results') }}
),
bench as (
    select * from r where is_benchmarkable
),
national as (
    select reporting_year, measure_id,
           median(rate)              as national_median,
           count(*)                  as national_centers
    from bench group by reporting_year, measure_id
),
state as (
    select reporting_year, state, measure_id,
           median(rate)              as state_median,
           count(*)                  as state_centers
    from bench group by reporting_year, state, measure_id
),
peer as (
    select reporting_year, peer_group, measure_id,
           median(rate)                    as peer_median,
           quantile_cont(rate, 0.25)       as peer_p25,
           quantile_cont(rate, 0.75)       as peer_p75,
           count(*)                        as peer_centers
    from bench group by reporting_year, peer_group, measure_id
),
ranked as (
    select
        bhcmisid, reporting_year, measure_id,
        -- 100 = best in the nation, whichever direction "better" is for the measure
        round(100 * percent_rank() over (
            partition by reporting_year, measure_id
            order by case when higher_is_better then rate else -rate end), 1) as national_percentile
    from bench
)
select
    r.*,
    n.national_median,
    s.state_median,
    p.peer_median,
    p.peer_p25,
    p.peer_p75,
    p.peer_centers,
    k.national_percentile,
    -- positive = better than peers, in percentage points
    round(100 * (r.rate - p.peer_median) * case when r.higher_is_better then 1 else -1 end, 1) as points_vs_peer_median,
    case
        when not r.is_benchmarkable then 'Too few patients to benchmark'
        when (r.higher_is_better and r.rate >= p.peer_p75) or (not r.higher_is_better and r.rate <= p.peer_p25) then 'Top quarter of peers'
        when (r.higher_is_better and r.rate >= p.peer_median) or (not r.higher_is_better and r.rate <= p.peer_median) then 'Above peer median'
        when (r.higher_is_better and r.rate > p.peer_p25) or (not r.higher_is_better and r.rate < p.peer_p75) then 'Below peer median'
        else 'Bottom quarter of peers'
    end                                                                as peer_band,
    case
        when r.is_benchmarkable and ((r.higher_is_better and r.rate < p.peer_median) or (not r.higher_is_better and r.rate > p.peer_median))
            then cast(ceil(abs(p.peer_median - r.rate) * r.denominator) as integer)
        else 0
    end                                                                as patients_to_peer_median
from r
left join national n on n.reporting_year = r.reporting_year and n.measure_id = r.measure_id
left join state s    on s.reporting_year = r.reporting_year and s.state = r.state and s.measure_id = r.measure_id
left join peer p     on p.reporting_year = r.reporting_year and p.peer_group = r.peer_group and p.measure_id = r.measure_id
left join ranked k   on k.reporting_year = r.reporting_year and k.bhcmisid = r.bhcmisid and k.measure_id = r.measure_id
