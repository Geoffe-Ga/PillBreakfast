# Exemption Rules

Which skills are excluded from distribution, and how the exemption is encoded.

## Mechanism

A skill is **exempt from distribution** if its frontmatter contains:

```yaml
metadata:
  distribute: false
```

`discover.py local` parses this field and omits exempt skills from the distributable set. `check_target.py` reads the same set, so missing-skill reports never include exempt skills. `distribute.py` only acts on names supplied via `--skills`, so even if a caller hand-crafts the argument, attempts to push an exempt skill are caught by the same flag.

## Permanently Exempt Skills

The following skills are exempt by design and must remain so:

| Skill | Why Exempt |
|-------|------------|
| `collect-skills` | Reaches outward to read sibling repos and is meaningful only inside the curating repo (well-worn-tools). Distributing it to leaf repos would invert the topology and create propagation loops. |
| `distribute-skills` | Same reason. The curator pushes outward; consumer repos do not push to each other. |

Both skills self-identify as exempt via `metadata.distribute: false`. Removing the flag would be a meaningful design change requiring discussion.

## Choosing to Exempt a New Skill

A skill should be exempt when at least one of these is true:

1. **Topology** — the skill reasons about the well-worn-tools curation process itself (collecting, distributing, curating), and only makes sense inside the hub.
2. **Leak risk** — the skill encodes secrets, internal repo names, or org-specific workflows that should not be propagated.
3. **Unfinished work** — the skill is staged for review but not yet ready for downstream consumption. Use a temporary `distribute: false` and remove it once the skill is ready.

A skill should NOT be exempt simply because:

- It might not be useful in every repo. Triggers and exclusions handle that — irrelevant skills sit dormant.
- It is opinionated. Opinions are the value proposition; downstream maintainers can decline a PR.

## How to Add the Flag

Edit the skill's `SKILL.md` frontmatter:

```yaml
metadata:
  author: Geoff
  version: 1.0.0
  distribute: false
```

Keep the field on its own line, indented two spaces under `metadata:`. The parser in `discover.py` is intentionally simple — it does not run a full YAML parser, so unusual indentation or inline mappings will not be recognized.

## How to Audit the Current Exempt Set

```bash
for skill in .claude/skills/*/; do
    if grep -q 'distribute: false' "$skill/SKILL.md"; then
        echo "$(basename "$skill"): EXEMPT"
    fi
done
```

Compare against `discover.py local` output to confirm:

```bash
diff <(ls .claude/skills/) <(python .claude/skills/distribute-skills/scripts/discover.py local)
```

The difference is exactly the exempt set.

## Workflows Are Governed Separately

`.github/workflows/*.yml` files have no frontmatter, so the `metadata.distribute: false` mechanism above does not apply. Workflow distribution is gated by an explicit allowlist in `scripts/distribute.py` (`DISTRIBUTABLE_WORKFLOWS`). A workflow ships only if its name is in that dict and a matching file is present under `--source-workflows-dir` (default `.github/workflows/`).

The two gating models exist for the same reason: the right answer for "should this propagate?" lives next to the artifact (frontmatter for skills, an explicit registry for workflows), not in a separate config file that's easy to miss.

To make a workflow distributable, add an entry to `DISTRIBUTABLE_WORKFLOWS` with the public name, the YAML filename, and the prose used in the PR body (`summary` + `requires`). Keep the entry conservative — every consumer of distribute-skills will see the workflow offered by name.

## Anti-Pattern: Whole-Repo Exemption Lists

Earlier designs put the exempt list in a separate config file. This was rejected because:

- The exemption travels with the skill if it is ever moved or copied.
- Per-skill metadata is visible during code review, while a separate config file is easy to miss.
- A skill that is exempt in one curator should usually be exempt in any curator that adopts it — frontmatter is a portable carrier.

If a future use case genuinely requires per-curator exemption (e.g., "this skill is exempt only in well-worn-tools but not in some other hub"), prefer adding a second flag (`distribute_in: ["other-hub"]`) rather than reverting to an external list.
