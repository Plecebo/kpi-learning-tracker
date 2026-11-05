#!/usr/bin/env python3
"""env_check.py — the lab smoke test. `make check` runs this.

Fails loudly (exit 1) if a dependency is missing or a dataset is absent/empty, because the whole
point of the environment is that every later exercise can trust it.
"""
from __future__ import annotations

import importlib
import sys
from pathlib import Path

LAB = Path(__file__).resolve().parent.parent
RAW = LAB / "data" / "raw"

REQUIRED = ["duckdb", "pandas", "pyarrow", "matplotlib", "seaborn", "statsmodels", "numpy"]
DATASETS = {
    "kanban_tasks.parquet": 100,
    "kanban_runs.parquet": 100,
    "kanban_events_daily.parquet": 50,
}
OPTIONAL_DATASETS = {
    # public Gitea repos only unless GITEA_TOKEN was exported at fetch time
    "gitea_commits.parquet": 1,
}

failures: list[str] = []


def ok(msg: str) -> None:
    print(f"  PASS  {msg}")


def bad(msg: str) -> None:
    print(f"  FAIL  {msg}")
    failures.append(msg)


print(f"python      {sys.version.split()[0]}  ({sys.executable})")

print("\ndependencies")
for mod in REQUIRED:
    try:
        m = importlib.import_module(mod)
        ok(f"{mod} {getattr(m, '__version__', '(no __version__)')}")
    except Exception as exc:  # noqa: BLE001 - report anything, keep going
        bad(f"{mod} import failed: {exc}")

print("\ndatasets")
import duckdb  # noqa: E402  (imported after the check above on purpose)

con = duckdb.connect()
for name, min_rows in DATASETS.items():
    path = RAW / name
    if not path.exists():
        bad(f"{name} missing (run `make data`)")
        continue
    try:
        rows, cols = con.execute(
            f"SELECT count(*), count(*) FROM read_parquet('{path}')"
        ).fetchone()
        distinct_cols = len(con.execute(f"DESCRIBE SELECT * FROM read_parquet('{path}')").fetchall())
        if rows >= min_rows:
            ok(f"{name}: {rows:,} rows x {distinct_cols} cols")
        else:
            bad(f"{name}: only {rows} rows (expected >= {min_rows})")
    except Exception as exc:  # noqa: BLE001
        bad(f"{name} unreadable: {exc}")

for name, min_rows in OPTIONAL_DATASETS.items():
    path = RAW / name
    if not path.exists():
        print(f"  SKIP  {name} absent (optional — see data/README.md)")
        continue
    try:
        rows = con.execute(f"SELECT count(*) FROM read_parquet('{path}')").fetchone()[0]
        if rows >= min_rows:
            ok(f"{name}: {rows:,} rows (optional)")
        else:
            print(f"  SKIP  {name} empty (optional)")
    except Exception as exc:  # noqa: BLE001
        bad(f"{name} unreadable: {exc}")

print("\nsemantics (the numbers must make sense, not just exist)")
try:
    row = con.execute(
        f"""SELECT count(*) FILTER (WHERE completed_at_utc IS NOT NULL) AS done,
                   count(*) FILTER (WHERE lead_time_hours < 0)         AS negative_lead,
                   count(DISTINCT assignee)                            AS profiles
            FROM read_parquet('{RAW / "kanban_tasks.parquet"}')"""
    ).fetchone()
    done, negative_lead, profiles = row
    if done > 0 and negative_lead == 0:
        ok(f"completed tasks {done:,}, no negative lead times, {profiles} profiles")
    else:
        bad(f"completed={done}, negative_lead_times={negative_lead}")
except Exception as exc:  # noqa: BLE001
    bad(f"semantic check failed: {exc}")

print("\nat the end")
if failures:
    print(f"ENV CHECK FAILED — {len(failures)} problem(s):")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)
print("ENV CHECK PASSED — the lab is ready.")
