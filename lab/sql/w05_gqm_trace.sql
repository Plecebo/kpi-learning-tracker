-- w05_gqm_trace.sql — Week 5 exercise: the full GQM trace on a real estate workflow.
--
-- Basili/Caldiera/Rombach structure, filled in for one goal:
--
--   Purpose:    improve        Object: agent task delivery      Quality focus: timeliness
--   Viewpoint:  Larry (estate operator)                            Context: the Hermes board
--
--   Goal: land agent work quickly without sacrificing a clean first attempt.
--   Q1  How long does a piece of work take from arrival to done?      -> M1 lead time (h)
--   Q2  Does it take long because of queueing or because of work?     -> M2 start delay (h)
--   Q3  How often does an attempt have to be repeated?                -> M3 attempts per card
--   Q4  Is the delay getting better or worse over time?               -> M4 weekly trend
--
-- The trace is the artifact; the numbers are the evidence that the metrics exist and are derivable.
--
-- Run:  bin/duckdb -no-agent -c ".read sql/w05_gqm_trace.sql"

WITH per_task AS (
    SELECT task_id,
           lead_time_hours,
           cycle_time_hours,
           round(epoch(started_at_utc - created_at_utc) / 3600.0, 2) AS queue_wait_hours
    FROM 'data/raw/kanban_tasks.parquet'
    WHERE completed_at_utc IS NOT NULL
), attempts AS (
    SELECT task_id, count(*) AS n_attempts
    FROM 'data/raw/kanban_runs.parquet'
    GROUP BY 1
), weekly AS (
    SELECT date_trunc('week', completed_at_utc) AS wk,
           round(median(lead_time_hours), 2)    AS median_lead_h,
           count(*)                             AS n
    FROM 'data/raw/kanban_tasks.parquet'
    WHERE completed_at_utc IS NOT NULL
    GROUP BY 1
)
SELECT 'Q1' AS question, 'M1 lead time (hours), completed cards' AS metric,
       round(median(lead_time_hours), 2) AS value, 'median' AS stat
FROM per_task
UNION ALL
SELECT 'Q1', 'M1 lead time p90', round(quantile_cont(lead_time_hours, 0.9), 2), 'p90'
FROM per_task
UNION ALL
SELECT 'Q2', 'M2 queue wait (created -> first claim)', round(median(queue_wait_hours), 2), 'median'
FROM per_task
UNION ALL
SELECT 'Q2', 'M2 work time (first claim -> done)', round(median(cycle_time_hours), 2), 'median'
FROM per_task
UNION ALL
SELECT 'Q3', 'M3 attempts per completed card', round(avg(n_attempts), 2), 'mean'
FROM attempts
UNION ALL
SELECT 'Q4', 'M4 worst week by median lead time',
       max(median_lead_h), 'max of weekly medians'
FROM weekly
ORDER BY question, stat;
