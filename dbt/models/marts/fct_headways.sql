-- One row per bus that arrived: the real gap since the previous bus of the same
-- service at the same stop, next to the gap LTA's timetable promises.
-- Only measured within a session, so a data outage never shows up as a fake long gap.
with arrivals as (
    select
        bus_stop_code,
        service_no,
        session_no,
        arrived_at,
        lag(arrived_at) over (
            partition by bus_stop_code, service_no, session_no order by arrived_at
        ) as previous_arrived_at
    from {{ ref('fct_bus_calls') }}
    where outcome = 'arrived'
),

-- Which direction of the service calls at this stop (for the scheduled frequency)
stop_direction as (
    select distinct on (service_no, bus_stop_code) service_no, bus_stop_code, direction
    from {{ ref('dim_routes') }}
    order by service_no, bus_stop_code, direction
),

timed as (
    select
        a.*,
        a.arrived_at at time zone 'Asia/Singapore'                       as arrived_at_sgt,
        extract(isodow from a.arrived_at at time zone 'Asia/Singapore') as day_of_week,
        (a.arrived_at at time zone 'Asia/Singapore')::time               as time_sgt,
        sd.direction
    from arrivals a
    left join stop_direction sd using (service_no, bus_stop_code)
    where a.previous_arrived_at is not null
)

select
    t.bus_stop_code,
    t.service_no,
    t.arrived_at,
    t.arrived_at_sgt,
    t.previous_arrived_at,
    round(extract(epoch from t.arrived_at - t.previous_arrived_at) / 60, 1) as headway_minutes,
    t.day_of_week <= 5                                                       as is_weekday,
    -- LTA's timetable periods
    case
        when t.time_sgt between '06:30' and '08:30' then 'AM peak'
        when t.time_sgt between '08:31' and '16:59' then 'AM off-peak'
        when t.time_sgt between '17:00' and '19:00' then 'PM peak'
        else 'PM off-peak'
    end                                                                      as period,
    case
        when t.time_sgt between '06:30' and '08:30' then s.am_peak_freq_max
        when t.time_sgt between '08:31' and '16:59' then s.am_offpeak_freq_max
        when t.time_sgt between '17:00' and '19:00' then s.pm_peak_freq_max
        else s.pm_offpeak_freq_max
    end                                                                      as scheduled_max_minutes
from timed t
left join {{ ref('stg_bus_services') }} s
    on s.service_no = t.service_no and s.direction = t.direction
