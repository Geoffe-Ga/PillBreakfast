#!/usr/bin/env python3
"""Discovery helper for distribute-skills.

Subcommands:

  owner
      Print the owner of the current git origin.

  local
      Print local skill names from `.claude/skills/` whose frontmatter does
      NOT carry `metadata.distribute: false`. One name per line.

  targets <owner>
      Print non-archived, non-fork repos under <owner> as `<owner>/<repo>`.
      Excludes the current repo (well-worn-tools).

The `local` subcommand is the canonical source of truth for "what's
distributable" — everything else in the skill defers to it.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

CURRENT_REPO_NAME = "well-worn-tools"
GH_MISSING_HINT = (
    "error: `gh` CLI not found. In Claude Code cloud environments (web / iOS), "
    "`gh` is not available — use the MCP-Only Flow at the bottom of SKILL.md."
)


def _require_gh() -> None:
    if shutil.which("gh") is None:
        sys.exit(GH_MISSING_HINT)


SKILLS_DIR = Path(".claude/skills")
ORIGIN_PATTERNS = (re.compile(r"github\.com[:/]+(?P<owner>[^/]+)/(?P<repo>[^/.]+?)(?:\.git)?$"),)
FRONTMATTER_BLOCK = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def _is_distributable(skill_md: Path) -> bool:
    """Return True unless the skill's frontmatter sets metadata.distribute: false.

    Best-effort YAML parse without the yaml package: looks for a `metadata:`
    block and within it a `distribute:` key whose scalar value is `false`.
    """
    if not skill_md.is_file():
        return False
    text = skill_md.read_text()
    match = FRONTMATTER_BLOCK.match(text)
    if not match:
        return True
    body = match.group(1)
    in_metadata = False
    for raw in body.splitlines():
        if raw.startswith("metadata:"):
            in_metadata = True
            continue
        if in_metadata:
            if raw and not raw.startswith(" "):
                in_metadata = False
                continue
            stripped = raw.strip()
            if stripped.startswith("distribute:"):
                value = stripped.split(":", 1)[1].strip().lower().strip("'\"")
                return value not in {"false", "no", "0"}
    return True


def cmd_owner(_args: argparse.Namespace) -> int:
    try:
        url = _run(["git", "remote", "get-url", "origin"]).stdout.strip()
    except subprocess.CalledProcessError as exc:
        print(f"error: git remote get-url origin failed: {exc.stderr.strip()}", file=sys.stderr)
        return 2
    for pattern in ORIGIN_PATTERNS:
        match = pattern.search(url)
        if match:
            print(match.group("owner"))
            return 0
    print(f"error: cannot parse owner from origin URL: {url}", file=sys.stderr)
    return 2


def cmd_local(_args: argparse.Namespace) -> int:
    if not SKILLS_DIR.is_dir():
        print(f"error: {SKILLS_DIR} not found — run from well-worn-tools repo root", file=sys.stderr)
        return 2
    for path in sorted(SKILLS_DIR.iterdir()):
        skill_md = path / "SKILL.md"
        if not skill_md.is_file():
            continue
        if _is_distributable(skill_md):
            print(path.name)
    return 0


def cmd_targets(args: argparse.Namespace) -> int:
    _require_gh()
    try:
        result = _run(
            [
                "gh",
                "repo",
                "list",
                args.owner,
                "--limit",
                str(args.limit),
                "--json",
                "name,nameWithOwner,isArchived,isFork,defaultBranchRef",
            ]
        )
    except subprocess.CalledProcessError as exc:
        print(f"error: gh repo list failed: {exc.stderr.strip()}", file=sys.stderr)
        return 2

    repos = json.loads(result.stdout)
    for repo in repos:
        if repo["name"] == CURRENT_REPO_NAME:
            continue
        if repo["isArchived"] and not args.include_archived:
            continue
        if repo["isFork"] and not args.include_forks:
            continue
        if not repo.get("defaultBranchRef"):
            continue
        print(repo["nameWithOwner"])
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("owner", help="print owner of current git origin")
    sub.add_parser("local", help="list distributable local skill names")

    p_targets = sub.add_parser("targets", help="list candidate target repos")
    p_targets.add_argument("owner")
    p_targets.add_argument("--limit", type=int, default=1000)
    p_targets.add_argument("--include-archived", action="store_true")
    p_targets.add_argument("--include-forks", action="store_true")

    args = parser.parse_args(argv)
    handlers = {"owner": cmd_owner, "local": cmd_local, "targets": cmd_targets}
    return handlers[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
