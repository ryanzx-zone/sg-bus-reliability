-- One row per bus prediction: (poll time, stop, service, slot).
-- Raw has one row per stop per poll with all services packed into JSON;
-- this unpacks it into proper typed columns.
-- Materialised as a table (not a view) because the JSON unpacking is the heavy part.
{{ config(materialized='table') }}

select
    r.polled_at,
    r.bus_stop_code,
    svc->>'ServiceNo'                                    as service_no,
    b.slot,                                              -- 1 = next bus, 2 = the one after, 3 = the one after that
    svc->>'Operator'                                     as operator,
    (b.bus->>'EstimatedArrival')::timestamptz            as estimated_arrival,
    round(extract(epoch from (b.bus->>'EstimatedArrival')::timestamptz - r.polled_at) / 60, 1)
                                                         as minutes_away,
    (b.bus->>'Monitored')::int = 1                       as is_monitored,      -- true = live GPS, false = timetable guess
    nullif(nullif(b.bus->>'Latitude', ''), '0.0')::double precision  as latitude,   -- NULL = no GPS fix
    nullif(nullif(b.bus->>'Longitude', ''), '0.0')::double precision as longitude,
    nullif(b.bus->>'Load', '')                           as crowd_level,       -- SEA seats, SDA standing, LSD limited standing
    nullif(b.bus->>'Type', '')                           as bus_type,          -- SD single, DD double, BD bendy
    b.bus->>'Feature' = 'WAB'                            as is_wheelchair_ok,
    nullif(b.bus->>'OriginCode', '')                     as origin_code,
    nullif(b.bus->>'DestinationCode', '')                as destination_code,
    nullif(b.bus->>'VisitNumber', '')::smallint          as visit_number       -- 2 = second pass on a loop service

from {{ source('raw', 'raw_arrivals') }} r
-- Unpack the Services array: one row per bus service at that stop
cross join lateral jsonb_array_elements(r.payload->'Services') as svc
-- Unpack NextBus / NextBus2 / NextBus3 into three rows with a slot number
cross join lateral (
    values (1, svc->'NextBus'), (2, svc->'NextBus2'), (3, svc->'NextBus3')
) as b(slot, bus)
-- LTA sends empty slots as blank strings when fewer than 3 buses are coming
where b.bus->>'EstimatedArrival' <> ''
