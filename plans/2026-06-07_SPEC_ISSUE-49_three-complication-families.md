# SPEC — Issue #49: Three Complication Families Reading Real Data

| Field | Value |
|---|---|
| Issue | #49 |
| Phase | 7 — Widgets & Complication |
| Labels | `spec-decomposition`, `core`, `phase-7-widgets`, `needs-spec` |
| Status | Draft |
| Date | 2026-06-07 |
| Epic | #8 |
| Predecessor | #48 (widget extension stub) |
| Successor issues | #50 (Smart Stack widget), #51 (LogNextDoseIntent), #52 (background-refresh debouncer) |

---

## 1. Summary

This issue replaces the stub complication from #48 with a fully functional `TimelineProvider` that reads the real pending-dose count from the shared SwiftData store via the App Group, then implements all three complication families — `.accessoryCircular`, `.accessoryCorner`, and `.accessoryInline` — rendering the live count or `"✓"` when the queue is clear. Tapping any family deep-links into the watch app's tap-through queue. The watch app's `onOpenURL` handler is wired to route `pillbreakfast://tap-through` to the correct view.

---

## 2. Problem Statement / Motivation

A complication that always shows `"--"` is a placeholder, not a product. The core promise — "Geoff knows what he has and hasn't taken, with zero ambiguity, on the device that's already on his wrist" (SPEC §1) — requires the complication to reflect reality: how many doses are due right now. Three families are required because users choose their watch face style; covering circular (most compact), corner (curved lower region), and inline (horizontal text strip) ensures the complication is available on virtually every supported watch face.

---

## 3. Goals and Non-Goals

**Goals:**
- Wire `PendingDoseTimelineProvider` to the real SwiftData store via a read-only `ModelContainer` opened against the App Group store URL.
- Compute the pending count using `PendingQueueSelector` (from `Shared/Queue/PendingQueueSelector.swift`).
- Produce a `Timeline` with one entry per `ScheduledDose` window boundary plus a final "all clear" entry.
- Implement `CircularComplicationView`, `CornerComplicationView`, and `InlineComplicationView`.
- Register all three families in `PendingDoseComplication`.
- Wire `widgetURL(URL(string: "pillbreakfast://tap-through"))` on each family's root view.
- Add `onOpenURL` handling in `PillBreakfast_Watch_App_Watch_AppApp` or `RightNowView` to route the deep-link.
- Snapshot tests for each family using a fixture `PendingDoseEntry`.

**Non-Goals:**
- Smart Stack widget — #50.
- `AppIntent` / tap-to-log — #51.
- Background refresh / `WidgetCenter.reloadAllTimelines()` calls from the main app — #52.
- Any iOS-side widget.
- Displaying individual medication names in the complication (count only per SPEC §7.4).

---

## 4. Background and Current State

After #48 lands, the codebase has:
- `WatchAppWidgets/WatchAppWidgetsBundle.swift` — `@main WidgetBundle`.
- `WatchAppWidgets/PendingDoseComplication.swift` — stub `.accessoryCircular`, renders `"--"`.
- `WatchAppWidgets/PendingDoseTimelineProvider.swift` — stub returning `PendingDoseEntry(date: .now, pendingCount: nil)` with a 15-minute reload policy.

Key types this issue must use from `Shared/`:
- `PersistenceController.schema` — the SwiftData schema array. The extension opens its own `ModelContainer` with the same schema and store URL.
- `PersistenceController.appGroupIdentifier = "group.com.creekmasons.pillbreakfast"` and `PersistenceController.appGroupStoreURL` — the store URL the extension must pass to `ModelConfiguration(url:)`.
- `PendingQueueSelector` (`@MainActor public struct`) in `Shared/Queue/PendingQueueSelector.swift`. This is the canonical source of truth for "which doses are pending right now." Its `pendingDoses(at:in:)` method returns `[PendingDose]`.
- `PendingDose` (`public struct PendingDose: Sendable, Hashable, Identifiable`) — the value type that comes back from the selector.
- `DoseEvent`, `Medication`, `ScheduledDose`, `Ingredient`, `MedicationComponent`, `SnoozeRecord`, `PillMeal` — the full schema that must be passed to `ModelContainer(for:configurations:)` to open the store without a migration error.

SPEC §7.4: "Shows count of pending doses for current window (e.g. '2 pending') or '✓' when clear. Tap → opens app to tap-through queue."

