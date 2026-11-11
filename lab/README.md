# KPI Lab — practice environment

The hands-on half of the KPI learning track. Sibling docs:

| Doc | What it is |
|---|---|
| `../docs/kpi-development-frameworks.md` | the framework research (SMART, BSC, OKR, GQM) |
| `../docs/kpi-learning-roadmap.md` | the 12-week roadmap (the "what") |
| `../DESIGN.md` | the accountability system (the "did you do it") |
| `docs/EXERCISES.md` | **week → exercise → query** map, so each week has something runnable |

The lab exists so every week's exercise runs on **real estate data**, not toy numbers:
agent/kanban task history, and Gitea commit history. Both are local, read-only, and need no credentials.

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
│   └── gitea_commits.parquet
├── data/README.md          # data dictionary: columns, grain, source, refresh
├── scripts/
│   ├── fetch_duckdb.sh     # download the CLI (pinned version, reports what it installed)
│   ├── export_kanban.sql   # sqlite kanban.db  -> parquet
│   ├── fetch_gitea.sh      # public Gitea API -> json -> parquet
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

The kanban DB is the *live* board, so the snapshots are point-in-time. Each parquet file carries a
`_snapshot_utc` column — quote it when you write a baseline down, or a later refresh will silently
move your numbers.

### Optional richer source (needs a credential, not wired)

A Home Assistant recorder Postgres has the long sensor history — the best data for weeks 8–9
(variation, before/after on a real sensor). The connection URL lives in that HA instance's secrets
file, not in this repository. To add it, export a CSV from that host and drop it in `data/raw/`;
nothing in the lab needs the password written down:

```bash
# in the HA container, with the dsn read from secrets.yaml at runtime
psql "$RECORDER_DSN" -c "\copy (SELECT * FROM states WHERE ...) TO STDOUT CSV HEADER" > ha_states.csv
```

That is deliberately left to whoever holds the credential — the lab stays credential-free.

## Conventions that keep the exercises honest

- **Snapshot or it didn't happen.** Downstream of a refresh, a metric changes. Record
  `_snapshot_utc` next to any baseline you claim (week 7's operational-definition card has a field for it).
- **One question per query file.** Each `sql/wNN_*.sql` answers exactly one week's exercise; if a
  query grows two purposes, split it.
- **Read-only against the lab.** Everything here reads (`READ_ONLY` sqlite attach, GET-only API).
  Nothing in the lab writes back to the board, Gitea, or HA.
