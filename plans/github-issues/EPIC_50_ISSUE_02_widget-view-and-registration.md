## Role

You are a senior watchOS engineer building the visible surface of the Smart Stack widget: a Liquid Glass `.accessoryRectangular` card that renders the next dose group, an idle "All caught up" state, and the `SmartStackWidget` registration that puts it in the Smart Stack.

## Goal

Implement `SmartStackWidgetView` rendering the group name, "N doses · HH:MM" subtitle, and an idle state, with a Liquid Glass `.containerBackground(for: .widget)`. Implement `SmartStackWidget` (`.accessoryRectangular`, `widgetURL("pillbreakfast://tap-through")`) and register it in `WatchAppWidgetsBundle`. Tapping the card opens the watch app (no logging yet — that is #51).

## Context

- **Parent epic:** #50
- **Predecessor:** `EPIC_50_ISSUE_01_entry-and-provider` (`SmartStackEntry`, `DoseGroupSummary`, `SmartStackTimelineProvider` exist and are unit-tested).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-50_smart-stack-widget.md` §5.3 (view), §5.4 (registration + bundle), §6 (visual design), §8 (snapshot tests).
- **Files involved:**
  - `WatchAppWidgets/SmartStackWidgetView.swift` (new).
  - `WatchAppWidgets/SmartStackWidget.swift` (new).
  - `WatchAppWidgets/WatchAppWidgetsBundle.swift` — add `SmartStackWidget()` to the body.
  - Uses `Shared/DesignSystem/LiquidGlassTheme.swift` (typography, spacing, colors) — already in the extension's reach.
- **Prior decisions (locked):**
  - Liquid Glass via `.containerBackground(for: .widget) { Color.clear.glassEffect() }`. If the compiler rejects `.glassEffect()` in the extension, fall back to `.ultraThinMaterial` and add the documented 4-line escape-hatch comment with review date `2026-11-01`. Do not silently swallow.
  - **No amber, no custom color** — even when `containsHighRisk == true`, the card stays monochromatic. Amber is reserved for the main-app press-and-hold ring. Typography from `LiquidGlassTheme` only.
  - Subtitle uses `monospacedDigit()` for the time; pluralize "dose"/"doses".
  - Idle state: `checkmark.circle` + "All caught up" in secondary style.
  - The whole card is the `widgetURL` deep-link target; tapping opens `RightNowView` (the `Button(intent:)` arrives in #51 — leave room for it but do not add it).
  - Family is `.accessoryRectangular` (the Smart Stack family on watchOS).

## Output Format

A single PR containing:

- [ ] `SmartStackWidgetView` with a loaded layout (group name `headlineFont` 2-line, "N dose(s) · HH:MM" subtitle) and an idle layout.
- [ ] Liquid Glass `.containerBackground(for: .widget)` (with the documented fallback if needed).
- [ ] `SmartStackWidget` — `StaticConfiguration`, `.accessoryRectangular`, `widgetURL("pillbreakfast://tap-through")`, display name/description.
- [ ] `WatchAppWidgetsBundle` registers both `PendingDoseComplication()` and `SmartStackWidget()`.
- [ ] No amber / custom color anywhere; typography from `LiquidGlassTheme`.
- [ ] Snapshot/preview tests: loaded card with a fixture `DoseGroupSummary` (name + count + time) and the idle state for `doseGroup == nil`.

## Examples

```swift
struct SmartStackWidget: Widget {
    static let kind = "com.creekmasons.pillbreakfast.widget.smartstack"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SmartStackTimelineProvider()) { entry in
            SmartStackWidgetView(entry: entry)
                .widgetURL(URL(string: "pillbreakfast://tap-through"))
        }
        .configurationDisplayName("Upcoming Dose")
        .description("See what's next and tap to open the app.")
        .supportedFamilies([.accessoryRectangular])
    }
}
```

## Constraints

**Scope fence:** View + registration only. **No** `Button(intent:)` / `LogNextDoseIntent` / `NextDoseSpec` (#51), **no** background refresh (#52), **no** iOS widget. Do not change the provider's data path from child #01. Stay monochromatic.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The Smart Stack widget appears in the Smart Stack on the simulator, renders the next group (or "All caught up"), and tapping it opens the watch app without crashing. The complication and watch app still build and run on the paired simulator.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #50`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `edges`, `phase-7-widgets`, `watch`
