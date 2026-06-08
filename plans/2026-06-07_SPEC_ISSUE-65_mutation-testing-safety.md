# SPEC: Issue #65 — Mutation Testing on Three Critical Safety Modules to >=85%

| Field | Value |
|---|---|
| Issue | #65 |
| Phase | 9 (Hardening and Submission Prep) |
| Epic | #10 |
| Labels | `spec-decomposition`, `core`, `phase-9-hardening`, `tests` |
| Status | Draft |
| Date | 2026-06-07 |
| Related issues | Predecessor: EPIC_10_ISSUE_05 (privacy nutrition labels); successor: EPIC_10_ISSUE_07 (soak test) |
| Authored by | Test Specialist |

---

## 1. Summary

Run `Muter` (the Swift mutation testing tool) against three safety-critical modules — `DoseEventWriter`, `IngredientQueries`, and `SafetyEvaluator` — and achieve a mutation score of at least 85% on all three. Fill the stub at `scripts/mutate.sh` with a real, reproducible invocation. Add new tests wherever mutants survive, guided by exact-value and boundary assertions. Document the tooling choice in `plans/decisions/2026-06-07_mutation-tester.md` and record the achieved score in `Submission/mutation-report.md`.

---

## 2. Problem Statement / Motivation

SPEC §10 Phase 9 calls out "mutation-tested critical paths: dose logging, running-total computation, ceiling enforcement" as a required gate before TestFlight submission. SPEC §11 Phase 9 adds: "Geoff has opinions here already." The mutation-testing skill confirms those opinions: a green test suite that a mutation tester can blow holes in is not a real safety net. It is coverage theater.

The three target modules are the exact functions that prevent a Tylenol + Excedrin acetaminophen overdose, an accidental lithium double-dose, and a corrupted dose history snapshot. These are not hypothetical failure modes — they are the product's core safety promise. A `>` changed to `>=` in `SafetyEvaluator.violationsIfTaken` would silently allow a dose landing exactly on the ceiling. A missing `status == .taken` filter in `totalToday` would count skipped doses toward safety totals. A `DoseEventWriter` that scaled ingredient amounts by `quantity - 1` instead of `quantity` would undercount every logged dose's mg.

Existing tests (`SafetyEvaluatorTests`, `IngredientQueriesTests`, `DoseEventWriterTests`) are logically correct but were written to verify behavior, not to kill mutants. The mutation run will reveal which branches, operators, and constants are unguarded.

---

## 3. Goals and Non-Goals

**Goals:**
- Mutation score >= 85% on each of the three target modules, measured individually.
- `scripts/mutate.sh` is a real, documented, reproducible script that any engineer can run locally to re-measure the score.
- New tests added (using exact-value assertions and boundary tests) wherever surviving mutants expose a real gap.
- Tool choice documented in `plans/decisions/2026-06-07_mutation-tester.md`.
- Score recorded in `Submission/mutation-report.md` (per module, with total, dated).

**Non-Goals:**
- Mutation-testing any other module (scope fence from the issue brief: "Don't mutation-test every module — only the three critical paths").
- Achieving 100% mutation score. Equivalent mutants (mutations that produce observably identical behavior) are inherent in any codebase and cannot be killed by correct tests. Document them rather than inflating the score by deleting them from the runner config.
- CI integration of the mutation run. The issue brief explicitly marks this as out of scope ("CI integration is out of scope (manual run is fine for now)"). `scripts/mutate.sh` runs locally; the passing test suite (killed mutants become new test cases) does run in CI.
- Killing mutants by suppressing them in the Muter configuration. Any excluded mutation must be documented as a genuinely equivalent mutant with a comment explaining why.

---

## 4. Background and Current State

### 4.1 The Three Target Modules

**Module 1: `Shared/Logging/DoseEventWriter.swift`**

Single public function: `DoseEventWriter.writeDoseEvent(for:scheduledFor:quantity:status:loggedOn:at:in:)`. The safety-critical logic is in the `amounts` array construction: `totalMg: Double(quantity) * component.dosagePerUnitMg`. A mutation to `*` (e.g., `+` or `-`) or to `quantity` (e.g., `quantity - 1`) corrupts the ingredient snapshot forever — these amounts are never recomputed. The `context.insert(event)` and `context.save()` calls are also mutation targets: omitting the save would leave the dose in memory but not persisted.

