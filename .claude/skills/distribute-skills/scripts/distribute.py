#!/usr/bin/env python3
"""Open a PR on a target repo that adds the requested local skills and/or workflows.

Usage:
    distribute.py <owner>/<repo>
        [--skills <name> [<name> ...]]
        [--workflows <name> [<name> ...]]
        [--branch <branch-name>]
        [--source-skills-dir <path>]
        [--source-workflows-dir <path>]
        [--dry-run]

At least one of --skills or --workflows must be provided.

Behavior:
  1. Clones the target repo into a temporary directory at its default branch.
  2. Creates the feature branch.
  3. Copies each requested skill from <source-skills-dir> into the clone, and
     each requested workflow from <source-workflows-dir> into the clone's
     `.github/workflows/`. Refuses to overwrite either.
  4. Commits with provenance referencing the local well-worn-tools HEAD SHA.
  5. Pushes the branch and opens a PR via `gh pr create`.

`--dry-run` performs steps 1-4 only and prints what would happen, without
pushing or opening the PR. Always dry-run the first target.

Distributable workflows are governed by the DISTRIBUTABLE_WORKFLOWS allowlist
below, not by frontmatter (workflow YAML has none). Add a workflow here when
it is generic enough to be useful in every Geoffe-Ga repo.
"""

from __future__ import annotations

import argparse
import datetime as dt
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_SOURCE_DIR = Path(".claude/skills")
DEFAULT_WORKFLOWS_SOURCE_DIR = Path(".github/workflows")
DEFAULT_BRANCH_PREFIX = "add-well-worn-skills"
GH_MISSING_HINT = (
    "error: `gh` CLI not found. In Claude Code cloud environments (web / iOS), "
    "`gh` and local `git push` are not available — use the MCP-Only Flow at the "
    "bottom of SKILL.md (mcp__github__create_branch + push_files + create_pull_request)."
)

# Allowlist of workflows distribute can ship into target repos. Each entry maps
# the public name (used on the --workflows CLI) to the YAML filename inside the
# source workflows dir, plus prose used in the PR body so the maintainer knows
# what the workflow does and what setup it needs.
DISTRIBUTABLE_WORKFLOWS: dict[str, dict[str, str]] = {
    "iteration-trigger": {
        "filename": "iteration-trigger.yml",
        "summary": (
            "Posts a brief CI / Claude-verdict / next-action summary comment "
            "(as the repo owner via PAT) whenever CI completes fully green and "
            "a Claude review comment exists, capped at 10 self-posts per PR. "
            "Designed to wake a Claude Code mobile session via webhook so it "
            "can keep iterating on review feedback."
        ),
        "requires": (
            "(a) a workflow named `CI` in the target repo so the "
            "`workflow_run` trigger matches; "
            "(b) repo secret `GEOFFE_GA_PAT` — a PAT with "
            "`pull-requests: write` so the comment posts under the owner's "
            "identity rather than github-actions[bot]; "
            "(c) an active Claude review workflow whose comments include a "
            "`Verdict` line (see `claude-code-review.yml` upstream)."
        ),
    },
}


def _require_gh() -> None:
    if shutil.which("gh") is None:
        sys.exit(GH_MISSING_HINT)


def _run(cmd: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=check)


def _local_head_sha() -> str:
    return _run(["git", "rev-parse", "HEAD"]).stdout.strip()


def _read_description(skill_md: Path) -> str:
    """Pull the `description:` field from frontmatter for the PR body."""
    text = skill_md.read_text()
    if not text.startswith("---"):
        return ""
    end = text.find("\n---\n", 3)
    if end == -1:
        return ""
    block = text[3:end]
    capturing = False
    chunks: list[str] = []
    for line in block.splitlines():
        if line.startswith("description:"):
            capturing = True
            value = line.split(":", 1)[1].strip().lstrip(">|").strip()
            if value:
                chunks.append(value)
            continue
        if capturing:
            if not line.startswith(" "):
                break
            chunks.append(line.strip())
    return " ".join(chunks).strip()


def _validate_skills(source_dir: Path, skills: list[str], target_skills_dir: Path) -> None:
    for name in skills:
        src = source_dir / name
        if not (src / "SKILL.md").is_file():
            raise SystemExit(f"error: source skill not found: {src}")
        if (target_skills_dir / name).exists():
            raise SystemExit(
                f"error: target already has .claude/skills/{name}/ — refuse to overwrite.\n"
                f"hint: use collect-skills to compare versions."
            )


