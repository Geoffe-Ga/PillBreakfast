# Adaptation Rules

Patterns the `adapt.py` static pass detects, and how to resolve each. The script reports; the agent decides.

## ABSOLUTE_PATH

**Pattern**: a string matching `/home/<user>/...`, `/Users/<user>/...`, or `C:\\...` in any text or code file.

**Why it matters**: absolute paths from another author's environment leak into examples and break when the skill is shared. Well-worn-tools examples should use repo-relative or generic placeholder paths.

**Resolutions**:

- Replace with `<absolute-path>` placeholder if the path is illustrative.
- Replace with a relative path under the project root if the example targets a real file.
- Drop the example if it only made sense in the source repo.

## EXTERNAL_REPO_REF

**Pattern**: a `github.com/<owner>/<repo>` URL where the owner or repo is anything other than `Geoffe-Ga/well-worn-tools`.

**Why it matters**: links to the source repo's issue tracker, PRs, or wiki break attribution and tie the skill to context that other consumers don't share.

**Resolutions**:

- Strip the link entirely if it referenced an internal artifact (e.g., `our-repo/issues/14`).
- Convert to a generic placeholder (`<owner>/<repo>`) if the example needs to demonstrate the shape of a URL.
- Keep the link only if it points to authoritative external documentation (a vendor advisory, a standards body, a public RFC).

## ORPHAN_XREF

**Pattern**: the description contains `(use <skill-name> skill)` for a `<skill-name>` that does not exist under `.claude/skills/` locally.

**Why it matters**: bilateral exclusions are how skills route correctly. A reference to a non-existent skill leaves the description silently broken.

**Resolutions**:

- **Recurse**: collect the missing skill from the source repo too, then leave the cross-reference intact.
- **Rewrite**: point to the closest local equivalent (e.g., `(use security skill)`).
- **Drop**: if no equivalent exists and the cross-reference is non-essential, remove the parenthetical and any surrounding "Do NOT" clause.
- **Open issue**: if the missing skill should exist but doesn't yet, open a tracking issue and leave a TODO comment in the description until the gap is filled.

## FRONTMATTER_MISSING

**Pattern**: required keys absent — top-level `name`, `description`, `metadata`, or nested `metadata.author`, `metadata.version`.

**Why it matters**: well-worn-tools' README and validation tooling assume the standard frontmatter shape.

**Resolutions**:

- Set `metadata.author: Geoff` for any skill imported into well-worn-tools.
- Default `metadata.version: 1.0.0` if absent. If the source repo had a meaningful version, preserve it but reset patch level to 0 to mark the import boundary.
- Fill `name` and `description` from the body if they were omitted entirely (rare).

## FRONTMATTER_DRIFT

**Pattern**: `metadata.author` is set to a value other than `Geoff`.

**Why it matters**: well-worn-tools is a single-author curated collection; mixed authorship in metadata breaks the convention used by README generation.

**Resolutions**:

- Overwrite with `Geoff`.
- Capture original authorship in the import commit message body, not in the frontmatter.

## COLLISION

**Pattern**: a skill with the same `name` already exists under `.claude/skills/`.

**Why it matters**: ingest must not silently overwrite. Two skills with the same name encode different decisions about what triggers and what the workflow is.

**Resolutions**:

- Diff the two (`diff -ru`).
- If the incoming skill is strictly better in every section, replace and bump the version.
- If they overlap partially, merge section by section, preserving examples from both, and bump version.
- If they conflict on philosophy, keep local and skip the import. Open a tracking issue capturing the divergence.

## MISSING_SKILL_MD

**Pattern**: the staged directory does not contain a `SKILL.md`.

**Why it matters**: not a skill — likely a misconfigured fetch.

**Resolutions**:

- Re-run `fetch.py` and inspect the source repo manually.
- If the source uses a non-standard layout, either restructure on import or skip.

## Notes on What `adapt.py` Does Not Detect

The static pass is deliberately limited. It does not judge:

- Whether the trigger phrases in the description match the user's actual language.
- Whether examples are clear or instructive.
- Whether the skill is composable with the rest of the well-worn-tools collection.

Those judgments belong to the agent during the human-in-the-loop adaptation step, with `skill-craft/references/quality-checklist.md` as the rubric.