**Module 2: `Shared/Queries/IngredientQueries.swift`**

Three public functions:
- `totalToday(ingredient:in:at:calendar:)` — the daily running total. Key logic: `startOfDay` boundary, `$0.takenAt >= startOfDay && $0.takenAt <= now` predicate, `.filter { $0.status == .taken }`, `.filter { $0.ingredientID == ingredientID }`, `.reduce(0) { $0 + $1.totalMg }`. Each of these is a potential mutant target.
- `lastDoseTime(ingredient:in:atOrBefore:)` — most recent `.taken` time for an ingredient. Key logic: `event.status == .taken && event.ingredientAmounts.contains { $0.ingredientID == ingredientID }` in the match closure.
- `lastProductDoseTime(medication:in:atOrBefore:)` — same paged scan, per-product instead of per-ingredient.
- `pagedScan(in:atOrBefore:match:)` (private) — paged descending scan. Key logic: `page.count < pageSize` termination condition, `offset += page.count` accumulation, `SortDescriptor(\.takenAt, order: .reverse)` sort direction.

**Module 3: `Shared/Safety/SafetyEvaluator.swift`**

Single public function: `SafetyEvaluator.violationsIfTaken(_:quantity:at:in:calendar:)`. Key logic:
- `proposed > ceiling` (not `>=`) in the ceiling check — this is the most safety-critical boundary in the codebase.
- `now.timeIntervalSince(lastDose) < Double(minInterval * 60)` in the interval check — mutating `<` to `<=` would allow a dose at exactly the interval boundary to fire a false warning.
- `aggregatedByIngredient` grouping — if this fails to merge duplicate-ingredient components, a combo product's ceiling violation would be under-counted (the existing `duplicateIngredientComponentsAggregateBeforeCeilingCheck` test covers this, but mutation testing verifies the assertion is sharp enough to catch operator mutations).
- `addedMg = Double(quantity) * component.dosagePerUnitMg` in the aggregate — same multiplication risk as `DoseEventWriter`.

### 4.2 Existing Test Coverage

Tests exist for all three modules. The coverage is logically correct but written with an eye toward scenario verification, not mutant-killing density.

| Module | Test file | Test count | Known gaps |
|---|---|---|---|
| `DoseEventWriter` | `PillBreakfastTests/Logging/DoseEventWriterTests.swift` | 5 | No test asserts exact `takenAt` timestamp on the written event; no test verifies `scheduledFor` is stored correctly; `loggedOn` is asserted in only one test. |
| `IngredientQueries` | `PillBreakfastTests/Queries/IngredientQueriesTests.swift` | 12 | Paged scan's `offset += page.count` accumulation is only tested by `lastDoseTimeFindsMatchBeyondFirstPage`; no test exercises the exact `pageSize` boundary (exactly `pageSize` events with no match vs. `pageSize + 1`). The `<= now` inclusive bound in `totalToday` is implicit in existing tests but no test pins the exact boundary value. |
| `SafetyEvaluator` | `PillBreakfastTests/Safety/SafetyEvaluatorTests.swift` | 9 | The `proposed > ceiling` (not `>=`) semantics are covered by `doseLandingExactlyOnCeilingIsAllowed`, but the `tooSoon` exact-boundary case is not: no test verifies that a dose at exactly `minInterval * 60` seconds since the last dose does NOT trigger a warning. The violation count (not just presence/absence) is asserted in `duplicateIngredientComponentsAggregateBeforeCeilingCheck` but not in the base `gabapentinSelfPacing` test. |

### 4.3 Mutation Testing Toolchain: Muter

**Chosen tool: Muter** (`https://github.com/muter-mutation-testing/muter`).

