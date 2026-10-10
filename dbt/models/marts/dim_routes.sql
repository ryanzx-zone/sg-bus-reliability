-- One row per stop on each service's route, with stop names
-- and the service's scheduled frequencies attached.
select
    r.service_no,
    r.direction,
    r.stop_sequence,
    r.bus_stop_code,
    s.stop_name,
    s.road_name,
    r.distance_km,
    r.operator,
    sv.category,
    sv.am_peak_freq_min,
    sv.am_peak_freq_max,
    sv.pm_peak_freq_min,
    sv.pm_peak_freq_max
from {{ ref('stg_bus_routes') }} r
left join {{ ref('stg_bus_stops') }} s using (bus_stop_code)
left join {{ ref('stg_bus_services') }} sv using (service_no, direction)
