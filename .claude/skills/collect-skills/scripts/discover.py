#!/usr/bin/env python3
"""Discover GitHub owner, sibling repos, and remote skill folders.

Subcommands:

  owner
      Print the owner segment of `git remote get-url origin`.

  repos <owner>
      Print non-archived, non-fork repos for the owner, one per line as
      "<owner>/<repo>". Excludes the current repo (well-worn-tools).

  skills <owner>/<repo>
      Print skill names found under `.claude/skills/*/SKILL.md` on the
      repo's default branch.

All subcommands require an authenticated `gh` CLI.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys

CURRENT_REPO_NAME = "well-worn-tools"
GH_MISSING_HINT = (
    "error: `gh` CLI not found. In Claude Code cloud environments (web / iOS), "
    "`gh` is not available — use the MCP-Only Flow at the bottom of SKILL.md."
)


def _require_gh() -> None:
    if shutil.which("gh") is None:
        sys.exit(GH_MISSING_HINT)


ORIGIN_PATTERNS = (re.compile(r"github\.com[:/]+(?P<owner>[^/]+)/(?P<repo>[^/.]+?)(?:\.git)?$"),)


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


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


def cmd_repos(args: argparse.Namespace) -> int:
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


def cmd_skills(args: argparse.Namespace) -> int:
    _require_gh()
    owner_repo = args.owner_repo
    listing = subprocess.run(
        ["gh", "api", f"repos/{owner_repo}/contents/.claude/skills"],
        capture_output=True,
        text=True,
        check=False,
    )
    if listing.returncode != 0:
        # Treat missing directory as "no skills" rather than an error.
        return 0

    entries = json.loads(listing.stdout)
    if not isinstance(entries, list):
        return 0

    for entry in entries:
        if entry.get("type") != "dir":
            continue
        name = entry["name"]
        # Confirm there is a SKILL.md inside.
        check = subprocess.run(
            ["gh", "api", f"repos/{owner_repo}/contents/.claude/skills/{name}/SKILL.md"],
            capture_output=True,
            text=True,
            check=False,
        )
        if check.returncode == 0:
            print(name)
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("owner", help="print owner of current git origin")

    p_repos = sub.add_parser("repos", help="list candidate sibling repos for owner")
    p_repos.add_argument("owner")
    p_repos.add_argument("--limit", type=int, default=1000)
    p_repos.add_argument("--include-archived", action="store_true")
    p_repos.add_argument("--include-forks", action="store_true")

    p_skills = sub.add_parser("skills", help="list skill names in remote repo")
    p_skills.add_argument("owner_repo", help="<owner>/<repo>")

    args = parser.parse_args(argv)
    handlers = {"owner": cmd_owner, "repos": cmd_repos, "skills": cmd_skills}
    return handlers[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
