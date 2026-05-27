#!/usr/bin/env python3
"""Print the set of distributable skills missing from a target repo.

Usage:
    check_target.py <owner>/<repo>

Reads the local distributable set via discover.py's `local` subcommand
(so the same exemption logic applies), queries the target's
`.claude/skills/` over the GitHub API, and prints names that are local
but absent on the target. Empty output means the target is up to date.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

DISCOVER = Path(__file__).with_name("discover.py")
GH_MISSING_HINT = (
    "error: `gh` CLI not found. In Claude Code cloud environments (web / iOS), "
    "`gh` is not available — use the MCP-Only Flow at the bottom of SKILL.md."
)


def _require_gh() -> None:
    if shutil.which("gh") is None:
        sys.exit(GH_MISSING_HINT)


def _local_distributable() -> set[str]:
    result = subprocess.run(
        [sys.executable, str(DISCOVER), "local"],
        capture_output=True,
        text=True,
        check=True,
    )
    return {line for line in result.stdout.splitlines() if line.strip()}


def _remote_skills(owner_repo: str) -> set[str]:
    _require_gh()
    result = subprocess.run(
        ["gh", "api", f"repos/{owner_repo}/contents/.claude/skills"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        # Missing directory means an empty target — every local skill is missing.
        return set()
    payload = json.loads(result.stdout)
    if not isinstance(payload, list):
        return set()

    names: set[str] = set()
    for entry in payload:
        if entry.get("type") != "dir":
            continue
        name = entry["name"]
        check = subprocess.run(
            ["gh", "api", f"repos/{owner_repo}/contents/.claude/skills/{name}/SKILL.md"],
            capture_output=True,
            text=True,
            check=False,
        )
        if check.returncode == 0:
            names.add(name)
    return names


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("owner_repo", help="<owner>/<repo>")
    parser.add_argument("--json", action="store_true", help="emit as JSON object")
    args = parser.parse_args(argv)

    local = _local_distributable()
    remote = _remote_skills(args.owner_repo)
    missing = sorted(local - remote)

    if args.json:
        json.dump(
            {"target": args.owner_repo, "local": sorted(local), "remote": sorted(remote), "missing": missing},
            sys.stdout,
            indent=2,
        )
        sys.stdout.write("\n")
    else:
        for name in missing:
            print(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
