# Epic — #50: Smart Stack widget surfacing 15 min before scheduled doses

## Epic Summary

Add a `SmartStackWidget` to the `WatchAppWidgets` extension that surfaces automatically in the Apple Watch Smart Stack ~15 minutes before each scheduled dose group. Each entry shows the next dose group's name (Pill Meal name or a time-slot aggregate label), the dose count, and the scheduled time, with a Liquid Glass background and a `pillbreakfast://tap-through` deep-link. Relevance scoring drives the surfacing. The widget does NOT log doses — single-tap logging is #51.

## Scope

- `SmartStackEntry: TimelineEntry, Sendable` carrying an optional `DoseGroupSummary` (group name, dose count, scheduled time, `containsHighRisk`).
- `SmartStackTimelineProvider` building a 24h timeline (three entries per group: T−15, T, T+60) with `TimelineEntryRelevance` peaking at T−15, plus a graceful idle (`doseGroup: nil`) state.
- `doseGroups(in:on:calendar:)` grouping by Pill Meal first, then time slot, with the `groupLabel` aggregator.
- `SmartStackWidgetView` (`.accessoryRectangular`) with Liquid Glass background and `LiquidGlassTheme` typography; idle "All caught up" state.
- Register `SmartStackWidget` in `WatchAppWidgetsBundle`.

## Success Criteria

- `doseGroups` returns correct groups (Pill Meal grouping, time-slot aggregation, `daysOfWeek` filtering, time-sorted) — unit-tested.
- `groupLabel` formats 1/2/3+ names correctly ("A", "A · B", "A · B · +1 more").
- The widget renders group name + count + time for a fixture, and the idle state for `doseGroup == nil`.
- The widget appears in the Smart Stack in the simulator and rises near T−15; tapping opens the watch app.
- No amber / no custom color anywhere in the widget.
- Both watch app and extension build under Swift 6 strict concurrency with zero warnings; `pre-commit run --all-files` clean.

## Child Issues

- [ ] **Skeleton + Core** — `EPIC_50_ISSUE_01_entry-and-provider.md`: `SmartStackEntry`, `DoseGroupSummary`, `SmartStackTimelineProvider` with `doseGroups`, `groupLabel`, `buildEntries`, and relevance scoring. Unit-testable, no view yet.
- [ ] **Edges** — `EPIC_50_ISSUE_02_widget-view-and-registration.md`: `SmartStackWidgetView` (loaded + idle), Liquid Glass background, `SmartStackWidget` registration in the bundle, snapshot/preview tests, simulator surfacing check.

## Sequencing Notes

Children are ordered: entry+provider (data, fully unit-testable) → view+registration (surface). Each child's Context names its predecessor. The epic is a child of phase-epic **#8**, the successor of **#49** (it reuses the extension's `Shared/` membership and deep-link), and the predecessor of **#51**, which adds `NextDoseSpec` to `DoseGroupSummary` and the `Button(intent:)`.

## SPEC Reference

`plans/2026-06-07_SPEC_ISSUE-50_smart-stack-widget.md` (full design). SPEC §7.5 (Smart Stack widget), SPEC §10 Phase 7 gate.

## Labels

`spec-decomposition`, `core`, `phase-7-widgets`, `watch`, `concurrency`
