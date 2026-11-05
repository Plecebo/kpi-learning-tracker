-- w01_metric_inventory.sql — Week 1 exercise: label the metrics you already track.
--
-- The exercise says: list 5 metrics you already track, label each leading vs lagging and
-- actionable vs vanity, then rewrite every vanity one as actionable.
--
-- This query does the "already track" half from real board data. Fill in the two label columns by
-- hand (they are judgements, not queries), then use the result as the week-1 check-in artifact.
--
-- Run:  bin/duckdb -no-agent -c ".read sql/w01_metric_inventory.sql"

WITH tracked AS (
    -- metric, formula in words, current measured value
    SELECT 'tasks completed / week'            AS metric,
           'count of completed_at_utc in the week'                       AS definition,
           round(avg(n), 1)                                             AS current_value
    FROM (SELECT date_trunc('week', completed_at_utc) wk, count(*) n
          FROM 'data/raw/kanban_tasks.parquet'
          WHERE completed_at_utc IS NOT NULL GROUP BY 1)
    UNION ALL
    SELECT 'median lead time (hours)',
           'median(completed - created)',
           round(median(lead_time_hours), 2)
    FROM 'data/raw/kanban_tasks.parquet' WHERE completed_at_utc IS NOT NULL
    UNION ALL
    SELECT 'first-pass yield (% runs completing without error)',
           '100 * completed runs / all runs started',
           round(100.0 * count(*) FILTER (WHERE outcome = 'completed')
                 / nullif(count(*), 0), 1)
    FROM 'data/raw/kanban_runs.parquet'
    UNION ALL
    SELECT 'blocked-card rate (% of tasks that ever blocked)',
           '100 * tasks with block_kind / all tasks',
           round(100.0 * count(*) FILTER (WHERE block_kind IS NOT NULL)
                 / nullif(count(*), 0), 1)
    FROM 'data/raw/kanban_tasks.parquet'
    UNION ALL
    SELECT 'event volume (events / day)',
           'mean daily event count',
           round(avg(n), 1)
    FROM (SELECT event_date_utc, sum(n_events) n
          FROM 'data/raw/kanban_events_daily.parquet' GROUP BY 1)
)
SELECT metric,
       definition,
       current_value,
       '___'  AS leading_or_lagging,   -- TODO: leading | lagging
       '___'  AS actionable_or_vanity, -- TODO: actionable | vanity
       '___'  AS rewritten_as_actionable
FROM tracked
ORDER BY current_value DESC;
