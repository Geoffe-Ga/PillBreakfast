#!/usr/bin/env python3
"""Fetch a single skill from a remote repo into a local destination directory.

Usage:
    fetch.py <owner>/<repo> <skill-name> <dest-dir> [--ref <branch-or-sha>]

Mirrors `.claude/skills/<skill-name>/SKILL.md` plus the `references/`,
`scripts/`, and `assets/` subtrees when present. Records provenance
(source repo, commit SHA, fetched-at timestamp) in `<dest-dir>/.provenance.json`
so the agent can attribute the import in its commit message.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

SKILL_SUBTREES = ("references", "scripts", "assets")
SKILL_ROOT_FILE = "SKILL.md"
GH_MISSING_HINT = (
    "error: `gh` CLI not found. In Claude Code cloud environments (web / iOS), "
    "`gh` is not available — use the MCP-Only Flow at the bottom of SKILL.md."
)


def _require_gh() -> None:
    if shutil.which("gh") is None:
        sys.exit(GH_MISSING_HINT)


def _api(path: str, ref: str | None = None) -> tuple[int, str]:
    cmd = ["gh", "api", path]
    if ref:
        cmd.extend(["-f", f"ref={ref}"])
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return result.returncode, result.stdout if result.returncode == 0 else result.stderr


def _resolve_default_branch(owner_repo: str) -> str:
    code, out = _api(f"repos/{owner_repo}")
    if code != 0:
        raise SystemExit(f"error: cannot read repo metadata for {owner_repo}: {out.strip()}")
    branch: str = json.loads(out)["default_branch"]
    return branch


def _resolve_commit_sha(owner_repo: str, ref: str) -> str:
    code, out = _api(f"repos/{owner_repo}/commits/{ref}")
    if code != 0:
        raise SystemExit(f"error: cannot resolve ref {ref} on {owner_repo}: {out.strip()}")
    sha: str = json.loads(out)["sha"]
    return sha


def _fetch_file(owner_repo: str, path: str, ref: str) -> bytes | None:
    code, out = _api(f"repos/{owner_repo}/contents/{path}", ref=ref)
    if code != 0:
        return None
    payload = json.loads(out)
    if isinstance(payload, dict) and payload.get("type") == "file":
        return base64.b64decode(payload["content"])
    return None


def _walk_tree(owner_repo: str, path: str, ref: str) -> list[dict[str, Any]]:
    """Return all file entries under `path`, recursively, via the tree API."""
    code, out = _api(f"repos/{owner_repo}/contents/{path}", ref=ref)
    if code != 0:
        return []
    payload = json.loads(out)
    if not isinstance(payload, list):
        return []

    files: list[dict[str, Any]] = []
    for entry in payload:
        if entry["type"] == "file":
            files.append(entry)
        elif entry["type"] == "dir":
            files.extend(_walk_tree(owner_repo, entry["path"], ref))
    return files


def fetch_skill(
    owner_repo: str,
    skill_name: str,
    dest: Path,
    ref: str | None = None,
) -> dict[str, Any]:
    _require_gh()
    resolved_ref = ref or _resolve_default_branch(owner_repo)
    sha = _resolve_commit_sha(owner_repo, resolved_ref)

    skill_root = f".claude/skills/{skill_name}"
    dest.mkdir(parents=True, exist_ok=True)

    # Required: SKILL.md
    skill_md = _fetch_file(owner_repo, f"{skill_root}/{SKILL_ROOT_FILE}", sha)
    if skill_md is None:
        raise SystemExit(f"error: no SKILL.md at {owner_repo}:{skill_root}")
    (dest / SKILL_ROOT_FILE).write_bytes(skill_md)

    # Optional subtrees
    files_copied = 1
    for subtree in SKILL_SUBTREES:
        for entry in _walk_tree(owner_repo, f"{skill_root}/{subtree}", sha):
            content = _fetch_file(owner_repo, entry["path"], sha)
            if content is None:
                continue
            relative = Path(entry["path"]).relative_to(skill_root)
            target = dest / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
            files_copied += 1

    provenance = {
        "source_repo": owner_repo,
        "source_path": skill_root,
        "ref": resolved_ref,
        "sha": sha,
        "fetched_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "files_copied": files_copied,
    }
    (dest / ".provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    return provenance


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("owner_repo", help="<owner>/<repo>")
    parser.add_argument("skill_name")
    parser.add_argument("dest", type=Path)
    parser.add_argument("--ref", default=None, help="branch or sha (default: repo's default branch)")
    args = parser.parse_args(argv)

    provenance = fetch_skill(args.owner_repo, args.skill_name, args.dest, args.ref)
    print(
        f"Fetched {args.skill_name} from {args.owner_repo}@{provenance['sha'][:7]} "
        f"into {args.dest} ({provenance['files_copied']} files)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
