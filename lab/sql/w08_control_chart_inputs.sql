-- w08_control_chart_inputs.sql — Week 8 exercise: variation, and signal vs noise.
--
-- Wheeler's discipline: a metric moving is not news until it leaves its control limits — and the
-- limits must come from a period you believe was stable. This query does the standard SPC move:
--
--   baseline  2026-09-29 .. 2026-10-31   (the board's establishment period)
--   monitor   2026-11-01 onward          (judged against those limits)
--
-- Metric: median worker-run duration per day (minutes), excluding `rate_limited` attempts (which
-- never did any work) and in-flight runs. It is the closest thing to a stable process metric here:
-- a run's wall-clock duration does not depend on how many cards are queued.
--
-- What the chart says, before you plot it: the baseline sits at 6.5–9.6 min/day with limits at
-- 4.61 / 11.62. November's days land at 5.5 (inside), 2.4 and 1.4 min — the last two below the
-- lower limit, on the same side, on consecutive monitored days. Two consecutive points beyond a
-- limit is a *shift*, not noise: that verdict is the week-8 check-in artifact. The cause (a
-- model/profile change?) is week 9's question.
--
-- Also in the output, and worth writing down: the 10-12 day reads as a signal *above* the UCL, but
-- it rests on a single run (n_runs = 1). A point that far out on n=1 is a measurement artefact, not
-- evidence — which is why it was excluded from the baseline but still shown.
--
-- Caveat to state in your write-up: six baseline days is a thin basis for limits. Say provisional.
--
-- Run:  bin/duckdb -no-agent -c ".read sql/w08_control_chart_inputs.sql"

WITH daily AS (
    SELECT CAST(started_at_utc AS DATE) AS day_utc,
           count(*)                     AS n_runs,
           median(duration_minutes)     AS median_minutes
    FROM 'data/raw/kanban_runs.parquet'
    WHERE status NOT IN ('rate_limited', 'running')
      AND duration_minutes IS NOT NULL
    GROUP BY 1
), baseline AS (
    -- n_runs >= 10: a day with a handful of runs has a noisy median and would inflate the limits
    -- (the one-run day on 10-12 sat at 17.7 min and, left in, widened the UCL to 20.8).
    SELECT avg(median_minutes)         AS mean_m,
           stddev_samp(median_minutes) AS sd_m,
           count(*)                    AS n_baseline_days
    FROM daily
    WHERE day_utc < DATE '2026-11-01'
      AND n_runs >= 10
)
SELECT
    d.day_utc,
    d.n_runs,
    round(d.median_minutes, 2)                                  AS median_run_minutes,
    round(b.mean_m, 2)                                          AS centre_line,
    round(b.mean_m + 3 * b.sd_m, 2)                             AS ucl_3sigma,
    round(greatest(b.mean_m - 3 * b.sd_m, 0), 2)                AS lcl_3sigma,
    CASE
        WHEN d.median_minutes > b.mean_m + 3 * b.sd_m THEN 'signal: above UCL'
        WHEN d.median_minutes < b.mean_m - 3 * b.sd_m THEN 'signal: below LCL'
        ELSE 'noise (within limits)'
    END                                                         AS verdict,
    CASE WHEN d.day_utc < DATE '2026-11-01' THEN 'baseline' ELSE 'monitor' END AS period,
    b.n_baseline_days
FROM daily d CROSS JOIN baseline b
ORDER BY d.day_utc;
