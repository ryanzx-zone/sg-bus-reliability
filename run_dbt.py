"""Run dbt with the database settings from .env.

Usage: python run_dbt.py build      (or run, test, seed, docs generate, ...)
"""
import os
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

from dbt.cli.main import dbtRunner
from dotenv import load_dotenv

BASE = Path(__file__).parent
load_dotenv(BASE / ".env")

# dbt wants host/user/password separately, but we store a single DATABASE_URL
url = urlparse(os.environ["DATABASE_URL"])
os.environ.update(
    PGHOST=url.hostname,
    PGUSER=unquote(url.username),
    PGPASSWORD=unquote(url.password),
    PGDATABASE=url.path.lstrip("/"),
)

dbt_dir = str(BASE / "dbt")
result = dbtRunner().invoke(sys.argv[1:] + ["--project-dir", dbt_dir, "--profiles-dir", dbt_dir])
sys.exit(0 if result.success else 1)
