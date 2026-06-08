# Epic — #51: LogNextDoseIntent for single-tap logging from the Smart Stack

## Epic Summary

Implement `LogNextDoseIntent: AppIntent` so a single tap on the Smart Stack widget logs the next pending **non-high-risk** maintenance dose without opening the watch app, then reloads widget timelines. High-risk doses (any medication with `isHighRisk == true`) are explicitly barred from single-tap logging — the widget shows an "Open to confirm" deep-link instead, preserving the main app's press-and-hold safety guarantee. The intent itself also refuses high-risk doses as defense-in-depth.

## Scope

- Extend `DoseGroupSummary` with `nextNonHighRiskDose: NextDoseSpec?` and populate it in `SmartStackTimelineProvider.doseGroups` (the first `scheduledFor`-sorted non-high-risk pending dose in the group).
- Implement `LogNextDoseIntent` (`@MainActor perform()`) + `LogIntentError` in `Shared/Intents/LogNextDoseIntent.swift`, added to the `WatchAppWidgets` target membership (NOT the iOS target).
- The intent re-verifies the dose is still pending, refuses high-risk (`LogIntentError.highRiskForbidden`), runs `SafetyEvaluator` as a best-effort warning (no interstitial in widget context), writes via `DoseEventWriter.writeDoseEvent(...)`, and calls `WidgetCenter.shared.reloadAllTimelines()`.
- Update `SmartStackWidgetView` to branch: non-high-risk → `Button(intent:)`; high-risk-only → "Open to confirm" label.

## Success Criteria

- `perform()` logs a `DoseEvent` (`status == .taken`, `loggedOn == .watch`) for a non-high-risk fixture and calls `reloadAllTimelines()` — unit-tested.
- `perform()` throws `LogIntentError.highRiskForbidden` for a high-risk dose — unit-tested.
- Already-logged dose → `perform()` returns `.result()` without a second write — unit-tested.
- `SmartStackWidgetView` renders `Button(intent:)` when `nextNonHighRiskDose != nil`, else "Open to confirm" — preview/snapshot tests.
- No amber anywhere in the widget.
- Both watch app and extension build under Swift 6 strict concurrency with zero warnings; `pre-commit run --all-files` clean.

## Child Issues

- [ ] **Core** — `EPIC_51_ISSUE_01_intent-and-spec.md`: `NextDoseSpec`, `DoseGroupSummary.nextNonHighRiskDose` population, `LogNextDoseIntent` + `LogIntentError`, target membership, intent unit tests.
- [ ] **Edges** — `EPIC_51_ISSUE_02_widget-action-view.md`: `SmartStackWidgetView.actionView(for:)` branching (`Button(intent:)` vs "Open to confirm"), `makeIntent`, preview/snapshot tests, manual checklist.

## Sequencing Notes

Children are ordered: intent + spec (data + behavior, fully unit-testable) → widget action view (surface). Each child's Context names its predecessor. The epic is a child of phase-epic **#8**, the successor of **#50** (it extends `DoseGroupSummary` and `doseGroups` additively), and the predecessor of **#52**, which adds the app-side reload debouncer and background refresh.

**Safety note (CLAUDE.md, locked):** the single-tap intent must NEVER one-tap-log a high-risk med — it opens the press-and-hold confirm path instead. Verify `Shared/Safety/Violation.swift` is `Sendable` (needed for `LogIntentError.safetyViolation`); if not, conform it or drop that case (v1 logs-and-proceeds anyway). Confirm `@MainActor perform()` is accepted by the Xcode 26 AppIntents SDK; if rejected, restructure `DoseEventWriter` to accept a non-shared `ModelContext` rather than adding any concurrency bypass.

## SPEC Reference

`plans/2026-06-07_SPEC_ISSUE-51_log-next-dose-intent.md` (full design). SPEC §7.2 / §7.4 / §7.5, CLAUDE.md "High-risk = press-and-hold".

## Labels

`spec-decomposition`, `core`, `phase-7-widgets`, `watch`, `concurrency`
