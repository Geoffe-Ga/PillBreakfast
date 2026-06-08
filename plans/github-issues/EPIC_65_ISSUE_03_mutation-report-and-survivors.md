## Role

You are a senior Swift test engineer closing out the mutation-testing effort for PillBreakfast. You confirm the ≥85% target holds on all three modules, then write the durable record: the submission report and the honest accounting of every surviving / equivalent mutant.

## Goal

A final `scripts/mutate.sh` run confirms ≥85% on each of `DoseEventWriter`, `IngredientQueries`, and `SafetyEvaluator`. `Submission/mutation-report.md` records, per module, the score, total mutants, killed/survived/equivalent counts, an explanation for each equivalent mutant, the Muter version, and the run date. Any genuinely equivalent mutant is documented (never deleted from the config); any high-risk mutation Muter cannot generate is noted under "manual coverage."

## Context

- **Parent epic:** #65 (child of phase-epic #10 — Phase 9).
- **Predecessors:** EPIC_65_ISSUE_02 (kill mutants to ≥85%) — the new tests must already drive each module to ≥85% before this report is written. Successor: EPIC_10_ISSUE_07 (soak test).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-65_mutation-testing-safety.md` §1 (record score in `Submission/mutation-report.md`), §3 (non-goals: document equivalent mutants, don't inflate), §7 (equivalent mutants in `pagedScan`; build-failure mutants excluded), §9 (85% guideline vs hard floor; manual coverage for ungenerated mutations), §11 (acceptance criteria).
- **Files involved:**
  - `Submission/mutation-report.md` (new — per-module score, counts, equivalent-mutant explanations, version, date).
  - `plans/decisions/2026-06-07_mutation-tester.md` (update — final scores and equivalent-mutant list, if the skeleton left it at baseline).
  - Read-only: `scripts/mutate.sh`, `muter.conf.yml`, the three target modules and their tests.
- **Prior decisions (locked):**
  - Equivalent mutants (e.g. `offset += page.count` vs `offset += pageSize` in `pagedScan`, which alias on the terminating path) are documented as equivalent with a written rationale — not killed by accidental-pass tests, not removed from the runner.
  - Build-failure mutants are excluded from the denominator (Muter reports them separately).
  - The 85% target is a guideline informed by equivalent-mutant density; if a module lands just under after honest effort, the report must justify it mutant-by-mutant rather than gaming the config.

## Output Format

A single PR containing:

- [ ] `Submission/mutation-report.md` with, per module: mutation score, total mutants generated, killed count, survived count, equivalent count (each with a one-paragraph explanation), Muter version, date of run; plus an overall summary line.
- [ ] A "manual coverage" subsection listing any dangerous mutation Muter does not generate (e.g. `.taken` → `.skipped` enum-case swap) and the test that covers it directly.
- [ ] `plans/decisions/2026-06-07_mutation-tester.md` updated with the final per-module scores and the equivalent-mutant inventory (if not already final from the skeleton).
- [ ] PR description states the final per-module scores and confirms no mutant was deleted from the config to inflate the score.

## Examples

`Submission/mutation-report.md` per-module shape:

```markdown
### SafetyEvaluator
- Score: 91% (20 killed / 22 scored; 2 equivalent excluded from numerator-as-killed)
- Total mutants: 24 (2 build-failure, excluded from denominator)
- Equivalent mutants:
  - `offset += page.count` → `offset += pageSize` (pagedScan): equivalent on the
    terminating path because a short page always ends the loop. No behavioral diff.
```

## Constraints

**Scope fence:** Documentation + final verification only. Do **not** add or change product tests (that is the core child) and do **not** modify `muter.conf.yml` or `scripts/mutate.sh`. If the final run shows a module below 85%, do not paper over it here — kick it back to the core child rather than weakening the config.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

Kill mutants via logic/boundary/exact-value assertions, not coverage theater. Do NOT delete or weaken equivalent mutants to inflate the score; document them per the `mutation-testing` skill.

**Tracer-code invariant:** The committed report reproduces — running `scripts/mutate.sh` again yields the documented per-module scores (within build-failure variance), and the product test suite stays green in CI on every push.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #65`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.
- [ ] Mutation score on the target module ≥ 85% (report the muter output in the PR).

## Labels

`spec-decomposition`, `tests`, `polish`, `phase-9-hardening`, `concurrency`
