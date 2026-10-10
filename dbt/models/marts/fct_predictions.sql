-- One row per prediction the app showed, paired with what actually happened.
-- error_minutes > 0 means the bus came LATER than the app said.
--
-- Careful: a bus's arrival time is estimated FROM its last prediction, so that
-- last prediction would always score a perfect 0 against itself. It's flagged
-- is_ground_truth and gets no error, so accuracy isn't flattered.
select
    o.polled_at,
    o.bus_stop_code,
    o.service_no,
    o.call_id,
    o.slot,
    o.eta                                                          as predicted_arrival,
    o.minutes_away,
    o.is_monitored,
    c.outcome,
    c.arrived_at,
    o.polled_at = c.last_seen_at                                   as is_ground_truth,
    case when o.polled_at < c.last_seen_at
        then round(extract(epoch from c.arrived_at - o.eta) / 60, 1)
    end                                                            as error_minutes,
    case
        when o.minutes_away < 3  then '0-3 min'
        when o.minutes_away < 6  then '3-6 min'
        when o.minutes_away < 10 then '6-10 min'
        when o.minutes_away < 15 then '10-15 min'
        else '15+ min'
    end                                                            as horizon
from {{ ref('int_bus_observations') }} o
join {{ ref('fct_bus_calls') }} c using (call_id)
