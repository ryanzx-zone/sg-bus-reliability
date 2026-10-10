-- My two routes each way between home and NUS, one row per (trip, route, leg, service),
-- enriched from LTA's route data: where I board and alight, and how far I ride.
with legs as (
    select * from {{ ref('my_commute') }}
)

select
    l.trip,
    l.route,
    l.leg,
    l.service_no,
    l.direction,
    l.board_stop,
    b.stop_name                         as board_stop_name,
    l.alight_stop,
    a.stop_name                         as alight_stop_name,
    b.stop_sequence                     as board_sequence,
    a.stop_sequence                     as alight_sequence,
    a.stop_sequence - b.stop_sequence   as n_stops,
    a.distance_km - b.distance_km       as ride_km,
    b.am_peak_freq_min,
    b.am_peak_freq_max
from legs l
left join {{ ref('dim_routes') }} b
    on b.service_no = l.service_no and b.direction = l.direction and b.bus_stop_code = l.board_stop
left join {{ ref('dim_routes') }} a
    on a.service_no = l.service_no and a.direction = l.direction and a.bus_stop_code = l.alight_stop
