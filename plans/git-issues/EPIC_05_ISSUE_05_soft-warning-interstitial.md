## Role

You are a senior watchOS engineer wiring the safety warning surface. You understand that this is the screen that distinguishes PillBreakfast from a generic medication app.

## Goal

Insert a soft warning interstitial between the quantity-picker confirmation and the `DoseEvent` write. If `SafetyEvaluator.violationsIfTaken(...)` returns a non-empty array, show a Liquid Glass interstitial that names each at-risk **ingredient**, shows current and proposed totals, and offers Override or Cancel. Override-on-a-high-risk-product still requires the press-and-hold gesture; non-high-risk products override with a single tap.

## Context

- **Parent epic:** #5
- **Predecessor issue(s):** #EPIC_05_ISSUE_04_NUMBER (quantity picker writes the dose; this issue gates that write on the evaluator).
- **SPEC section:** `plans/SPEC.md` §2.3 (PRN journey, soft warning step), §7.3 (ingredient-aware warning), §10 Phase 4 gate.
- **Files involved:**
  - `WatchApp Watch App/PRNSection/SafetyWarningView.swift` (new) — the interstitial.
  - `WatchApp Watch App/PRNSection/PRNQuantityPickerView.swift` — call `SafetyEvaluator.violationsIfTaken` on confirm; route to `SafetyWarningView` if non-empty.
- **Prior decisions (locked):**
  - **Warning names the ingredient**, not just the product. "Acetaminophen would total 4500mg today (ceiling 4000mg)."
  - **Override is allowed** — this is a soft warning, not a lockout. The user is the authority.
  - **Press-and-hold for override on high-risk meds** (e.g. lithium). Reuse `HighRiskConfirmButton`.
- **State of the world:** PRN list and quantity picker work; logging writes without consulting the evaluator.

## Output Format

A single PR containing:

- [ ] `SafetyWarningView` that takes `[Violation]` and renders one row per violation with ingredient name, current total, proposed total, and threshold context.
- [ ] Confirm path in `PRNQuantityPickerView` now calls `SafetyEvaluator.violationsIfTaken`; if empty, write directly; if non-empty, push `SafetyWarningView`.
- [ ] Override button: single-tap if `medication.isHighRisk == false`, press-and-hold (via `HighRiskConfirmButton`) if true.
- [ ] Cancel button returns to PRN list without writing.
- [ ] Tests: `SafetyWarningView` renders correctly for each `Violation` case; the path-decision logic in `PRNQuantityPickerView` (mockable harness) routes correctly.

## Examples

Sample copy:

```
⚠ Acetaminophen
Already today: 1500 mg
Would total: 4500 mg
Daily limit: 4000 mg

⚠ Acetaminophen
Last dose: 11:42 AM (1h 20m ago)
Recommended spacing: 4h

[Cancel]   [Hold to confirm anyway]
```

## Constraints

**Scope fence:** No iPhone-side warning; PRN logging only happens on the watch. No edit to the underlying ingredient ceilings — EPIC_05_ISSUE_06 ships the Ingredients screen.

**Override always available.** A PR that hard-blocks the user from overriding is wrong. PillBreakfast is a tool, not a guardrail.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** PRN safety warnings fire correctly; the three Phase 4 gate tests now have a visible UI counterpart.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #5` and `Closes #EPIC_05_ISSUE_05_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-4-prn-safety`.
