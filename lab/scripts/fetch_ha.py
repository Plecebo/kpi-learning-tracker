#!/usr/bin/env python3
"""fetch_ha.py — snapshot the Home Assistant recorder's long-term `statistics` table.

This is the *fetch* half of `make data-ha`. It reads the recorder Postgres (read-only),
resolves the allowlist in `ha_entities.sql`, pulls the raw hourly (and, behind a flag,
5-minute) rows, derives the local-day column, computes per-series coverage, and writes
intermediate parquets to `data/raw/ha/`. `ha_to_parquet.sql` then turns those into the
four final datasets.

Design rules that keep this correct (each is measured against the live table, see the
issue and `data/README.md`):

* The DSN is read ONLY from the `HA_POSTGRES_URL` environment variable, opened read-only
  with autocommit. It is never written to a file, a parquet, or a doc.
* `sum` is a CUMULATIVE counter. The period value is the reset-aware delta of `sum`, never
  `state` (which is sometimes the hour, sometimes today-to-date).
* A row whose `last_reset_ts` differs from the previous row's is dropped, not differenced.
* `has_sum` / `has_mean` are unreliable — period kind is decided by which column is non-null.
* Buckets are UTC hours; the house day is `America/Los_Angeles`. The first local bucket is
  partial (2024-12-31) and is expected, not "fixed".
* Coverage is reported per series and the run FAILS (exit 1) if a requested series is
  absent or below 90% of its expected hourly periods.

Run directly (requires HA_POSTGRES_URL in the environment) or via `make data-ha`.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

import duckdb
import numpy as np
import pandas as pd
import psycopg2
from psycopg2.extensions import connection as PgConnection

LAB = Path(__file__).resolve().parent.parent
RAW = LAB / "data" / "raw"
HA_RAW = RAW / "ha"
ENTITIES_SQL = LAB / "scripts" / "ha_entities.sql"

LOCAL_TZ = ZoneInfo("America/Los_Angeles")
COVERAGE_FLOOR_PCT = 90.0  # a series below this fraction of expected periods fails the run
SHORT_TERM_FLAG = "HA_SHORT_TERM"  # set to any non-empty value to also snapshot the 5-min table
HOURLY_S = 3600.0  # the statistics table is hourly (measured 2026-11-11)
# A gap larger than a week in an hourly series means the entity was not yet installed /
# recording (a stale first-touch) or went away and came back. The coverage denominator
# measures from the active start, so a single pre-install row does not mark a live series
# as dead. The raw first_ts is still reported for audit.
LARGE_GAP_S = 7 * 24 * 3600


def _connect(dsn: str) -> PgConnection:
    conn = psycopg2.connect(dsn)
    # read-only + autocommit, as the recorder should be consumed: never write back.
    conn.set_session(readonly=True, autocommit=True)
    return conn


def _like_pattern(pattern: str) -> str:
    """Convert an allowlist pattern (`%` = wildcard, `_` = literal) to a SQL LIKE
    expression with the underscore escaped, so `_` never matches a wildcard."""
    escaped = pattern.replace("\\", "\\\\").replace("_", "\\_")
    return escaped


def _load_allowlist() -> list[tuple[str, str]]:
    if not ENTITIES_SQL.exists():
        raise SystemExit(f"allowlist missing: {ENTITIES_SQL}")
    df = duckdb.sql(ENTITIES_SQL.read_text(encoding="utf-8")).fetchdf()
    if list(df.columns) != ["pattern", "use_week"]:
        raise SystemExit(f"allowlist must yield (pattern, use_week); got {list(df.columns)}")
    return list(zip(df["pattern"].astype(str), df["use_week"].astype(str)))


def resolve_entities(conn: PgConnection, allowlist: list[tuple[str, str]]) -> tuple[pd.DataFrame, list[str]]:
    """Map each allowlist pattern to the statistic_ids it matches, annotating each with
    the pattern's `use_week`. Returns (one row per resolved entity, patterns that matched
    nothing)."""
    rows: list[dict] = []
    matched_patterns: set[str] = set()
    with conn.cursor() as cur:
        for pattern, use_week in allowlist:
            cur.execute(
                "SELECT statistic_id, unit_of_measurement, has_sum, has_mean "
                "FROM statistics_meta WHERE statistic_id LIKE %s ESCAPE '\\' ORDER BY statistic_id",
                (_like_pattern(pattern),),
            )
            got = cur.fetchall()
            if got:
                matched_patterns.add(pattern)
            for statistic_id, unit, has_sum, has_mean in got:
                rows.append(
                    {
                        "statistic_id": statistic_id,
                        "unit_of_measurement": unit,
                        "has_sum": has_sum,
                        "has_mean": has_mean,
                        "use_week": use_week,
                    }
                )
    absent = [p for p, _ in allowlist if p not in matched_patterns]
    if rows:
        return pd.DataFrame(rows), absent
    return pd.DataFrame(
        columns=["statistic_id", "unit_of_measurement", "has_sum", "has_mean", "use_week"]
    ), absent


def _pull_rows(conn: PgConnection, statistic_ids: list[str], table: str) -> pd.DataFrame:
    """Pull raw rows for the given statistic_ids from `statistics` (or `statistics_short_term`)."""
    with conn.cursor() as cur:
        cur.execute(
            f"""
            SELECT m.statistic_id, m.unit_of_measurement,
                   s.start_ts, s.mean, s.min, s.max, s.state, s.sum, s.last_reset_ts
            FROM {table} s
            JOIN statistics_meta m ON m.id = s.metadata_id
            WHERE m.statistic_id = ANY(%s)
            ORDER BY m.statistic_id, s.start_ts
            """,
            (statistic_ids,),
        )
        cols = [d[0] for d in cur.description]
        return pd.DataFrame(cur.fetchall(), columns=cols)


def _add_local_date(df: pd.DataFrame) -> pd.DataFrame:
    utc = pd.to_datetime(df["start_ts"], unit="s", utc=True)
    # local day is a plain string date; ha_to_parquet.sql casts it to DATE. Doing the
    # timezone conversion here keeps the SQL transform free of any timezone dependency.
    df["local_date"] = utc.dt.tz_convert(LOCAL_TZ).dt.strftime("%Y-%m-%d")
    return df


def coverage(entities: pd.DataFrame, raw: pd.DataFrame) -> pd.DataFrame:
    """Per-series coverage over the entity's *active* span.

    `expected_periods` is the number of hourly buckets from the entity's active start to its
    last sample, where a leading gap larger than a week is a stale pre-install first-touch and
    is excluded from the start. A healthy live series sits near 100%; a dead series (1 row, or
    one that stopped long ago) collapses toward 0% and fails the gate.
    """
    rows: list[dict] = []
    for sid, g in raw.groupby("statistic_id", sort=False):
        ts = g["start_ts"].to_numpy()
        n = len(ts)
        first, last = ts[0], ts[-1]
        n_sum = int(g["sum"].notna().sum())
        n_mean = int(g["mean"].notna().sum())
        effective_first = first
        if n > 1:
            gaps = np.diff(ts)
            # A leading stale tail is a run of large gaps at the very start (a pre-install
            # first-touch row). The active start is the first sample whose preceding gap is
            # normal (<= LARGE_GAP_S); middle outages stay inside the span and only lower
            # coverage, they do not reset the active start.
            normal = np.where(gaps <= LARGE_GAP_S)[0]
            effective_first = ts[normal[0]] if normal.size else ts[-1]
        expected = int((last - effective_first) / HOURLY_S) + 1
        cov_pct = round(100.0 * n / expected, 2) if expected > 0 else 0.0
        rows.append(
            {
                "statistic_id": sid,
                "first_ts": first,
                "last_ts": last,
                "n_periods": n,
                "n_sum_notnull": n_sum,
                "n_mean_notnull": n_mean,
                "expected_periods": expected,
                "coverage_pct": cov_pct,
            }
        )
    cov = pd.DataFrame(rows)
    cov["period_kind"] = cov.apply(
        lambda r: "sum" if r["n_sum_notnull"] > 0 else "mean", axis=1
    )
    return entities.merge(cov, on="statistic_id", how="left")


def main() -> int:
    dsn = os.environ.get("HA_POSTGRES_URL", "").strip()
    if not dsn:
        print("HA_POSTGRES_URL is not set — export it (read from BWS, never from a file)", file=sys.stderr)
        return 1

    allowlist = _load_allowlist()
    print(f"allowlist: {len(allowlist)} pattern(s) from scripts/ha_entities.sql")

    conn = _connect(dsn)
    try:
        entities, absent = resolve_entities(conn, allowlist)
        if absent:
            for p in absent:
                print(f"  FAIL  pattern matched zero entities: {p!r}", file=sys.stderr)
            print(f"\n{len(absent)} allowlist pattern(s) matched nothing. Refusing to write a "
                  f"silently-incomplete snapshot.", file=sys.stderr)
            return 1
        if entities.empty:
            print("no allowlist pattern matched any entity — aborting", file=sys.stderr)
            return 1
        ids = sorted(entities["statistic_id"].unique().tolist())

        raw = _pull_rows(conn, ids, "statistics")
        raw = _add_local_date(raw)

        cov = coverage(entities, raw)

        # the gate: absent or under-covered series fail loudly.
        failures = 0
        print(f"\nper-series coverage ({len(cov)} entit(y/ies)):")
        print(f"  {'statistic_id':60} {'unit':8} {'kind':5} {'n':>7} {'exp':>7} {'cov%':>7}  use")
        for _, r in cov.sort_values("statistic_id").iterrows():
            n = r["n_periods"]
            exp = r["expected_periods"]
            cp = r["coverage_pct"]
            flag = ""
            if pd.isna(n) or n == 0:
                flag = "  <-- ABSENT (fails)"
                failures += 1
            elif cp < COVERAGE_FLOOR_PCT:
                flag = f"  <-- below {COVERAGE_FLOOR_PCT:.0f}% (fails)"
                failures += 1
            print(
                f"  {r['statistic_id']:60} {str(r['unit_of_measurement']):8} "
                f"{r['period_kind']:5} {int(n):>7} {int(exp):>7} {cp:>6.2f}%  {r['use_week']}{flag}"
            )

        if failures:
            print(f"\n{COVERAGE_FLOOR_PCT:.0f}% coverage gate failed: {failures} series absent or "
                  f"under-covered. Refusing to write a silently-incomplete snapshot.", file=sys.stderr)
            return 1

        HA_RAW.mkdir(parents=True, exist_ok=True)

        # raw hourly (local_date precomputed so the SQL transform needs no timezone logic)
        keep = ["statistic_id", "unit_of_measurement", "start_ts", "local_date",
                "mean", "min", "max", "state", "sum", "last_reset_ts"]
        raw[keep].to_parquet(HA_RAW / "_statistics_raw.parquet", index=False)

        # resolved entities + coverage + use_week -> feeds the catalog
        cov_cols = ["statistic_id", "unit_of_measurement", "has_sum", "has_mean",
                    "use_week", "period_kind", "first_ts", "last_ts",
                    "n_periods", "expected_periods", "coverage_pct"]
        cov[cov_cols].to_parquet(HA_RAW / "_entities.parquet", index=False)

        # optional 5-minute surface (30-day retention), behind a flag. The raw is always
        # written (empty when the flag is off) so ha_to_parquet.sql reads it unconditionally;
        # `make data-ha` drops the empty final parquet when the flag is off.
        if os.environ.get(SHORT_TERM_FLAG):
            short = _pull_rows(conn, ids, "statistics_short_term")
            short = _add_local_date(short)
            short[keep].to_parquet(HA_RAW / "_short_term_raw.parquet", index=False)
            print(f"  short-term: {len(short):,} rows written (5-min)")
        else:
            raw[keep].iloc[0:0].to_parquet(HA_RAW / "_short_term_raw.parquet", index=False)
            print(f"  short-term: skipped (set {SHORT_TERM_FLAG}=1 to include 30d of 5-min data)")
    finally:
        conn.close()

    print(f"\nfetched {len(raw):,} hourly rows for {len(cov)} entit(y/ies) "
          f"-> data/raw/ha/ (transform with ha_to_parquet.sql)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