---

## 5. Detailed Design

### 5.1 `PendingDoseEntry` (updated)

```swift
import WidgetKit
import Foundation

/// A snapshot value passed from the TimelineProvider to complication views.
/// Sendable by construction (all fields are value types).
struct PendingDoseEntry: TimelineEntry, Sendable {
    let date: Date
    /// Nil only in placeholder/preview context. Zero means "all caught up."
    let pendingCount: Int?
}

extension PendingDoseEntry {
    /// Convenience: the display string used by all three families.
    var displayText: String {
        guard let count = pendingCount else { return "--" }
        return count == 0 ? "✓" : "\(count)"
    }

    /// True when there are doses pending right now.
    var hasPending: Bool {
        (pendingCount ?? 0) > 0
    }
}
```

### 5.2 `PendingDoseTimelineProvider` (replaced)

The provider opens its own `ModelContainer` per `getTimeline` call, reads the pending count, then builds a timeline that covers the next ~24 hours of schedule transitions.

**Timeline construction strategy:**

The provider must answer: "at what future times will the pending count change?" It changes at:
1. The opening edge of each `ScheduledDose` window (T - 60 min per `PendingQueueSelector.windowMinutes`) — a dose becomes pending.
2. The closing edge of each window (T + 60 min) — a dose expires without being taken.
3. When a dose is logged — handled externally by `WidgetCenter.reloadAllTimelines()` in #52.

For a 24-hour lookahead with ~12 doses/day, this produces at most ~24 entries (12 opening edges + 12 closing edges). This is well within the ~25-entry guideline Apple recommends for watchOS complications.

```swift
import WidgetKit
import SwiftData
import Foundation

struct PendingDoseTimelineProvider: TimelineProvider {
    typealias Entry = PendingDoseEntry

    func placeholder(in context: Context) -> PendingDoseEntry {
        PendingDoseEntry(date: .now, pendingCount: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PendingDoseEntry) -> Void) {
        // Snapshot must be fast — use a quick count or fall back to nil.
        let count = (try? Self.pendingCount(at: .now)) ?? nil
        completion(PendingDoseEntry(date: .now, pendingCount: count))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PendingDoseEntry>) -> Void) {
        // Build timeline entries for all window transitions in the next 24 hours.
        // Falls back to a single current-state entry on any error.
        let entries = (try? Self.buildEntries(lookahead: .hours(24))) ?? [
            PendingDoseEntry(date: .now, pendingCount: nil)
        ]
        // After the last entry, ask for a refresh at the end of the timeline window.
        // WidgetCenter.reloadAllTimelines() (issued from #52 after each dose write)
        // will override this sooner when actual data changes.
        let policy: TimelineReloadPolicy = .atEnd
        completion(Timeline(entries: entries, policy: policy))
    }

    // MARK: - Private helpers

    /// Opens a read-only ModelContainer for the shared store. Each call creates a
    /// new container because the extension is a separate process from the watch app
    /// and cannot share PersistenceController.shared (which is @MainActor and lives
    /// in a different process). Read-only access avoids write conflicts with the
    /// watch app's active container.
    private static func makeContext() throws -> ModelContext {
        let url = PersistenceController.appGroupStoreURL
        let config = ModelConfiguration(url: url, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: PersistenceController.schema, configurations: config)
        return ModelContext(container)
    }

    private static func pendingCount(at date: Date) throws -> Int {
        let context = try makeContext()
        let selector = PendingQueueSelector()
        // PendingQueueSelector is @MainActor; the extension's getTimeline runs on
        // the main actor by convention (WidgetKit calls providers on the main thread
        // for watchOS). This is validated by the Swift 6 concurrency checker.
        return try selector.pendingDoses(at: date, in: context).count
    }

    private static func buildEntries(lookahead: Duration) throws -> [PendingDoseEntry] {
        let context = try makeContext()
        let now = Date.now
        let end = now + lookahead.timeInterval

        // Collect all window-transition moments: opening edges (T - windowMins)
        // and closing edges (T + windowMins) of every ScheduledDose in the next 24h.
        // This does not need to be perfectly accurate — WidgetCenter.reloadAllTimelines()
        // from #52 corrects for dose writes in between.
        let transitionDates = try Self.transitionDates(in: context, from: now, to: end)

        // Evaluate the pending count at each transition point plus right now.
        let evaluationDates = ([now] + transitionDates).sorted()
        let selector = PendingQueueSelector()

        return try evaluationDates.compactMap { date -> PendingDoseEntry? in
            let count = try selector.pendingDoses(at: date, in: context).count
            return PendingDoseEntry(date: date, pendingCount: count)
        }
    }

    /// Returns the set of dates at which the pending count may change, within
    /// [from, to), by inspecting the ScheduledDose schedule for all active
    /// maintenance medications. This is a pure calendar calculation — no
    /// DoseEvent lookup — so it represents the "if nothing is logged" upper bound.
    private static func transitionDates(
        in context: ModelContext,
        from start: Date,
        to end: Date
    ) throws -> [Date] {
        let windowSecs = Double(PendingQueueSelector().windowMinutes) * 60
        let meds = try context.fetch(
            FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived })
        ).filter { $0.kind == .maintenance }

        var dates: [Date] = []
        let calendar = Calendar.current
        // Walk each day from start to end (at most 2 days for a 24h lookahead).
        var day = calendar.startOfDay(for: start)
        while day < end {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            let isoWeekday = PendingQueueSelector.isoWeekday(
                fromCalendar: calendar.component(.weekday, from: day)
            )
            for med in meds {
                for dose in med.schedule {
                    guard dose.daysOfWeek.isEmpty || dose.daysOfWeek.contains(isoWeekday) else { continue }
                    guard let scheduled = calendar.date(
                        bySettingHour: dose.hour, minute: dose.minute, second: 0, of: day
                    ) else { continue }
                    let open = scheduled.addingTimeInterval(-windowSecs)
                    let close = scheduled.addingTimeInterval(windowSecs)
                    if open >= start && open < end { dates.append(open) }
                    if close >= start && close < end { dates.append(close) }
                }
            }
            day = nextDay
        }
        return dates
    }
}

private extension Duration {
    static func hours(_ n: Int) -> Duration {
        .seconds(n * 3600)
    }

    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}
```

