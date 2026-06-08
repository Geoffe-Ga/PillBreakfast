## Role

You are a senior Swift safety-test engineer killing the surviving mutants Muter found in PillBreakfast's three safety modules. You write sharp boundary and exact-value tests until each module clears an 85% mutation score — never by weakening the runner.

## Goal

`DoseEventWriter`, `IngredientQueries`, and `SafetyEvaluator` each reach a mutation score ≥85%, measured individually via `scripts/mutate.sh`. Every non-equivalent surviving mutant from the baseline is killed by a new test in `PillBreakfastTests/` that uses exact-value or boundary assertions — especially the `<` interval-boundary pair, the `pageSize` paged-scan boundary, the `*`-vs-`+` ingredient-mg multiplication, and the cross-product 4000mg acetaminophen exact-`proposed` case.

## Context

- **Parent epic:** #65 (child of phase-epic #10 — Phase 9).
- **Predecessors:** EPIC_65_ISSUE_01 (Muter harness + baseline) — `muter.conf.yml`, `scripts/mutate.sh`, and the baseline scores must already exist so this child knows which mutants survive.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-65_mutation-testing-safety.md` §4.1 (the three modules' safety-critical logic), §4.2 (existing coverage + known gaps), §5.4 (mutant-killing strategy), §5.5 (predicted new tests per module), §6 (concrete interval-boundary scenarios), §7 (equivalent mutants, `pageSize` testability).
- **Files involved:**
  - `PillBreakfastTests/Logging/DoseEventWriterTests.swift` (extend).
  - `PillBreakfastTests/Queries/IngredientQueriesTests.swift` (extend).
  - `PillBreakfastTests/Safety/SafetyEvaluatorTests.swift` (extend).
  - Read-only under test: `Shared/Logging/DoseEventWriter.swift`, `Shared/Queries/IngredientQueries.swift`, `Shared/Safety/SafetyEvaluator.swift`, `Shared/Safety/Violation.swift`.
- **Prior decisions (locked):**
  - The most safety-critical boundaries: `SafetyEvaluator` `proposed > ceiling` (not `>=`) and `now.timeIntervalSince(lastDose) < Double(minInterval * 60)`; `IngredientQueries` `takenAt >= startOfDay` / `takenAt <= now` / `page.count < pageSize`; `DoseEventWriter` `Double(quantity) * component.dosagePerUnitMg`.
  - Use quantity ≥ 3 in multiplication tests so a `*`→`+` mutant diverges (quantity 1 and 2 alias the two operators).
  - `pageSize` is `public` and testable by value — seed exactly `pageSize` vs `pageSize + 1` events.
  - All target modules are `@MainActor` enums; tests use in-memory `ModelContainer`.

## Output Format

A single PR adding mutant-killing tests (the spec §5.5 list is the starting checklist; the actual surviving-mutant report drives the final set):

- [ ] `SafetyEvaluator`: `tooSoonAtExactIntervalBoundaryIsAllowed` (prior dose at `now - 14400s`, `minInterval: 240`, no ceiling → no `.tooSoon`) and `tooSoonOneSecondBeforeBoundaryFires` (prior dose at `now - 14399s` → exactly one `.tooSoon`). The pair kills `<`→`<=`, `<`→`>`, `<`→`>=`.
- [ ] `SafetyEvaluator`: `ceilingViolationCountIsExactlyOne`, `multiIngredientComboProducesCorrectViolationCount` (4 Excedrin → exactly 1 violation), `addedMgUsesExactQuantityMultiplication` (pin `ceiling.proposed` exactly, e.g. `3500 + 4 * 250`).
- [ ] `IngredientQueries`: `totalTodayAtExactStartOfDayIncluded`, `totalTodayAtExactNowIncluded`, `lastDoseTimeAtExactNowIsReturned`, `totalTodayIsZeroForSkippedOnlyDay`, `pagedScanExactlyPageSizeEventsNoMatch`, `pagedScanExactlyPageSizePlusOneFindsMatch`.
- [ ] `DoseEventWriter`: `writeDoseEventStoresExactTimestamp`, `writeDoseEventStoresScheduledFor`, `writeDoseEventStoresLogSource` (`.iphone`), `ingredientSnapshotScalesByExactQuantityThree`, `comboProductTotalMgIsProductNotSum` (quantity 3).
- [ ] Re-run `scripts/mutate.sh`; each module reports ≥85%. Paste the per-module muter summary into the PR.

## Examples

Match the Swift Testing style of the existing `SafetyEvaluatorTests.swift`. Interval-boundary pair (spec §6):

```swift
// minInterval 240 == 14400s; a dose exactly at the boundary must NOT warn.
// Kills `< Double(minInterval * 60)` -> `<=`.
#expect(violations.allSatisfy { if case .tooSoon = $0 { return false } else { return true } })
```

Exact-value over truthiness (spec §5.4):

```swift
#expect(snapshot.totalMg == 3 * component.dosagePerUnitMg)  // not `> 0`
```

## Constraints

**Scope fence:** New tests only, in the three existing test files. Do **not** modify production code, `muter.conf.yml`, or `scripts/mutate.sh` (the harness is fixed by the skeleton child), and do **not** write `Submission/mutation-report.md` (that is the polish child). Do not mutation-test any module beyond the three.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

Kill mutants via logic/boundary/exact-value assertions, not coverage theater. Do NOT delete or weaken equivalent mutants to inflate the score; document them per the `mutation-testing` skill.

**Tracer-code invariant:** Each added test is a standard Swift Testing case that passes against unmutated `main` and fails against the specific mutant it targets; the product test suite stays green in CI on every push while the mutation score climbs to ≥85% on all three modules.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #65`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.
- [ ] Mutation score on the target module ≥ 85% (report the muter output in the PR).

## Labels

`spec-decomposition`, `tests`, `core`, `phase-9-hardening`, `concurrency`
