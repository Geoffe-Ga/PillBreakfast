## Role

You are a senior watchOS engineer who has shipped custom gesture recognizers before. You understand `LongPressGesture`, `DragGesture` cancellation semantics, and how to drive a `withAnimation` ring fill cleanly.

## Goal

Replace single-tap Mark Taken with **press-and-hold** for any `Medication` whose computed `isHighRisk == true`. The button shows a Liquid Glass progress ring that fills over the configured hold duration (default 0.5s). Releasing before completion animates the ring back to empty and writes no `DoseEvent`. Completing the hold writes the `DoseEvent` and advances. Non-high-risk meds keep the EPIC_03_ISSUE_03 single-tap behavior unchanged.

## Context

- **Parent epic:** #4
- **Predecessor issue(s):** #EPIC_04_ISSUE_01_NUMBER (design tokens).
- **SPEC section:** `plans/SPEC.md` §2.1 (Morning Maintenance lithium step), §7.2 (tap-through queue, high-risk subset), §9 (Liquid Glass press-and-hold ring).
- **Files involved:**
  - `WatchApp Watch App/TapThroughQueue/MarkTakenView.swift` — branch on `medication.isHighRisk`.
  - `WatchApp Watch App/TapThroughQueue/HighRiskConfirmButton.swift` (new) — the press-and-hold control with the ring.
  - `WatchApp Watch App/TapThroughQueue/SingleTapConfirmButton.swift` (new) — extracted from the existing `MarkTakenView`.
- **Files updated:** `WatchApp Watch App/TapThroughQueue/MarkTakenView.swift` — composes one or the other.
- **Prior decisions (locked):**
  - **Default hold duration: 0.5s** (SPEC §2.1). User-tweakable via Settings — that's EPIC_04_ISSUE_04. For this issue, the duration is hard-coded.
  - **No "tap to confirm" override for high-risk.** The user cannot bypass press-and-hold from the confirmation screen. They can still Skip via the Digital Crown long-press menu.
  - Haptic feedback: light haptic at 25%, 50%, 75% of the hold; success haptic on completion; cancel haptic on premature release.
  - The amber accent appears **only** on the ring stroke and the "Hold to confirm" hint label. The background remains monochromatic glass.
- **State of the world:** EPIC 03 ends with single-tap confirm for every med, including high-risk. The stub Lithium gets logged on a single tap, which is the bug this issue fixes.

## Output Format

A single PR containing:

- [ ] `HighRiskConfirmButton` rendering a ring that fills via `LongPressGesture(minimumDuration: holdDuration)` + a `@State` progress driver.
- [ ] Premature release detection via a `DragGesture(minimumDistance: 0)` paired with `.simultaneousGesture`, or whichever pattern reliably distinguishes "user lifted finger" from "gesture completed."
- [ ] Haptic calls at the four checkpoints.
- [ ] `MarkTakenView` branches: `if medication.isHighRisk { HighRiskConfirmButton(...) } else { SingleTapConfirmButton(...) }`.
- [ ] Unit tests on the progress-driver state machine (pure logic; the SwiftUI gesture itself is best covered by snapshot tests in EPIC_04_ISSUE_05). At minimum: progress hits 1.0 only after `holdDuration` elapses; releasing mid-hold transitions to "cancelled" with progress = 0.
- [ ] Manual checklist: stub Lithium can no longer be logged with a tap; a 0.5s hold completes the log; lifting at 0.3s does nothing.

## Examples

State machine outline:

```swift
@MainActor
@Observable
final class HoldProgress {
    enum State: Equatable {
        case idle
        case holding(startedAt: Date)
        case completed
        case cancelled
    }
    private(set) var state: State = .idle
    let holdDuration: TimeInterval

    init(holdDuration: TimeInterval) { self.holdDuration = holdDuration }

    func begin(at now: Date) { state = .holding(startedAt: now) }
    func release(at now: Date) {
        if case .holding(let started) = state, now.timeIntervalSince(started) >= holdDuration {
            state = .completed
        } else {
            state = .cancelled
        }
    }
    func progress(at now: Date) -> Double {
        guard case .holding(let started) = state else { return state == .completed ? 1 : 0 }
        return min(1, now.timeIntervalSince(started) / holdDuration)
    }
}
```

## Constraints

**Scope fence:** Do not change non-high-risk behavior. Do not add the gesture-duration setting — EPIC_04_ISSUE_04. Do not apply glass styling beyond what's needed on the ring itself — EPIC_04_ISSUE_03 does the broader pass.

**Single-tap on a high-risk med is a regression.** Any code path that lets a high-risk dose be logged without a completed hold must be rejected, including a "I'm sure" override on the confirmation screen.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The watch tap-through queue still completes for non-high-risk meds (single-tap), and now requires a 0.5s hold for high-risk meds. `DoseEvent`s still flow to iPhone.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair; the manual checklist completes.
- [ ] PR opened with `Refs #4` and `Closes #EPIC_04_ISSUE_02_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-3-high-risk`.
