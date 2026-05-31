## Role

You are a senior watchOS engineer making the tap-through queue, PRN list, and snooze flow feel like the surfaces of a finished product — not "an MVP that works."

## Goal

Apply the new design tokens (#158) across every watch surface so the wrist-side flow has a coherent typography rhythm, deliberate elevation hierarchy, and named motion. Polish covers: hero treatment for the current dose card, deliberate spacing pacing, refined success and empty states, micro-motion on confirm gestures (within the press-and-hold safety contract).

## Context

- **Parent epic:** #10 (Phase 9 — Hardening & TestFlight Submission).
- **Predecessor issue:** #158 (design token expansion — required before this work picks up tokens).
- **SPEC sections:** §6.1 (watch surfaces), §9 (visual design).
- **Files involved:**
  - `PillBreakfast Watch App Watch App/TapThroughQueue/TapThroughQueueView.swift` — hero card visual hierarchy, motion on advance.
  - `…/TapThroughQueue/SingleTapConfirmButton.swift`, `HighRiskConfirmButton.swift`, `HoldProgress.swift` — refine button shape via `CornerRadius.standard`, motion on tap via `Motion.snappy`, **press-and-hold ring polish stays inside the existing amber-on-progress contract**.
  - `…/TapThroughQueue/QueueSuccessView.swift` — promote "All caught up" to `displayFont`, add `Motion.dramatic` reveal.
  - `…/TapThroughQueue/MarkTakenView.swift` — copy hierarchy, secondary text treatment.
  - `…/PRNSection/PRNListView.swift`, `PRNRowView.swift`, `PRNQuantityPickerView.swift`, `SafetyWarningView.swift` — list visual rhythm, row elevation, picker treatment, safety warning treatment within the existing amber-on-high-risk rule.
  - `…/SnoozeView/SnoozeView.swift`, `SnoozeWarningView.swift` — typography hierarchy on the warning copy.
  - `…/RootView/RightNowView.swift` — landing state visual treatment.

## Output Format

A single PR containing:

- [ ] **Hero card** on `TapThroughQueueView`: medication name renders in `displayFont`, supporting dosage in `dosageFont`, card wraps in `.glassBackground()` + `CornerRadius.card` + `.elevation(.raised)`.
- [ ] **Confirm motion**: `Motion.snappy` on `SingleTapConfirmButton`/`HighRiskConfirmButton` press and on the queue's advance-to-next-dose transition.
- [ ] **Success state polish**: `QueueSuccessView` uses `displayFont` for "All caught up", a soft `Motion.dramatic` reveal, and an SF Symbol hero (`checkmark.seal.fill` or similar) at large size — monochromatic only.
- [ ] **PRN list rhythm**: `PRNRowView` row visual hierarchy — product name in `medicationNameFont`, secondary line in `captionFont`/`footnoteFont`, `.elevation(.raised)` per row, consistent `Spacing.standard` padding.
- [ ] **Safety warning treatment**: `SafetyWarningView` lifts to `headlineFont` for the headline and keeps the amber accent — within the existing high-risk color rule.
- [ ] **Snooze warning hierarchy**: title in `displayFont`, body in `footnoteFont`, buttons use `CornerRadius.standard`.
- [ ] No new colors. No new strings beyond what tokens compose. Press-and-hold gesture timing and threshold are unchanged.

## Constraints

**Scope fence:** Watch surfaces only. **No** iPhone changes. **No** new sound or haptic — those can stack as a separate motion-and-feel issue if Geoff wants them.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Tap-through flow still confirms a dose end-to-end on the paired simulator. Press-and-hold for high-risk meds still requires the existing gesture timing. PRN quantity picker still surfaces safety warnings.

## Definition of Done (stay-green)

- [ ] All existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair; the watch flow visibly uses the new typography/elevation/motion tokens.
- [ ] PR opened with `Refs #10` and `Closes #<this issue>`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`.
