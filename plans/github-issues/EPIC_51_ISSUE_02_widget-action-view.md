## Role

You are a senior watchOS engineer wiring the Smart Stack widget's action surface to the `LogNextDoseIntent`: a single-tap log button for non-high-risk groups, and a plain "Open to confirm" affordance for high-risk groups that routes to the main app's press-and-hold confirm.

## Goal

Add `actionView(for:)` to `SmartStackWidgetView` that renders `Button(intent: LogNextDoseIntent(...))` when `group.nextNonHighRiskDose != nil`, and a static "Open to confirm" label otherwise. Add `makeIntent(spec:)` to construct the parameterized intent. Tapping the button logs the dose in-process; tapping elsewhere on the card fires the existing `widgetURL`.

## Context

- **Parent epic:** #51
- **Predecessor:** `EPIC_51_ISSUE_01_intent-and-spec` (`LogNextDoseIntent`, `NextDoseSpec`, `DoseGroupSummary.nextNonHighRiskDose` exist and are unit-tested).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-51_log-next-dose-intent.md` §5.4 (updated `SmartStackWidgetView`), §6 (UX / color discipline), §8 (preview/snapshot tests + manual checklist).
- **Files involved:**
  - `WatchAppWidgets/SmartStackWidgetView.swift` — add `actionView(for:)` and `makeIntent(spec:)`.
- **Prior decisions (locked):**
  - Non-high-risk → `Button(intent:)` labeled "Log <medicationName>" with `checkmark.circle.fill`, `.buttonStyle(.plain)`. High-risk-only group (`nextNonHighRiskDose == nil`) → a non-interactive `Label("Open to confirm", systemImage: "hand.point.up.left")`; the card's existing `widgetURL` carries the tap to the app's press-and-hold screen.
  - **No amber, no custom color** — the "Open to confirm" label is deliberately plain (no warning icon, no amber). Amber stays in the main-app press-and-hold ring. Typography from `LiquidGlassTheme`.
  - `Button(intent:)` and `widgetURL` coexist per the standard WidgetKit interactive-widget model: button tap fires the intent, card tap fires the deep-link. Confirm this holds on watchOS 26 Smart Stack in Xcode 26.
  - The button logs the *first* pending non-high-risk dose in the group (carried by `NextDoseSpec`); mixed groups log that dose and leave any high-risk dose for the app queue.

## Output Format

A single PR containing:

- [ ] `SmartStackWidgetView.actionView(for:)` — `@ViewBuilder` branching on `group.nextNonHighRiskDose`.
- [ ] `makeIntent(spec:)` constructing `LogNextDoseIntent` with `medicationIDString` / `scheduledFor` / `quantity` from the `NextDoseSpec`.
- [ ] The loaded card composes name + subtitle + `actionView(for:)`; the idle state is unchanged.
- [ ] No amber / custom color; typography from `LiquidGlassTheme`.
- [ ] Preview/snapshot tests: a non-high-risk `DoseGroupSummary` renders `Button(intent:)`; a high-risk-only `DoseGroupSummary` renders "Open to confirm".
- [ ] PR description records the manual checklist result: add a non-high-risk maintenance med scheduled ~15 min out → Smart Stack surfaces → tap the button → dose recorded without opening the app → complication decrements → widget no longer offers that dose.

## Examples

```swift
@ViewBuilder
private func actionView(for group: DoseGroupSummary) -> some View {
    if let spec = group.nextNonHighRiskDose {
        Button(intent: makeIntent(spec: spec)) {
            Label("Log \(spec.medicationName)", systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(.plain)
    } else {
        Label("Open to confirm", systemImage: "hand.point.up.left")
    }
}
```

## Constraints

**Scope fence:** Widget action view only. **No** changes to the intent's behavior (child #01), **no** background refresh / app-side reload (#52). Do not add amber. Do not present the log button for high-risk groups.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** On the simulator, a non-high-risk Smart Stack card shows the log button and a single tap records the dose without opening the app; a high-risk card shows "Open to confirm" and routes to the app. The complication, widget, and watch app all still build and run on the paired simulator.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #51`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `edges`, `phase-7-widgets`, `watch`
