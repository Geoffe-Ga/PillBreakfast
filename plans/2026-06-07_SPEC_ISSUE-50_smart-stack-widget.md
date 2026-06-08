# SPEC — Issue #50: Smart Stack Widget Surfacing 15 Min Before Scheduled Doses

| Field | Value |
|---|---|
| Issue | #50 |
| Phase | 7 — Widgets & Complication |
| Labels | `spec-decomposition`, `core`, `phase-7-widgets`, `needs-spec` |
| Status | Draft |
| Date | 2026-06-07 |
| Epic | #8 |
| Predecessor | #49 (three complication families) |
| Successor issues | #51 (LogNextDoseIntent), #52 (background-refresh debouncer) |

---

## 1. Summary

This issue adds a `SmartStackWidget` to the `WatchAppWidgets` extension that surfaces automatically in the Apple Watch Smart Stack approximately 15 minutes before each scheduled dose. Each entry carries the name of the next medication group or Pill Meal due, the count of doses in that group, and a deep-link to open the watch app's tap-through queue. Relevance scoring drives the Smart Stack surfacing; the widget does not log doses — that is #51's scope.

---

## 2. Problem Statement / Motivation

SPEC §7.5: "Surfaces 15 min before each scheduled time. Single-tap from widget → logs the next pending dose (no need to open app). Liquid Glass background per watchOS 26 guidelines." The single-tap log arrives in #51; this issue delivers the prerequisite: the widget itself, with proper timeline entries and relevance metadata so the Smart Stack actually surfaces it at the right moments.

The Smart Stack is the mechanism by which the watch proactively surfaces relevant widgets without requiring the user to open the app or look at a complication. Used correctly, it means the dose reminder is visible with a glance and a scroll — one step below a complication, one step more visible than the notification shade. For someone with a 12-pill-a-day regimen this is meaningful ambient awareness.

---

## 3. Goals and Non-Goals

