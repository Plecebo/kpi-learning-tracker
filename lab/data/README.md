# Data dictionary

Every dataset here is a **point-in-time snapshot** of a live estate source, built by `make data`.
Rebuilds move the numbers, so quote `_snapshot_utc` whenever you record a baseline.

All timestamps are UTC (`TIMESTAMP WITH TIME ZONE`). Nothing here is written back to the source.

---

## `kanban_tasks.parquet` — one row per Hermes kanban task

Source: `$KANBAN_DB`, table `tasks` (attached `READ_ONLY`).
Grain: task. Coverage: the whole board since 2026-09-29 (~36 days at first build).

| Column | Type | Notes |
|---|---|---|
| `task_id` | VARCHAR | `t_xxxxxxxx` |
| `title` | VARCHAR | truncated to 160 chars; **task bodies are deliberately excluded** (they can carry personal detail) |
| `assignee` | VARCHAR | profile that owns the card; NULL for unassigned |
| `status` | VARCHAR | live board state: `todo`, `ready`, `running`, `review`, `blocked`, `done`, `archived`, … |
| `priority` | INTEGER | dispatcher tiebreaker |
| `created_by` | VARCHAR | `dashboard`, `auto-decomposer`, `cli`, … |
| `created_at_utc` | TIMESTAMPTZ | |
| `started_at_utc` | TIMESTAMPTZ | first claim |
| `completed_at_utc` | TIMESTAMPTZ | NULL if never completed |
| `lead_time_hours` | DOUBLE | `completed - created`; NULL if not completed |
| `cycle_time_hours` | DOUBLE | `completed - started` |
| `consecutive_failures` | INTEGER | retry counter at snapshot time |
| `block_kind` | VARCHAR | typed block reason (`dependency`, `needs_input`, `capability`, `transient`) |
| `block_recurrences` | INTEGER | unblock-loop counter |
| `goal_mode` | INTEGER | 1 = worker ran in the goal loop |
| `model_override` | VARCHAR | per-task model pin, NULL = profile default |
| `completion_contract` | VARCHAR | `local-only` / PR contract |
| `_snapshot_utc` | TIMESTAMPTZ | when this parquet was built |

**Caveats worth knowing before you compute anything:**
- `status` is *current* state, not history — use `completed_at_utc` for throughput, not `status = 'done'`.
- Archived cards keep `completed_at_utc`; filtering on `status` alone will undercount.
- Lead time is wall-clock, so an overnight human wait and a queue wait look identical. That is a
  **measurement-design discussion** (week 7), not a bug to fix silently.

---

## `kanban_runs.parquet` — one row per worker attempt

Source: `$KANBAN_DB`, table `task_runs`. Grain: attempt. 5,928 rows at first build.

| Column | Notes |
|---|---|
| `run_id`, `task_id`, `profile` | |
| `status` | `done`, `blocked`, `rate_limited`, `crashed`, `timed_out`, `running`, … |
| `started_at_utc`, `ended_at_utc` | |
| `duration_minutes` | `ended - started` |
| `outcome` | `completed`, `blocked`, `review_requested`, `changes_requested`, `rate_limited`, … |
| `had_error` | boolean; true for `rate_limited`/`crashed`/`timed_out` runs |
| `error_excerpt` | first 200 chars of the error text |
| `_snapshot_utc` | |

This is the **rework / first-pass-yield** dataset. `status = 'rate_limited'` (5,082 attempts) is a
real historical episode, not noise — it makes an excellent before/after case study for week 9.

---

## `kanban_events_daily.parquet` — event volume per day per kind

Source: `$KANBAN_DB`, table `task_events` (188k raw events → grouped).
Grain: `(event_date_utc, kind)`. Columns: `event_date_utc`, `kind`, `n_events`, `n_tasks`, `_snapshot_utc`.

Kinds and what they mean for KPI work:

