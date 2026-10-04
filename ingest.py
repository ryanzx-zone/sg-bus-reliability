import os
from datetime import datetime, timezone
from pathlib import Path

import psycopg
import requests
from dotenv import load_dotenv
from psycopg.types.json import Jsonb

# Folder this script lives in, so .env is found no matter where it's run from
BASE = Path(__file__).parent

# Locally this reads .env; on GitHub Actions the values come from repo secrets
load_dotenv(BASE / ".env")
API_KEY = os.environ["LTA_API_KEY"]
DATABASE_URL = os.environ["DATABASE_URL"]

STOPS = [
    "83139",
    "52009",  # Toa Payoh Int
    "84009",  # Bedok Int
    "75009",  # Tampines Int
    "46009",  # Woodlands Int
    "22009",  # Boon Lay Int
    "59009",  # Yishun Int
    "01012",
]

CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS raw_arrivals (
    id            BIGSERIAL PRIMARY KEY,
    polled_at     TIMESTAMPTZ NOT NULL,
    bus_stop_code TEXT        NOT NULL,
    payload       JSONB       NOT NULL,
    UNIQUE (bus_stop_code, polled_at)
)
"""

INSERT = """
INSERT INTO raw_arrivals (polled_at, bus_stop_code, payload)
VALUES (%s, %s, %s)
ON CONFLICT (bus_stop_code, polled_at) DO NOTHING
"""

# One UTC timestamp for the whole run, so all rows from this run are one snapshot.
# UTC because GitHub's servers aren't in Singapore; convert to SGT when querying.
now = datetime.now(timezone.utc)

# Step 1: fetch every stop from LTA (no database involved yet)
rows = []
for stop in STOPS:
    try:
        r = requests.get(
            "https://datamall2.mytransport.sg/ltaodataservice/v3/BusArrival",
            headers={"AccountKey": API_KEY},
            params={"BusStopCode": stop},
            timeout=10,
        )
        r.raise_for_status()
    except requests.RequestException as e:
        # One bad stop shouldn't stop the other stops from being saved
        print("FAILED", stop, e)
        continue

    data = r.json()
    rows.append((now, stop, Jsonb(data)))
    print("fetched", stop, "-", len(data["Services"]), "services")

# Step 2: save them all in one short connection.
# All rows go in together or none do, so a run is never half-saved.
with psycopg.connect(DATABASE_URL) as conn:
    conn.execute(CREATE_TABLE)
    with conn.cursor() as cur:
        cur.executemany(INSERT, rows)

print("saved", len(rows), "rows")