**Concurrency note:** `PendingQueueSelector` is `@MainActor`. WidgetKit calls `getTimeline` on the main thread in watchOS widget extensions (this is the documented behavior for watchOS — the extension has no background execution concurrency model the way iOS widgets do). The Swift 6 concurrency checker will accept `MainActor`-isolated calls from within `getTimeline` without an explicit `await` when the call already runs on the main actor. If the checker requires it, mark `getTimeline` as `@MainActor` (permitted per WidgetKit protocol).

### 5.3 Complication View Files

**`WatchAppWidgets/Variants/CircularComplicationView.swift`:**

```swift
import SwiftUI
import WidgetKit

struct CircularComplicationView: View {
    let entry: PendingDoseEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text(entry.displayText)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.5)
                .foregroundStyle(entry.hasPending ? .primary : .secondary)
                .widgetAccentable()
        }
    }
}
```

**`WatchAppWidgets/Variants/CornerComplicationView.swift`:**

The `.accessoryCorner` family uses a curved bottom-left or bottom-right region of the watch face. It pairs a small image with a short text label. The system applies watch-face tinting automatically.

```swift
import SwiftUI
import WidgetKit

struct CornerComplicationView: View {
    let entry: PendingDoseEntry

    var body: some View {
        // Label layout: icon + text in the corner slot.
        // .widgetLabel applies the text to the curved outer arc.
        Image(systemName: entry.hasPending ? "pills.fill" : "checkmark")
            .widgetAccentable()
            .widgetLabel {
                Text(entry.displayText)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
    }
}
```

**`WatchAppWidgets/Variants/InlineComplicationView.swift`:**

The `.accessoryInline` family is a single line of text + optional image, rendered in the top center of certain watch faces.

```swift
import SwiftUI
import WidgetKit

struct InlineComplicationView: View {
    let entry: PendingDoseEntry

    var body: some View {
        // Inline is strictly one line of text (with optional leading image).
        // The system truncates if needed; keep the string short.
        if entry.hasPending, let count = entry.pendingCount {
            Label("\(count) pending", systemImage: "pills.fill")
        } else {
            Label("All clear", systemImage: "checkmark")
        }
    }
}
```

