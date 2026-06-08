## Role

You are a senior watchOS engineer building the data layer for the Smart Stack widget: the `SmartStackEntry`/`DoseGroupSummary` value types and the `SmartStackTimelineProvider` that groups the day's scheduled doses and emits a relevance-scored 24-hour timeline. No view in this issue — everything here is unit-testable.

## Goal

Implement `SmartStackEntry: TimelineEntry, Sendable` and `DoseGroupSummary: Sendable, Hashable`, plus `SmartStackTimelineProvider` with: `doseGroups(in:on:calendar:)` (group by Pill Meal first, then by time slot), `groupLabel(names:)`, `buildEntries(lookahead:)` (three entries per group — T−15 / T / T+60 — plus an idle entry), and `TimelineEntryRelevance` peaking at T−15. The provider reads the shared store read-only via its own `ModelContainer`.

## Context

- **Parent epic:** #50
- **Predecessor:** #49 (the `WatchAppWidgets` extension reads the shared store; `Shared/` model + `PendingQueueSelector` membership and the `makeContext()` pattern exist; deep-link is wired).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-50_smart-stack-widget.md` §5.1 (entry types), §5.2 (provider, `doseGroups`, `groupLabel`, relevance), §5.5 (concurrency), §7 (edge cases), §9 (budget).
- **Files involved:**
  - `WatchAppWidgets/SmartStackTimelineProvider.swift` (new) — entry types, provider, helpers.
- **Prior decisions (locked):**
  - Open the store read-only via the same `makeContext()` pattern as #49 (`PersistenceController.appGroupStoreURL` + `.schema`) — never `PersistenceController.shared`, never the seeder, never `context.save()`.
  - Group by Pill Meal (keyed on `meal.id`, using `meal.targetHour/targetMinute` as the scheduled anchor), falling back to a `TimeSlotKey(hour:minute:)` aggregate for ungrouped doses.
  - Only non-archived `.maintenance` meds; honor `daysOfWeek`; guard DST `nil` from `date(bySettingHour:...)` with `continue`.
  - `groupLabel`: ≤2 names → joined with " · "; 3+ → first two + " · +N more" (mirrors `NotificationScheduler.bodyText(for:)` for visual consistency).
  - Relevance intent (stable regardless of exact Xcode 26 API shape): T−15 → `score 10, duration 15·60`; T → `score 8, duration 60·60`; T+60 → idle (`doseGroup: nil`, no relevance). Verify the exact `TimelineEntryRelevance` / `WidgetRelevances` surface in the Xcode 26 SDK; do not invent an API — match the SDK.
  - `@Model` reference types (`Medication`, `ScheduledDose`, `PillMeal`) must never leave the `ModelContext`'s actor — extract `DoseGroupSummary` value types before any boundary.

## Output Format

A single PR containing:

- [ ] `SmartStackEntry: TimelineEntry, Sendable` with `date` and optional `doseGroup`.
- [ ] `DoseGroupSummary: Sendable, Hashable` with `groupName`, `doseCount`, `scheduledAt`, `containsHighRisk`.
- [ ] `SmartStackTimelineProvider` with `placeholder`/`getSnapshot` (`context.isPreview` fast path)/`getTimeline` (`.atEnd`, idle-entry fallback).
- [ ] `doseGroups(in:on:calendar:)` — Pill Meal + time-slot grouping, time-sorted; `groupLabel(names:)` aggregator.
- [ ] `buildEntries(lookahead:)` — three entries per group with relevance metadata, idle entries after each window, never empty.
- [ ] Tests (`WatchAppWidgetsTests`, in-memory store): one maintenance dose at 08:00 → one group; one Pill Meal with two doses → one group (count 2, meal name); two meds at different times → two sorted groups; a `daysOfWeek = [2]` med queried on a Sunday → zero groups; `groupLabel` for 1/2/3 names.

## Examples

```swift
struct DoseGroupSummary: Sendable, Hashable {
    let groupName: String
    let doseCount: Int
    let scheduledAt: Date
    let containsHighRisk: Bool
}
```

## Constraints

**Scope fence:** Entry types + provider + grouping/relevance only. **No** `SmartStackWidgetView`, **no** `SmartStackWidget` registration (that is the view child #02), **no** `Button(intent:)` / `NextDoseSpec` (#51). Do not modify the complication or its provider.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The watch app, extension, and complication all still build and run on the paired simulator. The new provider is fully exercised by unit tests; the existing complication is untouched.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #50`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `core`, `phase-7-widgets`, `watch`, `concurrency`
