#!/usr/bin/env python3
"""Fail if a document refers to a path that is not in the repository.

Two checks, because this repository is mostly prose and SQL and its documents are the product:

1. **Relative Markdown links** — `[text](path)` must resolve. A dead link ships silently.
2. **Backticked file references** — `` `docs/kpi-learning-roadmap.md` `` must resolve too.

Check 2 exists because the failure that motivated this script was not a link. The READMEs pointed at
`../2026-11-04-kpi-learning-roadmap.md` in a parent directory, inside backticks, so a link-only check
passed while two of the repository's four parts lived outside it: the clone looked complete and was
not. A reference to a path outside the repository (`~/…`, `/abs/…`) is therefore a failure in its own
right — the repository has to be readable after a clone, on a machine that has never seen the
author's home directory.

Skipped on purpose: URLs and anchors, shell commands and globs (they carry spaces or metacharacters),
placeholder patterns (`week-NN.md`, `wNN_*.sql`), and generated artifacts (`*.parquet`, which
`make data` creates) — those are outputs, not files the repository claims to ship.

    python3 scripts/check_links.py

Exit status: 0 when every reference resolves, 1 otherwise.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
INLINE = re.compile(r"`([^`\n]+)`")
SKIP_SCHEMES = ("http://", "https://", "mailto:", "#", "data:")

# Extensions naming a file a reader is expected to find in the clone.
KNOWN_EXTS = {
    ".md", ".sql", ".py", ".sh", ".yml", ".yaml", ".ipynb", ".txt", ".json",
    ".toml", ".cfg", ".ini", ".example", ".csv", ".service", ".conf",
}
# Extensions produced by `make data` / `make setup` — outputs, not shipped files.
GENERATED_EXTS = {".parquet", ".db", ".duckdb", ".lock"}
# Files the reader creates as they work through the plan — check-ins are the product, not shipped.
READER_CREATED = re.compile(r"^(weeks/)?week-\d{2}\.md$")

# Shell/pattern syntax: a reference carrying any of these is a command or a glob, not a path.
NOT_A_PATH = set(" <>(){}|*?$\"'=,")
PLACEHOLDER = re.compile(r"(NN|NNN|\bN\b|…|X{2,})")


def markdown_files() -> list[Path]:
    return sorted(
        p
        for p in ROOT.rglob("*.md")
        if ".git" not in p.parts and ".venv" not in p.parts and "tmp" not in p.parts
    )


def _show(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def _inside_root(path: Path) -> bool:
    try:
        path.relative_to(ROOT)
    except ValueError:
        return False
    return True


def check_links(path: Path, text: str) -> list[str]:
    problems: list[str] = []
    for target in LINK.findall(text):
        if target.startswith(SKIP_SCHEMES):
            continue
        clean = target.split("#", 1)[0]
        if not clean:
            continue
        resolved = (path.parent / clean).resolve()
        if not _inside_root(resolved):
            # A link that escapes the clone can still resolve on the author's machine, which is
            # exactly how the roadmap lived outside this repository for a while. Always a failure.
            problems.append(f"{_show(path)}: link {target!r} points outside the repository")
        elif not resolved.exists():
            problems.append(f"{_show(path)}: link {target!r} -> missing {_show(resolved)}")
    return problems


def _resolves(from_dir: Path, token: str) -> bool:
    """True if `token` resolves from `from_dir` or any ancestor up to (and including) the root.

    Documents in `lab/docs/` refer to lab-relative paths (`sql/w08_…sql`) and root-relative paths
    (`docs/…`) in the same breath; both are true statements about the clone, so both must resolve.
    A path that lands outside the root never counts, even when it happens to exist on this machine.
    """
    base = from_dir
    while True:
        candidate = (base / token).resolve()
        if _inside_root(candidate) and candidate.exists():
            return True
        if base == ROOT or base.parent == base:
            return False
        base = base.parent


def check_inline_references(path: Path, text: str) -> list[str]:
    problems: list[str] = []
    for raw in INLINE.findall(text):
        token = raw.strip()
        if not token or token.startswith(SKIP_SCHEMES):
            continue
        if any(ch in NOT_A_PATH for ch in token) or PLACEHOLDER.search(token):
            continue
        token = token.split("#", 1)[0].rstrip(":.,;")
        if not token:
            continue
        # A reference whose last segment carries no extension names a directory: a convention
        # (`sql/`, `notebooks/`) or an output of `make data` (`data/raw/`), which cannot exist in a
        # clone. Files are the claim worth checking; directories are documented, not shipped.
        stem = Path(token.rstrip("/"))
        if not stem.suffix:
            continue
        suffix = stem.suffix.lower()
        if suffix in GENERATED_EXTS or READER_CREATED.match(token):
            continue
        if suffix not in KNOWN_EXTS:
            continue

        if token.startswith("~/") or token.startswith("/"):
            problems.append(f"{_show(path)}: reference {raw!r} points outside the repository")
            continue

        if not _resolves(path.parent, token):
            problems.append(
                f"{_show(path)}: reference {raw!r} -> missing {_show((path.parent / token).resolve())}"
            )
    return problems


def main() -> int:
    files = markdown_files()
    problems: list[str] = []
    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        problems += check_links(f, text)
        problems += check_inline_references(f, text)
    for problem in problems:
        print(problem)
    print(f"{len(files)} markdown file(s) checked, {len(problems)} broken reference(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