def _validate_workflows(source_dir: Path, workflows: list[str], target_workflows_dir: Path) -> None:
    unknown = [name for name in workflows if name not in DISTRIBUTABLE_WORKFLOWS]
    if unknown:
        raise SystemExit(f"error: unknown workflow(s) {unknown}. Distributable: {sorted(DISTRIBUTABLE_WORKFLOWS)}")
    for name in workflows:
        filename = DISTRIBUTABLE_WORKFLOWS[name]["filename"]
        src = source_dir / filename
        if not src.is_file():
            raise SystemExit(f"error: source workflow not found: {src}")
        if (target_workflows_dir / filename).exists():
            raise SystemExit(
                f"error: target already has .github/workflows/{filename} — refuse to overwrite.\n"
                f"hint: open the existing file and reconcile by hand if changes are wanted."
            )


def _copy_skills(source_dir: Path, skills: list[str], target_skills_dir: Path) -> None:
    target_skills_dir.mkdir(parents=True, exist_ok=True)
    for name in skills:
        shutil.copytree(source_dir / name, target_skills_dir / name)


def _copy_workflows(source_dir: Path, workflows: list[str], target_workflows_dir: Path) -> None:
    target_workflows_dir.mkdir(parents=True, exist_ok=True)
    for name in workflows:
        filename = DISTRIBUTABLE_WORKFLOWS[name]["filename"]
        shutil.copy2(source_dir / filename, target_workflows_dir / filename)


def _build_pr_body(
    skills: list[str],
    workflows: list[str],
    source_skills_dir: Path,
    source_sha: str,
) -> str:
    parts: list[str] = []
    summary_bits: list[str] = []
    if skills:
        summary_bits.append(f"{len(skills)} skill(s)")
    if workflows:
        summary_bits.append(f"{len(workflows)} workflow(s)")
    parts.extend(
        [
            "## Summary",
            "",
            f"Adds {' and '.join(summary_bits)} from [`Geoffe-Ga/well-worn-tools`]"
            f"(https://github.com/Geoffe-Ga/well-worn-tools/tree/{source_sha[:7]}) "
            "to this repo.",
            "",
        ]
    )

    if skills:
        parts.extend(["## Skills", ""])
        for name in skills:
            desc = _read_description(source_skills_dir / name / "SKILL.md")
            first_sentence = desc.split(". ")[0].rstrip(".") + "." if desc else "(no description)"
            parts.append(f"- **{name}** — {first_sentence}")
        parts.append("")

    if workflows:
        parts.extend(["## Workflows", ""])
        for name in workflows:
            spec = DISTRIBUTABLE_WORKFLOWS[name]
            parts.append(f"- **{spec['filename']}** — {spec['summary']}")
            parts.append(f"  - **Requires:** {spec['requires']}")
        parts.append("")

    parts.extend(
        [
            "## Provenance",
            "",
            f"Source SHA: `{source_sha}`",
            "Distributed via the `distribute-skills` skill (`metadata.distribute: false`, stays in well-worn-tools).",
            "",
            "## Test plan",
            "",
        ]
    )
    if skills:
        parts.extend(
            [
                "- [ ] Confirm `.claude/skills/` directory structure looks right",
                "- [ ] Spot-check one SKILL.md frontmatter for syntax",
                "- [ ] Decide whether each skill's triggers fit this repo's workflows",
            ]
        )
    if workflows:
        parts.extend(
            [
                "- [ ] Confirm each new file under `.github/workflows/` parses (actionlint)",
                "- [ ] Wire any required secrets noted under **Workflows** above",
                "- [ ] Confirm any referenced workflow names exist in this repo",
            ]
        )
    return "\n".join(parts)


def _build_commit_message(skills: list[str], workflows: list[str], source_sha: str) -> str:
    pieces: list[str] = []
    if skills:
        pieces.append(f"skills {', '.join(skills)}")
    if workflows:
        pieces.append(f"workflows {', '.join(workflows)}")
    summary = " and ".join(pieces)
    return (
        f"feat: Add {summary} from well-worn-tools\n\n"
        f"Source: https://github.com/Geoffe-Ga/well-worn-tools/tree/{source_sha}\n"
        f"Distributed via well-worn-tools/distribute-skills."
    )


