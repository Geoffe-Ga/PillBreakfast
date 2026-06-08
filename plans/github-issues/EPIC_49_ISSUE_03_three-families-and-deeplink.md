## Role

You are a senior watchOS engineer completing the complication: implementing the circular, corner, and inline family views, registering all three on one `Widget`, and wiring the `pillbreakfast://tap-through` deep-link end-to-end so tapping any family opens the watch app's tap-through queue.

## Goal

Add `CircularComplicationView`, `CornerComplicationView`, `InlineComplicationView` and a `ComplicationRouter` that switches on `@Environment(\.widgetFamily)`. Register `[.accessoryCircular, .accessoryCorner, .accessoryInline]` on `PendingDoseComplication` with `widgetURL("pillbreakfast://tap-through")`. Declare the `pillbreakfast` URL scheme in the watch app `Info.plist` and add an `onOpenURL` handler so the deep-link routes without crashing.

## Context

- **Parent epic:** #49
- **Predecessor:** `EPIC_49_ISSUE_02_real-timeline-provider` (the provider reads the live count and builds the transition timeline; only `.accessoryCircular` is registered).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-49_three-complication-families.md` §5.3 (family views), §5.4 (router + registration), §5.5 (deep-link routing), §6 (visual design / color discipline), §8 (snapshot tests).
- **Files involved:**
  - `WatchAppWidgets/Variants/CircularComplicationView.swift`, `CornerComplicationView.swift`, `InlineComplicationView.swift` (new).
  - `WatchAppWidgets/PendingDoseComplication.swift` — add `ComplicationRouter`, register all three families.
  - `PillBreakfast Watch App Watch App/RootView/RightNowView.swift` and/or `PillBreakfast_Watch_App_Watch_AppApp` — add `onOpenURL`.
  - Watch app `Info.plist` — add `CFBundleURLTypes` with `CFBundleURLSchemes = ["pillbreakfast"]`.
- **Prior decisions (locked):**
  - One `Widget` with multiple families via a `ComplicationRouter` switching on `widgetFamily` — not three separate `Widget` types (single picker entry). If Xcode 26 surfaces duplicates, fall back to separate `kind` strings.
  - **Color discipline:** no amber, no custom colors. Use `widgetAccentable()` so the system applies the *watch-face* accent, never the app's amber (amber is reserved for the main-app press-and-hold ring). The complication conveys a count, not risk.
  - Complications use `AccessoryWidgetBackground()` — `.glassEffect()` is a main-app API, not available in the extension.
  - Corner: `pills.fill` / `checkmark` image + `.widgetLabel` short text (< 6 chars). Inline: `Label("N pending", …)` / `Label("All clear", …)`.
  - The URL scheme must be declared in `Info.plist` or the system won't route the deep-link. The `onOpenURL` handler guards `scheme == "pillbreakfast" && host == "tap-through"`; bringing the app foreground is sufficient (`RightNowView` already shows the queue when doses are pending).

## Output Format

A single PR containing:

- [ ] `CircularComplicationView`, `CornerComplicationView`, `InlineComplicationView` rendering `entry.displayText` / pending-aware labels, all `widgetAccentable()`, no color.
- [ ] `ComplicationRouter` switching on `@Environment(\.widgetFamily)` with a circular fallback for `default`.
- [ ] `PendingDoseComplication` registers `[.accessoryCircular, .accessoryCorner, .accessoryInline]` and sets `widgetURL(URL(string: "pillbreakfast://tap-through"))`.
- [ ] `CFBundleURLTypes` with the `pillbreakfast` scheme declared in the watch app `Info.plist`.
- [ ] `onOpenURL` handler in the watch app that guards the scheme/host and does not crash.
- [ ] Snapshot/preview tests: one preview per family with `pendingCount: 2`, one per family with `pendingCount: 0` (`"✓"` state).

## Examples

```swift
private struct ComplicationRouter: View {
    @Environment(\.widgetFamily) private var family
    let entry: PendingDoseEntry
    var body: some View {
        switch family {
        case .accessoryCircular: CircularComplicationView(entry: entry)
        case .accessoryCorner:   CornerComplicationView(entry: entry)
        case .accessoryInline:   InlineComplicationView(entry: entry)
        default:                 CircularComplicationView(entry: entry)
        }
    }
}
```

## Constraints

**Scope fence:** The three families + router + deep-link wiring only. **No** Smart Stack widget (#50), **no** AppIntent / interactive button (#51), **no** background refresh (#52). Do not introduce any color or amber accent. Do not change the provider's data path from child #02.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** All three families render on a watch face in the simulator; they show the live count and `"✓"` when clear. Tapping any family opens the watch app and lands on `RightNowView` without crashing. The watch app and extension still build and run on the paired simulator.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #49`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `edges`, `phase-7-widgets`, `watch`
