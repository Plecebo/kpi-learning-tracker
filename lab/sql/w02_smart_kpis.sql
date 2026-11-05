-- w02_smart_kpis.sql — Week 2 exercise: write 10 SMART KPIs and run the 5-criteria check.
--
-- This query computes the *evidence* for candidate KPIs against real data, so the SMART check is
-- about numbers rather than adjectives. Each row is one candidate; the pass/fail columns are yours
-- to fill after reading the measured values.
--
-- Doran's original wording is Assignable / Realistic; the modern one is Achievable / Relevant. Pick
-- one and say which in your check-in artifact — the roadmap flags this variance on purpose.
--
-- Run:  bin/duckdb -no-agent -c ".read sql/w02_smart_kpis.sql"

WITH base AS (
    SELECT
        count(*)                                                AS tasks,
        count(*) FILTER (WHERE completed_at_utc IS NOT NULL)     AS completed,
        median(lead_time_hours)                                  AS median_lead_h,
        quantile_cont(lead_time_hours, 0.95)                     AS p95_lead_h,
        count(DISTINCT assignee)                                 AS profiles
    FROM 'data/raw/kanban_tasks.parquet'
), runs AS (
    SELECT
        count(*)                                                 AS attempts,
        count(*) FILTER (WHERE outcome = 'completed')             AS clean_runs,
        count(*) FILTER (WHERE status = 'rate_limited')           AS rate_limited_runs
    FROM 'data/raw/kanban_runs.parquet'
)
SELECT 'K1' AS kpi_id,
       'Median task lead time stays under 4 h for 30 days' AS candidate_kpi,
       round(b.median_lead_h, 2)                           AS measured,
       '4.0 h'                                             AS target,
       'S___ M___ A___ R___ T___'                          AS smart_check
FROM base b
UNION ALL
SELECT 'K2', 'p95 lead time under 8 h (tail control, not just the median)',
       round(b.p95_lead_h, 2), '8.0 h', 'S___ M___ A___ R___ T___' FROM base b
UNION ALL
SELECT 'K3', 'First-pass yield >= 80% of attempts on non-outage days',
       round(100.0 * r.clean_runs / nullif(r.attempts - r.rate_limited_runs, 0), 1), '80 %',
       'S___ M___ A___ R___ T___' FROM runs r
UNION ALL
SELECT 'K4', 'At most 20% of completed cards reopen within 7 days',
       NULL::DOUBLE, '20 %', 'S___ M___ A___ R___ T___'
UNION ALL
SELECT 'K5', 'Every profile completes >= 1 card per active week',
       round(1.0 * b.completed / nullif(b.profiles, 0), 1), '1 card', 'S___ M___ A___ R___ T___'
FROM base b
UNION ALL
SELECT 'K6', 'Zero tasks older than 14 days sitting in blocked',
       NULL::DOUBLE, '0 tasks', 'S___ M___ A___ R___ T___'
UNION ALL
SELECT 'K7', 'No week with fewer than 10 completed tasks (liveness floor)',
       NULL::DOUBLE, '10 / week', 'S___ M___ A___ R___ T___'
UNION ALL
SELECT 'K8', 'Median block duration under 2 h',
       NULL::DOUBLE, '2.0 h', 'S___ M___ A___ R___ T___'
UNION ALL
SELECT 'K9', 'Retry rate (runs per completed task) under 3.0',
       round(1.0 * r.attempts / nullif(b.completed, 0), 2), '3.0',
       'S___ M___ A___ R___ T___'
FROM base b, runs r
UNION ALL
SELECT 'K10', 'Heartbeat gap never exceeds 15 min during an active run',
       NULL::DOUBLE, '15 min', 'S___ M___ A___ R___ T___'
ORDER BY kpi_id;
