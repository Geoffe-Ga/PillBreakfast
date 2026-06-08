## Role

You are a senior watchOS / SwiftUI engineer completing the Ultra Action Button feature: routing the high-risk one-press into the existing press-and-hold confirm screen, giving the eyes-free press its haptic feedback vocabulary, and handling Ultra-only availability so non-Ultra watches never crash or show dead UI.

## Goal

Add an `@MainActor @Observable` `ActionButtonRouter` (mirroring `NotificationActionRouter`) that `LogNextPillIntent`'s high-risk outcome populates; have `RightNowView` observe it and present the existing high-risk `MarkTakenView` (press-and-hold ring, amber accent, hold duration from `UserPreferences`). Wire the three eyes-free haptics (logged / caught-up / failed), call `reloadAllTimelines()` after a successful log, debounce rapid double-presses, and gate any binding-guidance UI to where the Action Button hardware exists — with no crash and no dead UI on Series watches.

## Context

- **Parent epic:** #71
- **Predecessor:** #71 child #02 (`EPIC_71_ISSUE_02_log-next-pill-intent.md` — `LogNextPillIntent` + `AppShortcutsProvider`; the high-risk outcome brings the app forward and leaves a marked routing seam).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-71_ultra-action-button.md` §5.3 (the high-risk routing path — `ActionButtonRouter` + `RightNowView` presentation), §5.4 (Ultra-only availability), §7 (UX — haptics, amber reserved, all caught-up feedback), §8 (edge cases — rapid double-press debounce, write fails → dose stays pending, regimen lost the med, non-Ultra), §10 (router + availability tests).
- **Files involved:**
  - `Shared/Intents/ActionButtonRouter.swift` (new) — `@MainActor @Observable` singleton; `pendingHighRiskConfirm: ActionButtonConfirmContext?`, `requestHighRiskConfirm(_:)`, with a short in-flight debounce.
  - `ActionButtonConfirmContext` — `Identifiable, Sendable, Hashable` wrapping the `PendingDose`.
  - `PillBreakfast Watch App Watch App/.../RightNowView.swift` — already injects/observes `NotificationActionRouter`; add a sibling observation on `ActionButtonRouter.pendingHighRiskConfirm` that pushes/sheets the existing high-risk `MarkTakenView` for that dose.
  - `PillBreakfast Watch App Watch App/Bootstrap/NotificationActionRouter.swift` — the pattern to mirror (out-of-band action → root-view presentation).
  - `PillBreakfast Watch App Watch App/TapThroughQueue/TapThroughQueueView.swift` / `MarkTakenView` — the press-and-hold ring screen reused verbatim (`UserPreferences.highRiskHoldDurationSeconds`).
  - the watch Settings view — add an Ultra-only advisory hint pointing to system Settings → Action Button.
  - the haptics helper (e.g. `Haptics`) — `.doseLogged`, `.allCaughtUp`, and a failure haptic.
- **Prior decisions (locked):**
  - Reuse the `NotificationActionRouter` pattern: an `@MainActor @Observable` router the root view observes; the intent stashes a target and the root view presents the confirm screen.
  - The high-risk path reuses the **existing** `MarkTakenView` press-and-hold screen unchanged. **The safety gate is unchanged** — lithium still requires the deliberate hold; releasing early / backing out logs **nothing** (the dose stays pending).
  - **Amber stays reserved** for the high-risk press-and-hold confirmation only (CLAUDE.md). No color anywhere else.
  - Eyes-free feedback by haptic: distinct **logged**, **all-caught-up**, and **failed** haptics so the user learns the taps by feel. Non-high-risk log is silent (no screen), just the confirming haptic; `reloadAllTimelines()` after a successful log.
  - **Rapid double-press** is debounced in the router so an accidental double-press doesn't log two different pills (tune the window — a single named constant).
  - **Write failure** → failure haptic and the dose stays pending (a re-press retries). Silent failure on a med tracker is the worst outcome.
  - **Ultra-only:** the intent is always shipped and harmless via Shortcuts on non-Ultra. Binding-guidance copy is advisory (there is no public `isUltra`; rely on the system not offering the binding elsewhere). No crash, no dead UI on Series watches.
- **Open (confirm against the SDK):** the haptic vocabulary fidelity on the wrist; the debounce window; that the routing context survives an app launch from asleep (persist in the `@MainActor` router until the root view presents it).

## Output Format

A single PR containing:

- [ ] `ActionButtonRouter` (`@MainActor @Observable`): `pendingHighRiskConfirm: ActionButtonConfirmContext?`, `requestHighRiskConfirm(_:)`, in-flight debounce (named constant).
- [ ] `ActionButtonConfirmContext: Identifiable, Sendable, Hashable` over `PendingDose`.
- [ ] `LogNextPillIntent`'s high-risk seam now calls `ActionButtonRouter.shared.requestHighRiskConfirm(...)` and brings the app forward.
- [ ] `RightNowView` presents the existing high-risk `MarkTakenView` on `pendingHighRiskConfirm`; early release / back-out logs nothing and clears the context.
- [ ] Haptics: `.doseLogged` (success), `.allCaughtUp` (nothing due), failure haptic (write failed); `reloadAllTimelines()` after a successful log.
- [ ] Ultra-only advisory Settings hint (watch), shown only where applicable; non-Ultra invocation is a no-crash no-op surface.
- [ ] Tests: `requestHighRiskConfirm` sets/clears `pendingHighRiskConfirm`; debounce suppresses a second in-flight request; the intent is a no-op-safe surface on non-Ultra (no crash when invoked); high-risk routing sets the context and writes **no** `DoseEvent`.

## Examples

```swift
public struct ActionButtonConfirmContext: Identifiable, Sendable, Hashable {
    public let pendingDose: PendingDose
    public var id: UUID { pendingDose.id }
}

@MainActor
@Observable
public final class ActionButtonRouter {
    public static let shared = ActionButtonRouter()
    /// Non-nil while the root view should present the press-and-hold confirm for this dose.
    public var pendingHighRiskConfirm: ActionButtonConfirmContext?
    public func requestHighRiskConfirm(_ ctx: ActionButtonConfirmContext) {
        pendingHighRiskConfirm = ctx   // debounced; root view presents MarkTakenView
    }
}
```

## Constraints

**Scope fence:** Router + root-view high-risk presentation + haptics + Ultra availability handling only. **No** changes to the shared decision helper (#01) or the intent's logging path (#02) beyond wiring the high-risk seam to the router. **No** new logging logic. **No** redesign of `MarkTakenView` — reuse it verbatim. **No** color outside the high-risk amber confirm. **No** iPhone Action Button surface. **No** PRN or meal one-press.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run on the paired simulator. End-to-end: pressing the Action Button (or invoking the intent) with a non-high-risk dose due logs it silently with a confirming haptic and refreshed complication; with a high-risk dose due it opens the app onto the press-and-hold confirm, where releasing early logs nothing; nothing due plays the caught-up haptic; non-Ultra watches behave harmlessly with no crash. Amber appears only on the high-risk confirm.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #71`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`, `watch`
