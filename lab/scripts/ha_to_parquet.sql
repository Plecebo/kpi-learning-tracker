-- ha_to_parquet.sql — turn the fetched HA recorder rows into the lab's four datasets.
--
-- Run after `scripts/fetch_ha.py` (which writes data/raw/ha/_statistics_raw.parquet,
-- _entities.parquet and, behind a flag, _short_term_raw.parquet):
--
--   bin/duckdb -no-agent -init scripts/ha_to_parquet.sql -c "select 'ha parquet written'"
--
-- The one thing here that is easy to get wrong, and that the whole exercise hangs on, is
-- the period value: `sum` is a CUMULATIVE counter, so the hourly value is the reset-aware
-- delta of `sum`, never `state` (which is sometimes the hour, sometimes today-to-date).
-- Resets must be dropped, not differenced, or the first hour of a new billing period shows
-- up as a large negative "consumption":
--   * a row whose `last_reset_ts` differs from the previous row's is dropped (the recorder's
--     own marker — NULL in this estate, but kept for future data that populates it);
--   * a negative delta larger than 0.01 kWh is an *unmarked* reset (opower resets each
--     billing cycle, ~40–112 kWh) and is dropped too;
--   * a tiny negative (float/interpolation noise on the cumulative sum) is clamped to 0.
-- Gauge series (`sum` NULL, `mean` populated) take `mean` as the period value directly.

-- ---------------------------------------------------------------------------
-- hourly: one row per (statistic_id, period), period_value = reset-aware Δsum | mean
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TEMP VIEW ha_hourly AS
WITH ordered AS (
    SELECT *,
           lag(sum)          OVER (PARTITION BY statistic_id ORDER BY start_ts) AS prev_sum,
           lag(last_reset_ts) OVER (PARTITION BY statistic_id ORDER BY start_ts) AS prev_last_reset
    FROM read_parquet('data/raw/ha/_statistics_raw.parquet')
)
SELECT
    statistic_id,
    unit_of_measurement,
    to_timestamp(start_ts) AS start_ts,
    local_date,
    CASE
        WHEN sum IS NOT NULL AND prev_sum IS NOT NULL THEN greatest(sum - prev_sum, 0)
        WHEN sum IS NOT NULL THEN NULL                    -- first row: no previous to difference
        ELSE mean
    END AS period_value,
    mean, min, max, state, sum,
    to_timestamp(last_reset_ts) AS last_reset_ts,
    CASE WHEN sum IS NOT NULL THEN 'sum' ELSE 'mean' END AS period_kind
FROM ordered
-- drop the two reset cases (recorded marker, and unmarked big-negative delta)
WHERE NOT (sum IS NOT NULL AND last_reset_ts IS DISTINCT FROM prev_last_reset)
  AND NOT (sum IS NOT NULL AND prev_sum IS NOT NULL AND (sum - prev_sum) < -0.01);

COPY (
    SELECT statistic_id, unit_of_measurement, start_ts, period_value,
           mean, min, max, state, sum, last_reset_ts, period_kind,
           now() AS _snapshot_utc
    FROM ha_hourly
) TO 'data/raw/ha_statistics_hourly.parquet' (FORMAT parquet, COMPRESSION zstd);

-- ---------------------------------------------------------------------------
-- daily: one row per (statistic_id, local_date in America/Los_Angeles).
-- sum-type series aggregate the deltas; gauge series average the means.
-- ---------------------------------------------------------------------------
COPY (
    SELECT statistic_id,
           local_date::DATE AS local_date,
           CASE WHEN max(period_kind) = 'sum' THEN sum(period_value)
                ELSE avg(period_value) END AS value,
           count(period_value)              AS n_periods,
           24                               AS expected_periods,
           round(100.0 * count(period_value) / 24.0, 2) AS coverage_pct,
           now()                            AS _snapshot_utc
    FROM ha_hourly
    GROUP BY statistic_id, local_date
    ORDER BY statistic_id, local_date
) TO 'data/raw/ha_statistics_daily.parquet' (FORMAT parquet, COMPRESSION zstd);

-- ---------------------------------------------------------------------------
-- catalog: one row per entity — the "which series is even usable" table.
-- ---------------------------------------------------------------------------
COPY (
    SELECT statistic_id,
           unit_of_measurement AS unit,
           period_kind,
           to_timestamp(first_ts) AS first_ts,
           to_timestamp(last_ts)  AS last_ts,
           n_periods,
           expected_periods,
           coverage_pct,
           use_week,
           now() AS _snapshot_utc
    FROM read_parquet('data/raw/ha/_entities.parquet')
    ORDER BY statistic_id
) TO 'data/raw/ha_entity_catalog.parquet' (FORMAT parquet, COMPRESSION zstd);

-- ---------------------------------------------------------------------------
-- short-term (5-min, 30-day retention) — behind the HA_SHORT_TERM flag.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TEMP VIEW ha_short AS
WITH ordered AS (
    SELECT *,
           lag(sum)          OVER (PARTITION BY statistic_id ORDER BY start_ts) AS prev_sum,
           lag(last_reset_ts) OVER (PARTITION BY statistic_id ORDER BY start_ts) AS prev_last_reset
    FROM read_parquet('data/raw/ha/_short_term_raw.parquet')
)
SELECT
    statistic_id,
    unit_of_measurement,
    to_timestamp(start_ts) AS start_ts,
    CASE
        WHEN sum IS NOT NULL AND prev_sum IS NOT NULL THEN greatest(sum - prev_sum, 0)
        WHEN sum IS NOT NULL THEN NULL
        ELSE mean
    END AS period_value,
    mean, min, max, state, sum,
    to_timestamp(last_reset_ts) AS last_reset_ts,
    CASE WHEN sum IS NOT NULL THEN 'sum' ELSE 'mean' END AS period_kind
FROM ordered
WHERE NOT (sum IS NOT NULL AND last_reset_ts IS DISTINCT FROM prev_last_reset)
  AND NOT (sum IS NOT NULL AND prev_sum IS NOT NULL AND (sum - prev_sum) < -0.01);

COPY (
    SELECT statistic_id, unit_of_measurement, start_ts, period_value,
           mean, min, max, state, sum, last_reset_ts, period_kind,
           now() AS _snapshot_utc
    FROM ha_short
) TO 'data/raw/ha_short_term_5min.parquet' (FORMAT parquet, COMPRESSION zstd);
