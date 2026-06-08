## Role

You are a senior watchOS test engineer completing the golden-snapshot coverage for PillBreakfast's tap-through surface. The skeleton already proved the pipeline with one scene; you add the remaining six, including the safety-critical press-and-hold ring states and the success-view shimmer/empty states.

## Goal

`TapThroughSnapshotTests.swift` covers all 7 scenes from the spec. The high-risk ring is pinned at idle (0%), mid-hold (50%), and completed (100%); the non-high-risk meal-header path is pinned; `QueueSuccessView` is pinned pre-shimmer, shimmer-armed, and under Reduce Motion. Every golden PNG is committed, every assertion runs `record: false` at `precision: 0.98`, and no test relies on `Task.sleep` or live `TimelineView` timing.

## Context

- **Parent epic:** #31 (child of phase-epic #4 — Phase 3).
- **Predecessors:** EPIC_31_ISSUE_01 (snapshot harness skeleton) — the library, fixture, and Scene 1 must already be in place and green.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-31_tap-through-snapshot-tests.md` §5.5 (deterministic Liquid Glass), §6 Scenes 2–7, §7 (edge cases / determinism: `TimelineView`, `Task.sleep`, Reduce Motion, color scheme).
- **Files involved:**
  - `PillBreakfast Watch App Watch AppTests/Snapshots/TapThroughSnapshotTests.swift` (extend).
  - `PillBreakfast Watch App Watch AppTests/Snapshots/__Snapshots__/TapThroughSnapshotTests/` (six new PNGs).
  - `PillBreakfast Watch App Watch App/TapThroughQueue/MarkTakenView.swift`, `HighRiskConfirmButton.swift`, `HoldProgress.swift`, `SingleTapConfirmButton.swift`, `QueueSuccessView.swift`.
  - `Shared/DesignSystem/ShimmerModifier.swift`, `Shared/DesignSystem/View+GlassBackground.swift`.
- **Prior decisions (locked):**
  - **Mid-hold ring (Scene 4) cannot use live `TimelineView`.** Freeze it by injecting a pre-configured `HoldProgress` into `HighRiskConfirmButton` via a `@testable` initializer, or extract a pure `RingView(progress: Double)` sub-view and snapshot it at 0.5. Prefer the pure-view extraction; it is the only sanctioned "production touch" and must not change runtime behavior.
  - **`QueueSuccessView` states are pinned by parameter, not timing.** Expose `didAppear` / `shimmerArmed` via a `@testable` init using `_didAppear = State(initialValue:)` / `_shimmerArmed = State(initialValue:)`. The snapshot captures the frame before any `withAnimation` / `Task.sleep` fires.
  - Reduce Motion variant: set `\.accessibilityReduceMotion = true` in the environment; assert content is visible from frame 0 and the shimmer is suppressed.
  - Same fixture as the skeleton: Series 11 46mm, `en_US`, `America/New_York`, `precision: 0.98`, `record: false`.

## Output Format

A single PR adding the remaining scenes:

- [ ] Scene 2 — `MarkTakenView` non-high-risk with `mealHeader: "Pill Breakfast · 1 of 3"` (caption path).
- [ ] Scene 3 — `MarkTakenView` high-risk idle (`medicationName: "Lithium 300mg"`, `detail: "300mg · 1 tablet"`, `isHighRisk: true`, `colorHex: "#FFAA00"`); ring empty, amber accent, "Hold to confirm" hint.
- [ ] Scene 4 — high-risk mid-hold, ring at 50% via injected `HoldProgress` / extracted `RingView`; assert amber arc ≈ half circle, round line cap, -90° rotation, background ring at 25% opacity.
- [ ] Scene 5 — high-risk completed, ring at 100% (`HoldProgress` in `.completed`).
- [ ] Scene 6 — `QueueSuccessView` pre-shimmer (`didAppear = true`, `shimmerArmed = false`); checkmark seal at full opacity, "All pills logged" label, no shimmer band.
- [ ] Scene 7 — `QueueSuccessView` shimmer-armed (`shimmerArmed = true`); band at phase 0 (off-screen left).
- [ ] Reduce-Motion variant of `QueueSuccessView` (`\.accessibilityReduceMotion = true`).
- [ ] All new golden PNGs committed (non-blank); each test carries a comment naming the state and its mutant-killing purpose.

## Examples

Follow the skeleton's `assertSnapshot` shape and the comment density of `HoldProgressTests.swift`. State injection example:

```swift
// Freeze the ring mid-hold without the live TimelineView clock.
let progress = HoldProgress(holdDuration: 0.5)
progress.begin(at: Date(timeIntervalSince1970: 0))
let ring = RingView(progress: progress.progress(at: Date(timeIntervalSince1970: 0.25)))  // 0.5
```

## Constraints

**Scope fence:** Scenes only. Do **not** create the PR template or touch CI (that is the polish child). The only permitted production edit is extracting a pure `RingView` and/or adding `@testable` initializers that do not alter runtime behavior; if a larger production change seems required, stop and note it on the PR rather than reworking the confirm flow.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** After this PR the watch scheme builds and the full watch test suite passes with all 7 scenes green on `record: false`; the app behaves identically at runtime (any extracted `RingView` is a drop-in for the existing inline ring).

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #31`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `tests`, `core`, `phase-3-high-risk`, `design-system`, `watch`
