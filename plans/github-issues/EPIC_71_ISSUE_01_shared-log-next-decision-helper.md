## Role

You are a senior watchOS / App Intents engineer factoring the "log the next pending dose" decision tree into a single shared helper that both the existing widget intent (`LogNextDoseIntent`, EPIC 08 ISSUE 04) and the forthcoming Action Button intent (#71) call. This is the skeleton of the Ultra Action Button feature and its single most important safety guarantee: there must be exactly **one** copy of the "is this dose safe to one-press?" decision.

## Goal

Extract (or formalize from the widget intent) one `@MainActor` function that, given a `ModelContext` and `now`, computes the next pending dose and returns an outcome: `none` → caught-up feedback; `high-risk` → a *route* to the press-and-hold confirm (NEVER a log); `not high-risk` → write a `.taken` `DoseEvent` via `DoseEventWriter`, transfer it, reload timelines. Refactor the widget intent to call this helper so it behaves identically, and unit-test the three branches — especially the high-risk "must not auto-log" branch.

## Context

- **Parent epic:** #71
- **Predecessors:** EPIC 08 ISSUE 04 (`Shared/Intents/LogNextDoseIntent.swift` — the widget intent whose contract this formalizes), EPIC 04 (the high-risk press-and-hold safety model), the shipped `DoseEventWriter` / `PendingQueueSelector`.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-71_ultra-action-button.md` §4.2 (what exists — the widget intent contract), §4.3 (the reuse symmetry — factor the decision tree into one place), §5.2 (the intent core), §5.5 (concurrency — all `@MainActor`), §10 (shared decision helper tests).
- **Files involved:**
  - `Shared/Intents/` — the shared decision helper, co-located with `LogNextDoseIntent` so the safety decision is in one module.
  - `Shared/Intents/LogNextDoseIntent.swift` — refactor `perform()` to delegate to the shared helper (identical behavior).
  - `Shared/Queue/PendingQueueSelector.swift` — `pendingDoses(at:in:)` returns the ordered pending set; element 0 is "the next pill." `PendingDose` carries `medicationID`, `scheduledFor`, `quantity`.
  - `Shared/Logging/DoseEventWriter.swift` — `writeDoseEvent(for:scheduledFor:quantity:status:loggedOn:at:in:)`, the sole `@MainActor` dose-write path; builds the denormalized `ingredientAmounts` snapshot at log time.
  - `Shared/Models/Medication.swift` — `isHighRisk` (computed: true if any component's ingredient is high-risk) — the branch condition.
  - `Shared/Sync/DoseEventBatchTransfer.swift` — `transfer(_:)` queues the event to the iPhone; non-fatal on failure (mirror `TapThroughQueueView.log`).
- **Prior decisions (locked):**
  - **One safety decision, two entry points.** The widget and the Action Button are two entry points to the *same* decision tree; it must live in one helper so they can never drift on the high-risk rule.
  - The decision tree is exactly: `next pending dose? → none: caught-up feedback · high-risk: open app to press-and-hold confirm (NEVER auto-log) · not high-risk: DoseEventWriter.write(.taken) + transfer + reloadAllTimelines + haptic`.
  - The non-high-risk branch is **byte-for-byte the widget's branch** (same writer call with `loggedOn: .watch`, same transfer, same `reloadAllTimelines`).
  - The high-risk branch **never** calls the writer — it returns a route/outcome the caller acts on (open + present confirm). One-tap log on high-risk is **forbidden** (EPIC 04/08, CLAUDE.md; lithium double-dose risk).
  - The whole path is `@MainActor` (`DoseEventWriter`, `PendingQueueSelector`, `ModelContext` are main-actor bound). No new actors. No `@unchecked Sendable`.
  - Transfer failure is **non-fatal** and **logged via `os.Logger`** — never a bare swallowing `try?`. The watch store is authoritative.

## Output Format

A single PR containing:

- [ ] A shared `@MainActor` decision helper (e.g. `LogNextPendingDose.resolve(now:in:)` returning an outcome enum like `.caughtUp` / `.routeHighRiskConfirm(PendingDose)` / `.logged(DoseEvent)`), computing the next pending dose, resolving the `Medication`, branching on `isHighRisk`, and performing the write (+ transfer + `reloadAllTimelines`) only on the non-high-risk branch.
- [ ] `LogNextDoseIntent.perform()` refactored to call the helper and map its outcome to the intent result — behavior unchanged.
- [ ] Transfer wrapped to log-and-continue on failure via `os.Logger` (no silent `try?`).
- [ ] Tests (in-memory `ModelContext`):
  - non-high-risk next dose → a `.taken` `DoseEvent` written with `loggedOn == .watch` and the correct `ingredientAmounts` snapshot; `reloadAllTimelines` fires;
  - high-risk next dose → **no** `DoseEvent` written; outcome is the route-to-confirm case carrying that dose (the load-bearing safety test);
  - no pending dose → no write, no route, caught-up outcome.

## Examples

```
next pending dose?
 ├─ none            → no-op + "all caught up" feedback
 ├─ high-risk       → open app to press-and-hold confirm screen (NEVER auto-log)
 └─ not high-risk   → DoseEventWriter.write(.taken) + transfer + reload timelines + haptic
```

```swift
// Shared/Intents/ — both the widget intent and the Action Button intent call this.
@MainActor
enum LogNextPendingDose {
    enum Outcome { case caughtUp; case routeHighRiskConfirm(PendingDose); case logged(DoseEvent) }
    static func resolve(now: Date, in context: ModelContext) throws -> Outcome { /* the one decision tree */ }
}
```

## Constraints

**Scope fence:** The shared decision helper + the widget-intent refactor to use it + its tests only. **No** new `AppIntent`, **no** `AppShortcutsProvider`, **no** Action Button binding (that is core child #02). **No** router or root-view presentation (#03). **No** haptics or Ultra availability handling (#03). Do not duplicate the high-risk gate — there must be exactly one copy after this PR.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run on the paired simulator. The Smart Stack widget's "log next dose" behaves exactly as before (now via the shared helper). No Action Button surface exists yet — that lands in the next children, which reuse this helper verbatim.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #71`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `tracer-skeleton`, `watch`