| kind | use |
|---|---|
| `created`, `claimed`, `spawned`, `completed` | the throughput series (arrivals vs departures) |
| `heartbeat` | liveness; a gap is an outage signal |
| `rate_limited` | the quota-wall episode |
| `respawn_guarded` | dispatcher suppressed a re-spawn (dominates volume — filter it out unless you're studying the guard) |
| `promoted`, `dependency_wait` | queue dynamics, useful for cycle-time decomposition |

---

## `gitea_commits.parquet` — commit history, public repos only

Source: `$GITEA_API` public API (anonymous). Grain: commit.
Columns: `repo`, `sha`, `author_name`, `author_email`, `authored_at_utc`, `committed_at_utc`, `message`, `gitea_login`, `_snapshot_utc`.

**Thin on purpose-of-design:** only the public repos on the configured Gitea host are reachable
anonymously — in the original run that was two repos and ten commits; the volume lived in private
ones. To include private repos, export a token and re-run:

```bash
export GITEA_TOKEN=<token>      # read by name from the env; never written to disk here
make data-gitea
```

The token is never stored by this lab — `scripts/fetch_gitea.sh` only reads it from the environment.

---

## `ha_statistics_hourly.parquet` — Home Assistant recorder, one row per (entity, hour)

Source: the HA recorder Postgres `statistics` table, for the ~30 entities in the
`scripts/ha_entities.sql` allowlist. Grain: `(statistic_id, start_ts)`. Built by `make data-ha`
(read-only; the DSN comes from `HA_POSTGRES_URL`, never from a file).

| Column | Type | Notes |
|---|---|---|
| `statistic_id` | VARCHAR | the entity id, e.g. `sensor.heat_pump_daily_energy` |
| `unit_of_measurement` | VARCHAR | `kWh`, `W`, `°F`, `%`, `inHg` |
| `start_ts` | TIMESTAMPTZ | start of the UTC hour (the grain) |
| `period_value` | DOUBLE | **the derived hourly value** — reset-aware Δ`sum` for counter series, `mean` for gauges |
| `mean`, `min`, `max` | DOUBLE | recorder aggregates; populated for gauge series, NULL for counters |
| `state` | DOUBLE | recorder `state`; **do not use as the period value** (see caveat 1) |
| `sum` | DOUBLE | recorder cumulative `sum`; the raw counter |
| `last_reset_ts` | TIMESTAMPTZ | recorder reset marker; NULL throughout this estate |
| `period_kind` | VARCHAR | `sum` (counter, Δsum) or `mean` (gauge) |
| `_snapshot_utc` | TIMESTAMPTZ | when this parquet was built |

## `ha_statistics_daily.parquet` — the same series rolled up to the house day

Source: the hourly file, re-bucketed into `America/Los_Angeles` local days. Grain:
`(statistic_id, local_date)`.

| Column | Type | Notes |
|---|---|---|
| `statistic_id` | VARCHAR | |
| `local_date` | DATE | the calendar day in `America/Los_Angeles` |
| `value` | DOUBLE | `sum(period_value)` for counters, `avg(period_value)` for gauges |
| `n_periods` | INT | hourly periods present that local day |
| `expected_periods` | INT | 24 (a full day); the first/last day are partial |
| `coverage_pct` | DOUBLE | `n_periods / expected_periods × 100` |
| `_snapshot_utc` | TIMESTAMPTZ | |

## `ha_entity_catalog.parquet` — one row per entity: "which series is even usable"

| Column | Type | Notes |
|---|---|---|
| `statistic_id` | VARCHAR | |
| `unit` | VARCHAR | |
| `period_kind` | VARCHAR | `sum` / `mean` (decided by which column is non-null, not the flags) |
| `first_ts`, `last_ts` | TIMESTAMPTZ | the raw first/last sample — `first_ts` can reveal a stale pre-install row |
| `n_periods` | INT | total rows |
| `expected_periods` | INT | hourly buckets over the *active* span (a leading gap > 7 days is a stale first-touch and excluded) |
| `coverage_pct` | DOUBLE | `n_periods / expected_periods × 100` — the fetch FAILS if < 90% |
| `use_week` | VARCHAR | which roadmap week(s) the series serves |

## `ha_short_term_5min.parquet` — 5-minute surface (optional, behind a flag)

Built only when `HA_SHORT_TERM=1` is set at fetch time. Same columns as the hourly file,
grain `(statistic_id, start_ts)` at 5-minute resolution, but only the last 30 days
(`statistics_short_term` retention). Empty/absent otherwise.

## The seven caveats (read these before you compute anything)

1. **`sum` is cumulative; the period value is Δ`sum`, never `state`.** `state` means different
   things per entity — for opower it is the hour, for `crawlspace_dehumidifier` it is
   today-to-date. Only the reset-aware delta of `sum` is the hourly value.
2. **Resets are dropped, not differenced.** A row whose `last_reset_ts` differs from the
   previous row's (or, since that marker is NULL here, whose Δ`sum` is more negative than
   −0.01 kWh) is a counter reset (opower resets each billing cycle, ~40–112 kWh) and is
   excluded; tiny negatives are float noise and are clamped to 0.
3. **`has_sum` / `has_mean` are unreliable.** 407/1183 entities carry `has_sum`, 0 carry
   `has_mean`, yet temperature entities have `mean`/`min`/`max` and NULL `state`/`sum`.
   `period_kind` is decided by which columns are non-null, not by the flags.
4. **Buckets are UTC hours; the house day is `America/Los_Angeles`.** The first local bucket
   (2024-12-31) is partial because the series starts 2025-01-01 00:00Z — that is correct and
   asserted, not "fixed".
5. **Dead and renamed entities exist.** `sensor.heat_4_daily_energy` has 1 row in 22 months;
   `electric_water_heater_*` appears twice (`…power` / `…power_2`). The extractor reports
   coverage per series and FAILS when a requested series is absent or below 90%.
6. **Only `statistics` is multi-year.** `states` and `statistics_short_term` retain 30 days;
   `statistics` is the only surface with 22 months of history.
7. **Do not use the REST history API for bulk work.** `/api/history/period` clamps to 24h
   without `end_time`. The recorder Postgres is the correct source.

---

## Not included (and why)

- **Task bodies, comments, and messages**: real text, potentially personal. Excluded from the snapshot;
  query the live DB read-only if a specific exercise needs it.
