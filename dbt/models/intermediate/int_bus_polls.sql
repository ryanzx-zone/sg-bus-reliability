-- One row per (stop, service, poll): the three predicted buses side by side,
-- next to the previous poll's three predictions for the same stop and service.
-- This is the input for matching "which bus is which" across polls.
with pivoted as (
    select
        bus_stop_code,
        service_no,
        polled_at,
        max(estimated_arrival) filter (where slot = 1) as eta_1,
        max(estimated_arrival) filter (where slot = 2) as eta_2,
        max(estimated_arrival) filter (where slot = 3) as eta_3,
        bool_or(is_monitored) filter (where slot = 1)  as gps_1,
        bool_or(is_monitored) filter (where slot = 2)  as gps_2,
        bool_or(is_monitored) filter (where slot = 3)  as gps_3
    from {{ ref('stg_arrivals') }}
    group by 1, 2, 3
)

select
    *,
    lag(polled_at) over w  as prev_polled_at,
    lead(polled_at) over w as next_polled_at,
    lag(eta_1) over w      as prev_eta_1,
    lag(eta_2) over w      as prev_eta_2,
    lag(eta_3) over w      as prev_eta_3
from pivoted
window w as (partition by bus_stop_code, service_no order by polled_at)
