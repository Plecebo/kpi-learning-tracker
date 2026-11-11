#!/usr/bin/env bash
# fetch_gitea.sh — pull commit history from any Gitea host into data/raw/gitea/*.json
#
# Only PUBLIC repos are reachable without a credential (that is the default and needs nothing).
# If GITEA_TOKEN is exported in the environment, private repos are included too — the token is
# read by name from the environment, never written into this file or into the snapshots.
set -euo pipefail

API="${GITEA_API:-}"
if [[ -z "$API" ]]; then
  echo "GITEA_API is not set — copy .env.example to .env and fill it in" >&2
  exit 1
fi
OUT="data/raw/gitea"
PER_REPO="${PER_REPO:-200}"

mkdir -p "$OUT"

auth=()
if [[ -n "${GITEA_TOKEN:-}" ]]; then
  auth=(-H "Authorization: token ${GITEA_TOKEN}")
fi

# 1. which repos can we see?
curl -s -m 20 "${auth[@]}" "$API/repos/search?limit=50&sort=updated&order=desc" \
  -o "$OUT/_repos.json" -w "repos: %{http_code}\n"

# 2. one file per repo — commits, newest first. One curl per repo, no wrapper.
mapfile -t repos < <(jq -r '.data[] | select(.empty == false) | .full_name' "$OUT/_repos.json")

echo "fetching commits for ${#repos[@]} repo(s)"
for repo in "${repos[@]}"; do
  slug="${repo//\//__}"
  curl -s -m 30 "${auth[@]}" \
    "$API/repos/${repo}/commits?limit=${PER_REPO}&stat=false&verification=false" \
    -o "$OUT/commits__${slug}.json" -w "  ${repo}: %{http_code}\n"
done

echo "done -> $OUT (convert with: bin/duckdb -init scripts/gitea_to_parquet.sql -c 'select 1')"
