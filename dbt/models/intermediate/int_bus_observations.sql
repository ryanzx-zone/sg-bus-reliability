-- Follow each bus across polls, giving every prediction a call_id:
-- one call = one bus approaching one stop.
--
-- LTA gives no bus IDs, so we match by ETA. Between two polls a bus's ETA only
-- drifts a little. So we test three possibilities and keep the best fit:
--   shift 0: same three buses as last poll        (new slot 1 ~ old slot 1)
--   shift 1: the front bus has gone                (new slot 1 ~ old slot 2)
--   shift 2: the front two buses have gone         (new slot 1 ~ old slot 3)
-- "Best fit" = smallest average gap in seconds between matched ETAs.
--
-- A long gap between polls (data outage, or service ended for the night) breaks
-- the chain: we start a new "session" rather than guess across the gap.
{{ config(materialized='table') }}

{% set max_poll_gap = "interval '7 minutes'" %}

with polls as (
    select * from {{ ref('int_bus_polls') }}
),

diffs as (
    select
        *,
        abs(extract(epoch from eta_1 - prev_eta_1)) as d11,
        abs(extract(epoch from eta_2 - prev_eta_2)) as d22,
        abs(extract(epoch from eta_3 - prev_eta_3)) as d33,
        abs(extract(epoch from eta_1 - prev_eta_2)) as d12,
        abs(extract(epoch from eta_2 - prev_eta_3)) as d23,
        abs(extract(epoch from eta_1 - prev_eta_3)) as d13
    from polls
),

costs as (
    select
        *,
        (coalesce(d11, 0) + coalesce(d22, 0) + coalesce(d33, 0))
            / nullif((d11 is not null)::int + (d22 is not null)::int + (d33 is not null)::int, 0) as cost_0,
        (coalesce(d12, 0) + coalesce(d23, 0))
            / nullif((d12 is not null)::int + (d23 is not null)::int, 0)                          as cost_1,
        d13                                                                                         as cost_2
    from diffs
),

shifts as (
    select
        *,
        case
            when cost_0 is not null and cost_0 <= coalesce(cost_1, 1e9) and cost_0 <= coalesce(cost_2, 1e9) then 0
            when cost_1 is not null and cost_1 <= coalesce(cost_2, 1e9) then 1
            when cost_2 is not null then 2
        end as shift
    from costs
),

sessions as (
    select
        *,
        (prev_polled_at is null
            or polled_at - prev_polled_at > {{ max_poll_gap }}
            or shift is null) as starts_session
    from shifts
),

numbered as (
    select
        *,
        sum(starts_session::int) over (
            partition by bus_stop_code, service_no order by polled_at
        ) as session_no
    from sessions
),

indexed as (
    select
        *,
        -- How many buses have left the front of the queue since the session began
        sum(case when starts_session then 0 else shift end) over (
            partition by bus_stop_code, service_no, session_no order by polled_at
        ) as buses_gone,
        -- The next poll in the same session, if any (used to decide arrived vs vanished)
        case when next_polled_at - polled_at <= {{ max_poll_gap }} then next_polled_at end as next_poll_in_session
    from numbered
)

-- Unpivot back to one row per prediction, now with a stable call_id
select
    i.bus_stop_code,
    i.service_no,
    i.session_no,
    i.buses_gone + s.slot                                                  as bus_index,
    i.bus_stop_code || '|' || i.service_no || '|' || i.session_no || '|' || (i.buses_gone + s.slot)
                                                                           as call_id,
    i.polled_at,
    s.slot,
    s.eta,
    s.gps                                                                  as is_monitored,
    round(extract(epoch from s.eta - i.polled_at) / 60, 1)                as minutes_away,
    i.next_poll_in_session
from indexed i
cross join lateral (
    values (1, i.eta_1, i.gps_1), (2, i.eta_2, i.gps_2), (3, i.eta_3, i.gps_3)
) as s(slot, eta, gps)
where s.eta is not null
