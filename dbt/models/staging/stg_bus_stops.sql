-- One row per bus stop in Singapore.
select
    payload->>'BusStopCode'               as bus_stop_code,
    payload->>'Description'               as stop_name,
    payload->>'RoadName'                  as road_name,
    (payload->>'Latitude')::double precision  as latitude,
    (payload->>'Longitude')::double precision as longitude,
    loaded_at
from {{ source('raw', 'raw_reference') }}
where dataset = 'BusStops'