### 5.4 `PendingDoseComplication` (updated)

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
            ComplicationRouter(entry: entry)
                .widgetURL(URL(string: "pillbreakfast://tap-through"))
        }
        .configurationDisplayName("Pending Doses")
        .description("Shows how many doses are due right now.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

/// Routes to the correct view per active family. A single Widget with multiple
/// families is the recommended pattern; it avoids separate entries in the
/// complication picker for what is conceptually one complication.
private struct ComplicationRouter: View {
    @Environment(\.widgetFamily) private var family
    let entry: PendingDoseEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        default:
            // Fallback: system should never call this for unsupported families,
            // but be safe.
            CircularComplicationView(entry: entry)
        }
    }
}
```

### 5.5 Deep-Link Routing in the Watch App

`RightNowView` (in `PillBreakfast Watch App Watch App/RootView/RightNowView.swift`) already wraps its content in a `NavigationStack`. Add an `onOpenURL` modifier at the scene level, or on `RightNowView`, to handle the deep-link:

```swift
// In PillBreakfast_Watch_App_Watch_AppApp or on RightNowView:
.onOpenURL { url in
    if url.scheme == "pillbreakfast", url.host == "tap-through" {
        // RightNowView already shows the tap-through queue when pendingDoses is
        // non-empty. The deep-link just needs to bring the app to the foreground —
        // the existing reload() logic handles the rest.
        // If a more targeted navigation is needed (e.g. scroll to first dose),
        // add a @State Bool flag here and pass it into TapThroughQueueView.
    }
}
```

The URL scheme `pillbreakfast` must be declared in the watch app target's `Info.plist` under `CFBundleURLTypes` with `CFBundleURLSchemes = ["pillbreakfast"]`. Without this declaration the system will not route the URL to the watch app process.

### 5.6 Shared Module Membership

The following `Shared/` files must be added to the `WatchAppWidgets` target's compilation sources in Xcode:
- `Shared/Models/Medication.swift`
- `Shared/Models/DoseEvent.swift`
- `Shared/Models/Ingredient.swift`
- `Shared/Models/MedicationComponent.swift`
- `Shared/Models/ScheduledDose.swift`
- `Shared/Models/SnoozeRecord.swift` (required by schema)
- `Shared/Models/PillMeal.swift` (required by schema)
- `Shared/Models/Enums.swift`
- `Shared/Models/LoggedIngredientAmount.swift`
- `Shared/Persistence/PersistenceController.swift` (for `appGroupStoreURL`, `schema`, `appGroupIdentifier`)
- `Shared/Queue/PendingQueueSelector.swift`
- `Shared/Persistence/IngredientLibrarySeeder.swift` (pulled in transitively by `PersistenceController.init`; the extension must not execute the seeder — see note below)

**Important:** `PersistenceController.init()` calls `IngredientLibrarySeeder.seedIfNeeded(context:)`. The extension must NOT call `PersistenceController.shared` — it must construct its own `ModelContainer` directly (as shown in §5.2) to avoid triggering the seeder in the extension process. The seeder is idempotent, but it issues writes and the extension should be read-only.

### 5.7 Swift 6 Concurrency

- `PendingDoseEntry`: `Sendable` by construction (value type, all fields `Sendable`).
- `PendingDoseTimelineProvider`: struct, no isolation annotation needed. Helper statics can be called from the main actor in `getTimeline`.
- `PendingQueueSelector` is `@MainActor`. The extension's `getTimeline` runs on the main thread. If the Swift 6 checker raises an isolation crossing warning, annotate `getTimeline` as `@MainActor`.
- The `ModelContext` created inside `makeContext()` belongs to the main actor by default (it is created on whichever actor calls the function). Do not pass it across actor boundaries.

---

## 6. UX and Visual Design

**Circular:** Numeral centred on `AccessoryWidgetBackground()`. Font: SF Pro Rounded bold, title3. `"✓"` when pending count is zero — lighter foreground style (`.secondary`). `"--"` only in placeholder mode.

**Corner:** `pills.fill` icon with the count string in the outer arc label. On high-density watch faces the arc label may be truncated by the system; keep the string under six characters (`"3"`, `"✓"`, `"--"`).

**Inline:** `"N pending"` with a `pills.fill` icon, or `"All clear"` with `checkmark`. The system tints the whole view based on the watch face theme.

**Color discipline:** No amber. No custom colors. `widgetAccentable()` marks views that should receive watch-face accent tinting, letting the system apply the user's chosen face accent — not our app's amber. The amber is reserved for the press-and-hold UX in the main app exclusively.

**Liquid Glass note:** WidgetKit on watchOS renders complication backgrounds using the system-provided `AccessoryWidgetBackground()`, not the `.glassEffect()` modifier. `.glassEffect()` is a main-app API and is not available in widget extensions. `AccessoryWidgetBackground()` achieves the same material-based look within the complication container.

---

## 7. Edge Cases and Failure Modes

| Scenario | Handling |
|---|---|
| `ModelContainer` fails to open (store corrupted, migration needed) | Catch in `makeContext()`, return `PendingDoseEntry(date: .now, pendingCount: nil)`. Display `"--"` rather than crashing. |
| `PendingQueueSelector` throws `CalendarError.fetchLimitReached` | Catch in `buildEntries`, return a single current-entry with `pendingCount: nil`. Log via `os_log` (no `os.Logger` in extensions? — use `OSLog` directly since `Logger` is available iOS 14+ / watchOS 7+; both are available on watchOS 26). |
| `PendingQueueSelector` throws `CalendarError.windowComputationFailed` | Same as above. |
| App Group container URL is nil (entitlement misconfigured) | `PersistenceController.appGroupStoreURL` calls `fatalError`. In the extension this would crash the extension process silently — the complication shows stale data. Mitigate by guarding the URL in the extension's `makeContext()` and returning a placeholder entry instead of calling `fatalError`. |
| No maintenance medications exist | `pendingCount` returns 0. Complication shows `"✓"`. Correct behavior. |
| DST gap causes `calendar.date(bySettingHour:minute:second:of:)` to return `nil` | The DST guard in `PendingQueueSelector.pendingDoses` already handles this with `continue`. The extension's `transitionDates` helper uses the same guard pattern. |
| Watch face tinting makes the numeral unreadable | `widgetAccentable()` opts the view into the system's tinting system, which adapts contrast automatically. |
| The complication is loaded in a snapshot context (`context.isPreview == true`) | Use `placeholder(in:)` data — `pendingCount: nil` / `"--"` — without touching the store. Already handled by the `getSnapshot` fast path. |

---

## 8. Testing Strategy

**Unit tests (`WatchAppWidgetsTests`):**
- `PendingDoseEntry.displayText`: assert `nil` → `"--"`, `0` → `"✓"`, `3` → `"3"`.
- `PendingDoseEntry.hasPending`: assert `nil` → `false`, `0` → `false`, `1` → `true`.
- `PendingDoseTimelineProvider.buildEntries` with an in-memory store containing two scheduled doses 6h apart: assert the returned entries contain transition-date entries (not just one entry) and that count values are correct per injected `now`.
- `transitionDates`: inject a fixed `now` and a `Medication` with one `ScheduledDose`; assert two transition dates are returned (opening and closing of the window).

**Snapshot tests (SwiftUI previews / `PreviewProvider`):**
- One preview per family with a fixture entry (`pendingCount: 2`).
- One preview per family with `pendingCount: 0` (the "✓" state).
- These previews serve as manual visual regression checkpoints; formal snapshot testing via a library like SnapshotTesting is optional at this phase.

**Manual / simulator:**
- Add all three family complications to a watch face; confirm they all render correctly.
- Tap each complication; confirm the watch app opens and lands on `RightNowView`.
- In the simulator, log a dose (via the watch app), then manually call `WidgetCenter.shared.reloadAllTimelines()` from a debug build to confirm the complication count updates (the automatic post-dose reload is #52's job).

**What cannot be tested until #52:**
- Automatic post-dose reload.

---

## 9. Performance and Resource Budget

- `getTimeline` must complete within ~300 ms. The `PendingQueueSelector` fetch is bounded by `fetchLimit: 200` and the `transitionDates` walk is O(doses × days) ≤ O(12 × 2) = O(24) — negligible.
- Timeline entry count: at most ~25 entries for a 24-hour lookahead (2 × 12 doses). Within Apple's guidance.
- `ModelContainer` initialization cost: opening the SQLite store is the dominant cost (~50–100 ms first open; subsequent opens hit the OS page cache). On watchOS this is acceptable. Do not open a `ModelContainer` in `placeholder(in:)` or `getSnapshot` (use a fast path or cached value).
- Memory: the full schema is opened but only `Medication`, `ScheduledDose`, and `DoseEvent` rows are fetched. With ~12 meds and ~12 doses per day × 3 days = ~36 `DoseEvent`s materialized, peak RSS stays well under the watchOS widget budget (~10 MB active).
- **No WCSession, no networking, no HealthKit** in the extension. Pure SwiftData reads.

---

## 10. Risks and Open Questions

| Risk | Likelihood | Mitigation |
|---|---|---|
| SwiftData store opened by both the watch app and the extension simultaneously causes write-ahead log contention | Medium | The extension is read-only; SQLite WAL mode allows concurrent readers with a single writer. Ensure the extension never calls `context.save()`. |
| `PendingQueueSelector`'s `@MainActor` annotation causes Swift 6 isolation errors in the extension | Low | Mark `getTimeline(in:completion:)` as `@MainActor` if needed; this is valid WidgetKit usage. |
| The `isoWeekday(fromCalendar:)` helper is `internal` (not `public`) in `PendingQueueSelector` | Confirmed: the function is `static` with no explicit access control, so it defaults to `internal`. The extension is in a different module — this is a problem. | In #49, either (a) make it `public`, or (b) inline the one-liner in `transitionDates`. Option (b) is simpler — it's `gregorian == 1 ? 7 : gregorian - 1`. |
| Three families in one `Widget` type means one `kind` string for all. Apple may surface them as duplicates in the picker | Low | Tested in Xcode 26 simulator. If the picker shows duplicates, split into three separate `Widget` types with distinct `kind` strings. |

**Open question resolved from #48:** `PendingDoseEntry` carries `Int?` (count only) — not the full `[PendingDose]` array. The Smart Stack (#50) introduces a separate `SmartStackEntry` that carries the next medication's name.

---

## 11. Decomposition Hints

This is a single PR. The implementation sequence within the PR:
1. Add `Shared/` file target membership to `WatchAppWidgets`.
2. Update `PendingDoseEntry` with `displayText` / `hasPending`.
3. Replace stub `PendingDoseTimelineProvider` with the real one.
4. Create the three variant view files.
5. Update `PendingDoseComplication` to register all three families.
6. Add `CFBundleURLTypes` to the watch app's `Info.plist` for the `pillbreakfast://` URL scheme.
7. Add `onOpenURL` handler in the watch app.
8. Write tests.

