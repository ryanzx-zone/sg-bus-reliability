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

# My commute between home and NUS, two routes each way:
#   A: 61 <-> 151, switching at Maju Camp (opposite stops each way)
#   B: 157/174/970 <-> 151, switching at King Albert Park (walk across the road)
STOPS = [
    # To NUS (morning)
    "42189",  # The Hillford: home, board leg 1 (both routes)
    "42159",  # Opp Beauty World Stn: leg 1 midpoint, traffic hotspot
    "42059",  # Opp King Albert Pk Stn: route B get off (also route B home: get off 151)
    "41081",  # Sixth Ave Stn: 151 upstream, is it already late?
    "42051",  # King Albert Pk Stn: route B board 151 (also route B home: board 157/174/970)
    "42149",  # Aft Bt Timah Rd: 61 and 151 both stop here, early-transfer option
    "12089",  # Opp Maju Camp: route A, switch 61 -> 151
    "17099",  # UTown - Cendana: leg 2 midpoint
    "16181",  # Ctrl Lib: destination
    # To home (evening)
    "16189",  # Information Technology: board 151 at NUS
    "12081",  # Clementi N'hood Pk: route A, switch 151 -> 61 (across from Maju Camp)
    "42141",  # Bef Dunearn Rd: last stop shared by 151 and 61, late-transfer option
    "42151",  # Beauty World Stn Exit C: leg 2 midpoint
    "42171",  # Signature Pk Condo: home, get off
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
