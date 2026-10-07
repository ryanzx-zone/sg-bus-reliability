import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv

BASE = Path(__file__).parent

load_dotenv(BASE / ".env")
DATABASE_URL = os.environ["DATABASE_URL"]

# Run these SQL files in order. Later files can build on earlier ones.
SQL_FILES = [
    "clean_arrivals.sql",
]

with psycopg.connect(DATABASE_URL) as conn:
    for name in SQL_FILES:
        conn.execute((BASE / "sql" / name).read_text())
        print("ran", name)

    total = conn.execute("SELECT count(*) FROM clean_arrivals").fetchone()[0]
    print("clean_arrivals now has", total, "rows")
