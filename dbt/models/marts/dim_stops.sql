-- One row per bus stop, with how many services call there
-- and whether we're polling it.
with services_per_stop as (
    select bus_stop_code, count(distinct service_no) as n_services
    from {{ ref('stg_bus_routes') }}
    group by 1
),

tracked as (
    select distinct bus_stop_code
    from {{ ref('stg_arrivals') }}
    where polled_at > now() - interval '1 day'
)

select
    s.bus_stop_code,
    s.stop_name,
    s.road_name,
    s.latitude,
    s.longitude,
    coalesce(sp.n_services, 0)        as n_services,
    t.bus_stop_code is not null       as is_tracked
from {{ ref('stg_bus_stops') }} s
left join services_per_stop sp using (bus_stop_code)
left join tracked t using (bus_stop_code)