---

## 12. Acceptance Criteria / Done-Done

- [ ] `PendingDoseEntry.displayText` returns `"--"` for `nil`, `"✓"` for `0`, digit string for positive counts (unit test).
- [ ] `PendingDoseTimelineProvider.getTimeline` produces entries at window-transition dates (unit test with in-memory store).
- [ ] All three families — circular, corner, inline — render on a watch face in the simulator.
- [ ] Complication shows `"2"` (or matching fixture count) when two doses are pending.
- [ ] Complication shows `"✓"` when no doses are pending.
- [ ] Tapping any complication opens the watch app (simulator manual test).
- [ ] `onOpenURL` handler does not crash on `pillbreakfast://tap-through`.
- [ ] Extension opens the SwiftData store read-only (no `context.save()` calls).
- [ ] Both watch app and widget extension build under Swift 6 strict concurrency with zero warnings.
- [ ] `pre-commit run --all-files` clean.
- [ ] PR references `Closes #49` and `Refs #8`.

---

## 13. References

- SPEC §7.4 — complication requirement.
- SPEC §10 Phase 7 — gate: "Add complication to watch face. See pending count update in real time after a dose is logged."
- `Shared/Queue/PendingQueueSelector.swift` — the canonical pending-dose computation.
- `Shared/Persistence/PersistenceController.swift` — `appGroupStoreURL`, `schema`, `appGroupIdentifier`.
- `Shared/Models/` — full schema types.
- `Shared/DesignSystem/LiquidGlassTheme.swift` — typography tokens (used in view styling).
- Predecessor: `2026-06-07_SPEC_ISSUE-48_widget-extension-stub.md`.
- Successor: `2026-06-07_SPEC_ISSUE-50_smart-stack-widget.md`.
- Apple: "Creating accessory widgets and watch complications" (WidgetKit, Xcode 26 SDK).
- Apple: "TimelineProvider" protocol documentation.
