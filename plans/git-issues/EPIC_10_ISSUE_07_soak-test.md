## Role

You are the product owner running the 5-day dogfood soak on real hardware.

## Goal

Install the TestFlight build on a paired iPhone + Apple Watch. Run real regimen through it for 5 consecutive days. Capture every bug, oddity, and impression in a soak diary. PR ends with either "no critical bugs — ready for TestFlight" or a follow-up issue per critical bug.

## Context

- **Parent epic:** #10
- **Predecessor issue(s):** #EPIC_10_ISSUE_06_NUMBER (mutation testing landed before soak so the safety paths are honest).
- **SPEC section:** §10 Phase 9 gate ("Submit to TestFlight; one week of dogfooding with no critical bugs").
- **Files involved:**
  - `Submission/soak-diary-<start-date>.md` — daily entries.
- **Prior decisions (locked):**
  - **5 consecutive days** of real-regimen use.
  - "Critical bug" definition: anything that causes a missed dose, double dose, or data loss.
- **State of the world:** Mutation-tested; ready to upload to TestFlight.

## Output Format

A single PR containing:

- [ ] `soak-diary-<start-date>.md` with 5 daily entries.
- [ ] Summary: critical / non-critical bug list at the end.
- [ ] One follow-up issue per critical bug (filed separately by the parent agent).

## Constraints

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Phase 9 gate completes.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] No critical bugs unresolved (or each has a tracked follow-up issue).
- [ ] PR opened with `Refs #10` and `Closes #EPIC_10_ISSUE_07_NUMBER`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`.
