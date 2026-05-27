## Role

You are a senior test engineer applying mutation testing to the critical safety paths. You have opinions about mutation testing already; lean on them.

## Goal

Set up `Muter` (or an equivalent Swift mutation tester) targeting three modules:

1. `Shared/Logging/DoseEventWriter.swift` (snapshot construction).
2. `Shared/Queries/IngredientQueries.swift` (`totalToday`, `lastDoseTime`).
3. `Shared/Safety/SafetyEvaluator.swift` (`violationsIfTaken`).

Achieve a mutation score >= 85% on those three modules. Update `scripts/mutate.sh` to be reproducible. Document the choice of tool in `plans/decisions/<today>_mutation-tester.md`.

## Context

- **Parent epic:** #10
- **Predecessor issue(s):** #EPIC_10_ISSUE_05_NUMBER.
- **SPEC section:** §10 Phase 9 ("Mutation-tested critical paths: dose logging, running-total computation, ceiling enforcement"). §11 Phase 9 skill callout.
- **Files involved:**
  - `scripts/mutate.sh` — real implementation.
  - `plans/decisions/<today>_mutation-tester.md` — choice rationale.
  - `Submission/mutation-report.md` — captures the latest score.
- **Prior decisions (locked):**
  - Target score: **>= 85%** on the three modules. Higher is welcome; below 85% means more tests are needed.
  - Reproducible via `scripts/mutate.sh`. CI integration is out of scope (manual run is fine for now).
- **State of the world:** Tests exist; no mutation testing.

## Output Format

A single PR containing:

- [ ] Mutation tester installed and configured.
- [ ] Targeted runs on the three modules.
- [ ] New tests added wherever mutants survived, until the score >= 85%.
- [ ] Updated `mutation-report.md`.

## Constraints

**Scope fence:** Don't mutation-test every module — only the three critical paths.

**No bypasses to inflate the score.** Killing a mutant by tightening a real test is correct; deleting the mutant from the runner config is forbidden.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Tests still pass; mutation score documented.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] Mutation score >= 85% on the three modules.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #10` and `Closes #EPIC_10_ISSUE_06_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-9-hardening`, `tests`.