Rationale:
- Swift-native; no Python/JVM runtime dependencies.
- Operates on the Xcode project directly; supports `xcodebuild` as the test runner.
- Supports scoped runs via `--files-to-mutate` so only the three target modules are mutated (critical for keeping the run time practical).
- Produces a JSON/HTML report with per-mutant outcomes (killed/survived/build failed/equivalent).
- Actively maintained (Swift 6 compatible as of 2025).
- The SPEC §11 Phase 9 skill callout references "Muter (or equivalent)" by name.
- The existing `scripts/mutate.sh` stub refers to "the mutation-testing harness" with no specific tool — Muter is the concrete implementation.

**Installation:** Muter can be installed via Homebrew (`brew install muter`) or as a pre-built binary. Pin the version in `scripts/mutate.sh` (check the installed version with `muter --version` and record it in the script header comment).

**Alternative considered: `muterbot`/`swift-mutations`:** Less mature, less documentation. Not chosen.

### 4.4 Mutation Operator Scope

Muter applies these operator categories by default. All are relevant for the three target modules:

| Operator | Relevance to target modules |
|---|---|
| Relational operator replacement (`>` to `>=`, `<` to `<=`, etc.) | `SafetyEvaluator`: `proposed > ceiling`, `now.timeIntervalSince < Double(minInterval * 60)`. `IngredientQueries`: `takenAt >= startOfDay`, `takenAt <= now`, `page.count < pageSize`. |
| Arithmetic operator replacement (`*` to `+`, `/`, etc.) | `DoseEventWriter`: `Double(quantity) * component.dosagePerUnitMg`. `SafetyEvaluator`: same multiplication in `aggregatedByIngredient`. `IngredientQueries`: `$0 + $1.totalMg` reduce, `offset += page.count`. |
| Logical operator replacement (`&&` to `||`, etc.) | `IngredientQueries`: `status == .taken && event.ingredientAmounts.contains { ... }` in `pagedScan` match. `SafetyEvaluator`: `ingredient.dailyCeilingMg` + `ingredient.minIntervalMinutes` guards. |
| Return value swap | `totalToday` returning `0.0` unconditionally; `violationsIfTaken` returning `[]` unconditionally. |
| Negate conditionals | Flipping `if let ceiling` / `if let minInterval` guards in `SafetyEvaluator`. |

---

## 5. Detailed Design

### 5.1 Muter Configuration File

Create `muter.conf.yml` at the project root:

```yaml
# muter.conf.yml
# Mutation testing config for PillBreakfast — targets only the three critical
# safety modules per SPEC §10 Phase 9 and Issue #65.
# Review date: 2027-06-07 (or after any Swift/Muter major version upgrade).
project_directory: .
test_command_arguments:
  - test
  - -project
  - PillBreakfast.xcodeproj
  - -scheme
  - PillBreakfast
  - -destination
  - platform=iOS Simulator,name=iPhone 17,OS=latest
files_to_mutate:
  - Shared/Logging/DoseEventWriter.swift
  - Shared/Queries/IngredientQueries.swift
  - Shared/Safety/SafetyEvaluator.swift
```

**Why the iOS scheme, not the watchOS scheme?** The three target modules live in `Shared/` and are compiled into both targets. `SafetyEvaluatorTests`, `IngredientQueriesTests`, and `DoseEventWriterTests` all live in `PillBreakfastTests/` (the iOS test target). Running against the iOS scheme keeps the Muter run fast (iOS simulator boots faster than watchOS in CI and local environments) and correctly exercises the tests that cover the target modules. The watchOS scheme would also work but adds unnecessary boot time.

**Note:** Muter runs `xcodebuild test` for each mutation. With three files at approximately 10–20 mutants each (30–60 total), the run takes on the order of 30–90 minutes depending on hardware. This is why CI integration is deferred.

### 5.2 `scripts/mutate.sh`

Replace the stub with:

