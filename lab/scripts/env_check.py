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
    # Home Assistant recorder long-term statistics (make data-ha / make data)
    "ha_statistics_hourly.parquet": 100_000,
    "ha_statistics_daily.parquet": 1_000,
    "ha_entity_catalog.parquet": 20,
}
OPTIONAL_DATASETS = {
    # public Gitea repos only unless GITEA_TOKEN was exported at fetch time
    "gitea_commits.parquet": 1,
    # 30-day 5-minute surface, only when HA_SHORT_TERM=1 was set at fetch time
    "ha_short_term_5min.parquet": 1,
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

print("\nha semantics (the numbers must mean what the recorder means)")
HHOURLY = RAW / "ha_statistics_hourly.parquet"
HDAILY = RAW / "ha_statistics_daily.parquet"
if HHOURLY.exists() and HDAILY.exists():
    def _q(sql, *a):
        return con.execute(sql, list(a)).fetchall()

    # 1. grain uniqueness
    dup_h = _q(f"SELECT count(*) - count(DISTINCT (statistic_id, start_ts)) FROM read_parquet('{HHOURLY}')")[0][0]
    dup_d = _q(f"SELECT count(*) - count(DISTINCT (statistic_id, local_date)) FROM read_parquet('{HDAILY}')")[0][0]
    if dup_h == 0 and dup_d == 0:
        ok("hourly & daily grains are unique")
    else:
        bad(f"duplicate grain rows — hourly={dup_h}, daily={dup_d}")

    # 2. no negative period_value for cumulative (sum) series — resets are dropped, not differenced
    neg = _q(f"SELECT count(*) FROM read_parquet('{HHOURLY}') WHERE period_kind='sum' AND period_value < 0")[0][0]
    if neg == 0:
        ok("no negative period_value on sum series (resets dropped, noise clamped)")
    else:
        bad(f"{neg} negative period_value on sum series")

    # 3. daily rollup is lossless: sum(daily) == sum(hourly) per sum series
    lossy = _q(f"""
        WITH sum_series AS (SELECT DISTINCT statistic_id FROM read_parquet('{HHOURLY}') WHERE period_kind='sum'),
        h AS (SELECT statistic_id, sum(period_value) hv FROM read_parquet('{HHOURLY}') WHERE period_kind='sum' GROUP BY 1),
        d AS (SELECT statistic_id, sum(value) dv FROM read_parquet('{HDAILY}') WHERE statistic_id IN (SELECT statistic_id FROM sum_series) GROUP BY 1)
        SELECT count(*) FROM h JOIN d USING (statistic_id) WHERE abs(hv - dv) > 0.01
    """)[0][0]
    if lossy == 0:
        ok("sum(daily) == sum(hourly) per sum series")
    else:
        bad(f"{lossy} sum series where daily rollup disagrees with hourly deltas")

    # 4. local-day bucketing: the first local day is a partial 2024-12-31 bucket (expected)
    first_day = _q(f"SELECT min(local_date) FROM read_parquet('{HDAILY}')")[0][0]
    first_n = _q(f"SELECT max(n_periods) FROM read_parquet('{HDAILY}') WHERE local_date = (SELECT min(local_date) FROM read_parquet('{HDAILY}'))")[0][0]
    if str(first_day) == "2024-12-31" and first_n is not None and first_n < 24:
        ok(f"partial first local bucket {first_day} (max {first_n} of 24 periods)")
    else:
        bad(f"expected partial 2024-12-31 first bucket, got {first_day} with {first_n} periods")

    # 5. sane unit ranges (catches gross corruption, not the subtle anomalies week 8 is for)
    UNIT_BOUNDS = {
        "kWh": (0.0, 1000.0), "W": (0.0, 100_000.0), "%": (0.0, 100.0),
        "°F": (-50.0, 150.0), "inHg": (20.0, 40.0), "A": (0.0, 100.0), "V": (0.0, 300.0),
    }
    range_rows = _q(f"SELECT unit_of_measurement, min(period_value), max(period_value) FROM read_parquet('{HHOURLY}') WHERE period_value IS NOT NULL GROUP BY 1")
    range_bad = 0
    for unit, lo, hi in range_rows:
        if unit in UNIT_BOUNDS:
            flo, fhi = UNIT_BOUNDS[unit]
            if lo < flo or hi > fhi:
                range_bad += 1
                bad(f"{unit} out of range: period_value {lo} .. {hi} (expected {flo} .. {fhi})")
    if range_bad == 0:
        ok(f"period_value within sane unit ranges ({len(range_rows)} unit(s))")
else:
    print("  SKIP  ha semantics (ha parquets absent — run `make data-ha`)")

print("\nat the end")
if failures:
    print(f"ENV CHECK FAILED — {len(failures)} problem(s):")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)
print("ENV CHECK PASSED — the lab is ready.")
