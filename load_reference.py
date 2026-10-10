"""Load LTA reference data (stops, routes, services) into Postgres as raw JSON.

Reference data changes rarely (new stops, route tweaks), so run this
weekly or by hand, not every 5 minutes like ingest.py.
"""
import os
from datetime import datetime, timezone

import psycopg
from psycopg.types.json import Jsonb

from lta import fetch_all

DATASETS = ["BusStops", "BusRoutes", "BusServices"]

CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS raw_reference (
    dataset    TEXT        NOT NULL,
    loaded_at  TIMESTAMPTZ NOT NULL,
    payload    JSONB       NOT NULL
)
"""

# Step 1: extract everything from LTA before touching the database
now = datetime.now(timezone.utc)
data = {name: fetch_all(name) for name in DATASETS}

# Step 2: swap in the new copy of each dataset in one transaction.
# Anyone querying sees either the old full copy or the new full copy, never half.
with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    conn.execute(CREATE_TABLE)
    with conn.cursor() as cur:
        for name, rows in data.items():
            cur.execute("DELETE FROM raw_reference WHERE dataset = %s", (name,))
            cur.executemany(
                "INSERT INTO raw_reference (dataset, loaded_at, payload) VALUES (%s, %s, %s)",
                [(name, now, Jsonb(row)) for row in rows],
            )
            print(f"loaded {name}: {len(rows)} rows")