```bash
#!/usr/bin/env bash
# Mutation testing harness for PillBreakfast — targets the three critical safety modules.
# Tool: Muter <VERSION> (see plans/decisions/2026-06-07_mutation-tester.md)
# Usage:
#   ./scripts/mutate.sh            # run all mutations, write report
#   ./scripts/mutate.sh --dry-run  # print mutants without running tests
#
# Prerequisites:
#   brew install muter  (or download the binary from the Muter GitHub releases)
#   Both simulators must be available; the iOS scheme is used (see SPEC).
#   Estimated runtime: 30–90 minutes.
#
# Output:
#   mutation-report/muter-report.json    (Muter native output)
#   mutation-report/muter-report.html    (human-readable)
#   Submission/mutation-report.md        (updated by this script with summary)
set -euo pipefail

MUTER=$(command -v muter || echo "")
if [ -z "$MUTER" ]; then
  echo "ERROR: muter not found. Install with: brew install muter"
  exit 1
fi

echo "muter version: $($MUTER --version)"
echo "Starting mutation run on three critical safety modules..."
echo "  Shared/Logging/DoseEventWriter.swift"
echo "  Shared/Queries/IngredientQueries.swift"
echo "  Shared/Safety/SafetyEvaluator.swift"
echo ""

mkdir -p mutation-report

if [ "${1:-}" = "--dry-run" ]; then
  $MUTER --dry-run
  exit 0
fi

$MUTER

echo ""
echo "Mutation run complete. Reports:"
echo "  mutation-report/muter-report.html"
echo "  mutation-report/muter-report.json"
echo ""
echo "Update Submission/mutation-report.md with the scores above before committing."
```

### 5.3 Baseline Measurement Plan

Before writing any new tests, run `scripts/mutate.sh` once to establish the baseline score. Record:
- Total mutants generated per module.
- Killed vs. survived per module.
- Baseline mutation score per module.
- Any mutants that fail to build (build-failure mutants are excluded from the score denominator).

This baseline informs which modules need the most test investment. Based on the gap analysis in §4.2, `SafetyEvaluator` is expected to have the strongest baseline (9 tests, including 3 SPEC gate tests with sharp assertions), while `DoseEventWriter` is the most likely to have surviving mutants (5 tests, with some missing exact-value assertions).

### 5.4 Mutant-Killing Strategy

Apply the mutation-testing skill philosophy (from `.claude/skills/mutation-testing/SKILL.md`):

**For every surviving mutant, ask:**
1. Would a test fail if the constant changed by 1? → Add exact-value assertions.
2. Would a test fail if the operator changed? → Add boundary tests (at, above, below).
3. Would a test fail if a check were removed? → Add negative tests (verify that conditions that should not fire, do not).
4. Would a test fail if a return value were swapped? → Add tests that distinguish the returned values, not just their truthiness.

**Do not:** Delete surviving mutants from the Muter config to inflate the score. Each excluded mutant must be documented in `Submission/mutation-report.md` as "equivalent" with a written explanation.

### 5.5 New Tests Required (Predicted from Gap Analysis)

The following test cases are predicted to kill surviving mutants. They are starting points, not an exhaustive list — the actual mutant report drives final decisions.

#### DoseEventWriter new tests

**`writeDoseEventStoresExactTimestamp`**
Asserts `event.takenAt == now` with a pinned `now: Date`. Kills mutants that substitute a different date (e.g., `.distantFuture`, `scheduledFor ?? now`).

**`writeDoseEventStoresScheduledFor`**
Passes a non-nil `scheduledFor` and asserts `event.scheduledFor == scheduledFor`. Kills the mutant that sets `scheduledFor` to `nil` unconditionally.

**`writeDoseEventStoresLogSource`**
Asserts `event.loggedOn == .iphone` for an `.iphone`-sourced call. Currently only `.watch` is tested. Kills the mutant that hardcodes `.watch` regardless of the parameter.

**`ingredientSnapshotScalesByExactQuantityThree`**
Takes quantity 3, asserts `totalMg == 3 * dosagePerUnitMg` (not just `> 0`). The existing `singleIngredientSnapshotScalesByQuantity` uses quantity 1 — `1 * x == x`, so a mutant replacing `*` with `+` (giving `quantity + dosagePerUnitMg`) would pass for quantity 1 but fail for quantity 3.

**`comboProductTotalMgIsProductNotSum`**
For Excedrin at quantity 2: asserts each ingredient's `totalMg` is exactly `2 * dosagePerUnitMg`, not `dosagePerUnitMg + dosagePerUnitMg` (which equals the same thing for quantity 2 but would differ for quantity 3). Use quantity 3 in this test to distinguish multiplication from addition.

