# Week → exercise → query

Each week of the roadmap (`docs/kpi-learning-roadmap.md`) has a check-in artifact.
This table says which part of the lab produces it. Rows marked **manual** are judgement work — the
lab gives you the numbers, not the verdict.

| Week | Framework | Lab artifact | Query / notebook | Status |
|---|---|---|---|---|
| 1 | metric literacy (leading/lagging, vanity/actionable) | 5-metric inventory with labels + 3 rewrites | `sql/w01_metric_inventory.sql` (numbers) + **manual** (labels) | runnable |
| 2 | SMART | 10 candidate KPIs with measured evidence + 5-criterion pass/fail | `sql/w02_smart_kpis.sql` | runnable, 5 rows need your judgement |
| 3 | Balanced Scorecard | 4-perspective scorecard, ≤12 measures | **manual** — no query; map each measure to an existing dataset | not automated on purpose |
| 4 | OKR | 1 Objective + 3 KRs with baselines | `sql/w04_okr_baseline.sql` | runnable |
| 5 | GQM | one full goal→question→metric trace | `sql/w05_gqm_trace.sql` | runnable |
| 6 | North Star + guardrails | 1 North Star + 3 guardrails with rationale | **manual**; `w04`'s guardrail row is the model | not automated on purpose |
| 7 | measurement design | one operational-definition card (formula, source, frequency, owner, floor/ceiling, snapshot) | template in the check-in; every `data/raw` dataset has `_snapshot_utc` for the last field | template |
| 8 | variation / signal vs noise | control chart + signal verdict on three differently-behaved series — the whole-home March 2026 step, the stable dehumidifier ("no signal"), the sparse carport | `data/raw/ha_statistics_daily.parquet` (the real case) + `sql/w08_control_chart_inputs.sql` (kanban mechanics) | runnable |
| 9 | before/after & causality | baseline, comparison, confounders on the 2026-03-07→03-26 episode (weather-normalised) **and** the heat-pump null result | `data/raw/ha_statistics_daily.parquet` + `sql/w09_before_after.sql` (the rate-limit episode) | runnable |
| 10 | dashboards & communication | dashboard + one-page "state of the metric" | `notebooks/` for the chart; Grafana is the lab's, not wired here | manual + notebook |
| 11 | capstone | end-to-end pass (this is the portfolio piece) | combine `w05` + `w07` card + `w08` + `w09` | — |
| 12 | consolidate & present | consolidation note + 5-min talk | **manual** | — |

## Why three rows are deliberately not automated

Weeks 3, 6 and 12 are judgement weeks: the frameworks are about *choosing* measures and defending
them, and a query that "produces a Balanced Scorecard" would produce a fiction. The lab's job is to
make the evidence cheap so the judgement gets the time.

## Running one

```bash
bin/duckdb -no-agent -c ".read sql/w08_control_chart_inputs.sql"
```

Or in a notebook: `con.sql(open('../sql/w08_control_chart_inputs.sql').read()).df()`.

## What each week needs from the data, and whether it's there

| Need | Present? |
|---|---|
| A throughput metric with ≥4 weeks of history | yes — `kanban_tasks` (36 days at first build) |
| A rework/quality metric | yes — `kanban_runs` (`outcome`, `had_error`) |
| A genuinely stable process metric for SPC | yes — median run duration per day (`w08`) |
| A real intervention to test before/after on | yes — the 2026-10-05 rate-limit episode (`w09`) |
| A long sensor time series (temps, power, energy) | yes — `ha_statistics_hourly.parquet` / `ha_statistics_daily.parquet`, 22 months at hourly grain |
| PR review/merge latency | **thin** — only public Gitea repos are visible anonymously (10 commits) |

The second row is the remaining honest gap: it does not block weeks 1–9, and it would improve week 7's
"measure the process" exercise. (It is a separate, known defect in `scripts/fetch_gitea.sh`, out of scope
for the HA-recorder change — see the tracker issue.)
