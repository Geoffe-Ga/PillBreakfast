# SPEC — Issue #48: Watch Widget Extension Stub (Tracer Skeleton)

| Field | Value |
|---|---|
| Issue | #48 |
| Phase | 7 — Widgets & Complication |
| Labels | `spec-decomposition`, `tracer-skeleton`, `phase-7-widgets`, `needs-spec` |
| Status | Draft |
| Date | 2026-06-07 |
| Epic | #8 |
| Successor issues | #49 (three complication families), #50 (Smart Stack widget), #51 (LogNextDoseIntent), #52 (background-refresh debouncer) |

---

## 1. Summary

This issue adds a new watchOS widget extension target (`WatchAppWidgets`) to the Xcode project, registers it with the App Group so it can later read the shared SwiftData store, and ships one stub `.accessoryCircular` complication that renders the placeholder string `"--"`. The goal is skeleton-first: prove the target compiles, the extension is reachable from the watch face, and the App Group entitlement flows through correctly — before any real data wiring happens. Issues #49–#52 build on this skeleton.

---

## 2. Problem Statement / Motivation

The product thesis is "zero-ambiguity tap-through logging on the wrist." Every extra step between Geoff and knowing his pending dose count is friction that erodes the core promise. A watch face complication closes that gap to zero: a glance at the wrist, no app open required. Before any complication logic can be written (#49), the extension target must exist and be reachable — that is this issue's entire scope. Getting the plumbing right (App Group, entitlements, bundle identifier conventions, the `WidgetBundle` entry point) is the foundational work; doing it in isolation keeps the diff small and reviewable.

---

## 3. Goals and Non-Goals

**Goals:**
- Create a new `WatchAppWidgets` watchOS widget extension target in `PillBreakfast.xcodeproj`.
- Add the `com.apple.security.application-groups` entitlement (`group.com.creekmasons.pillbreakfast`) to the new target so it shares the same store as the watch app and iPhone app.
- Implement `WatchAppWidgetsBundle.swift` — the `@main WidgetBundle` entry point.
- Implement `PendingDoseComplication.swift` — a single `.accessoryCircular` complication.
- Implement `PendingDoseTimelineProvider.swift` — a stub `TimelineProvider` that returns one entry with the display value `"--"` and a far-future refresh date.
- The complication must be addable to a watch face in the simulator and render `"--"` centred.
- The target must build and pass `pre-commit run --all-files` clean.

**Non-Goals:**
- Reading any data from SwiftData — that is #49.
- Corner or inline families — that is #49.
- Smart Stack widget — that is #50.
- `AppIntent` / tap-to-log — that is #51.
- Background refresh — that is #52.
- Any iOS-side widget extension.

---

## 4. Background and Current State

**No widget extension exists today.** A search across all 166 Swift source files confirms zero references to `WidgetKit`, `WidgetBundle`, `TimelineProvider`, `WidgetConfiguration`, `AppIntent`, or `WidgetCenter`. Phase 7 is greenfield.

**What does exist and must be respected:**

- `Shared/Persistence/PersistenceController.swift` (`@MainActor public final class PersistenceController`) owns the shared SwiftData container. It is keyed on `PersistenceController.appGroupIdentifier = "group.com.creekmasons.pillbreakfast"` and the store URL is `<app-group-container>/PillBreakfast.store`. The widget extension will eventually open its own `ModelContainer` against the same URL and schema — not share the watch app's singleton, because the extension is a separate process.

- Both existing targets already carry the `group.com.creekmasons.pillbreakfast` App Group entitlement (confirmed in `PillBreakfast Watch App Watch App/PillBreakfast Watch App Watch App.entitlements` and `PillBreakfast/PillBreakfast.entitlements`). The new extension target needs the same entitlement added via Xcode's Signing & Capabilities editor.

- The schema set is defined in `PersistenceController.schema`: `[Ingredient, MedicationComponent, Medication, ScheduledDose, DoseEvent, SnoozeRecord, PillMeal]`. The extension must reference the same schema array to open the store correctly in #49; in this stub issue the schema is declared but no fetch is issued.

- SPEC §7.4 (lines 334–337): "Watch face complication (circular, corner, inline variants). Shows count of pending doses for current window (e.g. '2 pending') or '✓' when clear. Tap → opens app to tap-through queue."

- SPEC §10 Phase 7 gate: "Add complication to watch face. See pending count update in real time after a dose is logged." The gate is not satisfied by this issue alone; it requires #49 + #52 to complete.

---

## 5. Detailed Design

### 5.1 New Target

**Target name:** `WatchAppWidgets`
**Platform:** watchOS 26+
**Bundle ID:** `com.creekmasons.pillbreakfast.watchkitapp.widgets`
**Product type:** Widget Extension
**Parent app:** The watch app (`com.creekmasons.pillbreakfast.watchkitapp`)

Xcode will generate the extension with an `NSExtension` principal class. The standard Widget Extension template for watchOS sets `NSExtensionPrincipalClass` to `$(PRODUCT_MODULE_NAME).WatchAppWidgetsBundle` — confirm that the generated `Info.plist` entry matches.

The watch app's `Info.plist` or Xcode target settings must declare `NSWidgetWantsLocation` as `NO` (we need no location) and `WKWatchOnly` is already `YES` for the parent watch app. No special entitlements beyond the App Group are needed for the stub.

### 5.2 File Layout

```
WatchAppWidgets/
├── WatchAppWidgetsBundle.swift          // @main WidgetBundle
├── PendingDoseComplication.swift        // Widget + View (circular stub)
└── PendingDoseTimelineProvider.swift    // Stub TimelineProvider
```

No `Shared/` files are included in the extension's target membership at this stub stage. In #49, `Shared/` files (specifically the models and `PendingQueueSelector`) will be added to the extension's target membership list.

### 5.3 Swift Code Sketches

**`WatchAppWidgetsBundle.swift`:**

```swift
import WidgetKit
import SwiftUI

@main
struct WatchAppWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PendingDoseComplication()
        // SmartStackWidget() — added in #50
    }
}
```

**`PendingDoseTimelineProvider.swift`:**

```swift
import WidgetKit
import Foundation

struct PendingDoseEntry: TimelineEntry {
    let date: Date
    /// Nil in the stub phase; #49 populates this from PendingQueueSelector.
    let pendingCount: Int?
}

struct PendingDoseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PendingDoseEntry {
        PendingDoseEntry(date: .now, pendingCount: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PendingDoseEntry) -> Void) {
        completion(PendingDoseEntry(date: .now, pendingCount: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PendingDoseEntry>) -> Void) {
        // Stub: one entry, no real data, refresh in 15 minutes so the system
        // doesn't poll us aggressively during development.
        let entry = PendingDoseEntry(date: .now, pendingCount: nil)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}
```

**`PendingDoseComplication.swift`:**

```swift
import WidgetKit
import SwiftUI

struct PendingDoseComplication: Widget {
    static let kind = "com.creekmasons.pillbreakfast.complication.pendingdose"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: PendingDoseTimelineProvider()
        ) { entry in
            CircularComplicationView(entry: entry)
                .widgetURL(URL(string: "pillbreakfast://tap-through"))
        }
        .configurationDisplayName("Pending Doses")
        .description("Shows how many doses are due right now.")
        .supportedFamilies([.accessoryCircular])
        // contentMarginsDisabled() — evaluate in #49 once real layout lands;
        // omit in the stub to keep the diff minimal.
    }
}

struct CircularComplicationView: View {
    let entry: PendingDoseEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text("--")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.6)
                .foregroundStyle(.primary)
        }
    }
}
```

### 5.4 App Group Entitlement

The extension target requires a `.entitlements` file at `WatchAppWidgets/WatchAppWidgets.entitlements` containing:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.creekmasons.pillbreakfast</string>
    </array>
</dict>
</plist>
```

This entitlement is required now — even though the stub does not read the store — because adding it later without re-signing would break any user who installs between #48 and #49.

### 5.5 Deep-Link URL Scheme

The `widgetURL(URL(string: "pillbreakfast://tap-through"))` call is set in the stub, even before the watch app handles it, so the link is in place for #49 to validate end-to-end. The watch app's `onOpenURL` handler is wired in #49; for now the tap simply opens the watch app to whatever root it lands on.

### 5.6 Swift 6 Concurrency Considerations

- `PendingDoseEntry` must be `Sendable` (it crosses the WidgetKit/extension process boundary as data, and WidgetKit internally moves entries across actor contexts). Both fields (`Date`, `Int?`) are value types, so the conformance is synthesized for free.
- `PendingDoseTimelineProvider` runs on the extension's main thread; no custom isolation annotation is required. In #49 when the provider issues a SwiftData fetch, the context must be accessed from `@MainActor` — the implementation will use `Task { @MainActor in ... }` inside `getTimeline`.
- The `WidgetBundle` entry point uses `@main`, which must not conflict with the watch app's `@main`. The extension is a separate process with its own entry point, so there is no conflict — but Xcode's build system requires that the two targets' `@main` types live in separate module scopes, which is already the case because they are separate targets with separate module names.

### 5.7 Memory and Execution Budget

watchOS widget extensions are subject to the tightest resource constraints on the platform:

- **Memory:** Apple does not publish a hard limit, but widget extensions on watchOS are expected to stay well under 30 MB. The stub allocates essentially nothing. In #49, the extension will open a read-only `ModelContainer` — the lightweight schema initialization is the primary cost; avoid eager prefetching of the full medication graph.
- **CPU time:** `getTimeline` is expected to complete quickly (under 300 ms on device; Apple's guideline is "as fast as possible"). The stub is instant. In #49, the `PendingQueueSelector` fetch must complete within that budget; its bounded `fetchLimit: 200` design already accounts for this.
- **Execution budget:** The system grants widget extensions a background execution budget. The stub's 15-minute `policy: .after(nextRefresh)` is a reasonable interval that does not exhaust the budget. #52 (debouncer) will call `WidgetCenter.shared.reloadAllTimelines()` after each dose write, which overrides the scheduled policy.
- **No WatchConnectivity inside the extension.** The extension is a separate sandboxed process; `WCSession` cannot be activated there. The extension reads data exclusively from the shared SwiftData store.
- **No `@Observable` in the extension.** Widget extensions use `TimelineEntry` value types as their data model, not `@Observable` classes. The entry types must be plain `Sendable` structs.

---

## 6. UX and Visual Design

The stub renders `"--"` in SF Pro Rounded bold (`title3` weight) centred in the `AccessoryWidgetBackground()` circle. This is intentionally minimal — it proves the slot is taken on the watch face without attempting final polish.

Final circular complication design (#49) will follow the monochromatic Liquid Glass baseline:
- `AccessoryWidgetBackground()` as the container (watchOS system-provided, adapts to watch face tinting).
- Text: the pending count as a numeral, or `"✓"` when clear.
- No amber accent — amber is reserved for the press-and-hold screen in the main app. The complication conveys state (a count), not risk.
- Typography: `LiquidGlassTheme.Typography.titleFont` equivalent — SF Pro Rounded semibold at complication-appropriate size.

---

## 7. Edge Cases and Failure Modes

| Scenario | Handling |
|---|---|
| Extension target fails to build due to missing App Group provisioning | Caught in CI; provisioning must be configured in the developer portal before first merge. |
| `widgetURL` URL string is malformed | `URL(string:)` returns `nil` silently; the complication becomes non-tappable. Use a `URL` constant validated at compile time (see #49 for the deep-link URL enum). |
| Watch face tinting obscures `"--"` text | `AccessoryWidgetBackground()` adapts automatically to the watch face's tint mode; test in the "tinted" face style in Simulator. |
| Two `@main` annotations in the same build | Not possible — the extension and watch app are separate targets with separate module namespaces. |

---

## 8. Testing Strategy

**Unit tests (new target `WatchAppWidgetsTests`):**
- `PendingDoseTimelineProvider` stub test: call `getTimeline`, assert one entry is returned with `pendingCount == nil` and `policy` is `.after(...)` with a date ~15 min in the future (within 5-second tolerance).
- `PendingDoseEntry` Sendable conformance: checked by the Swift compiler.

**Manual / simulator:**
- Build both `PillBreakfast Watch App Watch App` and `WatchAppWidgets` targets without errors.
- On the Apple Watch Series 11 (46mm) simulator, long-press the watch face, tap "Edit", navigate to complications, and confirm "Pending Doses" appears in the complication picker.
- Add the complication to the watch face; confirm `"--"` renders in the circular slot.
- Tap the complication; confirm the watch app opens (routing is unimportant at this stage — just confirms the deep-link fires without crashing).

**What cannot be tested until #49:**
- Real data rendering.
- `onOpenURL` routing to the tap-through queue.
- Any timeline policy driven by actual pending doses.

---

## 9. Performance and Resource Budget

The stub has no performance considerations beyond compilation speed. The design decisions recorded here (schema-only `ModelContainer` in #49, bounded `fetchLimit`, no `WCSession`, value-type entries) are the budget plan for the complete widget.

---

## 10. Risks and Open Questions

| Risk | Likelihood | Mitigation |
|---|---|---|
| Xcode 26 watchOS widget extension template generates unexpected boilerplate that conflicts with the design | Medium | Review generated files before committing; delete unused generated tests/preview code. |
| App Group provisioning is not set up for the new bundle ID in the portal | High (first-time) | Must be done manually before first CI run; document in the PR description. |
| `StaticConfiguration` vs. `AppIntentConfiguration` — which is correct for the stub? | Low | `StaticConfiguration` is correct here; `AppIntentConfiguration` is introduced in #51 for the Smart Stack widget. Complications use `StaticConfiguration`. |
| watchOS 26 may have changed the WidgetKit complication surface APIs | Low | Verify against Xcode 26 SDK; the design above follows the watchOS 10+ accessory family pattern which carried forward through 26. |

**Open question for #49:** Should `PendingDoseEntry` carry the full `[PendingDose]` array or just a pre-computed `Int` count? The complication only needs the count; the Smart Stack (#50) needs enough to render the next medication name. The resolution: keep `PendingDoseEntry` lean (count only) and introduce `SmartStackEntry` as a separate `TimelineEntry` type in #50.

---

## 11. Decomposition Hints

This issue is already the atomic skeleton step. There is exactly one implementation task: add the target, write the three files listed in §5.2, configure entitlements, and confirm the complication appears on the watch face. No further decomposition is warranted.

Child ordering for the Phase 7 epic:
1. **#48 (this)** — target skeleton, stub circular complication.
2. **#49** — real data in all three families + deep-link routing.
3. **#50** — Smart Stack widget with timeline relevance.
4. **#51** — `LogNextDoseIntent` + high-risk gate.
5. **#52** — background-refresh debouncer; Phase 7 gate passes.

---

## 12. Acceptance Criteria / Done-Done

- [ ] `WatchAppWidgets` target exists in `PillBreakfast.xcodeproj` with `watchOS 26` deployment target.
- [ ] `WatchAppWidgets.entitlements` contains `group.com.creekmasons.pillbreakfast`.
- [ ] `WatchAppWidgetsBundle.swift` compiles as the `@main` entry point for the extension.
- [ ] `PendingDoseTimelineProvider` returns one entry with `pendingCount == nil` (unit test passes).
- [ ] `PendingDoseComplication` registers `.accessoryCircular` family.
- [ ] Complication appears in the watch face complication picker on the Series 11 (46mm) simulator.
- [ ] Complication renders `"--"` in the circular slot.
- [ ] Both the watch app and the new extension build without warnings under Swift 6 strict concurrency.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR references `Closes #48` and `Refs #8`.

---

## 13. References

- SPEC §7.4 — complication requirements.
- SPEC §10 Phase 7 — gate criteria.
- `Shared/Persistence/PersistenceController.swift` — app-group container, schema, store URL.
- `PillBreakfast Watch App Watch App/PillBreakfast Watch App Watch App.entitlements` — existing App Group entitlement pattern.
- Apple: "Building Widgets for the Lock Screen and Watch Face" (WidgetKit documentation, Xcode 26 SDK).
- Apple: "Keeping a Widget Up To Date" (timeline policy reference).
- Successor: `2026-06-07_SPEC_ISSUE-49_three-complication-families.md`.
