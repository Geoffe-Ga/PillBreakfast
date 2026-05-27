#!/usr/bin/env python3
"""Static analysis pass over a fetched skill directory.

Reports patterns that may need manual adaptation before the skill is moved
into the live `.claude/skills/` tree. Exits non-zero if any finding is
emitted, so the report is loop-friendly:

    while ! python adapt.py .collect-staging/<name>; do
        # edit, then re-run
    done

Findings are not auto-fixed. The agent reads each line and decides whether
to generalize, drop, rewrite, or accept the pattern.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

LIVE_SKILLS_DIR = Path(".claude/skills")
EXPECTED_OWNER = "Geoffe-Ga"
EXPECTED_REPO = "well-worn-tools"

ABSOLUTE_PATH = re.compile(r"(?:/home/[A-Za-z0-9_-]+/|/Users/[A-Za-z0-9_-]+/|[A-Z]:\\)\S+")
EXTERNAL_REPO = re.compile(r"github\.com[:/]+(?P<owner>[A-Za-z0-9_-]+)/(?P<repo>[A-Za-z0-9_.-]+)")
SKILL_XREF = re.compile(r"\(use ([a-z][a-z0-9-]+) skill\)")
FRONTMATTER_BLOCK = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
REQUIRED_FRONTMATTER = ("name", "description", "metadata")
REQUIRED_METADATA = ("author", "version")


@dataclass
class Finding:
    code: str
    location: str
    detail: str

    def format(self) -> str:
        return f"{self.code:20s} {self.location:20s} {self.detail}"


def _local_skill_names() -> set[str]:
    if not LIVE_SKILLS_DIR.is_dir():
        return set()
    return {p.name for p in LIVE_SKILLS_DIR.iterdir() if (p / "SKILL.md").is_file()}


def _parse_frontmatter(
    text: str,
) -> tuple[dict[str, Any], int] | tuple[None, int]:
    """Best-effort YAML frontmatter parse without a yaml dependency.

    Returns (mapping, end_line) or (None, 0) if no frontmatter.
    The mapping uses string keys and string values for top-level scalars,
    plus a nested dict for `metadata:`.
    """
    match = FRONTMATTER_BLOCK.match(text)
    if not match:
        return None, 0
    body = match.group(1)
    end_line = text[: match.end()].count("\n")
    parsed: dict[str, Any] = {}
    metadata: dict[str, str] = {}
    in_metadata = False
    for raw_line in body.splitlines():
        if not raw_line.strip():
            continue
        if raw_line.startswith("metadata:"):
            in_metadata = True
            parsed["metadata"] = metadata
            continue
        if in_metadata and raw_line.startswith("  ") and ":" in raw_line:
            key, _, value = raw_line.strip().partition(":")
            metadata[key.strip()] = value.strip()
            continue
        if not raw_line.startswith(" ") and ":" in raw_line:
            in_metadata = False
            key, _, value = raw_line.partition(":")
            parsed[key.strip()] = value.strip().lstrip(">|").strip()
    return parsed, end_line


def scan_skill(skill_dir: Path) -> list[Finding]:
    findings: list[Finding] = []
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return [Finding("MISSING_SKILL_MD", skill_dir.name, "no SKILL.md present")]

    text = skill_md.read_text()
    frontmatter, _header_lines = _parse_frontmatter(text)

    # --- Frontmatter integrity ---
    if frontmatter is None:
        findings.append(Finding("FRONTMATTER_MISSING", "SKILL.md", "no YAML frontmatter block"))
    else:
        for key in REQUIRED_FRONTMATTER:
            if key not in frontmatter:
                findings.append(Finding("FRONTMATTER_MISSING", "frontmatter", f"missing field '{key}'"))
        metadata = frontmatter.get("metadata") or {}
        for key in REQUIRED_METADATA:
            if key not in metadata:
                findings.append(Finding("FRONTMATTER_MISSING", "frontmatter", f"missing metadata.{key}"))
        if metadata.get("author") and metadata["author"] not in {"Geoff", '"Geoff"', "'Geoff'"}:
            findings.append(
                Finding(
                    "FRONTMATTER_DRIFT",
                    "frontmatter",
                    f"metadata.author='{metadata['author']}' (expected 'Geoff')",
                )
            )

        # --- Local skill name collision ---
        name = frontmatter.get("name", "").strip().strip('"').strip("'")
        if name and name in _local_skill_names() and skill_dir.parent.resolve() != LIVE_SKILLS_DIR.resolve():
            findings.append(
                Finding(
                    "COLLISION",
                    "frontmatter",
                    f"skill named '{name}' already exists locally — diff before moving",
                )
            )

        # --- Orphan cross-references in description ---
        description = frontmatter.get("description", "")
        local_names = _local_skill_names()
        for xref in SKILL_XREF.findall(description):
            if xref == name:
                continue
            if xref not in local_names:
                findings.append(
                    Finding(
                        "ORPHAN_XREF",
                        "frontmatter",
                        f"description references '(use {xref} skill)' but no local skill named '{xref}'",
                    )
                )

    # --- Body / file-content scans ---
    for path in sorted(skill_dir.rglob("*")):
        if not path.is_file():
            continue
        if path.name == ".provenance.json":
            continue
        if path.suffix not in {".md", ".py", ".sh", ".toml", ".yml", ".yaml", ".json", ".txt"}:
            continue
        try:
            content = path.read_text()
        except UnicodeDecodeError:
            continue
        rel = path.relative_to(skill_dir)
        for lineno, line in enumerate(content.splitlines(), start=1):
            for hit in ABSOLUTE_PATH.findall(line):
                findings.append(Finding("ABSOLUTE_PATH", f"{rel}:{lineno}", hit))
            for owner, repo in EXTERNAL_REPO.findall(line):
                if (owner, repo.removesuffix(".git")) == (EXPECTED_OWNER, EXPECTED_REPO):
                    continue
                findings.append(
                    Finding(
                        "EXTERNAL_REPO_REF",
                        f"{rel}:{lineno}",
                        f"github.com/{owner}/{repo}",
                    )
                )

    return findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("skill_dir", type=Path)
    parser.add_argument("--json", action="store_true", help="emit findings as JSON")
    args = parser.parse_args(argv)

    if not args.skill_dir.is_dir():
        print(f"error: not a directory: {args.skill_dir}", file=sys.stderr)
        return 2

    findings = scan_skill(args.skill_dir)
    if args.json:
        json.dump([f.__dict__ for f in findings], sys.stdout, indent=2)
        sys.stdout.write("\n")
    elif not findings:
        print("OK")
    else:
        for f in findings:
            print(f.format())
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
