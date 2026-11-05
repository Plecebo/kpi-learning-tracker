# Data dictionary

Every dataset here is a **point-in-time snapshot** of a live estate source, built by `make data`.
Rebuilds move the numbers, so quote `_snapshot_utc` whenever you record a baseline.

All timestamps are UTC (`TIMESTAMP WITH TIME ZONE`). Nothing here is written back to the source.

---

## `kanban_tasks.parquet` — one row per Hermes kanban task

Source: `$KANBAN_DB`, table `tasks` (attached `READ_ONLY`).
Grain: task. Coverage: the whole board since 2026-09-29 (~36 days at first build).

| Column | Type | Notes |
|---|---|---|
| `task_id` | VARCHAR | `t_xxxxxxxx` |
| `title` | VARCHAR | truncated to 160 chars; **task bodies are deliberately excluded** (they can carry personal detail) |
| `assignee` | VARCHAR | profile that owns the card; NULL for unassigned |
| `status` | VARCHAR | live board state: `todo`, `ready`, `running`, `review`, `blocked`, `done`, `archived`, … |
| `priority` | INTEGER | dispatcher tiebreaker |
| `created_by` | VARCHAR | `dashboard`, `auto-decomposer`, `cli`, … |
| `created_at_utc` | TIMESTAMPTZ | |
| `started_at_utc` | TIMESTAMPTZ | first claim |
| `completed_at_utc` | TIMESTAMPTZ | NULL if never completed |
| `lead_time_hours` | DOUBLE | `completed - created`; NULL if not completed |
| `cycle_time_hours` | DOUBLE | `completed - started` |
| `consecutive_failures` | INTEGER | retry counter at snapshot time |
| `block_kind` | VARCHAR | typed block reason (`dependency`, `needs_input`, `capability`, `transient`) |
| `block_recurrences` | INTEGER | unblock-loop counter |
| `goal_mode` | INTEGER | 1 = worker ran in the goal loop |
| `model_override` | VARCHAR | per-task model pin, NULL = profile default |
| `completion_contract` | VARCHAR | `local-only` / PR contract |
| `_snapshot_utc` | TIMESTAMPTZ | when this parquet was built |

**Caveats worth knowing before you compute anything:**
- `status` is *current* state, not history — use `completed_at_utc` for throughput, not `status = 'done'`.
- Archived cards keep `completed_at_utc`; filtering on `status` alone will undercount.
- Lead time is wall-clock, so an overnight human wait and a queue wait look identical. That is a
  **measurement-design discussion** (week 7), not a bug to fix silently.

---

## `kanban_runs.parquet` — one row per worker attempt

Source: `$KANBAN_DB`, table `task_runs`. Grain: attempt. 5,928 rows at first build.

| Column | Notes |
|---|---|
| `run_id`, `task_id`, `profile` | |
| `status` | `done`, `blocked`, `rate_limited`, `crashed`, `timed_out`, `running`, … |
| `started_at_utc`, `ended_at_utc` | |
| `duration_minutes` | `ended - started` |
| `outcome` | `completed`, `blocked`, `review_requested`, `changes_requested`, `rate_limited`, … |
| `had_error` | boolean; true for `rate_limited`/`crashed`/`timed_out` runs |
| `error_excerpt` | first 200 chars of the error text |
| `_snapshot_utc` | |

This is the **rework / first-pass-yield** dataset. `status = 'rate_limited'` (5,082 attempts) is a
real historical episode, not noise — it makes an excellent before/after case study for week 9.

---

## `kanban_events_daily.parquet` — event volume per day per kind

Source: `$KANBAN_DB`, table `task_events` (188k raw events → grouped).
Grain: `(event_date_utc, kind)`. Columns: `event_date_utc`, `kind`, `n_events`, `n_tasks`, `_snapshot_utc`.

Kinds and what they mean for KPI work:

| kind | use |
|---|---|
| `created`, `claimed`, `spawned`, `completed` | the throughput series (arrivals vs departures) |
| `heartbeat` | liveness; a gap is an outage signal |
| `rate_limited` | the quota-wall episode |
| `respawn_guarded` | dispatcher suppressed a re-spawn (dominates volume — filter it out unless you're studying the guard) |
| `promoted`, `dependency_wait` | queue dynamics, useful for cycle-time decomposition |

---

## `gitea_commits.parquet` — commit history, public repos only

Source: `your-gitea.example.com` public API (anonymous). Grain: commit.
Columns: `repo`, `sha`, `author_name`, `author_email`, `authored_at_utc`, `committed_at_utc`, `message`, `gitea_login`, `_snapshot_utc`.

**Thin on purpose-of-design:** only two repos are public (`larry/hermes-deployment`, `larry/smk-branding`
→ 10 commits). The volume lives in private repos. To include them, export a Gitea token and re-run:

```bash
export GITEA_TOKEN=<token>      # read by name from the env; never written to disk here
make data-gitea
```

The token is never stored by this lab — `scripts/fetch_gitea.sh` only reads it from the environment.

---

## Not included (and why)

- **HA recorder sensor history** (the richest series): needs a Postgres credential. See the README's
  "optional richer source" — export a CSV from HA and drop it in `data/raw/`.
- **Task bodies, comments, and messages**: real text, potentially personal. Excluded from the snapshot;
  query the live DB read-only if a specific exercise needs it.