#### IngredientQueries new tests

**`totalTodayAtExactStartOfDayIncluded`**
Insert a dose at exactly `calendar.startOfDay(for: now)`. Assert total == that dose's mg. Kills the mutant that changes `takenAt >= startOfDay` to `takenAt > startOfDay` (which would exclude the midnight dose).

**`totalTodayAtExactNowIncluded`**
Insert a dose at exactly `now`. Assert total includes it. Kills the mutant that changes `takenAt <= now` to `takenAt < now`.

**`lastDoseTimeAtExactNowIsReturned`**
Insert a dose with `takenAt == now`. Assert `lastDoseTime(atOrBefore: now) == now`. Kills the mutant changing `<= now` to `< now` in `pagedScan`.

**`totalTodayIsZeroForSkippedOnlyDay`**
Insert only `.skipped` and `.snoozed` doses. Assert `totalToday == 0.0`. Kills mutants that remove the `status == .taken` filter. (An analogous test exists but adding an assertion on the exact value `0.0` rather than just trusting the existing `== 1000` test to catch the filter removal makes the kill more direct.)

**`pagedScanExactlyPageSizeEventsNoMatch`**
Insert exactly `pageSize` ibuprofen events. Query for acetaminophen. Assert result is `nil`. Kills the mutant that changes `page.count < pageSize` to `page.count <= pageSize` (which would terminate one page early and miss an event at the exact boundary).

**`pagedScanExactlyPageSizePlusOneFindsMatch`**
Insert `pageSize + 1` ibuprofen events sorted after a single acetaminophen event. Assert the acetaminophen event is found. This is the complementary boundary test to the above.

**`lastDoseTimeExactIntervalBoundary`**
Not a direct `IngredientQueries` test but a `SafetyEvaluator` test that exercises the full stack. See §5.5 below.

#### SafetyEvaluator new tests

**`ceilingExactlyOnBoundaryAllowed` (already exists as `doseLandingExactlyOnCeilingIsAllowed`)**
This test exists. Verify the assertion is sharp: it asserts `violations.isEmpty`. The mutant changing `>` to `>=` would produce one violation. The test would kill it. No new test needed here — but verify the current test's assertion style is exact (it is: `#expect(... .isEmpty)`).

**`tooSoonAtExactIntervalBoundaryIsAllowed`**
The exact boundary case for interval enforcement. Insert a dose at exactly `minInterval * 60` seconds before `now`. Assert NO `tooSoon` violation fires. This kills the mutant changing `<` to `<=` in `now.timeIntervalSince(lastDose) < Double(minInterval * 60)`.

Parameters: `minInterval: 240` (4 hours = 14400 seconds). Insert prior dose at `now.addingTimeInterval(-14400)`. Assert `violationsIfTaken` returns no `.tooSoon` violation (ceiling may fire separately, configure ingredient with no ceiling).

**`tooSoonOneSecondBeforeBoundaryFires`**
Complementary: insert prior dose at `now.addingTimeInterval(-14399)`. Assert `.tooSoon` violation fires. Together with the above, these two tests pin both sides of the `<` operator — either mutant to `<=` or `>` kills one of the pair.

**`ceilingViolationCountIsExactlyOne`**
Extend `gabapentinSelfPacing` to assert `violations.count == 1`, not just that a ceiling violation is present. This kills the mutant that produces two violations for a single-ingredient, single-ceiling scenario.

**`multiIngredientComboProducesCorrectViolationCount`**
Take 4 Excedrin (acetaminophen + aspirin + caffeine) where acetaminophen would exceed its ceiling but aspirin and caffeine have no ceilings. Assert exactly 1 violation (only acetaminophen fires). Kills the mutant that emits a violation for every component regardless of ceiling configuration.

**`addedMgUsesExactQuantityMultiplication`**
Verify `proposed == current + (quantity * dosagePerUnitMg)` with quantity == 3 and a known `dosagePerUnitMg`. The cross-product test (`crossProductTylenolPlusExcedrinTripsAcetaminophenCeiling`) uses quantity 4 but asserts only that the ceiling fires, not the exact `proposed` value. Add an assertion: `ceiling.proposed == 3500 + (4 * 250)` to pin the arithmetic. This kills the mutant that uses `quantity - 1` or `quantity + 1` in `aggregatedByIngredient`.

