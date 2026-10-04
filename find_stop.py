import os
import sys
from pathlib import Path

import requests
from dotenv import load_dotenv

BASE = Path(__file__).parent
load_dotenv(BASE / ".env")
API_KEY = os.environ["LTA_API_KEY"]

# Usage: python find_stop.py "toa payoh"
search = " ".join(sys.argv[1:]).lower()
if not search:
    sys.exit('Usage: python find_stop.py "place or road name"')

# LTA returns bus stops 500 at a time, so keep asking until it runs out
skip = 0
while True:
    r = requests.get(
        "https://datamall2.mytransport.sg/ltaodataservice/BusStops",
        headers={"AccountKey": API_KEY},
        params={"$skip": skip},
        timeout=10,
    )
    r.raise_for_status()
    stops = r.json()["value"]
    if not stops:
        break

    for s in stops:
        if search in s["Description"].lower() or search in s["RoadName"].lower():
            print(s["BusStopCode"], "|", s["Description"], "|", s["RoadName"])

    skip += 500
