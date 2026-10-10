-- One row per bus call: one bus approaching one stop, followed across polls.
--
-- What happened to it is decided by its LAST sighting:
--   arrived   its final ETA was before the next poll, so it reached the stop then disappeared.
--             Arrival time ~ that final ETA (most accurate prediction we have).
--   vanished  it disappeared while still predicted to be minutes away: a "ghost bus".
--   unknown   the data stops after its last sighting (outage, or end of service), can't tell.
{% set arrival_tolerance = "interval '1 minute'" %}

with calls as (
    select
        call_id,
        bus_stop_code,
        service_no,
        session_no,
        bus_index,
        min(polled_at)                                        as first_seen_at,
        max(polled_at)                                        as last_seen_at,
        count(*)                                              as n_sightings,
        (array_agg(eta order by polled_at desc))[1]           as last_eta,
        (array_agg(is_monitored order by polled_at desc))[1]  as last_was_gps,
        (array_agg(minutes_away order by polled_at desc))[1]  as last_minutes_away,
        (array_agg(next_poll_in_session order by polled_at desc))[1] as next_poll_after_last
    from {{ ref('int_bus_observations') }}
    group by 1, 2, 3, 4, 5
)

select
    *,
    case
        when next_poll_after_last is null                                 then 'unknown'
        when last_eta <= next_poll_after_last + {{ arrival_tolerance }}   then 'arrived'
        else 'vanished'
    end as outcome,
    case
        when next_poll_after_last is not null
         and last_eta <= next_poll_after_last + {{ arrival_tolerance }}   then last_eta
    end as arrived_at
from calls
