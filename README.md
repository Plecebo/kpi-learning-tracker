# KPI Learning Track

A 3-month track for learning to **develop KPIs that trace to a real goal** and **measure whether a
change actually had impact** — practised on live estate data, not toy examples.

Four parts, each with one job:

| Path | What it is |
|---|---|
| `../2026-11-04-kpi-development-frameworks.md` | framework research: SMART, Balanced Scorecard, OKR, GQM (plus North Star / Performance Prism / 4DX) |
| `../2026-11-04-kpi-learning-roadmap.md` | the 12-week roadmap — readings, weekly practice, a check-in artifact per week |
| `DESIGN.md`, `ledger.md`, `rubric.md`, `checkin-template.md`, `weeks/`, `mastery-tests.md` | the accountability system — did the work happen, and did it get better |
| `lab/` | **the practice environment**: venv, DuckDB, Jupyter, and parquet snapshots of real estate data (`lab/README.md`) |

## Start here

```bash
cd lab
make check     # proves the environment is ready (imports, datasets, sanity assertions)
make lab       # JupyterLab, then open notebooks/00_environment_check.ipynb
```

`lab/docs/EXERCISES.md` maps each roadmap week to a runnable query. Weeks 1–9 have real SQL today;
weeks 3, 6 and 12 are judgement weeks by design.

## Progress

Progress lives in one place: `ledger.md`, one row per week. The roadmap is the "what", the ledger is
the "did it happen".

## What this is grounded in

- Framework research is cited in `../2026-11-04-kpi-development-frameworks.md` (Doran 1981, Kaplan &
  Norton HBR 1992, Basili et al. 1994, Doerr/Grove).
- Every dataset in `lab/data/raw` is a point-in-time snapshot of a live local source, documented
  column-by-column in `lab/data/README.md`. Nothing is synthetic.
