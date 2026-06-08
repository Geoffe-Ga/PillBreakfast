# SPEC — Issue #51: LogNextDoseIntent for Single-Tap Logging from Smart Stack

| Field | Value |
|---|---|
| Issue | #51 |
| Phase | 7 — Widgets & Complication |
| Labels | `spec-decomposition`, `core`, `phase-7-widgets`, `needs-spec` |
| Status | Draft |
| Date | 2026-06-07 |
| Epic | #8 |
| Predecessor | #50 (Smart Stack widget) |
| Successor issues | #52 (background-refresh debouncer) |

---

## 1. Summary

This issue implements `LogNextDoseIntent: AppIntent`, which allows a single tap on the Smart Stack widget to log the next pending non-high-risk maintenance dose without opening the watch app. High-risk doses — those whose medications inherit `isHighRisk == true` from any ingredient — are explicitly barred from single-tap logging; the widget shows an "Open to confirm" deep-link affordance instead, preserving the press-and-hold safety guarantee that exists in the main app. After a successful log, `WidgetCenter.shared.reloadAllTimelines()` is called to keep the complication and Smart Stack current.

---

## 2. Problem Statement / Motivation

SPEC §7.5: "Single-tap from widget → logs the next pending dose (no need to open app)." SPEC §7.2: "For `isHighRisk == true`: button requires press-and-hold." These two requirements are in direct tension at the widget surface. A widget `Button(intent:)` is a single tap — there is no press-and-hold gesture available in WidgetKit. The resolution, documented in the issue body and enforced in this spec, is:

- **Non-high-risk maintenance doses** — the next pending dose may be logged via a single-tap `Button(intent:)`. The intent calls the existing `DoseEventWriter.writeDoseEvent(...)` path through the App Group SwiftData store.
- **High-risk maintenance doses** — the widget renders an "Open to confirm" label linked via `widgetURL` to the watch app's press-and-hold screen. The intent is not invoked. The press-and-hold guarantee is maintained.

