#!/usr/bin/env bash
# fetch_duckdb.sh — download the pinned DuckDB CLI into bin/ (not committed: 77 MB binary).
# Usage: bash scripts/fetch_duckdb.sh v2.0.0
set -euo pipefail

VERSION="${1:-v2.0.0}"
ASSET="duckdb-cli-linux-amd64.tar.gz"   # release asset naming from DuckDB 2.0 on
URL="https://github.com/duckdb/duckdb/releases/download/${VERSION}/${ASSET}"

mkdir -p bin tmp
if [[ -x bin/duckdb && "$(bin/duckdb --version 2>/dev/null | head -1 | awk '{print $1}')" == "${VERSION}" ]]; then
  echo "duckdb ${VERSION} already present in bin/"
  exit 0
fi

echo "fetching ${URL}"
curl -sSL -m 300 -o tmp/duckdb_cli.tar.gz "$URL"
tar -xzf tmp/duckdb_cli.tar.gz -C bin
chmod +x bin/duckdb
bin/duckdb --version