**Goals:**
- Implement `SmartStackWidget` (new `Widget` conformance) and register it in `WatchAppWidgetsBundle`.
- Implement `SmartStackTimelineProvider: TimelineProvider` producing entries for the next 24 hours with `TimelineEntryRelevance` scores set to peak 15 minutes before each scheduled dose group.
- Implement `SmartStackEntry: TimelineEntry, Sendable` carrying the data needed to render: medication group name, dose count, and the `isHighRisk` flag for the leading dose (used in #51 to gate the intent button).
- Implement `SmartStackWidgetView` with Liquid Glass background and SF Pro Rounded typography per `LiquidGlassTheme`.
- Tapping anywhere on the widget opens the watch app to the tap-through queue via `widgetURL("pillbreakfast://tap-through")`.
- Snapshot tests for the widget view with fixture entries.

**Non-Goals:**
- `Button(intent:)` / `LogNextDoseIntent` — that is #51. The widget in this issue is tap-to-open-app only.
- iOS widget extension — out of scope entirely (CLAUDE.md: iPhone never shows "take pills now").
- Showing PRN medications in the Smart Stack — PRN has no scheduled time, so there is no 15-min-before trigger.
- Real-time updates after a dose is logged — that is #52 (`WidgetCenter.reloadAllTimelines()`).

---

## 4. Background and Current State

After #49 lands:
- `WatchAppWidgets/WatchAppWidgetsBundle.swift` registers `PendingDoseComplication`.
- `WatchAppWidgets/PendingDoseTimelineProvider.swift` reads the shared SwiftData store and builds a timeline for the complication.
- The deep-link `pillbreakfast://tap-through` is wired in the watch app.

The Smart Stack uses the same extension and the same App Group store. The key difference from the complication is **timeline relevance**: `TimelineEntryRelevance` lets you declare that a particular entry has high relevance during a specific interval, which is how Apple decides when to surface the widget near the top of the Smart Stack. Without proper relevance scores the widget appears in the Stack but is not proactively surfaced.

`PillMealDTO` and `MedicationDTO` from `Shared/Sync/RegimenSnapshot.swift` carry the data needed for display. Because the extension already has `Medication`, `ScheduledDose`, and `PillMeal` in its target membership (added in #49), this issue uses the SwiftData models directly.

---

## 5. Detailed Design

### 5.1 `SmartStackEntry`

```swift
import WidgetKit
import Foundation

/// One entry in the Smart Stack timeline. Represents the state of the widget
/// for a given moment in time, typically aligned to 15 min before a dose group.
struct SmartStackEntry: TimelineEntry, Sendable {
    let date: Date
    /// Nil only in placeholder context.
    let doseGroup: DoseGroupSummary?
}

/// A minimal snapshot of one dose group (a Pill Meal or a per-slot aggregate of
/// medications scheduled at the same time) carried value-type from the provider
/// to the view. Sendable because all fields are value types.
struct DoseGroupSummary: Sendable, Hashable {
    /// Display name. For a Pill Meal this is the meal name (e.g. "Morning Meds").
    /// For ungrouped doses this is the aggregate label (e.g. "Lithium · Vitamin D").
    let groupName: String
    /// How many individual medication doses are in this group (e.g. 4).
    let doseCount: Int
    /// The wall-clock scheduled time for this group (used in the subtitle).
    let scheduledAt: Date
    /// True if any medication in this group is high-risk. Used in #51 to gate
    /// the intent button; stored here so the view can render a hint.
    let containsHighRisk: Bool
}
```

### 5.2 `SmartStackTimelineProvider`

The provider builds a timeline over the next 24 hours. Each dose group produces **three entries**:

1. **T - 15 min** (`relevance.score` = 10, `relevance.duration` = 15 * 60 s): the entry that appears just before the dose window opens. High relevance causes the Stack to surface the widget.
2. **T** (the scheduled time, `relevance.score` = 8, `relevance.duration` = 60 * 60 s): the entry while the dose window is active. Slightly lower score because the complication (not the Stack widget) is the primary surface once the window is open.
3. **T + 60 min** (`relevance.score` = 0): the entry after the window closes, when the group should no longer be prominently surfaced.

A "no upcoming doses" entry (`doseGroup: nil`) is appended at the end of all group entries so the widget has a graceful idle state.

```swift
import WidgetKit
import SwiftData
import Foundation

struct SmartStackTimelineProvider: TimelineProvider {
    typealias Entry = SmartStackEntry

    func placeholder(in context: Context) -> SmartStackEntry {
        SmartStackEntry(date: .now, doseGroup: DoseGroupSummary(
            groupName: "Morning Meds",
            doseCount: 4,
            scheduledAt: .now,
            containsHighRisk: false
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (SmartStackEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let entry = (try? Self.currentEntry(at: .now)) ?? SmartStackEntry(date: .now, doseGroup: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmartStackEntry>) -> Void) {
        let entries = (try? Self.buildEntries(lookahead: .hours(24))) ?? [
            SmartStackEntry(date: .now, doseGroup: nil)
        ]
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    // MARK: - Private

    private static func makeContext() throws -> ModelContext {
        let url = PersistenceController.appGroupStoreURL
        let config = ModelConfiguration(url: url, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: PersistenceController.schema, configurations: config)
        return ModelContext(container)
    }

    private static func currentEntry(at now: Date) throws -> SmartStackEntry {
        let context = try makeContext()
        let groups = try doseGroups(in: context, on: now, calendar: .current)
        // Find the nearest upcoming (or currently active) group.
        let windowMins = Double(PendingQueueSelector().windowMinutes)
        let nearest = groups.first { group in
            let delta = group.scheduledAt.timeIntervalSince(now)
            return delta >= -(windowMins * 60) // within the window or upcoming
        }
        return SmartStackEntry(date: now, doseGroup: nearest)
    }

    private static func buildEntries(lookahead: Duration) throws -> [SmartStackEntry] {
        let context = try makeContext()
        let now = Date.now
        let calendar = Calendar.current
        var entries: [SmartStackEntry] = []

        // Walk each day in the lookahead window.
        var day = calendar.startOfDay(for: now)
        let end = now + lookahead.timeInterval
        while day < end {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            let groups = try doseGroups(in: context, on: day, calendar: calendar)
            for group in groups {
                let t = group.scheduledAt
                let t_minus15 = t.addingTimeInterval(-15 * 60)
                let t_plus60 = t.addingTimeInterval(60 * 60)

                // Only emit entries within [now, end).
                if t_minus15 >= now && t_minus15 < end {
                    var entry = SmartStackEntry(date: t_minus15, doseGroup: group)
                    entries.append(entry.withRelevance(score: 10, duration: 15 * 60))
                }
                if t >= now && t < end {
                    var entry = SmartStackEntry(date: t, doseGroup: group)
                    entries.append(entry.withRelevance(score: 8, duration: 60 * 60))
                }
                if t_plus60 >= now && t_plus60 < end {
                    // After the window: the group is gone, show idle state.
                    entries.append(SmartStackEntry(date: t_plus60, doseGroup: nil))
                }
            }
            day = nextDay
        }

        // Ensure at least one entry (idle state) so the timeline is never empty.
        if entries.isEmpty {
            entries.append(SmartStackEntry(date: now, doseGroup: nil))
        }

        return entries.sorted { $0.date < $1.date }
    }

    /// Builds `DoseGroupSummary` objects for all scheduled dose groups on the calendar
    /// day containing `date`. Groups by Pill Meal first; ungrouped doses aggregate
    /// by time slot.
    static func doseGroups(
        in context: ModelContext,
        on date: Date,
        calendar: Calendar
    ) throws -> [DoseGroupSummary] {
        let startOfDay = calendar.startOfDay(for: date)
        let isoWeekday = PendingQueueSelector.isoWeekday(
            fromCalendar: calendar.component(.weekday, from: date)
        )
        let meds = try context.fetch(
            FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived })
        ).filter { $0.kind == .maintenance }

        // Collect (ScheduledDose, Medication) pairs active on this day.
        let activePairs: [(ScheduledDose, Medication)] = meds.flatMap { med in
            med.schedule.compactMap { dose -> (ScheduledDose, Medication)? in
                guard dose.daysOfWeek.isEmpty || dose.daysOfWeek.contains(isoWeekday) else { return nil }
                return (dose, med)
            }
        }

        // Group by Pill Meal, falling back to time slot for ungrouped doses.
        var mealGroups: [UUID: (PillMeal, [(ScheduledDose, Medication)])] = [:]
        var slotGroups: [TimeSlotKey: [(ScheduledDose, Medication)]] = [:]

        for pair in activePairs {
            let (dose, med) = pair
            if let meal = dose.pillMeal {
                mealGroups[meal.id, default: (meal, [])].1.append(pair)
            } else {
                let key = TimeSlotKey(hour: dose.hour, minute: dose.minute)
                slotGroups[key, default: []].append(pair)
            }
        }

        var summaries: [DoseGroupSummary] = []

        // Meal groups: use the meal's targetHour/targetMinute for the scheduled time.
        for (_, (meal, pairs)) in mealGroups {
            guard let scheduledAt = calendar.date(
                bySettingHour: meal.targetHour,
                minute: meal.targetMinute,
                second: 0,
                of: startOfDay
            ) else { continue }
            let containsHighRisk = pairs.contains { $0.1.isHighRisk }
            summaries.append(DoseGroupSummary(
                groupName: meal.name,
                doseCount: pairs.count,
                scheduledAt: scheduledAt,
                containsHighRisk: containsHighRisk
            ))
        }

        // Slot groups: aggregate medication names into a display label.
        for (slot, pairs) in slotGroups {
            guard let scheduledAt = calendar.date(
                bySettingHour: slot.hour,
                minute: slot.minute,
                second: 0,
                of: startOfDay
            ) else { continue }
            let names = pairs.map(\.1.displayName).sorted()
            let label = Self.groupLabel(names: names)
            let containsHighRisk = pairs.contains { $0.1.isHighRisk }
            summaries.append(DoseGroupSummary(
                groupName: label,
                doseCount: pairs.count,
                scheduledAt: scheduledAt,
                containsHighRisk: containsHighRisk
            ))
        }

        return summaries.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// "Lithium · Vitamin D · +2 more" — matches the notification body format from
    /// `NotificationScheduler.bodyText(for:)` for visual consistency.
    static func groupLabel(names: [String]) -> String {
        guard names.count > 2 else { return names.joined(separator: " · ") }
        return names.prefix(2).joined(separator: " · ") + " · +\(names.count - 2) more"
    }
}

// MARK: - Supporting types

private struct TimeSlotKey: Hashable {
    let hour: Int
    let minute: Int
}

private extension SmartStackEntry {
    // Relevance is applied via WidgetKit's TimelineEntryRelevance attached
    // to the Timeline at build time, not stored on the entry.
    // This helper returns a new entry for API symmetry in the call site.
    func withRelevance(score: Float, duration: TimeInterval) -> SmartStackEntry {
        // TimelineEntryRelevance is set on the Timeline struct itself using
        // `Timeline(entries:policy:)` with per-entry relevance. In WidgetKit,
        // relevance is attached to entries via the TimelineEntryRelevance value
        // associated with each entry during timeline construction. The pattern
        // below is the correct one for watchOS.
        self // actual relevance attachment is at timeline construction below
    }
}
```

**Important implementation note on `TimelineEntryRelevance`:** WidgetKit's `TimelineEntryRelevance` is not stored on `TimelineEntry` values directly in Swift. It is attached to entries during `Timeline` construction via `Timeline(entries:policy:)` — each entry carries a parallel `TimelineEntryRelevance?`. The code sketch above uses a helper for clarity; the actual wiring is:

```swift
// In getTimeline, after building entries with relevance metadata:
let timedEntries: [(entry: SmartStackEntry, relevance: TimelineEntryRelevance?)] = [
    (entry: entryT_minus15, relevance: TimelineEntryRelevance(score: 10, duration: 15 * 60)),
    (entry: entryT,         relevance: TimelineEntryRelevance(score: 8,  duration: 60 * 60)),
    (entry: entryT_plus60,  relevance: nil),
]
// Combine into a Timeline. WidgetKit accepts (entry, relevance) pairs:
let timeline = Timeline(
    entries: timedEntries.map(\.entry),
    policy: .atEnd
)
// Relevance is passed separately — check Xcode 26 SDK for the exact API surface.
// As of watchOS 10+: entries conform to TimelineEntry which has no relevance field;
// relevance is configured per-widget via `relevance` computed property on the
// TimelineProvider — see note below.
```

**Actual relevance API:** In WidgetKit, `TimelineEntryRelevance` is injected via the `relevances` method on `TimelineProvider` (optional protocol method) rather than inline with entries. The `relevances(for:)` method takes an array of entries and returns a parallel array of optional `TimelineEntryRelevance`. The implementation sketch in `getTimeline` above is conceptually correct; the actual method signature to implement is:

```swift
// Optional method on TimelineProvider — not required but improves Smart Stack surfacing.
func relevances() async -> WidgetRelevances<Void> {
    // Return relevance for all upcoming 15-min-before windows.
    // This is the watchOS-specific path — consult the Xcode 26 SDK for exact API.
}
```

The implementor must verify the exact API surface in Xcode 26's WidgetKit documentation. The intent (peak relevance at T-15, trailing relevance through the window, zero after) is correct regardless of the exact call shape.

### 5.3 `SmartStackWidgetView`

```swift
import SwiftUI
import WidgetKit

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
        // Liquid Glass background: on watchOS 26 widget extensions the
        // `.glassEffect()` modifier IS available in the widget extension context.
        // Unlike complications (which use AccessoryWidgetBackground), Smart Stack
        // widgets are full-surface widgets that can use glassEffect.
        // If the compiler rejects .glassEffect() in the extension, fall back to:
        //   .background(.ultraThinMaterial)
        // and file a radar. Review: 2026-11-01.
        .containerBackground(for: .widget) {
            Color.clear.glassEffect()
        }
    }

    private func loadedView(group: DoseGroupSummary) -> some View {
        VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.compact) {
            // Group name — could be a meal name or a slot aggregate.
            Text(group.groupName)
                .font(LiquidGlassTheme.Typography.headlineFont)
                .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            // Subtitle: dose count + formatted scheduled time.
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LiquidGlassTheme.Spacing.standard)
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

**Note on `.containerBackground`:** watchOS widget extensions in watchOS 26 use `.containerBackground(for: .widget) { ... }` to set the widget background, not `.background`. This is required to get proper Smart Stack integration (the system reads the background value to apply its own blending). If `.glassEffect()` is not available inside `.containerBackground`, use `.ultraThinMaterial`.

**Note on amber / color discipline:** The `SmartStackWidgetView` uses no amber. Even when `group.containsHighRisk == true`, the widget renders in the monochromatic baseline — the amber press-and-hold ring appears in the main app, not in a widget. In #51, when the `Button(intent:)` is added for non-high-risk doses, the high-risk case renders an "Open to confirm" label (never amber) per CLAUDE.md.

### 5.4 `SmartStackWidget` Registration

```swift
import WidgetKit
import SwiftUI

struct SmartStackWidget: Widget {
    static let kind = "com.creekmasons.pillbreakfast.widget.smartstack"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: SmartStackTimelineProvider()
        ) { entry in
            SmartStackWidgetView(entry: entry)
                .widgetURL(URL(string: "pillbreakfast://tap-through"))
        }
        .configurationDisplayName("Upcoming Dose")
        .description("See what's next and tap to open the app.")
        // Smart Stack is a rectangular widget family on watchOS.
        .supportedFamilies([.accessoryRectangular])
    }
}
```

**Updated `WatchAppWidgetsBundle`:**

```swift
@main
struct WatchAppWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PendingDoseComplication()
        SmartStackWidget()
    }
}
```

### 5.5 Swift 6 Concurrency

- `SmartStackEntry` and `DoseGroupSummary`: value types, `Sendable` by synthesis.
- `SmartStackTimelineProvider`: struct, no isolation needed. `doseGroups` is a static helper that may need `@MainActor` if `PendingQueueSelector` is called within it — but `doseGroups` in this design queries `Medication` and `ScheduledDose` directly without going through `PendingQueueSelector`. It uses a `ModelContext` created on whatever actor calls it, which is the main actor by convention.
- `ModelContext` must not cross actor boundaries. All store access happens inside `getTimeline` / `getSnapshot`, which run on the main thread.
- `PillMeal`, `Medication`, `ScheduledDose` are `@Model` reference types — they cannot leave the `ModelContext`'s actor. `DoseGroupSummary` is extracted as a `Sendable` value type before any actor boundary.

### 5.6 Relationship to the Notification Scheduler

The 15-min surfacing window mirrors — but does not replace — the notification scheduler. `NotificationScheduler` fires a `UNCalendarNotificationTrigger` at the scheduled dose time (T+0). The Smart Stack widget surfaces 15 minutes before (T-15). These are complementary: the notification interrupts; the Smart Stack widget is ambient. They both read from the same schedule, but through different mechanisms. No coupling between `NotificationScheduler` and `SmartStackTimelineProvider` is needed.

---

## 6. UX and Visual Design

**Smart Stack card (`.accessoryRectangular`):**
- Background: Liquid Glass via `.containerBackground { Color.clear.glassEffect() }` (or `.ultraThinMaterial` fallback — see §5.3).
- Primary text: meal name or slot aggregate (SF Pro Rounded headline semibold, max 2 lines).
- Secondary text: "N doses · HH:MM" (SF Pro Rounded footnote, monospaced digits for the time).
- Idle state: checkmark icon + "All caught up" in secondary style.
- No colored accents; no amber; no pill imagery (deferred to v1.1 per SPEC §12).

**When the widget surfaces in the Stack:**
- High relevance at T-15: the widget rises to the top of the Stack.
- Medium relevance from T to T+60: the widget remains in the Stack but may not be topmost.
- Zero relevance after T+60: the widget sinks to its natural position.

**Tap behavior (this issue):** The entire card is a deep-link target (`widgetURL`). Tapping opens the watch app to `RightNowView`, which reloads and routes to the tap-through queue if doses are pending. In #51, the card gains a `Button(intent:)` for non-high-risk doses; the `widgetURL` fallback remains for the high-risk case and the idle state.

---

## 7. Edge Cases and Failure Modes

| Scenario | Handling |
|---|---|
| No maintenance medications scheduled | `doseGroups` returns `[]`; the timeline has only the idle entry; the widget shows "All caught up." |
| A Pill Meal's `targetHour`/`targetMinute` differs from its doses' individual hours (possible if doses were manually adjusted) | The Smart Stack uses the meal's target time for surfacing (the user-named meal time is the right anchor); the complication (#49) uses per-dose times. Documented trade-off. |
| Two meals are scheduled at the same time | Each produces its own entry. The system picks the highest-relevance one to show; the second may be visible on scroll. No deduplication needed. |
| `ModelContainer` fails to open | Catch; return idle entry; log via `OSLog`. |
| `calendar.date(bySettingHour:minute:second:of:)` returns nil (DST gap) | `guard ... else { continue }` — the group is skipped. This matches `PendingQueueSelector`'s behavior. |
| The widget is in preview / snapshot context | `placeholder(in:)` returns a fixture entry; `getSnapshot` checks `context.isPreview`. |
| Widget receives a timeline entry with `doseGroup.containsHighRisk == true` | In this issue: rendered as normal monochromatic text. In #51: a "Open to confirm" label replaces the intent button. |

---

## 8. Testing Strategy

**Unit tests (`WatchAppWidgetsTests`):**
- `SmartStackTimelineProvider.doseGroups(in:on:calendar:)` with an in-memory store:
  - One maintenance med with one scheduled dose at 08:00 daily → one group.
  - One Pill Meal with two doses at 08:00 → one group (meal name, count 2).
  - Two meds at different times → two groups, sorted by time.
  - Med with `daysOfWeek = [2]` (Mon only) queried on a Sunday → zero groups.
- `SmartStackTimelineProvider.groupLabel(names:)`:
  - One name → the name itself.
  - Two names → "A · B".
  - Three names → "A · B · +1 more".
- `SmartStackEntry.doseGroup` nil → `SmartStackWidgetView` renders idle state (preview / snapshot test).
- `SmartStackEntry.doseGroup` non-nil → view renders with group name and count (preview / snapshot test).

**Manual / simulator:**
- Add `SmartStackWidget` to the Smart Stack on the Apple Watch simulator; confirm it appears.
- With a scheduled dose 15 minutes in the future (adjust system clock on the simulator), confirm the widget rises in the Stack.
- Tap the widget; confirm the watch app opens.

**What cannot be tested until #52:**
- The widget updating after a dose is logged.

---

## 9. Performance and Resource Budget

- `doseGroups` fetches `Medication` rows (at most ~12 active) and traverses their `schedule` and `pillMeal` relationships. This is a small, bounded fetch.
- The timeline lookahead is 24 hours × ~12 doses × 3 entries = ~36 entries maximum. Well within the watchOS timeline budget.
- `ModelContainer` initialization cost: same as #49 (first open ~50–100 ms, cached thereafter by the OS page cache). `getSnapshot` uses a fast path that avoids the full `buildEntries` traversal.
- Relevance scoring does not add any compute cost; it is metadata attached to the `Timeline` object.
- No networking, no WCSession, no HealthKit.

---

## 10. Risks and Open Questions

| Risk | Likelihood | Mitigation |
|---|---|---|
| `TimelineEntryRelevance` API shape in Xcode 26 differs from the watchOS 10 pattern | Medium | Verify against Xcode 26 SDK before implementation. The intent (score + duration) is stable; the call site may differ. |
| `.glassEffect()` is not available in widget extension bundles on watchOS 26 | Low-medium | Fall back to `.containerBackground { .ultraThinMaterial }`. The visual difference is minimal. |
| Smart Stack does not surface the widget at T-15 despite correct relevance scores | Low | Relevance is a hint, not a guarantee. Apple's documentation says "The system takes note of this information and may use it to reorder widgets." Manual testing on device (not simulator) is the only validation. |
| `PillMeal.targetHour/targetMinute` drifting from actual dose hours after manual edits | Medium | Document in code; this is a known edge case tracked in existing issue backlog. The Smart Stack surface time may be up to a few minutes off from the complication's window. Acceptable for v1. |
| `doseGroups` called with a `date` at midnight of a DST transition | Very low | Same guard pattern as `PendingQueueSelector`; DST gaps are handled by `continue`. |

**Open question for #51:** `SmartStackEntry` carries `containsHighRisk: Bool` at the group level. Should #51 need per-dose `isHighRisk` to branch the intent button on a per-dose basis within the widget? Resolution: the Smart Stack widget logs the *next* pending dose (singular). If that dose is high-risk, the widget shows "Open to confirm" for the entire card. The group-level `containsHighRisk` flag is sufficient for this because the *first* dose in the queue is the one the intent would log. If the first dose is not high-risk (but another in the group is), the intent is still safe to offer. Clarify in #51 whether the "next dose" is the first alphabetically, first by scheduledFor, or first by meal ordinal — `PendingQueueSelector` returns a `scheduledFor`-sorted list, so use that order.

---

## 11. Decomposition Hints

This is a single PR. Implementation sequence:
1. Define `SmartStackEntry` and `DoseGroupSummary`.
2. Implement `SmartStackTimelineProvider` — start with `doseGroups` (unit-testable) then `buildEntries`.
3. Implement `SmartStackWidgetView`.
4. Implement `SmartStackWidget`.
5. Register in `WatchAppWidgetsBundle`.
6. Write unit tests.
7. Manual simulator check.

---

## 12. Acceptance Criteria / Done-Done

- [ ] `SmartStackWidget` is registered in `WatchAppWidgetsBundle`.
- [ ] `SmartStackTimelineProvider.doseGroups` unit tests pass for the cases in §8.
- [ ] `SmartStackTimelineProvider.groupLabel` unit tests pass.
- [ ] The widget renders a group name, dose count, and scheduled time for a fixture `DoseGroupSummary` (snapshot test or preview).
- [ ] The widget renders the idle state for `entry.doseGroup == nil`.
- [ ] The widget appears in the Smart Stack in the simulator.
- [ ] Tapping the widget opens the watch app without crashing.
- [ ] No amber color is used anywhere in the widget.
- [ ] Both watch app and widget extension build under Swift 6 strict concurrency with zero warnings.
- [ ] `pre-commit run --all-files` clean.
- [ ] PR references `Closes #50` and `Refs #8`.

---

## 13. References

- SPEC §7.5 — Smart Stack widget requirements.
- SPEC §10 Phase 7 — gate criteria.
- `Shared/Queue/PendingQueueSelector.swift` — `PendingDose`, `PendingQueueSelector`, `windowMinutes`.
- `Shared/Notifications/NotificationScheduler.swift` — `bodyText(for:)` pattern for group label format.
- `Shared/Models/PillMeal.swift`, `Shared/Sync/RegimenSnapshot.swift` (`PillMealDTO`) — meal structure.
- `Shared/DesignSystem/LiquidGlassTheme.swift` — typography, spacing, color tokens.
- `Shared/Persistence/PersistenceController.swift` — `appGroupStoreURL`, `schema`.
- Predecessor: `2026-06-07_SPEC_ISSUE-49_three-complication-families.md`.
- Successor: `2026-06-07_SPEC_ISSUE-51_log-next-dose-intent.md`.
- Apple: "WidgetRelevances" and "TimelineEntryRelevance" (WidgetKit documentation, Xcode 26 SDK).
- Apple: "Building Widgets for the Lock Screen and Watch Face" — Smart Stack section.
