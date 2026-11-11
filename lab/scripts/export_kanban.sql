-- export_kanban.sql — build the lab's core datasets from the LIVE Hermes kanban board.
-- Read-only by construction: the sqlite file is attached READ_ONLY and nothing writes back.
-- Run with:  bin/duckdb -no-agent -init scripts/export_kanban.sql :memory:
--            (or `make data`, which does exactly that)

INSTALL sqlite;
LOAD sqlite;

ATTACH getenv('KANBAN_DB') AS kb (TYPE sqlite, READ_ONLY);

-- ---------------------------------------------------------------------------
-- kanban_tasks — one row per board task. Lead/cycle time are precomputed in
-- hours so week 8's control chart has something to plot without a join.
-- ---------------------------------------------------------------------------
COPY (
    SELECT
        t.id                                        AS task_id,
        left(t.title, 160)                          AS title,
        t.assignee,
        t.status,
        t.priority,
        t.created_by,
        to_timestamp(t.created_at)                  AS created_at_utc,
        to_timestamp(t.started_at)                  AS started_at_utc,
        to_timestamp(t.completed_at)                AS completed_at_utc,
        round((t.completed_at - t.created_at) / 3600.0, 2)  AS lead_time_hours,
        round((t.completed_at - t.started_at) / 3600.0, 2)  AS cycle_time_hours,
        t.consecutive_failures,
        t.block_kind,
        t.block_recurrences,
        t.goal_mode,
        t.model_override,
        t.completion_contract,
        now()                                       AS _snapshot_utc
    FROM kb.tasks t
) TO 'data/raw/kanban_tasks.parquet' (FORMAT parquet, COMPRESSION zstd);

-- ---------------------------------------------------------------------------
-- kanban_runs — one row per worker attempt on a task. This is the retry/rework
-- dataset: duration, outcome, and whether the attempt ended in an error.
-- ---------------------------------------------------------------------------
COPY (
    SELECT
        r.id                                        AS run_id,
        r.task_id,
        r.profile,
        r.status,
        to_timestamp(r.started_at)                  AS started_at_utc,
        to_timestamp(r.ended_at)                    AS ended_at_utc,
        round((r.ended_at - r.started_at) / 60.0, 2) AS duration_minutes,
        r.outcome,
        (r.error IS NOT NULL AND r.error <> '')     AS had_error,
        left(r.error, 200)                          AS error_excerpt,
        now()                                       AS _snapshot_utc
    FROM kb.task_runs r
) TO 'data/raw/kanban_runs.parquet' (FORMAT parquet, COMPRESSION zstd);

-- ---------------------------------------------------------------------------
-- kanban_events_daily — event volume per day per kind. The throughput/liveness
-- series: heartbeats, claims, completions, blocks per day.
-- ---------------------------------------------------------------------------
COPY (
    SELECT
        CAST(to_timestamp(e.created_at) AS DATE)    AS event_date_utc,
        e.kind,
        count(*)                                    AS n_events,
        count(DISTINCT e.task_id)                   AS n_tasks,
        now()                                       AS _snapshot_utc
    FROM kb.task_events e
    GROUP BY 1, 2
) TO 'data/raw/kanban_events_daily.parquet' (FORMAT parquet, COMPRESSION zstd);
