## Role

You are a senior watchOS engineer implementing `LogNextDoseIntent` — the single-tap dose-logging AppIntent for the Smart Stack widget — plus the `NextDoseSpec` data it consumes. This is the safety-critical core of Phase 7: the intent must log only non-high-risk doses and refuse high-risk ones as defense-in-depth.

## Goal

Add `NextDoseSpec` and `DoseGroupSummary.nextNonHighRiskDose`, populate it in `SmartStackTimelineProvider.doseGroups`, and implement `LogNextDoseIntent: AppIntent` (`@MainActor perform()`) + `LogIntentError` in `Shared/Intents/LogNextDoseIntent.swift`. The intent re-verifies the dose is pending, refuses high-risk doses, runs `SafetyEvaluator` best-effort, writes via `DoseEventWriter`, and calls `WidgetCenter.shared.reloadAllTimelines()`.

## Context

- **Parent epic:** #51
- **Predecessor:** #50 (`SmartStackTimelineProvider.doseGroups` builds `DoseGroupSummary` with `containsHighRisk`; `SmartStackWidgetView` renders via `widgetURL` only).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-51_log-next-dose-intent.md` §5.1 (layout), §5.2 (intent + error), §5.3 (`NextDoseSpec` population), §5.5 (concurrency), §5.6 (safety policy in widget context), §7 (edge cases), §8 (unit tests).
- **Files involved:**
  - `Shared/Intents/LogNextDoseIntent.swift` (new) — `LogNextDoseIntent`, `LogIntentError`, `NextDoseSpec`, `makeContext()`.
  - `WatchAppWidgets/SmartStackTimelineProvider.swift` — add `nextNonHighRiskDose` to `DoseGroupSummary`; populate in `doseGroups`.
  - `PillBreakfast.xcodeproj` — add `Shared/Intents/LogNextDoseIntent.swift` to the `WatchAppWidgets` target (and optionally the watch app for future donation); **NOT** the iOS target.
- **Prior decisions (locked):**
  - **Never one-tap-log a high-risk med.** `perform()` throws `LogIntentError.highRiskForbidden` if `medication.isHighRisk`. This is defense-in-depth — the widget (child #02) never shows the button for high-risk groups.
  - The intent stamps the specific `medicationID` / `scheduledFor` / `quantity` at entry-build time (carried by `NextDoseSpec`) so it logs the intended dose, not "whatever is pending at tap time." It re-checks `PendingQueueSelector` and, if the dose was already logged, returns `.result()` after `reloadAllTimelines()` (not an error).
  - `nextNonHighRiskDose` = the first `scheduledFor`-sorted non-high-risk pending dose in the group; `nil` if every dose in the group is high-risk. Ties on `scheduledFor` break by `medicationID` for determinism.
  - `SafetyEvaluator.violationsIfTaken` runs but does NOT block (no interstitial surface in a widget); log a `.warning` and proceed for v1.
  - `perform()` is `@MainActor` (so the `@MainActor` `DoseEventWriter` / `SafetyEvaluator` / `PendingQueueSelector` callees are reachable). If the Xcode 26 SDK rejects `@MainActor perform()`, restructure `DoseEventWriter` to take a non-shared `ModelContext` — do NOT add `@unchecked Sendable` / `MainActor.assumeIsolated` hacks.
  - The extension cannot use `WCSession`; widget-logged doses reach the iPhone on the watch app's next foreground. `DoseEventWriter` write goes through `makeContext()` against the App Group store; no `PersistenceController.shared`.
  - Verify `Shared/Safety/Violation.swift` is `Sendable`; if not, conform it or drop `LogIntentError.safetyViolation` (v1 logs-and-proceeds regardless).

## Output Format

A single PR containing:

- [ ] `NextDoseSpec: Sendable, Hashable` (`medicationID`, `scheduledFor`, `quantity`, `medicationName`).
- [ ] `DoseGroupSummary.nextNonHighRiskDose: NextDoseSpec?`, populated in `doseGroups` (first non-high-risk pending dose, deterministic ordering; `nil` when all high-risk).
- [ ] `LogNextDoseIntent: AppIntent` with `@MainActor perform()`: invalid-UUID guard → still-pending re-check → archived/not-found guard → high-risk refusal → best-effort `SafetyEvaluator` warning → `DoseEventWriter.writeDoseEvent(... status: .taken, loggedOn: .watch ...)` → `WidgetCenter.shared.reloadAllTimelines()`.
- [ ] `LogIntentError: Error, LocalizedError` (`invalidMedicationID`, `medicationNotFound(UUID)`, `highRiskForbidden`, `safetyViolation([Violation])` if `Violation` is `Sendable`).
- [ ] `LogNextDoseIntent.swift` added to the `WatchAppWidgets` target only (not iOS).
- [ ] Tests: success path (one `DoseEvent` inserted, `reloadAllTimelines` invoked — via a seam); high-risk refusal throws `highRiskForbidden`; already-logged dose returns `.result()` with no second write; `nextNonHighRiskDose` is `nil` for an all-high-risk group and correct for a mixed group.

## Examples

```swift
struct NextDoseSpec: Sendable, Hashable {
    let medicationID: UUID
    let scheduledFor: Date
    let quantity: Int
    let medicationName: String
}
```

## Constraints

**Scope fence:** Intent + `NextDoseSpec` + `doseGroups` population only. **No** widget-view branching / `Button(intent:)` (that is the view child #02), **no** background refresh / app-side reload (#52). Do not weaken the high-risk gate. Do not add the intent to the iOS target.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The widget, complication, and watch app still build and run on the paired simulator. The intent is exercised by unit tests in this PR; the Smart Stack card still opens the app via `widgetURL` (the button arrives in child #02). A high-risk dose can never be logged through `perform()`.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #51`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `core`, `phase-7-widgets`, `watch`, `concurrency`
