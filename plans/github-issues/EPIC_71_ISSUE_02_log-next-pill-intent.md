## Role

You are a senior watchOS / App Intents engineer exposing a runnable `LogNextPillIntent` that the watchOS 26 system can offer as an Apple Watch Ultra Action Button option. The intent is a thin adapter over the shared decision helper from child #01 — it adds no logging logic of its own.

## Goal

Ship `LogNextPillIntent` (an `AppIntent`) whose `perform()` calls the shared `LogNextPendingDose` decision helper and maps its outcome to an intent result, and expose it via an `AppShortcutsProvider` so the system can present it as an Action Button (and Siri/Shortcuts) option. The non-high-risk outcome logs silently (`openAppWhenRun = false`); the high-risk outcome brings the app forward (the router presentation itself lands in child #03 — this child wires the open/forward decision and leaves a clearly-marked seam the router plugs into).

## Context

- **Parent epic:** #71
- **Predecessor:** #71 child #01 (`EPIC_71_ISSUE_01_shared-log-next-decision-helper.md` — the shared `@MainActor` decision helper with the three-way outcome).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-71_ultra-action-button.md` §5.1 (how watchOS 26 exposes the Action Button — App Intents + `AppShortcutsProvider`), §5.2 (the intent), §5.4 (Ultra-only availability — intent always shipped, harmless via Shortcuts elsewhere), §11 (open: exact binding mechanism + `openAppWhenRun` vs `opensIntent`).
- **Files involved:**
  - `Shared/Intents/LogNextPillIntent.swift` (new) — the `AppIntent`; `perform()` is `@MainActor` and delegates to the shared helper.
  - the `AppShortcutsProvider` (watch app target, or `Shared/Intents/`) — register the intent so the system surfaces it as an Action Button option.
  - `Shared/Intents/LogNextDoseIntent.swift` — reference adapter; `LogNextPillIntent` mirrors its structure as a sibling over the same helper.
  - `PersistenceController.shared.container.mainContext` — the shared App Group store, accessed exactly as the WC coordinator and widget intent do.
- **Prior decisions (locked):**
  - App Intents is the integration path for the Action Button (and Siri/Shortcuts/Spotlight). The intent must be exposed via `AppShortcutsProvider` to be discoverable to the system action surfaces.
  - The intent adds **no** logging logic — it delegates entirely to the shared helper from #01 so the safety decision stays in one place.
  - Non-high-risk outcome → silent log (`openAppWhenRun = false`). High-risk outcome → bring the app forward and route to the press-and-hold confirm (NEVER auto-log). The actual router + presentation is child #03; this child wires the "open the app" decision and a marked seam.
  - The whole `perform()` is `@MainActor`; reuses `PersistenceController.shared.container.mainContext`. No new actors. No `@unchecked Sendable`.
- **Open (confirm against Xcode 26 SDK before coding):**
  - The exact mechanism by which a watchOS 26 app declares an intent as Action-Button-bindable specifically (vs. Siri/Shortcuts only) — purely `AppShortcutsProvider`, a specific intent protocol, or an Info.plist key.
  - Whether an intent can decide *at runtime* to come forward (high-risk) vs. stay background (safe) cleanly, or whether a returned `opensIntent` / a second intent is needed.

## Output Format

A single PR containing:

- [ ] `LogNextPillIntent: AppIntent` with `title`, `openAppWhenRun = false` default, and a `@MainActor perform()` that calls `LogNextPendingDose.resolve(now:in:)` against `PersistenceController.shared.container.mainContext` and maps the outcome to an `IntentResult` (caught-up → `.result()`; logged → `.result()`; high-risk → bring app forward via the SDK-confirmed mechanism + a marked routing seam).
- [ ] An `AppShortcutsProvider` registering `LogNextPillIntent` so the system can present it as an Action Button option.
- [ ] A short doc comment recording the confirmed watchOS 26 binding mechanism and the `openAppWhenRun`/`opensIntent` decision, so #03 and future readers know the chosen route.
- [ ] Tests: invoking the intent with a non-high-risk next dose produces the same outcome as the shared helper (parity, ideally by testing the helper once with the intent as a thin adapter); invoking with no pending dose is a safe no-op; the high-risk outcome does **not** write a `DoseEvent`.

## Examples

```swift
// Shared/Intents/ — same module as the shared helper so the safety decision is shared.
struct LogNextPillIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Next Pill"
    static let openAppWhenRun = false   // flipped/handled at runtime for the high-risk path

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = PersistenceController.shared.container.mainContext
        switch try LogNextPendingDose.resolve(now: .now, in: context) {
        case .caughtUp:                       /* caught-up haptic (wired in #03) */ return .result()
        case .logged:                         /* haptic + reload handled in helper/#03 */ return .result()
        case .routeHighRiskConfirm(let dose): /* seam: router request lands in #03 */ return .result(/* opensIntent: ... */)
        }
    }
}
```

## Constraints

**Scope fence:** The `AppIntent` + `AppShortcutsProvider` exposure + the open/forward decision only. **No** logging logic in the intent (delegate to #01's helper). **No** `ActionButtonRouter`, root-view presentation, debounce, or haptic vocabulary (child #03 — leave a clearly-marked seam). **No** iPhone Action Button surface (the iPhone never logs). **No** PRN or meal logging via the button.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run on the paired simulator. The intent is invocable (via Shortcuts on any watch, and as an Action Button option where the SDK surfaces it) and logs the next non-high-risk pending dose using the shared helper. The high-risk path brings the app forward but the press-and-hold confirm presentation arrives in #03 — until then the high-risk path safely no-ops the log (never auto-logs). The widget continues to behave as before.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #71`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`, `watch`
