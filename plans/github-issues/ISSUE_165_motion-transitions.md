## Role

You are a senior SwiftUI engineer adding the deliberate motion that turns a finished-looking app into a finished-feeling one.

## Goal

Apply matched geometry effects, presentation transitions, and named motion tokens (#158) across the high-traffic flows so navigation feels intentional instead of stock. Focus areas: tap-through dose advance on watch, sheet/push transitions on iPhone, success-state celebrations. Stay within the Liquid Glass aesthetic — motion should feel like physical glass settling, not "animated."

## Context

- **Parent epic:** #10 (Phase 9 — Hardening & TestFlight Submission).
- **Predecessor issues:** #158 (tokens), #159 (watch), #160 (regimen) — motion is the last layer over a settled visual baseline.
- **SPEC sections:** §9.
- **Files involved:**
  - `PillBreakfast Watch App Watch App/TapThroughQueue/TapThroughQueueView.swift` — matched geometry on the dose card as it advances.
  - `PillBreakfast Watch App Watch App/TapThroughQueue/QueueSuccessView.swift` — celebration motion (within the existing color rule).
  - `PillBreakfast/RegimenTab/RegimenListView.swift`, `MedicationFormView.swift` — sheet presentation transition.
  - `PillBreakfast/HistoryTab/HistoryTabView.swift`, `DayDrillDownView.swift` — push transition with `matchedGeometryEffect` on the day cell → drill-down hero.
  - `PillBreakfast/HealthKitImport/HealthKitImportSheet.swift` — step-to-step transition.

## Output Format

A single PR containing:

- [ ] **Watch tap-through advance**: matched geometry on the hero card from the dismissed dose to the next dose; `Motion.snappy` on advance, `Motion.gentle` on the dismissal of the resolved dose.
- [ ] **Watch success state**: `Motion.dramatic` reveal on "All caught up" — symbol scales in, copy fades in beneath it.
- [ ] **iPhone history drill-down**: matched geometry on the tapped heatmap cell expanding into the drill-down's day header — date stamp scales smoothly into the destination.
- [ ] **iPhone Regimen sheet presentation**: `.presentationDetents` if the form is short; `.transition(.move(edge: .bottom).combined(with: .opacity))` as the underlying transition, using `Motion.gentle`.
- [ ] **HealthKit step transitions**: `.transition` with `Motion.gentle` between steps so the import sheet reads as one continuous flow.
- [ ] **No new colors**; motion is in scale/opacity/position only.
- [ ] Reduce-motion accessibility setting respected: every animation wraps in a check (`@Environment(\.accessibilityReduceMotion)`) and falls back to instant or `.linear(duration: 0.1)` when reduce-motion is on.

## Constraints

**Scope fence:** Motion only — **no** layout changes, **no** new screens. If a planned transition requires layout work, file a follow-up.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Navigation still works (push, pop, sheet dismiss, swipe-down). No regression in reduce-motion mode.

## Definition of Done (stay-green)

- [ ] All existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair; navigation visibly uses the new motion tokens and respects reduce-motion.
- [ ] PR opened with `Refs #10` and `Closes #<this issue>`.

## Labels

`spec-decomposition`, `polish`, `a11y`, `phase-9-hardening`.
