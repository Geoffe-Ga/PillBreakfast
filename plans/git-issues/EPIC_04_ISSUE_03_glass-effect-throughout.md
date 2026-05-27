## Role

You are a senior SwiftUI designer-engineer responsible for the visual cohesion of PillBreakfast. You know that consistent styling is not "more decoration" but the elimination of incidental variation.

## Goal

Apply `.glassBackground()` and the `LiquidGlassTheme` tokens across every primary watch screen (`RightNowView`, `TapThroughQueueView`, `MarkTakenView`, `QueueSuccessView`) and the iPhone Regimen tab (`RegimenListView`, `AddMedicationView`, `EditMedicationView`). Add the success-state shimmer animation per SPEC §9 ("confirm-and-advance uses a glass-shimmer + slide"). Verify color discipline: amber appears only on the EPIC_04_ISSUE_02 ring and the "Hold to confirm" hint; nowhere else.

## Context

- **Parent epic:** #4
- **Predecessor issue(s):** #EPIC_04_ISSUE_02_NUMBER (the gesture must be in place; we're styling around it).
- **SPEC section:** `plans/SPEC.md` §9 (Liquid Glass Design Language). §7.2 "animated transition to next screen. Final screen: success state with a glass shimmer."
- **Files updated:** all the views named in Goal.
- **Files new:** `Shared/DesignSystem/ShimmerModifier.swift` — the success shimmer.
- **Prior decisions (locked):**
  - Use the `Typography` helpers from EPIC_04_ISSUE_01 — no inline `.font(.title)` calls.
  - Negative space (SPEC §9 "lots of it"): the watch screen should look mostly empty. One name, one number, one button.
- **State of the world:** Watch tap-through has the high-risk gesture; default SwiftUI chrome everywhere else.

## Output Format

A single PR containing:

- [ ] All listed views wrapped in `.glassBackground()`.
- [ ] All inline `Text(...).font(...)` replaced with `Typography.medicationName(...)` / `Typography.dosage(...)` calls or the corresponding modifier.
- [ ] `ShimmerModifier` view modifier producing a brief glass-refraction shimmer; applied to `QueueSuccessView`'s success label.
- [ ] Page-style transitions on `TapThroughQueueView` updated to use a custom transition (slide + glass refraction). If the watchOS 26 system transition already provides this, document the API call and reference WWDC 2025 in a comment.
- [ ] Visual review: open Settings > Color Filters > inverted (or a screenshot diffing tool) and confirm no unexpected color leaks.

## Examples

`ShimmerModifier`:

```swift
public struct ShimmerModifier: ViewModifier {
    @State private var phase: Double = 0
    public func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: phase * 200 - 100)
                .blendMode(.plusLighter)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 0.9)) { phase = 1 }
            }
    }
}
public extension View { func shimmer() -> some View { modifier(ShimmerModifier()) } }
```

Visual checklist:

1. Watch root view, tap-through queue, success state all use a glass background.
2. iPhone Regimen tab list uses `.regularMaterial` or equivalent under the navigation.
3. Vitamin D row + tap-through screen show no color anywhere. Lithium tap-through shows the amber ring + hint only.

## Constraints

**Scope fence:** Don't style PRN UI — it doesn't exist yet (EPIC 05). Don't style notifications, complications, or the History tab — later epics.

**Color discipline check.** Audit every modifier you add. If a `.foregroundStyle(.blue)` or `.tint(.green)` slipped in, remove it. The PR review must include "color audit: no leaks."

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The app looks like a watchOS 26 native; no functional regression.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #4` and `Closes #EPIC_04_ISSUE_03_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-3-high-risk`, `design-system`.
