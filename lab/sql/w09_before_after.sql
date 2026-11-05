-- w09_before_after.sql — Week 9 exercise: before/after, with the counterfactual stated.
--
-- There is a real event in this data: the quota wall. From 2026-10-05 00:29 UTC to 2026-10-06 17:25
-- UTC, 5,082 worker attempts ended `rate_limited` — an attempt that never got to do any work. Then
-- the board went quiet (no completed cards at all in the weeks of 10-12 and 10-26).
--
-- So the honest before/after pair is:
--   Phase A  "normal"       2026-09-28 .. 2026-10-05   (before the wall)
--   Phase B  "quota wall"   2026-10-05 .. 2026-10-07
--   Phase C  "recovery"     2026-11-02 ..               (after the rebuild)
--
-- Confounders you must name before claiming impact: the wall was an *external quota*, not a change
-- Larry made; the recovery window coincides with a fresh CT install; sample sizes are small (C has
-- ~4 days). That is exactly the point of the exercise — write the caveats down or the comparison is
-- a story, not a measurement.
--
-- Run:  bin/duckdb -no-agent -c ".read sql/w09_before_after.sql"

WITH phases AS (
    SELECT 'A before (normal)'  AS phase, TIMESTAMPTZ '2026-09-28 00:00:00+00' AS t0, TIMESTAMPTZ '2026-10-05 00:00:00+00' AS t1
    UNION ALL SELECT 'B quota wall',    TIMESTAMPTZ '2026-10-05 00:00:00+00', TIMESTAMPTZ '2026-10-07 00:00:00+00'
    UNION ALL SELECT 'C recovery',      TIMESTAMPTZ '2026-11-02 00:00:00+00', TIMESTAMPTZ '2026-11-06 00:00:00+00'
), run_stats AS (
    SELECT p.phase,
           count(r.run_id)                                              AS attempts,
           count(*) FILTER (WHERE r.status = 'rate_limited')             AS rate_limited,
           count(*) FILTER (WHERE r.outcome = 'completed')               AS clean_completions,
           round(median(r.duration_minutes), 2)                          AS median_minutes
    FROM phases p
    LEFT JOIN 'data/raw/kanban_runs.parquet' r
           ON r.started_at_utc >= p.t0 AND r.started_at_utc < p.t1
    GROUP BY 1
), task_stats AS (
    SELECT p.phase,
           count(t.task_id)                                              AS tasks_created,
           count(*) FILTER (WHERE t.completed_at_utc IS NOT NULL)        AS tasks_completed,
           round(median(t.lead_time_hours), 2)                           AS median_lead_h
    FROM phases p
    LEFT JOIN 'data/raw/kanban_tasks.parquet' t
           ON t.created_at_utc >= p.t0 AND t.created_at_utc < p.t1
    GROUP BY 1
)
SELECT r.phase,
       r.attempts,
       r.rate_limited,
       round(100.0 * r.rate_limited / nullif(r.attempts, 0), 1)  AS pct_rate_limited,
       r.clean_completions,
       r.median_minutes,
       t.tasks_created,
       t.tasks_completed,
       t.median_lead_h
FROM run_stats r JOIN task_stats t USING (phase)
ORDER BY r.phase;
