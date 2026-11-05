-- w04_okr_baseline.sql — Week 4 exercise: one Objective + 3 Key Results, with the baseline measured.
--
-- A Key Result is only measurable if you can state its baseline *today*. This query produces the
-- baseline for a candidate Objective about estate-agent delivery:
--
--   Objective: "Make estate agent work predictable and quick to land"
--   KR1  median lead time:      baseline here -> target
--   KR2  weekly completion rate: baseline here -> target
--   KR3  rework rate (attempts per completed card): baseline here -> target
--
-- Run:  bin/duckdb -no-agent -c ".read sql/w04_okr_baseline.sql"

WITH weekly AS (
    SELECT date_trunc('week', completed_at_utc) AS wk, count(*) AS completed
    FROM 'data/raw/kanban_tasks.parquet'
    WHERE completed_at_utc IS NOT NULL
    GROUP BY 1
), tasks AS (
    SELECT median(lead_time_hours) AS median_lead_h,
           quantile_cont(lead_time_hours, 0.9) AS p90_lead_h,
           count(*) AS completed_total
    FROM 'data/raw/kanban_tasks.parquet'
    WHERE completed_at_utc IS NOT NULL
), runs AS (
    SELECT count(*) AS attempts FROM 'data/raw/kanban_runs.parquet'
)
SELECT 'KR1' AS kr,
       'Median lead time (hours)'                       AS kr_statement,
       round((SELECT median_lead_h FROM tasks), 2)      AS baseline,
       '1.00'                                           AS target,
       'lower is better'                                AS direction
UNION ALL
SELECT 'KR2', 'Completed tasks per active week',
       round((SELECT avg(completed) FROM weekly WHERE completed > 5), 1),
       '200', 'higher is better'
UNION ALL
SELECT 'KR3', 'Rework rate — attempts per completed card',
       round((SELECT attempts FROM runs) * 1.0
             / (SELECT completed_total FROM tasks), 2),
       '1.50', 'lower is better'
UNION ALL
SELECT 'guardrail', 'p90 lead time (catches gaming the median)',
       round((SELECT p90_lead_h FROM tasks), 2),
       '4.00', 'lower is better'
ORDER BY kr;
