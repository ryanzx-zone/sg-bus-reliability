-- One row per stop on each service's route, in order.
select
    payload->>'ServiceNo'                 as service_no,
    (payload->>'Direction')::int          as direction,
    (payload->>'StopSequence')::int       as stop_sequence,
    payload->>'BusStopCode'               as bus_stop_code,
    payload->>'Operator'                  as operator,
    (payload->>'Distance')::numeric       as distance_km,     -- cumulative distance from the route's first stop
    nullif(payload->>'WD_FirstBus', '-')  as weekday_first_bus,  -- "0530" style, local time
    nullif(payload->>'WD_LastBus', '-')   as weekday_last_bus,
    loaded_at
from {{ source('raw', 'raw_reference') }}
where dataset = 'BusRoutes'