---

## 6. Concrete Test Cases / Scenarios

The Phase 4 killer test from SPEC §10 ("The cross-product safety case: acetaminophen from Tylenol plus Excedrin exceeds the 4000mg ceiling") is already implemented as `crossProductTylenolPlusExcedrinTripsAcetaminophenCeiling` in `SafetyEvaluatorTests`. The mutation-testing work enriches it — the test currently asserts:

```swift
#expect(ceiling.current == 3500)
#expect(ceiling.proposed == 4500)
#expect(ceiling.ceiling == 4000)
```

These three exact-value assertions are already strong mutant killers. No change needed to the test itself. What is missing is the boundary test at `proposed == 4000` (exactly on ceiling — allowed) which `doseLandingExactlyOnCeilingIsAllowed` covers for a simpler scenario.

**The highest-value new scenario is the exact-boundary interval test**, because it pins both sides of the `<` operator that is the most likely surviving mutant target in `SafetyEvaluator`:

```
tooSoonAtExactIntervalBoundaryIsAllowed:
  ingredient: Acetaminophen, minInterval: 240 (14400 seconds), no ceiling
  prior dose: takenAt = now - 14400 seconds (exactly at boundary)
  prospective dose: 1 tablet
  expected: violations.isEmpty
  kills: mutant changing `< Double(minInterval * 60)` to `<= Double(minInterval * 60)`

tooSoonOneSecondBeforeBoundaryFires:
  ingredient: Acetaminophen, minInterval: 240 (14400 seconds), no ceiling
  prior dose: takenAt = now - 14399 seconds (one second inside the interval)
  prospective dose: 1 tablet
  expected: exactly one .tooSoon violation, ingredient is Acetaminophen
  kills: mutant changing `<` to `>`
```

The pair kills all three directional mutations: `<` to `<=`, `<` to `>`, and `<` to `>=`.

---

## 7. Edge Cases and Determinism Concerns

**Equivalent mutants.** Some mutants in `pagedScan` are genuinely equivalent: changing `offset += page.count` to `offset += pageSize` produces identical behavior because a short page (`count < pageSize`) always terminates the loop, making the two expressions equivalent on the non-terminating path. Document these as equivalent in `Submission/mutation-report.md`; do not add tests that would only "pass" by accident.

**Muter build-failure mutants.** Muter sometimes produces mutations that fail to compile (e.g., replacing a `Double` expression with a `String`). These are automatically excluded from the score. They appear in the report as "build failures" and do not count for or against the 85% target.

**Test runtime under mutation.** Each mutation runs the full test suite for the iOS scheme. The three modules' tests are fast (all in-memory `ModelContainer`) but the entire `PillBreakfastTests` target runs per mutation. With ~100 test cases in the suite and 30–60 mutations, expect 3000–6000 test executions total. On an M-series Mac this is approximately 30–60 minutes. On an M1 it may run 60–90 minutes.

**Non-determinism in test ordering.** Swift Testing randomizes test execution order by default. Muter runs each mutant's test suite as a subprocess. Since the target tests use in-memory `ModelContainer` (no shared global state), order independence is guaranteed. No concern here.

**`@MainActor` isolation.** All three modules are `@MainActor`-isolated enums. Muter's instrumented build may introduce race conditions if it inserts synchronization-breaking mutations (e.g., removing actor annotations). Muter does not mutate actor annotations by default — only logic operators, constants, and conditions. This is safe.

**`IngredientQueries.pageSize` is `public`.** The tests already exercise `IngredientQueries.pageSize` directly (`haystackCount = IngredientQueries.pageSize + 50`). A mutant changing `pageSize` from 100 to 101 would break the boundary test `pagedScanExactlyPageSizeEventsNoMatch` (which seeds exactly 100 ibuprofen events). This is the desired behavior — the constant is testable by value.

---

## 8. CI Integration

