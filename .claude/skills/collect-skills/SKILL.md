---
name: collect-skills
description: >-
  Discover and ingest skills from sibling GitHub repos owned by the same
  user or org as the well-worn-tools checkout. Use when the user says
  "collect skills", "harvest skills from my other repos", "import skills
  from <repo>", "find skills across my repos", or "pull in skills I made
  elsewhere". Walks every non-archived repo for the owner, finds
  .claude/skills/* on the default branch, downloads each skill into a
  staging directory, and runs an adaptation pass that flags repo-specific
  paths, broken cross-references, frontmatter drift, and naming collisions
  before anything moves into .claude/skills/. Uses Python helpers in
  scripts/ for owner detection, repo and skill listing, content fetching,
  and adaptation reporting; the agent makes the final calls. Carries
  metadata.distribute false and must not itself be sent outward. Do NOT
  use for sending skills outward (use distribute-skills skill), authoring
  new skills from scratch (use skill-craft skill), or general issue and
  PR workflow (use git-workflow skill).
metadata:
  author: Geoff
  version: 1.0.0
  distribute: false
---

# Collect Skills

Pull skills from every other repo the current GitHub owner has, adapt them to fit well-worn-tools conventions, and stage them under `.claude/skills/`. Run from inside the well-worn-tools checkout.

## Prerequisites

- Python 3.10+.
- Working tree clean enough that a per-skill commit makes sense.
- For the local path: `gh` CLI authenticated for the current owner (`gh auth status`).
- For the cloud path: GitHub MCP server tools (`mcp__github__*`) with read access to the owner's repos.

## Execution Environment

The Python helpers shell out to `gh`, which exists in some Claude Code environments and not others. Pick the path before doing anything:

```bash
if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || ! command -v gh >/dev/null 2>&1; then
  echo "cloud path — see 'MCP-Only Flow' at the bottom"
else
  echo "local path — Python helpers below"
fi
```

| Environment | Path |
|-------------|------|
| Claude Code CLI (terminal) | local — Python helpers, `gh` works |
| Claude Code desktop (Mac / Windows) | local — same |
| Claude Code on the web (claude.ai/code) | cloud — MCP-only flow |
| Claude Code on iOS / mobile | cloud — same as web |

Both paths produce identical output; only the calling tools change. `adapt.py` is pure Python and is used in either path.

## Instructions

### Step 1: Determine the GitHub Owner

```bash
python .claude/skills/collect-skills/scripts/discover.py owner
```

Reads `git remote get-url origin` and prints the owner segment. If the script fails, the user is in a non-git directory or origin is missing — stop and report.

### Step 2: List Candidate Repos

```bash
python .claude/skills/collect-skills/scripts/discover.py repos <owner>
```

Prints non-archived, non-fork repos for the owner, one per line. The current repo (well-worn-tools) is always excluded as a source. Forks are excluded by default to avoid copying skills out of upstream projects.

### Step 3: Find Skills in Each Candidate

```bash
python .claude/skills/collect-skills/scripts/discover.py skills <owner>/<repo>
```

Lists `.claude/skills/<name>/` directories that contain a `SKILL.md` on the default branch. Repos without a skills directory are silently skipped.

### Step 4: Fetch into a Staging Area

Stage outside the live tree so adaptation is reviewable:

```bash
python .claude/skills/collect-skills/scripts/fetch.py \
    <owner>/<repo> <skill-name> .collect-staging/<skill-name>
```

Mirrors `SKILL.md` plus `references/`, `scripts/`, and `assets/` subtrees. Records provenance (source repo, commit SHA) in `.collect-staging/<skill-name>/.provenance.json`.

### Step 5: Run the Adaptation Report

```bash
python .claude/skills/collect-skills/scripts/adapt.py .collect-staging/<skill-name>
```

The script reports — but does not silently rewrite — the patterns in `references/adaptation-rules.md`:

- Absolute filesystem paths suggesting another repo's layout
- Owner / repo names other than `Geoffe-Ga/well-worn-tools`
- Cross-references in the description to skills not present locally
- Missing or non-standard frontmatter fields
- Local-name collisions with an existing well-worn-tools skill

For each finding, decide:

- **Generalize**: rewrite the path or example to be repo-agnostic
- **Drop**: the example or note is too repo-specific to keep
- **Cross-reference fix**: point to the equivalent well-worn-tools skill, or open a tracking issue if no equivalent exists yet
- **Frontmatter normalize**: set `metadata.author: Geoff`, default `metadata.version: 1.0.0`

Apply edits to the staged copy, then re-run `adapt.py` until the report is clean.

### Step 6: Resolve Collisions

If `.claude/skills/<skill-name>/` already exists, do not overwrite. Diff the two:

```bash
diff -ru .claude/skills/<skill-name>/ .collect-staging/<skill-name>/
```

Decide section-by-section: keep local, take incoming, or merge. Bump `metadata.version` per semver — additive merges are minor bumps; structural changes are major.

### Step 7: Move Adapted Skills into Place

```bash
mv .collect-staging/<skill-name> .claude/skills/<skill-name>
```

Update the README skills table and bump the count.

### Step 8: Validate Each Imported Skill

Run the skill-craft quality checklist for every new or updated skill (`.claude/skills/skill-craft/references/quality-checklist.md`). Skills that fail validation must be fixed before commit — bilateral exclusions, description length, and frontmatter integrity are the most common failures on imports.

### Step 9: Commit per Skill

One commit per imported skill keeps attribution clean:

```text
feat(skills): Import <skill-name> from <owner>/<source-repo>

Source: https://github.com/<owner>/<source-repo>/tree/<sha>/.claude/skills/<skill-name>
Adaptation: <one-line summary of what was changed during the pass>
```

Provenance lives in the commit body, not the skill file — the skill should read as native to well-worn-tools after adaptation.

## Examples

### Example 1: Single Sibling Repo

```bash
$ python .claude/skills/collect-skills/scripts/discover.py owner
Geoffe-Ga
$ python .claude/skills/collect-skills/scripts/discover.py skills Geoffe-Ga/another-tool
async-patterns
graphql-conventions
$ python .claude/skills/collect-skills/scripts/fetch.py \
      Geoffe-Ga/another-tool async-patterns .collect-staging/async-patterns
$ python .claude/skills/collect-skills/scripts/adapt.py .collect-staging/async-patterns
ABSOLUTE_PATH        SKILL.md:42   /home/geoff/another-tool/lib/runner.py
EXTERNAL_REPO_REF    SKILL.md:88   another-tool/issues/14
ORPHAN_XREF          frontmatter   "(use test-coverage skill)" — no such skill locally
FRONTMATTER_MISSING  frontmatter   metadata.author
$ # Edit the staged copy to address each finding, then:
$ python .claude/skills/collect-skills/scripts/adapt.py .collect-staging/async-patterns
OK
$ mv .collect-staging/async-patterns .claude/skills/async-patterns
```

### Example 2: Bulk Sweep Across All Sibling Repos

```bash
mkdir -p .collect-staging
for repo in $(python .claude/skills/collect-skills/scripts/discover.py repos Geoffe-Ga); do
  for skill in $(python .claude/skills/collect-skills/scripts/discover.py skills "$repo"); do
    python .claude/skills/collect-skills/scripts/fetch.py \
        "$repo" "$skill" ".collect-staging/${skill}"
  done
done
ls .collect-staging
```

Then run `adapt.py` against each staged directory and address findings before any `mv`.

## Troubleshooting

### Error: gh CLI not authenticated
Run `gh auth login`. Listing private repos and reading file contents both require an authenticated session.

### Error: Skill already exists locally
Resolve by diff (Step 6), never overwrite. If incoming is strictly better, take it and bump the version. If they conflict on philosophy, keep local and skip the import — record the decision in a tracking issue so the source repo's drift is visible.

### Error: Adaptation report flags an orphan cross-reference
The incoming description references a skill that doesn't exist in well-worn-tools. Either collect that skill too (recurse), or rewrite the cross-reference to a local equivalent. Never silently delete — bilateral exclusions are part of why skills route correctly.

### Error: Helper script "Not Found" on a private repo
Confirm `gh auth status` shows the right account and the token's scopes include `repo`. Forks in other orgs may need a separate auth context.

### Error: Two sibling repos have different versions of the same skill
Treat the higher version as the trunk, diff-merge any unique additions from the other, and document the merge decision in the commit body.

## MCP-Only Flow (Cloud Environments)

When `gh` is not available, drive the same workflow with GitHub MCP tools. The shape is identical; only Steps 1-4 swap their backend.

| Step | Local helper | MCP equivalent |
|------|--------------|----------------|
| 1. Owner | `discover.py owner` | Read `git remote get-url origin` via Bash; parse owner. (No GitHub call needed — pure git.) |
| 2. List repos | `discover.py repos <owner>` | `mcp__github__search_repositories` with query `user:<owner>` (or `org:<owner>`). Filter out archived, forks, and well-worn-tools in the agent. |
| 3. Find skills | `discover.py skills <owner>/<repo>` | `mcp__github__get_file_contents` on path `.claude/skills` — returns the directory listing. Confirm each subdir's `SKILL.md` with another `get_file_contents`. |
| 4. Fetch skill | `fetch.py ...` | For each file under `.claude/skills/<name>/` (walk the tree with `get_file_contents`), save locally with the `Write` tool. Build the `.provenance.json` manually from the SHA returned by `mcp__github__get_commit`. |
| 5. Adapt | `adapt.py <dir>` | Same — `adapt.py` is pure Python and works in both paths. |
| 6-9. Resolve / move / validate / commit | Same | Same — local filesystem and git only. |

MCP tool scope is bounded by the session's GitHub auth. If `mcp__github__search_repositories` does not return the expected sibling repos, the session is scoped to a single repo — request broader auth before continuing rather than partially-collecting.

## See Also

- `references/adaptation-rules.md` — full pattern catalog the adaptation pass detects
- `.claude/skills/distribute-skills/` — the inverse skill for sending skills outward
- `.claude/skills/skill-craft/` — the quality bar imported skills must clear