def _build_pr_title(skills: list[str], workflows: list[str]) -> str:
    if skills and workflows:
        return "Add skills and workflows from well-worn-tools"
    if skills:
        return f"Add {', '.join(skills)} from well-worn-tools"
    return f"Add {', '.join(workflows)} workflow(s) from well-worn-tools"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("owner_repo", help="<owner>/<repo>")
    parser.add_argument("--skills", nargs="+", default=[], help="skill names to add")
    parser.add_argument(
        "--workflows",
        nargs="+",
        default=[],
        help=f"workflow names to add. Distributable: {sorted(DISTRIBUTABLE_WORKFLOWS)}",
    )
    parser.add_argument("--branch", default=None, help="feature branch name")
    parser.add_argument("--source-skills-dir", type=Path, default=DEFAULT_SOURCE_DIR)
    parser.add_argument(
        "--source-workflows-dir",
        type=Path,
        default=DEFAULT_WORKFLOWS_SOURCE_DIR,
        help="directory containing distributable workflow YAMLs (default: .github/workflows)",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    if not args.skills and not args.workflows:
        parser.error("provide at least one of --skills or --workflows")

    _require_gh()
    source_skills = args.source_skills_dir.resolve() if args.skills else None
    if source_skills is not None and not source_skills.is_dir():
        print(f"error: source skills dir not found: {source_skills}", file=sys.stderr)
        return 2
    source_workflows = args.source_workflows_dir.resolve() if args.workflows else None
    if source_workflows is not None and not source_workflows.is_dir():
        print(f"error: source workflows dir not found: {source_workflows}", file=sys.stderr)
        return 2

    branch = args.branch or f"{DEFAULT_BRANCH_PREFIX}/{dt.date.today().isoformat()}"
    source_sha = _local_head_sha()

    with tempfile.TemporaryDirectory(prefix="distribute-skills-") as tmp:
        clone_root = Path(tmp) / "clone"
        clone_url = f"https://github.com/{args.owner_repo}.git"
        print(f"[1/6] Cloning {clone_url} ...")
        _run(["git", "clone", "--depth", "1", clone_url, str(clone_root)])

        print(f"[2/6] Creating branch {branch} ...")
        _run(["git", "checkout", "-b", branch], cwd=clone_root)

        target_skills_dir = clone_root / ".claude" / "skills"
        target_workflows_dir = clone_root / ".github" / "workflows"
        print(f"[3/6] Validating no overwrite for {len(args.skills)} skill(s), {len(args.workflows)} workflow(s) ...")
        if args.skills:
            assert source_skills is not None
            _validate_skills(source_skills, args.skills, target_skills_dir)
        if args.workflows:
            assert source_workflows is not None
            _validate_workflows(source_workflows, args.workflows, target_workflows_dir)

        print("[4/6] Copying into clone ...")
        if args.skills:
            assert source_skills is not None
            _copy_skills(source_skills, args.skills, target_skills_dir)
            _run(["git", "add", ".claude/skills"], cwd=clone_root)
        if args.workflows:
            assert source_workflows is not None
            _copy_workflows(source_workflows, args.workflows, target_workflows_dir)
            _run(["git", "add", ".github/workflows"], cwd=clone_root)

        commit_message = _build_commit_message(args.skills, args.workflows, source_sha)
        _run(["git", "commit", "-m", commit_message], cwd=clone_root)

        if args.dry_run:
            print("[dry-run] Would push and open PR. Stopping here.")
            print(f"  Branch:    {branch}")
            if args.skills:
                print(f"  Skills:    {' '.join(args.skills)}")
            if args.workflows:
                print(f"  Workflows: {' '.join(args.workflows)}")
            return 0

        print(f"[5/6] Pushing branch {branch} ...")
        _run(["git", "push", "-u", "origin", branch], cwd=clone_root)

        print("[6/6] Opening PR ...")
        title = _build_pr_title(args.skills, args.workflows)
        body = _build_pr_body(
            args.skills,
            args.workflows,
            source_skills if source_skills is not None else Path("."),
            source_sha,
        )
        pr = _run(
            ["gh", "pr", "create", "--repo", args.owner_repo, "--head", branch, "--title", title, "--body", body],
            cwd=clone_root,
        )
        print(pr.stdout.strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