Mutation testing is explicitly NOT automated in CI for this issue. The rationale: a full Muter run takes 30–90 minutes and would make every PR unbearably slow. The investment is better placed in the quality of the tests that Muter drives us to write — those tests run in CI on every push.

**What DOES run in CI:** Every new test case written as a result of surviving mutants is a standard Swift Testing test in `PillBreakfastTests/`. These run in CI via the `xcodebuild test` step (when un-commented per Issue #31's work). Any regression in the new tests shows up immediately on every push.

**Future consideration:** If Muter adds a "changed files only" mode (analogous to Stryker's incremental mode), it could be added to CI gated on a short timeout (e.g., 10 minutes). Not in scope for this issue.

**Running locally:**

```bash
# Full mutation run (30–90 minutes):
./scripts/mutate.sh

# Dry run (prints mutants without executing tests — useful for planning):
./scripts/mutate.sh --dry-run

# Run only the existing test suite (what CI does):
xcodebuild test \
  -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast' \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'

# Run only the safety module tests:
xcodebuild test \
  -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast' \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:'PillBreakfastTests/SafetyEvaluatorTests' \
  -only-testing:'PillBreakfastTests/IngredientQueriesTests' \
  -only-testing:'PillBreakfastTests/DoseEventWriterTests'
```

Note the Swift Testing filter syntax (from CLAUDE.md): suite name without `test` prefix, colon-separated from the scheme's test target.

---

## 9. Risks and Open Questions

**Risk: Muter does not support watchOS targets as a test runner.** Muter runs `xcodebuild test` with the arguments in `muter.conf.yml`. Using the iOS scheme (as specified in §5.1) sidesteps this: the three target modules are compiled into the iOS app's `Shared/` group, and their tests live in `PillBreakfastTests`. The watchOS scheme is irrelevant for mutation testing of shared logic.

**Risk: Muter version incompatibility with Xcode 26 / Swift 6.** Muter uses `SourceKit` internally to parse and instrument Swift source. Swift 6 source-breaking changes may require a Muter version from 2025 or later. The engineer must verify Muter builds and runs against the Xcode 26 toolchain before beginning. If Muter is incompatible, an alternative is `swift-mutations` (a simpler source-text-level tool) — document the fallback choice in `plans/decisions/`.

**Risk: 85% target is not achievable without deleting equivalent mutants.** If the baseline score after adding new tests is, say, 82% with 3 equivalent mutants, the engineer must document the equivalent mutants in detail and justify why they cannot be killed (because killing them would require tests that verify implementation details rather than behavior). The score should reflect real test quality; the 85% target is a guideline informed by the expected density of equivalent mutants in pure-functional query code, not a hard floor that overrides engineering judgment.

**Risk: Muter's mutation operators do not cover all dangerous mutations.** Muter's default operators (relational, arithmetic, logical, return value) cover the highest-risk patterns in the target modules. If a higher-risk mutation is identified (e.g., changing `.taken` enum case comparison to `.skipped`) and Muter does not generate it, write a targeted test for that case directly as a "manual mutation test" and document it in `Submission/mutation-report.md` under "manual coverage".

**Open question: Should `SafetyEvaluator` also be tested on the watchOS scheme?** `SafetyEvaluator` is `@MainActor` and runs on the watch. The existing tests run on the iOS scheme. Mutation testing on the watchOS scheme would require a separate `muter.conf.yml` targeting `PillBreakfast Watch App Watch App` scheme — the watch test target (`PillBreakfast Watch App Watch AppTests`) does not currently contain tests for `SafetyEvaluator` (it has `PRNListViewTests` and `SafetyWarningViewTests` which are view-level tests, not logic-level). Mutation testing the iOS scheme is correct and sufficient because the business logic is identical on both targets.

---

## 10. Decomposition Hints

Single PR per the issue brief. Logical sequence within the PR:

1. Install Muter and verify it runs against the iOS scheme.
2. Fill in `scripts/mutate.sh` (replacing the stub).
3. Run `./scripts/mutate.sh` to get the baseline score.
4. Write `plans/decisions/2026-06-07_mutation-tester.md` documenting the tool choice and baseline.
5. Write new tests for each surviving mutant (use §5.5 as a starting checklist, adjust based on actual surviving mutants).
6. Re-run mutation testing to verify >=85% score on all three modules.
7. Write `Submission/mutation-report.md` with the final scores.
8. Run `pre-commit run --all-files` and `xcodebuild test` on both schemes.
9. Open PR.

If the baseline score is already >=85% (possible given the existing test depth), the PR's main deliverable is `scripts/mutate.sh`, `muter.conf.yml`, `plans/decisions/`, and `Submission/mutation-report.md`. Still add at least the boundary tests from §5.5 — they are the right tests to have regardless of the mutation score.

---

## 11. Acceptance Criteria / Done-Done

These map to SPEC §10 Phase 9: "Mutation-tested critical paths: dose logging, running-total computation, ceiling enforcement."

- [ ] `muter.conf.yml` exists at the project root, targeting exactly the three files: `Shared/Logging/DoseEventWriter.swift`, `Shared/Queries/IngredientQueries.swift`, `Shared/Safety/SafetyEvaluator.swift`.
- [ ] `scripts/mutate.sh` is a real, documented script (not the stub). Running it from the project root produces a mutation report. It includes a `--version` print of the installed Muter.
- [ ] `plans/decisions/2026-06-07_mutation-tester.md` exists and documents: tool choice (Muter), version pinned, installation method, rationale over alternatives, baseline score per module, and any known equivalent mutants.
- [ ] Mutation score is >=85% on each of the three target modules individually, as measured by `scripts/mutate.sh`.
- [ ] `Submission/mutation-report.md` records: per-module mutation score, total mutants generated, killed count, survived count, equivalent mutant count (with explanation per equivalent mutant), Muter version, date of run.
- [ ] All surviving mutants that are NOT classified as equivalent have corresponding new test cases in `PillBreakfastTests/`.
- [ ] New test cases use exact-value assertions (not just `isEmpty` or `!= nil`) for all safety-critical constants and boundaries.
- [ ] `tooSoonAtExactIntervalBoundaryIsAllowed` test exists and passes.
- [ ] `tooSoonOneSecondBeforeBoundaryFires` test exists and passes.
- [ ] `writeDoseEventStoresExactTimestamp` test exists and passes.
- [ ] `pagedScanExactlyPageSizePlusOneFindsMatch` or an equivalent boundary test for the paged scan termination condition exists and passes.
- [ ] `xcodebuild test` passes for both schemes (iOS scheme for safety module tests; watchOS scheme for all watch-side tests).
- [ ] `pre-commit run --all-files` is clean.
- [ ] No surviving mutant was deleted from the Muter config to inflate the score.
- [ ] No `Task.sleep` in any new test code.
- [ ] No `@unchecked Sendable`, no force-unwrap, no `try?` swallowing errors in new test or production code.

---

## 12. References

- SPEC §5.1–§5.3 (ingredient layer, denormalized snapshots, `violationsIfTaken` pseudocode)
- SPEC §10 Phase 4 (gate test: cross-product Tylenol + Excedrin killer case, 3500 + 1000 = 4500 > 4000)
- SPEC §10 Phase 9 (mutation-tested critical paths gate)
- SPEC §11 Phase 9 skill callout ("Geoff has opinions here already; lean on them")
- CLAUDE.md: build/test commands, exact scheme names, Swift Testing filter syntax
- `/Users/geoffgallinger/Projects/PillBreakfast/Shared/Logging/DoseEventWriter.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/Shared/Queries/IngredientQueries.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/Shared/Safety/SafetyEvaluator.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/Shared/Safety/Violation.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfastTests/Safety/SafetyEvaluatorTests.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfastTests/Queries/IngredientQueriesTests.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfastTests/Logging/DoseEventWriterTests.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/scripts/mutate.sh` (current stub)
- `/Users/geoffgallinger/Projects/PillBreakfast/.claude/skills/mutation-testing/SKILL.md`
- Muter: `https://github.com/muter-mutation-testing/muter`
- `plans/git-issues/EPIC_10_ISSUE_06_mutation-testing.md`
- `plans/git-issues/EPIC_10_hardening-and-submission.md`
