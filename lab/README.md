# KPI Lab — practice environment

The hands-on half of the KPI learning track. Sibling docs:

| Doc | What it is |
|---|---|
| `../docs/kpi-development-frameworks.md` | the framework research (SMART, BSC, OKR, GQM) |
| `../docs/kpi-learning-roadmap.md` | the 12-week roadmap (the "what") |
| `../DESIGN.md` | the accountability system (the "did you do it") |
| `docs/EXERCISES.md` | **week → exercise → query** map, so each week has something runnable |

The lab exists so every week's exercise runs on **real estate data**, not toy numbers:
agent/kanban task history, Gitea commit history, and the Home Assistant recorder's long sensor
series (energy, temperature, humidity). The kanban and Gitea sources are local and credential-free;
the recorder is read over a Postgres DSN taken from the environment (see `.env.example`).

## Quickstart

```bash
cd lab
cp .env.example .env   # set KANBAN_DB and GITEA_API (see .env.example)
make setup     # venv + python deps + pinned duckdb CLI
make data      # (re)build data/raw/*.parquet from the configured sources
make check     # smoke test: imports, dataset row counts, sanity assertions
make lab       # JupyterLab on http://127.0.0.1:8888
```

`make check` is the gate: if it passes, the environment is usable.

## What's here

```
lab/
├── bin/duckdb              # pinned DuckDB CLI (v2.0.0) — not committed, `make tools` refetches
├── .venv/                  # python 3.13 + duckdb, pandas, matplotlib, seaborn, statsmodels, jupyterlab
├── data/raw/               # parquet snapshots — not committed, `make data` rebuilds
│   ├── kanban_tasks.parquet
│   ├── kanban_runs.parquet
│   ├── kanban_events_daily.parquet
│   ├── gitea_commits.parquet
│   ├── ha_statistics_hourly.parquet
│   ├── ha_statistics_daily.parquet
│   ├── ha_entity_catalog.parquet
│   └── ha_short_term_5min.parquet    # optional (HA_SHORT_TERM=1)
├── data/README.md          # data dictionary: columns, grain, source, refresh
├── scripts/
│   ├── fetch_duckdb.sh     # download the CLI (pinned version, reports what it installed)
│   ├── export_kanban.sql   # sqlite kanban.db  -> parquet
│   ├── fetch_gitea.sh      # public Gitea API -> json -> parquet
│   ├── fetch_ha.py         # HA recorder Postgres -> raw parquet (read-only, coverage gate)
│   ├── ha_to_parquet.sql   # raw HA rows -> the four ha_*.parquet datasets
│   ├── ha_entities.sql     # the allowlist (patterns + week annotations)
│   └── env_check.py        # the smoke test `make check` runs
├── sql/                    # starter queries, one per exercise week
├── notebooks/              # 00_environment_check.ipynb proves the stack works
└── docs/EXERCISES.md       # week -> exercise -> query mapping
```

## Two ways to query

**DuckDB CLI** (fast, no notebook needed):

```bash
bin/duckdb -no-agent -c "SELECT * FROM 'data/raw/kanban_tasks.parquet' LIMIT 5;"
bin/duckdb -no-agent -c ".read sql/w08_control_chart_inputs.sql"
```

**Jupyter / pandas** (for charts and the write-ups):

```bash
make lab     # then open notebooks/00_environment_check.ipynb
```

## Data sources and how they refresh

| Dataset | Source (read-only) | Grain | Refresh |
|---|---|---|---|
| `kanban_tasks` | `$KANBAN_DB` → `tasks` | one row per board task | `make data` |
| `kanban_runs` | `$KANBAN_DB` → `task_runs` | one row per worker attempt | `make data` |
| `kanban_events_daily` | `$KANBAN_DB` → `task_events` | event counts per day per kind | `make data` |
| `gitea_commits` | `$GITEA_API` (public repos) | one row per commit | `make data` |
| `ha_statistics_hourly` | HA recorder Postgres `statistics` | one row per (entity, UTC hour) | `make data-ha` |
| `ha_statistics_daily` | the hourly file, re-bucketed | one row per (entity, local day) | `make data-ha` |
| `ha_entity_catalog` | the allowlist + coverage | one row per entity | `make data-ha` |
| `ha_short_term_5min` | `statistics_short_term` (5-min, 30 d) | one row per (entity, 5 min) | `make data-ha` + `HA_SHORT_TERM=1` |

The kanban DB is the *live* board, so the snapshots are point-in-time. Each parquet file carries a
`_snapshot_utc` column — quote it when you write a baseline down, or a later refresh will silently
move your numbers.

### Home Assistant recorder (wired; DSN from the environment)

The long sensor history — whole-home energy, temperature, humidity — is the richest source in the lab,
and it is now wired: `make data-ha` pulls the ~30 entities in `scripts/ha_entities.sql` from the recorder
Postgres into `data/raw/ha_*.parquet`. The DSN is read **only** from the `HA_POSTGRES_URL` environment
variable (supplied by whoever runs the fetch) and opened read-only; it is never written to a file,
a parquet, or a doc:

```bash
export HA_POSTGRES_URL="postgresql://user:pass@host:5432/hass"   # from your own secret store
make data-ha          # or `make data`, which includes it
```

Two pitfalls worth knowing (see `data/README.md` for the full semantics):

- The recorder's REST history API (`/api/history/period`) silently clamps to 24 h without an explicit
  `end_time` — bulk work must go through the Postgres `statistics` table, which is the only multi-year
  surface (`states` and `statistics_short_term` retain only 30 days).
- `sum` is a cumulative counter, so the hourly value is the reset-aware Δ`sum`, never `state`. The
  extractor encodes this and fails loudly if a requested series is absent or under-covered.

## Conventions that keep the exercises honest

- **Snapshot or it didn't happen.** Downstream of a refresh, a metric changes. Record
  `_snapshot_utc` next to any baseline you claim (week 7's operational-definition card has a field for it).
- **One question per query file.** Each `sql/wNN_*.sql` answers exactly one week's exercise; if a
  query grows two purposes, split it.
- **Read-only against the lab.** Everything here reads (`READ_ONLY` sqlite attach, GET-only API).
  Nothing in the lab writes back to the board, Gitea, or HA.
