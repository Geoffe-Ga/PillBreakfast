## Role

You are a senior Swift test-infrastructure engineer standing up mutation testing for PillBreakfast. This is the tracer-skeleton issue: get Muter installed and reproducibly running against the three safety modules, capture a baseline score, and document the tool choice — before writing any new tests.

## Goal

Muter runs against exactly the three target files via the iOS scheme, driven by a real `scripts/mutate.sh` (not the stub) and a `muter.conf.yml` at the project root. A baseline mutation run completes and produces a report; the per-module baseline scores, mutant counts, and any build-failure mutants are captured in `plans/decisions/2026-06-07_mutation-tester.md`. No new product tests yet — this PR proves the harness end-to-end.

## Context

- **Parent epic:** #65 (child of phase-epic #10 — Phase 9: Hardening and Submission Prep).
- **Predecessors:** EPIC_10_ISSUE_05 (privacy nutrition labels). This is the first child of #65; later children depend on the harness and baseline here.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-65_mutation-testing-safety.md` §4.3 (Muter choice / install), §4.4 (operator scope), §5.1 (`muter.conf.yml` — verbatim), §5.2 (`scripts/mutate.sh` — verbatim), §5.3 (baseline measurement plan), §9 (Muter/Xcode-26/Swift-6 compatibility risks).
- **Files involved:**
  - `muter.conf.yml` (new — project root; content per spec §5.1).
  - `scripts/mutate.sh` (replace the stub; content per spec §5.2; `set -euo pipefail`, `--version` print, `--dry-run` branch).
  - `plans/decisions/2026-06-07_mutation-tester.md` (new — tool choice, version, install method, rationale, baseline per module, build-failure mutants).
  - Read-only targets: `Shared/Logging/DoseEventWriter.swift`, `Shared/Queries/IngredientQueries.swift`, `Shared/Safety/SafetyEvaluator.swift`; their tests in `PillBreakfastTests/`.
- **Prior decisions (locked):**
  - **No Swift package manifest exists** (CLAUDE.md). Muter is installed as an external CLI (`brew install muter` or pinned binary), not as an SPM dependency. Record the exact version (`muter --version`) in both the script header and the decision doc.
  - **iOS scheme** (`PillBreakfast`, iPhone 17 simulator) — the three modules compile into the iOS app's `Shared/` group and their tests live in `PillBreakfastTests/`.
  - `muter.conf.yml` `files_to_mutate` lists exactly the three target files — no others.
  - If Muter is incompatible with the Xcode 26 / Swift 6 toolchain, document the fallback (`swift-mutations`) decision in `plans/decisions/` rather than forcing it.

## Output Format

A single PR containing:

- [ ] `muter.conf.yml` at project root, matching spec §5.1 (iOS scheme/destination, exactly the three `files_to_mutate`, review-date comment).
- [ ] `scripts/mutate.sh` replacing the stub, matching spec §5.2 (`set -euo pipefail`, muter-presence guard, `--version` echo, `--dry-run` branch, report paths, reminder to update `Submission/mutation-report.md`); executable bit set.
- [ ] `plans/decisions/2026-06-07_mutation-tester.md` documenting: tool = Muter, pinned version, install method, rationale over `swift-mutations`/`muterbot`, **baseline score per module**, total/killed/survived counts, and any build-failure mutants excluded from the denominator.
- [ ] PR description notes the baseline scores and which module is expected to need the most test investment (per spec §5.3: `DoseEventWriter` likely weakest, `SafetyEvaluator` likely strongest).

## Examples

`scripts/mutate.sh` header and guard (per spec §5.2):

```bash
#!/usr/bin/env bash
# Mutation testing harness for PillBreakfast — targets the three critical safety modules.
# Tool: Muter <VERSION> (see plans/decisions/2026-06-07_mutation-tester.md)
set -euo pipefail
MUTER=$(command -v muter || echo "")
if [ -z "$MUTER" ]; then
  echo "ERROR: muter not found. Install with: brew install muter"
  exit 1
fi
echo "muter version: $($MUTER --version)"
```

## Constraints

**Scope fence:** Harness + baseline only. Do **not** add or modify any product test (that is the core child) and do **not** write `Submission/mutation-report.md` (that is the polish child). Touch only the three new/replaced files plus the read of the target modules.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

Kill mutants via logic/boundary/exact-value assertions, not coverage theater. Do NOT delete or weaken equivalent mutants to inflate the score; document them per the `mutation-testing` skill.

**Tracer-code invariant:** After this PR, `./scripts/mutate.sh --dry-run` lists mutants for exactly the three modules and a full `./scripts/mutate.sh` produces a baseline report — proving the pipeline before any mutant-killing test work begins. The product test suite is unchanged and still green.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #65`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.
- [ ] Baseline mutation score per target module is reported from the muter output in the PR (the ≥85% target is met by the core child; this skeleton only establishes the baseline).

## Labels

`spec-decomposition`, `tests`, `tracer-skeleton`, `phase-9-hardening`, `core`, `concurrency`
