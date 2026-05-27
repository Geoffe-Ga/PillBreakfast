## Role

You are a senior release engineer setting up the submission scaffolding before the real work begins.

## Goal

Add a `Submission/` folder containing the asset checklist, screenshot script template, soak diary template, and a stub `scripts/mutate.sh`. Each file is empty (or contains a one-line "filled in EPIC_10_ISSUE_NN" pointer) so the rest of EPIC 10 has a place to land.

## Context

- **Parent epic:** #10
- **Predecessor issue(s):** Full EPIC 09 (v1 feature-complete).
- **SPEC section:** `plans/SPEC.md` §10 Phase 9.
- **Files involved (new):**
  - `Submission/asset-checklist.md`.
  - `Submission/screenshot-script.md`.
  - `Submission/soak-diary-TEMPLATE.md`.
  - `scripts/mutate.sh` — stub returning exit code 0 with "fill in EPIC_10_ISSUE_06."
- **State of the world:** Feature work complete; no submission scaffolding.

## Output Format

A single PR containing the four new files. Each contains a one-paragraph description of what will fill it in.

## Constraints

**Scope fence:** No real content yet — that's the rest of EPIC 10.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** No code change; documentation-only.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] App builds and runs.
- [ ] PR opened with `Refs #10` and `Closes #EPIC_10_ISSUE_01_NUMBER`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-9-hardening`.
