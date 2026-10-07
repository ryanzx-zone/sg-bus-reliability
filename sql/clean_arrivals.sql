-- One row per bus prediction: (poll time, stop, service, slot).
-- Raw has one row per stop per poll, with all services packed into JSON;
-- this unpacks it into proper typed columns.

CREATE TABLE IF NOT EXISTS clean_arrivals (
    polled_at          TIMESTAMPTZ NOT NULL,
    bus_stop_code      TEXT        NOT NULL,
    service_no         TEXT        NOT NULL,
    slot               SMALLINT    NOT NULL,  -- 1 = next bus, 2 = the one after, 3 = the one after that
    operator           TEXT,
    estimated_arrival  TIMESTAMPTZ NOT NULL,
    minutes_away       NUMERIC(6, 1),         -- how far away the app said the bus was, at poll time
    is_monitored       BOOLEAN     NOT NULL,  -- true = live GPS, false = timetable guess
    latitude           DOUBLE PRECISION,      -- NULL when there's no GPS fix
    longitude          DOUBLE PRECISION,
    crowd_level        TEXT,                  -- SEA = seats, SDA = standing, LSD = limited standing
    bus_type           TEXT,                  -- SD = single deck, DD = double deck, BD = bendy
    is_wheelchair_ok   BOOLEAN,
    origin_code        TEXT,
    destination_code   TEXT,
    visit_number       SMALLINT,              -- 2 = second time past this stop on a loop service
    PRIMARY KEY (polled_at, bus_stop_code, service_no, slot)
);

INSERT INTO clean_arrivals
SELECT
    r.polled_at,
    r.bus_stop_code,
    svc->>'ServiceNo',
    b.slot,
    svc->>'Operator',
    (b.bus->>'EstimatedArrival')::timestamptz,
    round(extract(epoch FROM (b.bus->>'EstimatedArrival')::timestamptz - r.polled_at) / 60, 1),
    (b.bus->>'Monitored')::int = 1,
    nullif(nullif(b.bus->>'Latitude', ''), '0.0')::double precision,
    nullif(nullif(b.bus->>'Longitude', ''), '0.0')::double precision,
    nullif(b.bus->>'Load', ''),
    nullif(b.bus->>'Type', ''),
    b.bus->>'Feature' = 'WAB',
    nullif(b.bus->>'OriginCode', ''),
    nullif(b.bus->>'DestinationCode', ''),
    nullif(b.bus->>'VisitNumber', '')::smallint
FROM raw_arrivals r
-- Unpack the Services array: one row per bus service at that stop
CROSS JOIN LATERAL jsonb_array_elements(r.payload->'Services') AS svc
-- Unpack NextBus / NextBus2 / NextBus3 into three rows with a slot number
CROSS JOIN LATERAL (
    VALUES (1, svc->'NextBus'), (2, svc->'NextBus2'), (3, svc->'NextBus3')
) AS b(slot, bus)
-- LTA sends empty slots as blank strings when fewer than 3 buses are coming
WHERE b.bus->>'EstimatedArrival' <> ''
-- Already cleaned on a previous run? Skip it. This makes reruns safe.
ON CONFLICT (polled_at, bus_stop_code, service_no, slot) DO NOTHING;