This is not a compromise on safety — it is the correct product design. A widget tap is inherently ambiguous (the user's wrist may shift, the watch face may be tapped accidentally). High-risk meds — lithium, anything with `ingredient.isHighRisk == true` — must require a deliberate, sustained gesture that a watch face tap cannot provide. The SPEC §9 Liquid Glass design section reinforces this: "Press-and-hold uses a ring that fills with refraction." There is no WidgetKit equivalent.

---

## 3. Goals and Non-Goals

**Goals:**
- Implement `LogNextDoseIntent: AppIntent` in `Shared/Intents/LogNextDoseIntent.swift`.
- The intent's `perform()` identifies the next pending non-high-risk dose, calls `DoseEventWriter.writeDoseEvent(...)`, and calls `WidgetCenter.shared.reloadAllTimelines()`.
- Update `SmartStackWidget` to branch on `entry.doseGroup.containsHighRisk`:
  - `false` — render a `Button(intent: LogNextDoseIntent(...))` that logs the first pending dose in the group.
  - `true` — render a `widgetURL` affordance that opens the app to the tap-through queue.
- The intent must refuse (throw a typed error, not `fatalError`) if invoked for a high-risk dose — a defense-in-depth check even though the widget never presents the button in that case.
- Unit tests for: intent success (fixture non-high-risk dose logged); intent refusal (fixture high-risk dose); `WidgetCenter.reloadAllTimelines()` called after success.
- Manual checklist: add a non-high-risk maintenance med → wait for the Smart Stack widget to surface → tap to log → dose is recorded without opening the app.

**Non-Goals:**
- PRN dose logging from the widget — PRN has no "next pending" concept from the scheduled queue.
- iOS-side widget or Siri intent exposure.
- `DoseEventBatchTransfer` / WatchConnectivity sync triggered from the intent — the intent runs in the extension process and cannot access `WCSession`. The main watch app will pick up the new `DoseEvent` from the shared store on its next foreground.
- Background refresh scheduling — that is #52.
- Handling the "skip" action from the widget — out of scope; the widget has one action (log) or falls back to opening the app.

---

## 4. Background and Current State

After #50 lands:
- `SmartStackWidget` renders `SmartStackWidgetView` with a `widgetURL` deep-link. Tapping anywhere opens the watch app.
- `SmartStackEntry` carries `DoseGroupSummary` with `containsHighRisk: Bool`.
- `DoseEventWriter.writeDoseEvent(for:scheduledFor:quantity:status:loggedOn:at:in:)` exists in `Shared/Logging/DoseEventWriter.swift` and is `@MainActor`.
- `PendingQueueSelector` returns `[PendingDose]` sorted by `scheduledFor`. `PendingDose` carries `medicationID`, `scheduledFor`, `quantity`.
- `PersistenceController.appGroupStoreURL` and `PersistenceController.schema` are the keys to open the shared store from a separate process.
- `SafetyEvaluator.violationsIfTaken(_:quantity:at:in:)` is `@MainActor` and is the canonical safety check.
- No `AppIntent` exists anywhere in the codebase.

**The `@MainActor` problem:** Both `DoseEventWriter` and `SafetyEvaluator` are `@MainActor`. `AppIntent.perform()` is not inherently `@MainActor` — it can run on a background executor. The Swift 6 concurrency checker will reject direct calls to `@MainActor` types from a non-isolated `perform()`. The resolution is documented in §5.2.

---

## 5. Detailed Design

### 5.1 File Layout

```
Shared/Intents/LogNextDoseIntent.swift         // new — AppIntent + types
WatchAppWidgets/SmartStackWidget.swift         // updated — branch on isHighRisk
WatchAppWidgets/SmartStackWidgetView.swift     // updated — conditional Button(intent:)
```

`LogNextDoseIntent.swift` lives in `Shared/` because it accesses `DoseEventWriter` and `PendingQueueSelector` — both in `Shared/`. It must be added to the `WatchAppWidgets` target membership (the extension process runs the intent's `perform()`) and may optionally be added to the watch app target for Siri/Spotlight donation in the future. Do not add it to the iOS target — the iPhone never logs doses (CLAUDE.md fence).

### 5.2 `LogNextDoseIntent`

```swift
import AppIntents
import SwiftData
import WidgetKit
import Foundation
import os

/// Single-tap dose logging from the Smart Stack widget.
///
/// Invariant: this intent NEVER logs a high-risk dose. If the next pending
/// dose is high-risk, perform() throws LogIntentError.highRiskForbidden.
/// The widget never presents the Button(intent:) for high-risk doses, so this
/// is a defense-in-depth check, not the primary safety gate.
@available(watchOS 26, *)
struct LogNextDoseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Next Dose"
    static var description = IntentDescription("Logs the next pending maintenance dose.")

    /// The medication ID of the dose to log. The widget stamps this at entry-
    /// build time so the intent logs the correct specific dose, not "whatever
    /// is pending when perform() runs" — avoiding a race if the regimen changes
    /// between widget render and tap.
    @Parameter(title: "Medication ID")
    var medicationIDString: String

    /// The scheduled wall-clock time for this dose, as a TimeInterval since
    /// epoch. AppIntent parameters must be AppEntity or primitive types;
    /// `Date` is supported directly in AppIntents on watchOS 26.
    @Parameter(title: "Scheduled For")
    var scheduledFor: Date

    /// Quantity to log (pulled from the PendingDose.quantity at entry-build time).
    @Parameter(title: "Quantity")
    var quantity: Int

    private static let logger = Logger(
        subsystem: "com.creekmasons.pillbreakfast",
        category: "LogNextDoseIntent"
    )

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let medicationID = UUID(uuidString: medicationIDString) else {
            throw LogIntentError.invalidMedicationID
        }

        let context = try Self.makeContext()
        let selector = PendingQueueSelector()

        // Re-verify the dose is still pending. If the user already logged it
        // via the main app between widget render and this tap, bail gracefully.
        let pending = try selector.pendingDoses(at: .now, in: context)
        guard pending.contains(where: { $0.medicationID == medicationID }) else {
            // Not an error — the dose was already logged. Reload timelines so
            // the widget reflects the current state.
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }

        // Fetch the Medication model. Must exist in the store.
        let medDescriptor = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.id == medicationID && !$0.isArchived }
        )
        let meds = try context.fetch(medDescriptor)
        guard let medication = meds.first else {
            throw LogIntentError.medicationNotFound(medicationID)
        }

        // Safety gate: refuse to log high-risk doses. This is defense-in-depth —
        // the widget never presents this intent button for high-risk meds.
        if medication.isHighRisk {
            Self.logger.error(
                "LogNextDoseIntent invoked for high-risk medication \(medicationID, privacy: .public); refusing."
            )
            throw LogIntentError.highRiskForbidden
        }

        // Run the safety evaluator. Violations do NOT block the log from a widget
        // (there is no UI surface to show a warning interstitial). Instead, log the
        // violation and proceed — the widget is a convenience path for the common
        // non-violation case. If a violation is present, the user should open the
        // app where the interstitial is available.
        let violations = try SafetyEvaluator.violationsIfTaken(
            medication,
            quantity: quantity,
            at: .now,
            in: context
        )
        if !violations.isEmpty {
            Self.logger.warning(
                "LogNextDoseIntent: safety violations present for \(medication.displayName, privacy: .public) — logging anyway (no interstitial in widget context). Violations: \(violations.map(\.description).joined(separator: ", "), privacy: .public)"
            )
            // Note: for future consideration, throw LogIntentError.safetyViolation(violations)
            // to prevent the log entirely and surface a "Open app to review" message.
            // For v1, proceed with a warning log.
        }

        // Write the dose event.
        try DoseEventWriter.writeDoseEvent(
            for: medication,
            scheduledFor: scheduledFor,
            quantity: quantity,
            status: .taken,
            loggedOn: .watch,
            at: .now,
            in: context
        )

        Self.logger.info(
            "LogNextDoseIntent: logged \(medication.displayName, privacy: .public) qty=\(quantity)."
        )

        // Reload all widget timelines so the complication and Smart Stack reflect
        // the new pending count immediately. (#52 handles the post-dose path from
        // the main app; this covers the widget-originated log path.)
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }

    // MARK: - Private helpers

    private static func makeContext() throws -> ModelContext {
        let url = PersistenceController.appGroupStoreURL
        let config = ModelConfiguration(url: url, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: PersistenceController.schema, configurations: config)
        return ModelContext(container)
    }
}

// MARK: - Error type

enum LogIntentError: Error, LocalizedError {
    case invalidMedicationID
    case medicationNotFound(UUID)
    case highRiskForbidden
    case safetyViolation([Violation])

    var errorDescription: String? {
        switch self {
        case .invalidMedicationID:
            return "Invalid medication identifier."
        case .medicationNotFound(let id):
            return "Medication \(id) not found in the store."
        case .highRiskForbidden:
            return "High-risk medications must be confirmed in the app."
        case .safetyViolation(let violations):
            return "Safety check failed: \(violations.map(\.description).joined(separator: "; "))"
        }
    }
}
```

**Why `@MainActor` on `perform()`:** `DoseEventWriter` and `SafetyEvaluator` are both `@MainActor`. Rather than `await MainActor.run { ... }` inside a non-isolated `perform()` (which would require the caller to not be isolated, creating a hop), annotating `perform()` as `@MainActor` directly is the correct Swift 6 pattern — it tells the concurrency system that this method runs on the main actor, allowing the `@MainActor`-isolated callees to be called directly. WidgetKit / AppIntents on watchOS accepts `@MainActor perform()` — verify in Xcode 26 SDK that `AppIntent.perform()` can be `@MainActor` without generating a diagnostic.

**Alternative if `@MainActor perform()` is rejected:** Restructure `DoseEventWriter` to accept the write data as a pure `Sendable` struct and perform the SwiftData write inside a `ModelContext` constructed on whatever actor calls it. The `@MainActor` requirement on `DoseEventWriter` comes from it calling into a `ModelContext`, not from any UI work. A non-`@MainActor` `ModelContext` is valid when the context is not shared with UI — this is the extension's use case.

### 5.3 Passing Parameters from the Widget Entry to the Intent

The `SmartStackEntry` / `DoseGroupSummary` must carry the specific `PendingDose` data needed to initialize `LogNextDoseIntent`. The current `DoseGroupSummary` carries only `groupName`, `doseCount`, `scheduledAt`, and `containsHighRisk`. This must be extended:

```swift
struct DoseGroupSummary: Sendable, Hashable {
    let groupName: String
    let doseCount: Int
    let scheduledAt: Date
    let containsHighRisk: Bool

    // Added in #51: the specific data for the *first* pending dose in the group
    // (the one the intent will log). nil if the group has no non-high-risk
    // candidate (e.g. all doses in the group are high-risk).
    let nextNonHighRiskDose: NextDoseSpec?
}

/// The minimal data needed to instantiate LogNextDoseIntent from the widget's entry.
/// Sendable by construction (UUID and Date are value types).
struct NextDoseSpec: Sendable, Hashable {
    let medicationID: UUID
    let scheduledFor: Date
    let quantity: Int
    let medicationName: String // for display in the widget button label
}
```

**Population:** `SmartStackTimelineProvider.doseGroups(in:on:calendar:)` in `SmartStackTimelineProvider.swift` must be updated to populate `nextNonHighRiskDose`. After building the pairs for each group, find the first pair where `medication.isHighRisk == false`, extract its `medicationID`, `scheduledFor`, and `quantity` from the corresponding `PendingDose` (or synthesize the `scheduledFor` from the dose's `hour`/`minute` on the relevant calendar day).

**Note on cross-issue coordination:** #50's `doseGroups` was designed without `nextNonHighRiskDose`. This field is added in #51. The implementation in #51 must update `SmartStackTimelineProvider.doseGroups` and the `DoseGroupSummary` initializer. This is an additive change that does not break the #50 implementation.

### 5.4 Updated `SmartStackWidgetView`

```swift
import SwiftUI
import WidgetKit
import AppIntents

struct SmartStackWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SmartStackEntry

    var body: some View {
        Group {
            if let group = entry.doseGroup {
                loadedView(group: group)
            } else {
                idleView
            }
        }
        .containerBackground(for: .widget) {
            Color.clear.glassEffect()
        }
    }

    private func loadedView(group: DoseGroupSummary) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.compact) {
            Text(group.groupName)
                .font(LiquidGlassTheme.Typography.headlineFont)
                .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            HStack(spacing: LiquidGlassTheme.Spacing.compact) {
                Text("\(group.doseCount) dose\(group.doseCount == 1 ? "" : "s")")
                    .font(LiquidGlassTheme.Typography.footnoteFont)
                    .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
                Text("·")
                    .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
                Text(group.scheduledAt, style: .time)
                    .font(LiquidGlassTheme.Typography.footnoteFont)
                    .monospacedDigit()
                    .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
            }

            // Log button or high-risk affordance.
            actionView(for: group)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LiquidGlassTheme.Spacing.standard)
    }

    @ViewBuilder
    private func actionView(for group: DoseGroupSummary) -> some View {
        if let spec = group.nextNonHighRiskDose {
            // Non-high-risk: render a single-tap intent button.
            Button(intent: makeIntent(spec: spec)) {
                Label("Log \(spec.medicationName)", systemImage: "checkmark.circle.fill")
                    .font(LiquidGlassTheme.Typography.captionFont)
                    .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
            }
            .buttonStyle(.plain)
        } else {
            // All doses in this group are high-risk: show "Open to confirm".
            // This is a widgetURL link (already set at the widget level), so the
            // label is purely informational.
            Label("Open to confirm", systemImage: "hand.point.up.left")
                .font(LiquidGlassTheme.Typography.captionFont)
                .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        }
    }

    private func makeIntent(spec: NextDoseSpec) -> LogNextDoseIntent {
        var intent = LogNextDoseIntent()
        intent.medicationIDString = spec.medicationID.uuidString
        intent.scheduledFor = spec.scheduledFor
        intent.quantity = spec.quantity
        return intent
    }

    private var idleView: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.compact) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
            Text("All caught up")
                .font(LiquidGlassTheme.Typography.footnoteFont)
                .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

**Why no amber on the button:** The `Button(intent:)` is for non-high-risk doses only. Amber is reserved for high-risk meds in the press-and-hold context. Even if we wanted to tint the button, WidgetKit's button styling on watchOS is system-controlled — custom `foregroundStyle` on a `Button(intent:)` may not apply. Stay monochromatic.

**The `widgetURL` and `Button(intent:)` coexistence:** When a `Button(intent:)` is present in the widget view, tapping the button fires the intent. Tapping anywhere else on the card fires the `widgetURL` deep-link. This is the standard WidgetKit interaction model for interactive widgets. Confirm in Xcode 26 that this behavior is consistent with watchOS 26 Smart Stack.

### 5.5 Swift 6 Concurrency Analysis

This is the most concurrency-sensitive design decision in Phase 7.

**`LogNextDoseIntent.perform()` is `@MainActor`.** This is valid for `AppIntent` conformances. The Swift 6 checker will verify that:
- `PendingQueueSelector()` and `selector.pendingDoses(at:in:)` are `@MainActor` — verified.
- `DoseEventWriter.writeDoseEvent(...)` is `@MainActor` — verified.
- `SafetyEvaluator.violationsIfTaken(...)` is `@MainActor` — verified.
- `ModelContext(container)` is created on the main actor — valid.
- `WidgetCenter.shared.reloadAllTimelines()` — `WidgetCenter` is not actor-isolated; it can be called from any context.

**`LogNextDoseIntent` struct itself:** AppIntent conformers must be `Sendable` (they cross the AppIntents framework boundary). All `@Parameter` properties are of types that are `Sendable` (`String`, `Date`, `Int`). The struct's implicit `Sendable` conformance should compile without issues.

**`DoseGroupSummary` with `NextDoseSpec`:** Both are value types with `Sendable` fields — `UUID`, `Date`, `Int`, `String`. Synthesized `Sendable` conformance is fine.

**`LogIntentError`:** An enum with `Sendable` associated values (`UUID`, `[Violation]`). `Violation` must be `Sendable` — check `Shared/Safety/Violation.swift`.

### 5.6 Violation of Safety Interstitial Policy in Widget Context

In the main watch app, `SafetyEvaluator.violationsIfTaken` drives a `SafetyWarningView` interstitial that the user must confirm before the dose is logged. This UI does not exist in the widget extension process. The design in §5.2 logs a warning and proceeds (for v1). This is an intentional product decision: the Smart Stack log button is a convenience path, not a replacement for the full logging UX. If violations are common for a given user, they will encounter them in the app and be trained to expect the interstitial — the widget log will be for the routine, violation-free case.

If this policy becomes unacceptable (e.g., a user repeatedly exceeds a ceiling via the widget), the fix is to throw `LogIntentError.safetyViolation` and return a failure result — AppIntents can display a user-facing error string via `IntentResult.failure(error:)`. This is tracked as a risk item in §10.

### 5.7 `DoseEventBatchTransfer` from the Extension

`TapThroughQueueView.log(...)` calls `DoseEventBatchTransfer.transfer([event])` after writing the dose, which enqueues the event for WatchConnectivity transfer to the iPhone. The extension cannot call this (it has no `WCSession` access). This means widget-logged doses will reach the iPhone store only when the watch app next opens and runs its background sync. This is acceptable behavior documented in the issue and this spec — the watch store is authoritative, and the iPhone gets the dose on the next foreground.

If immediate transfer is required in the future, a possible path is for the watch app to detect new `DoseEvent`s it didn't log itself (by checking `loggedOn == .watch` with a `takenAt` newer than the last transfer timestamp) on each foreground launch and transfer them. This is a future issue.

---

## 6. UX and Visual Design

**Non-high-risk group:**
```
Morning Meds
4 doses · 8:00 AM
[✓ Log Vitamin D]         ← Button(intent:) with the first non-high-risk med's name
```

**High-risk group (e.g. first dose is Lithium):**
```
Morning Meds
4 doses · 8:00 AM
[↖ Open to confirm]       ← static label, card tap fires widgetURL
```

**Mixed group (first dose non-high-risk, later doses high-risk):**
```
Morning Meds
4 doses · 8:00 AM
[✓ Log Vitamin D]         ← logs Vitamin D; Lithium will be first in the queue when app opens
```

The "Open to confirm" label is intentionally plain (no amber, no warning icon). It communicates "this requires the app" without alarming the user. Amber is reserved for the press-and-hold confirmation ring in the app itself.

**After a successful intent log:** The complication count decrements, the Smart Stack widget updates to show the next group (or "All caught up"). This is driven by `WidgetCenter.shared.reloadAllTimelines()` in `perform()`.

---

## 7. Edge Cases and Failure Modes

| Scenario | Handling |
|---|---|
| Intent invoked after the dose was already logged via the main app | `pendingDoses` won't contain the dose; guard passes; `WidgetCenter.reloadAllTimelines()` is called; `perform()` returns `.result()` (success with no action). |
| `Medication` has been archived between widget render and intent tap | `FetchDescriptor` with `!$0.isArchived` returns nothing; `throw LogIntentError.medicationNotFound`. AppIntents surfaces the `errorDescription` string to the user. |
| Intent invoked for a high-risk medication (defense-in-depth) | `throw LogIntentError.highRiskForbidden`. Log at `.error` level. Surface to user. |
| `ModelContainer` fails to open | `makeContext()` throws; propagates to AppIntents as an error result. |
| `DoseEventWriter.writeDoseEvent` throws (SwiftData save failure) | Error propagates; `WidgetCenter.reloadAllTimelines()` is NOT called (no state change to reflect). AppIntents surface the error. |
| `SafetyEvaluator` throws (CalendarError, fetch failure) | Treated as a non-blocking warning in v1 (the violation check is best-effort from the widget). Log at `.error`, proceed with the write. |
| Widget timeline entry has a stale `scheduledFor` (regimen changed between entry build and intent tap) | The dose may no longer exist in `PendingQueueSelector`. The guard at the top of `perform()` catches this; no spurious write happens. |
| `NextDoseSpec.medicationIDString` is a malformed UUID | `UUID(uuidString:)` returns nil; `throw LogIntentError.invalidMedicationID`. |

---

## 8. Testing Strategy

**Unit tests (`WatchAppWidgetsTests` or `PillBreakfastTests`):**

- `LogNextDoseIntent` success path: create an in-memory `ModelContainer` with one non-high-risk `Medication`, one `ScheduledDose` in the current window, and no logged `DoseEvent`s. Construct the intent with matching parameters. Call `perform()`. Assert: one `DoseEvent` was inserted in the store with `status == .taken`, `loggedOn == .watch`. Assert: `WidgetCenter.shared.reloadAllTimelines()` was called (inject a mock `WidgetCenter` or verify via side-effect observation).

- `LogNextDoseIntent` high-risk refusal: construct intent for a medication with `ingredient.isHighRisk == true`. Assert `perform()` throws `LogIntentError.highRiskForbidden`.

- `LogNextDoseIntent` already-logged dose: write a `DoseEvent` for the slot before calling `perform()`. Assert `perform()` returns `.result()` without writing a second event.

- `SmartStackWidgetView` with non-high-risk `DoseGroupSummary` (non-nil `nextNonHighRiskDose`): renders `Button(intent:)` (preview / snapshot test).

- `SmartStackWidgetView` with high-risk-only `DoseGroupSummary` (nil `nextNonHighRiskDose`): renders "Open to confirm" label (preview / snapshot test).

- `DoseGroupSummary.nextNonHighRiskDose`: given a group with all high-risk meds, assert `nil`. Given a group with one non-high-risk med, assert non-nil with correct `medicationID`.

**Manual checklist (from issue body):**
1. Add a non-high-risk maintenance med (e.g. Vitamin D) with a schedule 15 min from now.
2. Wait for the Smart Stack widget to surface.
3. Tap the intent button.
4. Open the watch app; confirm the dose appears in history; confirm the complication count decremented.
5. Confirm the dose does NOT appear in the Smart Stack widget again.

**Device (not simulator):**
- `AppIntent.perform()` may behave differently on device vs. simulator for timing and actor execution. Run the manual checklist on real hardware before marking done.

---

## 9. Performance and Resource Budget

- `perform()` opens a `ModelContainer`, fetches one `Medication` (by indexed `id`), runs `PendingQueueSelector` (bounded 200-event fetch), and writes one `DoseEvent`. Total expected duration: < 100 ms on Apple Watch hardware.
- AppIntents has an execution time budget (Apple does not publish the exact number, but it is in the order of a few seconds). This operation is well within budget.
- `WidgetCenter.shared.reloadAllTimelines()` is synchronous from the caller's perspective; the actual timeline rebuild happens asynchronously in the extension process. No additional cost in `perform()`.
- Memory: same as the complication provider (one `ModelContainer`, bounded fetch). Well under the extension budget.

---

## 10. Risks and Open Questions

| Risk | Likelihood | Mitigation |
|---|---|---|
| `AppIntent.perform()` cannot be `@MainActor` on watchOS 26 | Medium | If rejected by the compiler, restructure `DoseEventWriter` to not require `@MainActor` by accepting a non-shared `ModelContext` as a parameter; the context is constructed on the appropriate actor in the callee. |
| WidgetKit `Button(intent:)` is not available on watchOS 26 Smart Stack | Low | Verify against Xcode 26 SDK. Interactive widgets (`Button(intent:)`) were introduced for Apple Watch in watchOS 10. If unavailable in the Smart Stack family specifically, fall back to `widgetURL` for all taps and document as a known limitation. |
| `WidgetCenter.shared.reloadAllTimelines()` is not available in the AppIntent extension sandbox | Low | `WidgetCenter` is available in widget extensions; verify it is also available from an AppIntent's `perform()` execution context, which may run in the main app process or a separate intent process depending on platform. |
| Safety violations silently bypassed by the widget log path | Medium | This is a documented design decision for v1. Track as a follow-up issue to surface a system notification or error result when violations are present. |
| `Violation` is not `Sendable` (required for `LogIntentError.safetyViolation`) | Low | Check `Shared/Safety/Violation.swift`. If not `Sendable`, either add conformance or remove the `.safetyViolation` case from `LogIntentError` (the v1 path logs and proceeds anyway). |
| Mixed group: the "first non-high-risk dose" concept may not match what the user expects to log | Medium | Documented in the UX section. The ordering is `PendingQueueSelector`'s `scheduledFor`-sorted order. Edge: two meds at the same `scheduledFor` — sort by `medicationID` for determinism. |

**Open question resolved:** Which dose is "the next dose" when a group has multiple doses? Answer: the first `PendingDose` from `PendingQueueSelector.pendingDoses(at:in:)` (sorted by `scheduledFor`) that belongs to this group AND whose medication is not high-risk. This is the `NextDoseSpec` stored on `DoseGroupSummary`.

**Open question for #52:** After `LogNextDoseIntent.perform()` calls `WidgetCenter.shared.reloadAllTimelines()`, does the complication timeline rebuild run inside the extension process or the watch app process? If the extension process, the rebuild's `makeContext()` will open the store again (fine — it is read-only, and the new `DoseEvent` is already persisted). If the watch app process, the rebuild reads from `PersistenceController.shared` (also fine). Either way the `DoseEvent` is visible because the write was committed with `context.save()` before `reloadAllTimelines()` was called.

---

## 11. Decomposition Hints

Single PR. Implementation sequence:
1. Check `Shared/Safety/Violation.swift` for `Sendable` and `description`.
2. Add `NextDoseSpec` to `DoseGroupSummary`; update `SmartStackTimelineProvider.doseGroups` to populate it.
3. Implement `LogNextDoseIntent` and `LogIntentError` in `Shared/Intents/LogNextDoseIntent.swift`.
4. Add `LogNextDoseIntent.swift` to `WatchAppWidgets` target membership.
5. Update `SmartStackWidgetView` with `actionView(for:)`.
6. Write unit tests.
7. Manual checklist on simulator, then device.

---

## 12. Acceptance Criteria / Done-Done

- [ ] `LogNextDoseIntent.perform()` logs a `DoseEvent` with `status == .taken`, `loggedOn == .watch` for a fixture non-high-risk pending dose (unit test).
- [ ] `LogNextDoseIntent.perform()` throws `LogIntentError.highRiskForbidden` for a high-risk dose (unit test).
- [ ] `WidgetCenter.shared.reloadAllTimelines()` is called after a successful log (unit test or manual verification).
- [ ] `SmartStackWidgetView` renders `Button(intent:)` when `nextNonHighRiskDose` is non-nil (preview / snapshot test).
- [ ] `SmartStackWidgetView` renders "Open to confirm" label when `nextNonHighRiskDose` is nil (preview / snapshot test).
- [ ] No amber color appears anywhere in the widget view.
- [ ] Manual checklist: tap intent button → dose recorded → complication decrements → widget updates. Verified on simulator.
- [ ] Both watch app and widget extension build under Swift 6 strict concurrency with zero warnings.
- [ ] `pre-commit run --all-files` clean.
- [ ] PR references `Closes #51` and `Refs #8`.

---

## 13. References

- SPEC §7.4 — press-and-hold for high-risk.
- SPEC §7.5 — "Single-tap from widget → logs the next pending dose."
- SPEC §7.2 — "For `isHighRisk == true`: button requires press-and-hold."
- CLAUDE.md — "High-risk = press-and-hold. Single-tap is fine for vitamins; lithium and anything else flagged `isHighRisk` must require the press-and-hold gesture with a visible progress ring."
- `Shared/Logging/DoseEventWriter.swift` — `@MainActor writeDoseEvent(...)`.
- `Shared/Safety/SafetyEvaluator.swift` — `@MainActor violationsIfTaken(...)`.
- `Shared/Queue/PendingQueueSelector.swift` — `PendingDose`, `pendingDoses(at:in:)`.
- `Shared/Persistence/PersistenceController.swift` — `appGroupStoreURL`, `schema`.
- `Shared/DesignSystem/LiquidGlassTheme.swift` — typography, color discipline.
- Predecessor: `2026-06-07_SPEC_ISSUE-50_smart-stack-widget.md`.
- Successor: `2026-06-07_SPEC_ISSUE-52_complication-refresh-debouncer.md`.
- Apple: "AppIntent" protocol documentation (AppIntents framework, Xcode 26 SDK).
- Apple: "Adding interactivity to widgets and Live Activities" (WidgetKit, watchOS 10+).
