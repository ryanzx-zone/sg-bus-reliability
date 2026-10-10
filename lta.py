"""Shared helpers for talking to the LTA DataMall API."""
import os
from pathlib import Path

import requests
from dotenv import load_dotenv
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

BASE = Path(__file__).parent
load_dotenv(BASE / ".env")

URL = "https://datamall2.mytransport.sg/ltaodataservice"

# One reused connection for all requests, and if LTA drops it,
# wait (1s, 2s, 4s, ...) and try again instead of crashing
session = requests.Session()
session.headers["AccountKey"] = os.environ["LTA_API_KEY"]
session.mount("https://", HTTPAdapter(max_retries=Retry(
    total=5, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504],
)))


def fetch_all(dataset):
    """Download a whole LTA dataset. It comes 500 rows per page, so keep asking until it runs out."""
    rows, skip = [], 0
    while True:
        r = session.get(f"{URL}/{dataset}", params={"$skip": skip}, timeout=30)
        r.raise_for_status()
        page = r.json()["value"]
        if not page:
            break
        rows += page
        skip += 500
        print(f"  downloading {dataset}: {len(rows)} rows", end="\r")
    print()
    return rows
