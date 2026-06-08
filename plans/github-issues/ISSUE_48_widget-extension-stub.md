## Role

You are a senior watchOS engineer adding the foundational watchOS widget-extension target to PillBreakfast: a new `WatchAppWidgets` extension, registered with the App Group, shipping one stub `.accessoryCircular` complication that renders `"--"`. This is the tracer skeleton for Phase 7 — prove the target compiles, is reachable from the watch face, and that the App Group entitlement flows through, before any data wiring.

## Goal

Create the `WatchAppWidgets` watchOS widget-extension target in `PillBreakfast.xcodeproj`, add the `group.com.creekmasons.pillbreakfast` App Group entitlement, implement the `@main WidgetBundle` entry point plus a single `.accessoryCircular` complication backed by a stub `TimelineProvider` that returns one entry (`pendingCount: nil`, display `"--"`). The complication must be addable to a watch face in the simulator and render `"--"` centred. No SwiftData reads, no extra families, no AppIntent.

## Context

- **Parent epic:** #48 (this issue is the atomic skeleton — no further decomposition per the spec's §11).
- **Predecessors:** none — Phase 7 is greenfield (a search across all 166 Swift files confirms zero references to `WidgetKit`, `WidgetBundle`, `TimelineProvider`, `WidgetConfiguration`, `AppIntent`, `WidgetCenter`).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-48_widget-extension-stub.md` §5 (detailed design), §5.2 (file layout), §5.4 (entitlement), §12 (acceptance). SPEC §7.4 (complication requirement), SPEC §10 Phase 7 gate.
- **Files involved:**
  - `WatchAppWidgets/WatchAppWidgetsBundle.swift` (new) — `@main WidgetBundle`.
  - `WatchAppWidgets/PendingDoseComplication.swift` (new) — `Widget` + circular stub view.
  - `WatchAppWidgets/PendingDoseTimelineProvider.swift` (new) — stub `TimelineProvider` + `PendingDoseEntry`.
  - `WatchAppWidgets/WatchAppWidgets.entitlements` (new) — App Group entitlement.
  - `PillBreakfast.xcodeproj` — new target, bundle ID `com.creekmasons.pillbreakfast.watchkitapp.widgets`, watchOS 26 deployment.
- **Prior decisions (locked):**
  - The extension is a **separate process** — it must NOT share `PersistenceController.shared`; in #49 it opens its own `ModelContainer` against `PersistenceController.appGroupStoreURL` with `PersistenceController.schema`.
  - The App Group entitlement is added **now**, before any store read, so re-signing between #48 and #49 never breaks an install.
  - `PendingDoseEntry` is a `Sendable` value type (`Date` + `Int?`), never an `@Observable` class — widget extensions use `TimelineEntry` value types.
  - No `WCSession`, no networking, no HealthKit inside the extension — ever.
  - Complications use `StaticConfiguration` (not `AppIntentConfiguration`; that arrives in #51 for the interactive widget).

## Output Format

A single PR containing:

- [ ] New `WatchAppWidgets` widget-extension target in `PillBreakfast.xcodeproj` (watchOS 26 deployment, bundle ID `com.creekmasons.pillbreakfast.watchkitapp.widgets`, parent = the watch app).
- [ ] `WatchAppWidgets.entitlements` containing `com.apple.security.application-groups` → `group.com.creekmasons.pillbreakfast`.
- [ ] `WatchAppWidgetsBundle.swift` — `@main WidgetBundle` whose body is `PendingDoseComplication()`.
- [ ] `PendingDoseEntry: TimelineEntry, Sendable` with `let date: Date` and `let pendingCount: Int?`.
- [ ] `PendingDoseTimelineProvider: TimelineProvider` whose `placeholder`/`getSnapshot`/`getTimeline` all return `pendingCount: nil`; `getTimeline` uses a ~15-minute `.after(...)` reload policy.
- [ ] `PendingDoseComplication: Widget` registering only `.accessoryCircular`, rendering `"--"` centred in `AccessoryWidgetBackground()`, with `widgetURL(URL(string: "pillbreakfast://tap-through"))` set (the watch app's `onOpenURL` handler is wired in #49).
- [ ] Tests (new `WatchAppWidgetsTests` target): `getTimeline` returns one entry with `pendingCount == nil` and an `.after(...)` policy ~15 min in the future (5-second tolerance).
- [ ] PR description documents the App Group provisioning step done in the developer portal for the new bundle ID.

## Examples

```swift
@main
struct WatchAppWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PendingDoseComplication()
        // SmartStackWidget() — added in #50
    }
}

struct PendingDoseEntry: TimelineEntry, Sendable {
    let date: Date
    /// Nil in the stub phase; #49 populates this from PendingQueueSelector.
    let pendingCount: Int?
}
```

## Constraints

**Scope fence:** Target + entitlement + stub circular complication only. **No** SwiftData reads (that is #49). **No** corner/inline families (#49). **No** Smart Stack widget (#50). **No** AppIntent (#51). **No** background refresh (#52). **No** iOS-side widget. Delete any unused boilerplate Xcode's template generates.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** After this PR the watch app still builds and runs on the paired simulator, and the new extension builds alongside it. The "Pending Doses" complication appears in the watch-face complication picker on the Apple Watch Series 11 (46mm) simulator and renders `"--"` in the circular slot; tapping it opens the watch app without crashing.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #48` and `Refs #8`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-7-widgets`, `watch`
