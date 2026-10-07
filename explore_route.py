import json
import os
import sys
from pathlib import Path

import requests
from dotenv import load_dotenv
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

BASE = Path(__file__).parent
load_dotenv(BASE / ".env")
API_KEY = os.environ["LTA_API_KEY"]

# One reused connection for all pages, and if LTA drops it,
# wait (1s, 2s, 4s, ...) and try again instead of crashing
session = requests.Session()
session.headers["AccountKey"] = API_KEY
session.mount("https://", HTTPAdapter(max_retries=Retry(
    total=5, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504],
)))

# Reference data barely changes, so download once and reuse (data/ is gitignored)
CACHE = BASE / "data" / "reference"

USAGE = """Usage:
  python explore_route.py 151              list every stop on service 151, in order
  python explore_route.py 12345 67890      list services that go from stop 12345 to stop 67890"""


def fetch_all(dataset):
    """Download a whole LTA dataset (it comes 500 rows at a time), cached locally."""
    path = CACHE / f"{dataset}.json"
    if path.exists():
        return json.loads(path.read_text())

    rows, skip = [], 0
    while True:
        r = session.get(
            f"https://datamall2.mytransport.sg/ltaodataservice/{dataset}",
            params={"$skip": skip},
            timeout=30,
        )
        r.raise_for_status()
        page = r.json()["value"]
        if not page:
            break
        rows += page
        skip += 500
        print(f"  downloading {dataset}: {len(rows)} rows", end="\r")
    print()

    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows))
    return rows


args = sys.argv[1:]
if len(args) not in (1, 2):
    sys.exit(USAGE)

routes = fetch_all("BusRoutes")
names = {s["BusStopCode"]: f'{s["Description"]} ({s["RoadName"]})' for s in fetch_all("BusStops")}

if len(args) == 1:
    service = args[0].upper()
    for direction in (1, 2):
        stops = sorted(
            (r for r in routes if r["ServiceNo"] == service and r["Direction"] == direction),
            key=lambda r: r["StopSequence"],
        )
        if not stops:
            continue
        print(f"\nService {service}, direction {direction}:")
        for r in stops:
            print(f'  {r["StopSequence"]:>3}  {r["BusStopCode"]}  {names.get(r["BusStopCode"], "?")}')

else:
    start, end = args
    print(f"From {start} {names.get(start, '?')}")
    print(f"To   {end} {names.get(end, '?')}\n")

    # For each service+direction, where in the route each stop appears
    position = {}
    for r in routes:
        position.setdefault((r["ServiceNo"], r["Direction"]), {}).setdefault(r["BusStopCode"], r["StopSequence"])

    found = False
    for (service, direction), seq in sorted(position.items()):
        if start in seq and end in seq and seq[start] < seq[end]:
            print(f"  {service:>5}  (direction {direction}, {seq[end] - seq[start]} stops)")
            found = True
    if not found:
        print("  No direct service between these two stops.")
