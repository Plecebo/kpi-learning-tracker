# KPI lab — one-command lifecycle. Run from this directory.
#
#   make setup   venv + python deps + jupyter kernel + pinned duckdb CLI
#   make data    snapshot the lab's real data into data/raw/*.parquet
#   make check   smoke test (imports + datasets + sanity assertions)
#   make lab     JupyterLab
#   make query Q="select 1;"   one-off DuckDB query

SHELL   := /bin/bash
UV      ?= uv
PY      := .venv/bin/python
DUCKDB  := bin/duckdb -no-agent
DUCKDB_VERSION := v2.0.0

# Load .env if present (gitignored): KANBAN_DB, GITEA_API, GITEA_TOKEN.
# Each is also overridable as a real environment variable.
-include .env
export

.PHONY: setup venv deps kernel tools data data-kanban data-gitea check lab query clean-note

setup: venv deps tools kernel
	@echo "setup complete — now: make data"

venv:
	@test -x $(PY) || $(UV) venv --python 3.13 .venv

deps: venv
	$(UV) pip install --python $(PY) -r requirements.txt

kernel: venv
	@$(PY) -m ipykernel install --user --name kpi-lab --display-name "Python 3 (kpi-lab)"

tools:
	@bash scripts/fetch_duckdb.sh $(DUCKDB_VERSION)

data: data-kanban data-gitea
	@echo "datasets rebuilt:"
	@ls -la data/raw/*.parquet

data-kanban: tools
	@test -n "$(KANBAN_DB)" || { echo "KANBAN_DB is not set — copy .env.example to .env and fill it in"; exit 1; }
	$(DUCKDB) -init scripts/export_kanban.sql -c "select 'kanban snapshot written'"

data-gitea: tools
	bash scripts/fetch_gitea.sh
	$(DUCKDB) -init scripts/gitea_to_parquet.sql -c "select 'gitea snapshot written'"

check: venv
	$(PY) scripts/env_check.py

lab: venv
	.venv/bin/jupyter lab --no-browser --port 8888

query: tools
	$(DUCKDB) -c "$(Q)"

clean-note:
	@echo "data/raw/*.parquet and .venv/ are disposable: 'make setup && make data' rebuilds both."
